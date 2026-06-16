// Command app-tunnel-proxy 是 app_tunnel 的本機認證閘道。
//
// 職責:驗證來自 Cloudflare Tunnel 的連線帶有正確的本機密鑰(X-App-Tunnel-Token),
// 通過才透明反向代理到本機 ttyd(WebSocket 一併轉發)。這是「通往完整 shell」的
// 第二道認證(第一道:Cloudflare Access 邊緣;第三道:ttyd basic auth 本機最後防線)。
//
// 詳見 docs/contract.md。
package main

import (
	"crypto/subtle"
	"flag"
	"log"
	"net/http"
	"net/http/httputil"
	"net/url"
	"os"

	"github.com/tarrragon/app_tunnel/server/internal/secret"
)

// tokenHeader 是 app 帶本機密鑰用的 header,與 ttyd 的 Authorization 不衝突。
const tokenHeader = "X-App-Tunnel-Token"

func main() {
	// 子指令:enroll(QR 配對)。預設 serve(認證 proxy)。
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
	)
	fs.Parse(args)

	token, err := secret.Load(secret.Config{
		Backend:         *backend,
		FilePath:        *secFile,
		KeychainService: *kcService,
		KeychainAccount: *kcAccount,
		EnvVar:          *envVar,
	})
	if err != nil {
		log.Fatalf("[app-tunnel-proxy] 載入密鑰失敗: %v", err)
	}
	tokenBytes := []byte(token)

	target, err := url.Parse(*ttydURL)
	if err != nil {
		log.Fatalf("[app-tunnel-proxy] ttyd URL 無效: %v", err)
	}
	// SingleHostReverseProxy 自 Go 1.12 起透明處理 WebSocket upgrade。
	proxy := httputil.NewSingleHostReverseProxy(target)

	mux := http.NewServeMux()
	mux.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		// 預設拒絕:密鑰錯或缺一律回 404,不洩漏服務存在(constant-time 比較防時序側信道)。
		got := []byte(r.Header.Get(tokenHeader))
		if subtle.ConstantTimeCompare(got, tokenBytes) != 1 {
			http.NotFound(w, r)
			log.Printf("[app-tunnel-proxy] 拒絕未授權連線 from=%s path=%s", r.RemoteAddr, r.URL.Path)
			return
		}
		// 通過後不把本機密鑰往上游 ttyd 傳。
		r.Header.Del(tokenHeader)
		proxy.ServeHTTP(w, r)
	})

	log.Printf("[app-tunnel-proxy] 監聽 %s → 轉發 %s(密鑰後端=%s)", *listen, target, *backend)
	// TODO(TDD Phase 2/3):graceful shutdown、連線數限制、結構化日誌、單元測試。
	if err := http.ListenAndServe(*listen, mux); err != nil {
		log.Fatalf("[app-tunnel-proxy] 啟動失敗: %v", err)
	}
}
