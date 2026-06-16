// Command app-tunnel-proxy 是 app_tunnel 的本機認證閘道。
//
// 職責:驗證來自 Cloudflare Tunnel 的連線帶有正確的本機密鑰(X-App-Tunnel-Token),
// 通過才透明反向代理到本機 ttyd(WebSocket 一併轉發)。這是「通往完整 shell」的
// 第二道認證(第一道:Cloudflare Access 邊緣;第三道:ttyd basic auth 本機最後防線)。
//
// 子指令:serve(預設,認證 proxy)、enroll(QR 配對)。詳見 docs/contract.md。
package main

import (
	"context"
	"crypto/subtle"
	"flag"
	"log/slog"
	"net"
	"net/http"
	"net/http/httputil"
	"net/url"
	"os"
	"os/signal"
	"strings"
	"syscall"
	"time"

	"github.com/tarrragon/app_tunnel/server/internal/secret"
)

// tokenHeader 是 app 帶本機密鑰用的 header,與 ttyd 的 Authorization 不衝突。
const tokenHeader = "X-App-Tunnel-Token"

func main() {
	if len(os.Args) > 1 && os.Args[1] == "enroll" {
		runEnroll(os.Args[2:])
		return
	}
	args := os.Args[1:]
	if len(args) > 0 && args[0] == "serve" {
		args = args[1:]
	}
	runServe(args)
}

func runServe(args []string) {
	fs := flag.NewFlagSet("serve", flag.ExitOnError)
	var (
		listen    = fs.String("listen", "127.0.0.1:8080", "proxy 監聽位址(只綁本機,對外由 cloudflared 接)")
		ttydURL   = fs.String("ttyd", "http://127.0.0.1:7681", "本機 ttyd 位址")
		backend   = fs.String("secret-backend", "file", "密鑰後端:file|keychain|env")
		secFile   = fs.String("secret-file", "", "file 後端:密鑰檔路徑(需 0600)")
		kcService = fs.String("keychain-service", "app-tunnel", "keychain 後端:service 名")
		kcAccount = fs.String("keychain-account", "proxy-token", "keychain 後端:account 名")
		envVar    = fs.String("secret-env", "APP_TUNNEL_TOKEN", "env 後端:環境變數名")
		dialTO    = fs.Duration("ttyd-dial-timeout", 5*time.Second, "連 ttyd 的建立連線逾時")
	)
	fs.Parse(args)

	// 結構化稽核 log(JSON):放行/拒絕連線事件可 grep、可關聯。絕不記 PTY 內容。
	logger := slog.New(slog.NewJSONHandler(os.Stderr, nil))

	token, err := secret.Load(secret.Config{
		Backend:         *backend,
		FilePath:        *secFile,
		KeychainService: *kcService,
		KeychainAccount: *kcAccount,
		EnvVar:          *envVar,
	})
	if err != nil {
		logger.Error("載入密鑰失敗", "err", err.Error())
		os.Exit(1)
	}

	target, err := url.Parse(*ttydURL)
	if err != nil {
		logger.Error("ttyd URL 無效", "err", err.Error())
		os.Exit(1)
	}

	srv := &http.Server{
		Addr:    *listen,
		Handler: authProxyHandler([]byte(token), target, *dialTO, logger),
	}

	ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	defer stop()

	go func() {
		logger.Info("proxy 啟動", "listen", *listen, "ttyd", target.String(), "backend", *backend)
		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			logger.Error("啟動失敗", "err", err.Error())
			os.Exit(1)
		}
	}()

	<-ctx.Done()
	// Graceful shutdown:先停收新連線(進行中的 WS 終端機 session 會在工具停止時斷開)。
	logger.Info("收到終止訊號,graceful shutdown")
	shutdownCtx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	_ = srv.Shutdown(shutdownCtx)
}

// authProxyHandler 建立認證閘道:constant-time 驗 token,通過才透明反向代理到 ttyd。
// 抽成函式以便單元測試。
func authProxyHandler(token []byte, target *url.URL, dialTimeout time.Duration, logger *slog.Logger) http.Handler {
	proxy := httputil.NewSingleHostReverseProxy(target)
	// 明確 timeout:沒有 timeout 的外部呼叫會把 ttyd 的慢轉成自己的連線耗盡。
	proxy.Transport = &http.Transport{
		DialContext:           (&net.Dialer{Timeout: dialTimeout}).DialContext,
		MaxIdleConns:          10,
		IdleConnTimeout:       90 * time.Second,
		TLSHandshakeTimeout:   10 * time.Second,
		ExpectContinueTimeout: 1 * time.Second,
	}
	proxy.ErrorHandler = func(w http.ResponseWriter, r *http.Request, err error) {
		// 依賴(ttyd)失敗,與 client 端 4xx 分開計數。
		logger.Error("轉發 ttyd 失敗", "err", err.Error(), "client_ip", clientIP(r))
		w.WriteHeader(http.StatusBadGateway)
	}

	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		got := []byte(r.Header.Get(tokenHeader))
		if subtle.ConstantTimeCompare(got, token) != 1 {
			http.NotFound(w, r) // 預設拒絕、回 404 不洩漏存在
			logger.Warn("connection rejected", "client_ip", clientIP(r), "path", r.URL.Path)
			return
		}
		// 通過後不把本機密鑰往上游 ttyd 傳。
		r.Header.Del(tokenHeader)
		// 稽核:記錄「放行」連線——對 shell 閘道,什麼連線通過了是入侵指標。
		logger.Info("connection accepted",
			"client_ip", clientIP(r), "path", r.URL.Path, "websocket", isWebSocketUpgrade(r))
		proxy.ServeHTTP(w, r)
	})
}

// clientIP 取真實來源 IP:cloudflared 把實際 client 放進 CF-Connecting-IP;
// 否則退回 X-Forwarded-For、再退回 RemoteAddr(直連時)。
func clientIP(r *http.Request) string {
	if ip := r.Header.Get("Cf-Connecting-Ip"); ip != "" {
		return ip
	}
	if ip := r.Header.Get("X-Forwarded-For"); ip != "" {
		return ip
	}
	return r.RemoteAddr
}

func isWebSocketUpgrade(r *http.Request) bool {
	return strings.EqualFold(r.Header.Get("Upgrade"), "websocket")
}
