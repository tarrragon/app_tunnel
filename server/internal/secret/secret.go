// Package secret 提供可插拔的密鑰載入後端。
//
// 跨平台設計:macOS 用 keychain(security CLI)、Linux 與通用情境用 file(0600)、
// CI/容器用 env。proxy 啟動時依設定挑後端,密鑰本體不寫進 repo。
package secret

import (
	"fmt"
	"os"
	"os/exec"
	"runtime"
	"strings"
)

// Config 指定密鑰來源後端與其參數。
type Config struct {
	Backend string // "file" | "keychain" | "env"

	// file 後端
	FilePath string

	// keychain 後端(僅 darwin)
	KeychainService string
	KeychainAccount string

	// env 後端
	EnvVar string
}

// Load 依設定的後端取得密鑰,回傳去除前後空白的字串。
func Load(c Config) (string, error) {
	switch c.Backend {
	case "file":
		return loadFile(c.FilePath)
	case "keychain":
		return loadKeychain(c.KeychainService, c.KeychainAccount)
	case "env":
		v := strings.TrimSpace(os.Getenv(c.EnvVar))
		if v == "" {
			return "", fmt.Errorf("secret: 環境變數 %s 為空", c.EnvVar)
		}
		return v, nil
	default:
		return "", fmt.Errorf("secret: 未知後端 %q(支援 file|keychain|env)", c.Backend)
	}
}

// loadFile 從 0600 檔讀密鑰。權限過寬即拒絕,避免同群組/他人可讀。
func loadFile(path string) (string, error) {
	if path == "" {
		return "", fmt.Errorf("secret: file 後端需要 -secret-file 路徑")
	}
	info, err := os.Stat(path)
	if err != nil {
		return "", fmt.Errorf("secret: 讀取 %s 失敗: %w", path, err)
	}
	if perm := info.Mode().Perm(); perm&0o077 != 0 {
		return "", fmt.Errorf("secret: %s 權限過寬 (%#o),請 chmod 600", path, perm)
	}
	b, err := os.ReadFile(path)
	if err != nil {
		return "", fmt.Errorf("secret: 讀取 %s 失敗: %w", path, err)
	}
	v := strings.TrimSpace(string(b))
	if v == "" {
		return "", fmt.Errorf("secret: %s 內容為空", path)
	}
	return v, nil
}

// loadKeychain 透過 macOS security CLI 讀 generic password。非 darwin 直接報錯導向 file。
func loadKeychain(service, account string) (string, error) {
	if runtime.GOOS != "darwin" {
		return "", fmt.Errorf("secret: keychain 後端僅支援 macOS(目前 %s),請改用 -secret-backend file", runtime.GOOS)
	}
	if service == "" || account == "" {
		return "", fmt.Errorf("secret: keychain 後端需要 -keychain-service 與 -keychain-account")
	}
	out, err := exec.Command("security", "find-generic-password", "-s", service, "-a", account, "-w").Output()
	if err != nil {
		return "", fmt.Errorf("secret: 從 keychain 讀取失敗(service=%s account=%s): %w", service, account, err)
	}
	v := strings.TrimSpace(string(out))
	if v == "" {
		return "", fmt.Errorf("secret: keychain 項目為空")
	}
	return v, nil
}
