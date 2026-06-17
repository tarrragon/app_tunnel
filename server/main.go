// Command app-tunnel-proxy 是 app_tunnel 的本機稽核代理。
//
// 職責:透明反向代理到本機 ttyd(WebSocket 一併轉發),記錄結構化稽核 log。
// 不做認證——認證由 Tailscale 裝置認證(網路層)與 ttyd basic auth(應用層)負責。
//
// 子指令:serve(預設,透明 proxy)、enroll(QR 配對)。詳見 docs/contract.md。
package main

import (
	"context"
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
)

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
		listen = fs.String("listen", "127.0.0.1:8080", "proxy 監聽位址(Tailscale 內網)")
		ttydURL = fs.String("ttyd", "http://127.0.0.1:7681", "本機 ttyd 位址")
		dialTO  = fs.Duration("ttyd-dial-timeout", 5*time.Second, "連 ttyd 的建立連線逾時")
	)
	fs.Parse(args)

	// 結構化稽核 log(JSON):連線事件可 grep、可關聯。絕不記 PTY 內容。
	logger := slog.New(slog.NewJSONHandler(os.Stderr, nil))

	target, err := url.Parse(*ttydURL)
	if err != nil {
		logger.Error("ttyd URL 無效", "err", err.Error())
		os.Exit(1)
	}

	srv := &http.Server{
		Addr:    *listen,
		Handler: proxyHandler(target, *dialTO, logger),
	}

	ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	defer stop()

	go func() {
		logger.Info("proxy 啟動", "listen", *listen, "ttyd", target.String())
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

// proxyHandler 建立透明反向代理到 ttyd,記錄稽核 log。
// 抽成函式以便單元測試。
func proxyHandler(target *url.URL, dialTimeout time.Duration, logger *slog.Logger) http.Handler {
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
		logger.Error("轉發 ttyd 失敗", "err", err.Error(), "client_ip", r.RemoteAddr)
		w.WriteHeader(http.StatusBadGateway)
	}

	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		// 稽核:記錄連線事件——對 shell 閘道,什麼連線通過了是入侵指標。
		logger.Info("connection accepted",
			"client_ip", r.RemoteAddr, "path", r.URL.Path, "websocket", isWebSocketUpgrade(r))
		proxy.ServeHTTP(w, r)
	})
}

func isWebSocketUpgrade(r *http.Request) bool {
	return strings.EqualFold(r.Header.Get("Upgrade"), "websocket")
}
