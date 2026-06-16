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

## 配對手機(QR enrollment,設計 A)

`enroll` 子指令產生 proxy 密鑰、存後端、組憑證包,並在終端機印 ASCII QR(需 `qrencode`,
無頭 Linux 亦可)。**一次性配對**——人在主機旁掃一次,之後遠端用手機儲存的憑證連。

```bash
# 需先安裝 qrencode:brew install qrencode / apt install qrencode
./app-tunnel-proxy enroll \
  -endpoint wss://term.<你的網域>/ws \
  -cf-access-id <CF Access client id> -cf-access-secret <CF Access client secret> \
  -ttyd-user <user> -ttyd-pass <pass> \
  -secret-backend keychain -keychain-service app-tunnel -keychain-account proxy-token
# 預設每次 enroll 產生「新」密鑰(=輪替);要重用既有密鑰加 -reuse
```

QR 含全部憑證明文、僅顯示一次,**勿截圖外流**。格式見 `../docs/contract.md`。

## 執行(serve)

```bash
# macOS
./app-tunnel-proxy serve -listen 127.0.0.1:8080 -ttyd http://127.0.0.1:7681 \
  -secret-backend keychain -keychain-service app-tunnel -keychain-account proxy-token

# Linux
./app-tunnel-proxy serve -listen 127.0.0.1:8080 -ttyd http://127.0.0.1:7681 \
  -secret-backend file -secret-file ~/.config/app_tunnel/token
```

(`serve` 為預設子指令,可省略。)

常駐部署見 `../deploy/`(launchd / systemd)。

## 測試與 CI

```bash
go vet ./... && go test ./... -count=1
```

CI gate 見 `../.github/workflows/ci.yml`(vet + test + darwin/linux build)。

## 已硬化

- [x] 單元測試:認證閘道(無/錯/對 token + 不上傳 token)、`secret` Store/Load roundtrip、權限拒絕、env、未知後端、enroll 憑證包/密鑰長度
- [x] 結構化稽核 log(JSON):記錄**放行**與拒絕連線、真實 client_ip(CF-Connecting-Ip)、依賴失敗分類
- [x] graceful shutdown(SIGTERM 先停收新連線)
- [x] proxy→ttyd 明確 dial timeout

## 待辦

- [ ] 連線數限制(rate limit)
- [ ] (Phase 2 選項)自行用 `creack/pty` 開 PTY、拿掉 ttyd 依賴(`apptunnel/v1` 協議)
