package main

import (
	"bytes"
	"crypto/rand"
	"encoding/hex"
	"encoding/json"
	"flag"
	"fmt"
	"log"
	"os"
	"os/exec"

	"github.com/tarrragon/app_tunnel/server/internal/secret"
)

// bundle 是 QR 憑證包(設計 A 對稱),一次性配對灌進手機。格式見 docs/contract.md。
type bundle struct {
	V              int    `json:"v"`
	Protocol       string `json:"protocol"`
	Endpoint       string `json:"endpoint"`
	CFAccessID     string `json:"cf_access_id"`
	CFAccessSecret string `json:"cf_access_secret"`
	ProxyToken     string `json:"proxy_token"`
	TtydUser       string `json:"ttyd_user"`
	TtydPass       string `json:"ttyd_pass"`
}

// runEnroll 產生(或重用)proxy 密鑰、組憑證包,並在終端機印出 QR 供手機掃描配對。
func runEnroll(args []string) {
	fs := flag.NewFlagSet("enroll", flag.ExitOnError)
	var (
		endpoint  = fs.String("endpoint", "", "wss://term.<你的網域>/ws(必填)")
		cfID      = fs.String("cf-access-id", "", "Cloudflare Access service token client id")
		cfSecret  = fs.String("cf-access-secret", "", "Cloudflare Access service token client secret")
		ttydUser  = fs.String("ttyd-user", "", "ttyd basic auth 帳號")
		ttydPass  = fs.String("ttyd-pass", "", "ttyd basic auth 密碼")
		backend   = fs.String("secret-backend", "file", "proxy 密鑰後端:file|keychain")
		secFile   = fs.String("secret-file", "", "file 後端:密鑰檔路徑")
		kcService = fs.String("keychain-service", "app-tunnel", "keychain 後端:service 名")
		kcAccount = fs.String("keychain-account", "proxy-token", "keychain 後端:account 名")
		reuse     = fs.Bool("reuse", false, "重用既有 proxy 密鑰(預設產生新的=輪替)")
	)
	fs.Parse(args)

	if *endpoint == "" {
		log.Fatal("[enroll] 需要 -endpoint(例:wss://term.example.com/ws)")
	}

	cfg := secret.Config{
		Backend:         *backend,
		FilePath:        *secFile,
		KeychainService: *kcService,
		KeychainAccount: *kcAccount,
	}

	var token string
	if *reuse {
		t, err := secret.Load(cfg)
		if err != nil {
			log.Fatalf("[enroll] 重用既有密鑰失敗: %v", err)
		}
		token = t
	} else {
		token = newToken()
		if err := secret.Store(cfg, token); err != nil {
			log.Fatalf("[enroll] 儲存新密鑰失敗: %v", err)
		}
		log.Printf("[enroll] 已產生新 proxy 密鑰並存入 %s 後端", *backend)
	}

	payload, err := json.Marshal(bundle{
		V:              1,
		Protocol:       "ttyd-tty/v1",
		Endpoint:       *endpoint,
		CFAccessID:     *cfID,
		CFAccessSecret: *cfSecret,
		ProxyToken:     token,
		TtydUser:       *ttydUser,
		TtydPass:       *ttydPass,
	})
	if err != nil {
		log.Fatalf("[enroll] 組憑證包失敗: %v", err)
	}

	renderQR(payload)
}

// newToken 用 crypto/rand 產生 32 bytes(64 hex)密鑰。
func newToken() string {
	buf := make([]byte, 32)
	if _, err := rand.Read(buf); err != nil {
		log.Fatalf("[enroll] 產生密鑰失敗: %v", err)
	}
	return hex.EncodeToString(buf)
}

// renderQR 優先用 qrencode 在終端機印 ASCII QR(零 Go 依賴、無頭 Linux 可用);
// 找不到 qrencode 時退回印出原始憑證包。
func renderQR(payload []byte) {
	if path, err := exec.LookPath("qrencode"); err == nil {
		cmd := exec.Command(path, "-t", "ANSIUTF8", "-o", "-")
		cmd.Stdin = bytes.NewReader(payload)
		cmd.Stdout = os.Stdout
		cmd.Stderr = os.Stderr
		if runErr := cmd.Run(); runErr == nil {
			fmt.Println("\n用手機 app 掃描上方 QR 完成配對。憑證包僅顯示這一次,勿截圖外流。")
			return
		}
	}
	fmt.Fprintln(os.Stderr, "[提示] 未找到 qrencode(brew install qrencode / apt install qrencode)。")
	fmt.Fprintln(os.Stderr, "以下為原始憑證包,請自行轉 QR 或手動灌入 app:")
	fmt.Println(string(payload))
}
