# server — app_tunnel 本機 proxy(Go)

稽核 log + 透明反向代理到 ttyd。認證由 Tailscale(網路層)+ ttyd basic auth(應用層)處理,proxy 不做認證。
跨平台:Go 編譯到 darwin/linux 皆為單一靜態 binary,零改碼。設計見 `../docs/contract.md`。

## 建置

```bash
cd server
go build -o app-tunnel-proxy .
# 跨編譯到 Linux:
GOOS=linux GOARCH=amd64 go build -o app-tunnel-proxy-linux .
```

## 配對手機(QR enrollment,精簡版)

`enroll` 子指令收集 Tailscale endpoint + ttyd 帳密、組憑證包,並在終端機印 ASCII QR(需 `qrencode`,
無頭 Linux 亦可)。**一次性配對**——人在主機旁掃一次,之後遠端用手機儲存的憑證連。

```bash
# 需先安裝 qrencode:brew install qrencode / apt install qrencode
./app-tunnel-proxy enroll \
  -endpoint http://<tailscale-ip-or-magicDNS>:<port>/ws \
  -ttyd-user <user> -ttyd-pass <pass>
```

QR 含 ttyd 帳密明文、僅顯示一次,**勿截圖外流**。格式見 `../docs/contract.md`。

## 執行(serve)

```bash
./app-tunnel-proxy serve -listen 127.0.0.1:8080 -ttyd http://127.0.0.1:7681
```

(`serve` 為預設子指令,可省略。)

常駐部署見 `../deploy/`(launchd / systemd)。

## 測試與 CI

```bash
go vet ./... && go test ./... -count=1
```

CI gate 見 `../.github/workflows/ci.yml`(vet + test + darwin/linux build)。

## 已硬化

- [x] 結構化稽核 log(JSON):記錄每次連線、client_ip(Tailscale 對端 IP via req.RemoteAddr)
- [x] graceful shutdown(SIGTERM 先停收新連線)
- [x] proxy→ttyd 明確 dial timeout

## 待適配(Tailscale 遷移)

- [ ] 移除認證閘道(X-App-Tunnel-Token 驗證 + constant-time 比較)
- [ ] 簡化 enroll(移除 proxy token 產生 + 可插拔後端 + CF Access 參數)
- [ ] 更新 client_ip 取用(CF-Connecting-Ip → req.RemoteAddr)
- [ ] 移除對應單元測試(認證閘道 3 個測試)

## 待辦

- [ ] (Phase 2 選項)自行用 `creack/pty` 開 PTY、拿掉 ttyd 依賴(`apptunnel/v1` 協議)
