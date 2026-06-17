package main

import (
	"bytes"
	"encoding/json"
	"flag"
	"fmt"
	"log"
	"os"
	"os/exec"
)

// bundle 是 QR 憑證包(v2, Tailscale),一次性配對灌進手機。格式見 docs/contract.md。
type bundle struct {
	V        int    `json:"v"`
	Protocol string `json:"protocol"`
	Endpoint string `json:"endpoint"`
	TtydUser string `json:"ttyd_user"`
	TtydPass string `json:"ttyd_pass"`
}

// runEnroll 組憑證包,並在終端機印出 QR 供手機掃描配對。
func runEnroll(args []string) {
	fs := flag.NewFlagSet("enroll", flag.ExitOnError)
	var (
		endpoint = fs.String("endpoint", "", "http://<tailscale-ip>:<port>/ws(必填)")
		ttydUser = fs.String("ttyd-user", "", "ttyd basic auth 帳號")
		ttydPass = fs.String("ttyd-pass", "", "ttyd basic auth 密碼")
	)
	fs.Parse(args)

	if *endpoint == "" {
		log.Fatal("[enroll] 需要 -endpoint(例:http://100.x.y.z:7681/ws)")
	}

	payload, err := json.Marshal(buildBundle(*endpoint, *ttydUser, *ttydPass))
	if err != nil {
		log.Fatalf("[enroll] 組憑證包失敗: %v", err)
	}

	renderQR(payload)
}

// buildBundle 組裝 v2 QR 憑證包(抽成函式以便測試)。
func buildBundle(endpoint, ttydUser, ttydPass string) bundle {
	return bundle{
		V:        2,
		Protocol: "ttyd-tty/v1",
		Endpoint: endpoint,
		TtydUser: ttydUser,
		TtydPass: ttydPass,
	}
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
