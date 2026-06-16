# server — app_tunnel 本機認證 proxy(Go)

通往本機 shell 的第二道認證閘道。驗 `X-App-Tunnel-Token` 後透明反向代理到 ttyd。
跨平台:Go 編譯到 darwin/linux 皆為單一靜態 binary,零改碼。設計見 `../docs/contract.md`。

## 建置

```bash
cd server
go build -o app-tunnel-proxy .
# 跨編譯到 Linux:
GOOS=linux GOARCH=amd64 go build -o app-tunnel-proxy-linux .
```

## 產生密鑰

```bash
openssl rand -hex 32
```

一份給 app(存 Keychain/Keystore),一份給 proxy(依下列後端保管)。

## 密鑰後端(可插拔)

| 後端 | 適用 | 旗標 |
|------|------|------|
| `keychain` | macOS(預設保管) | `-secret-backend keychain -keychain-service app-tunnel -keychain-account proxy-token` |
| `file` | **Linux / 通用 fallback** | `-secret-backend file -secret-file ~/.config/app_tunnel/token`(需 `chmod 600`) |
| `env` | CI / 容器 | `-secret-backend env -secret-env APP_TUNNEL_TOKEN` |

macOS 寫入 keychain:

```bash
security add-generic-password -s app-tunnel -a proxy-token -w "$(openssl rand -hex 32)"
```

Linux 建密鑰檔:

```bash
mkdir -p ~/.config/app_tunnel
umask 077 && openssl rand -hex 32 > ~/.config/app_tunnel/token
chmod 600 ~/.config/app_tunnel/token   # proxy 啟動會檢查權限,過寬即拒絕
```

## 執行

```bash
# macOS
./app-tunnel-proxy -listen 127.0.0.1:8080 -ttyd http://127.0.0.1:7681 \
  -secret-backend keychain -keychain-service app-tunnel -keychain-account proxy-token

# Linux
./app-tunnel-proxy -listen 127.0.0.1:8080 -ttyd http://127.0.0.1:7681 \
  -secret-backend file -secret-file ~/.config/app_tunnel/token
```

常駐部署見 `../deploy/`(launchd / systemd)。

## 待辦(TDD Phase 2/3)

- [ ] 單元測試:認證閘道(無/錯/對 token)、各密鑰後端、權限檢查
- [ ] graceful shutdown(SIGTERM 先停收新連線)
- [ ] 連線數限制與結構化日誌
- [ ] (Phase 2 選項)自行用 `creack/pty` 開 PTY、拿掉 ttyd 依賴
