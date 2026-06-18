# app_tunnel 使用說明

從零到可用的完整指引。依照順序執行即可完成：主機設定 → 配對 → 手機連線。

---

## 快速開始（一鍵）

根目錄的 `bootstrap.sh` 會自動完成「檢查依賴 → 缺就安裝（ttyd/qrencode/Go）→ 編譯 proxy → 起服務」：

```bash
./bootstrap.sh -u "你的帳號:你的密碼"
```

旗標與 `deploy/scripts/start.sh` 一致（`-p` proxy port、`-t` ttyd port、`-b` proxy binary）。

> Tailscale 例外：`bootstrap.sh` 只檢查不自動安裝（`tailscale up` 需互動式瀏覽器登入），缺失時會印出安裝指引。請先依 Step 3 把主機與手機加入同一 tailnet。
>
> 完成後跳到 Step 5 配對。仍想了解每一步細節，往下讀 Step 1-8。

---

## 前置需求

| 項目 | 主機 | 手機 |
|------|------|------|
| 作業系統 | macOS / Linux | iOS / Android |
| Tailscale | 已安裝並加入 tailnet | 已安裝並加入**同一** tailnet |
| ttyd | 已安裝 | - |
| Go 1.21+ | 編譯 proxy 用 | - |
| qrencode | 產生 QR 用（建議） | - |
| Flutter app | - | 已安裝 app_tunnel app |

---

## Step 1：編譯 Go proxy

```bash
cd server
go build -o app-tunnel-proxy .
```

產出 `server/app-tunnel-proxy` 單一 binary。

---

## Step 2：安裝外部依賴

### macOS

```bash
brew install ttyd qrencode
# Tailscale：下載 macOS app https://tailscale.com/download/mac
```

### Linux (Debian/Ubuntu)

```bash
sudo apt install ttyd qrencode
curl -fsSL https://tailscale.com/install.sh | sh
```

---

## Step 3：加入 Tailscale tailnet

主機和手機都需要加入**同一個** tailnet。

```bash
# 主機
tailscale up
# 瀏覽器會跳出 SSO 登入頁，完成後裝置加入 tailnet
```

手機端：開啟 Tailscale app → 登入同一帳號 → 裝置自動加入 tailnet。

確認雙方已連線：

```bash
tailscale status
# 應看到主機和手機都列在 tailnet 中，狀態 active
```

記下主機的 Tailscale IP（100.x.y.z）或 MagicDNS 名稱，後續配對要用。

---

## Step 4：啟動服務

### 方式 A：使用起停腳本（推薦）

```bash
# 從專案根目錄執行
./deploy/scripts/start.sh -u "你的帳號:你的密碼" -p 8080
```

參數說明：
- `-u user:pass`：ttyd basic auth 帳密（**必填**，這是應用層最後防線）
- `-p 8080`：proxy 監聽 port（預設 8080）
- `-t 7681`：ttyd 監聽 port（預設 7681）
- `-b ./server/app-tunnel-proxy`：proxy binary 路徑

成功會顯示：

```
Starting ttyd on 127.0.0.1:7681 ...
  ttyd PID: 12345
Starting app-tunnel-proxy on 127.0.0.1:8080 ...
  proxy PID: 12346
All services started.
```

### 方式 B：手動啟動

```bash
# 1. 啟動 ttyd（帶 basic auth）
ttyd --port 7681 --interface 127.0.0.1 --credential "你的帳號:你的密碼" /bin/zsh &

# 2. 啟動 proxy
./server/app-tunnel-proxy -listen 127.0.0.1:8080 -ttyd http://127.0.0.1:7681 &
```

### 驗證服務正常

```bash
# 確認 proxy 在監聽
curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:8080/
# 預期：502（proxy 轉發到 ttyd，ttyd 要求 auth）或 401
```

---

## Step 5：首次配對（UC-01）

配對 = 把主機的連線資訊（endpoint + ttyd 帳密）安全灌進手機。只需做一次。

### 5.1 在主機產生 QR

```bash
./server/app-tunnel-proxy enroll \
  -endpoint "http://你的Tailscale-IP:8080/ws" \
  -ttyd-user "你的帳號" \
  -ttyd-pass "你的密碼"
```

- `endpoint`：手機連線用的 WebSocket 位址。格式 `http://<Tailscale-IP>:<proxy-port>/ws`
  - 例：`http://100.64.0.1:8080/ws`
  - 或用 MagicDNS：`http://my-mac:8080/ws`
- `ttyd-user` / `ttyd-pass`：和 Step 4 設定的帳密**一致**

終端機會印出 ASCII QR code：

```
 ██████████████  ████████████  ██████████████
 ██          ██  ██        ██  ██          ██
 ...（QR code）...

 用手機 app 掃描上方 QR 完成配對。憑證包僅顯示這一次，勿截圖外流。
```

> 如果沒安裝 qrencode，會直接印出 JSON 憑證包，可手動輸入。

### 5.2 手機掃描 QR

1. 開啟 app_tunnel app
2. 點「掃描配對」按鈕（或從首頁導航到配對畫面）
3. 掃描主機終端機上的 QR code
4. 成功後顯示「配對成功」提示
5. 憑證已安全存入手機 Keychain/Keystore

### 5.3 關閉 QR 顯示

掃描成功後，在主機終端機按 Enter 或 Ctrl+C 關閉 QR 顯示。QR 含帳密明文，不要截圖。

---

## Step 6：日常連線（UC-02）

配對完成後，每次連線只需：

1. **確認主機服務已啟動**（Step 4）
2. **開啟 app**
3. **Face ID / 指紋解鎖** → 自動讀取儲存的憑證
4. **點「Connect Terminal」** → 建立 Tailscale VPN 內的 WebSocket 連線
5. **操作終端機** → 輸入指令、使用底部工具列的 Esc/Ctrl/方向鍵

### 終端機操作

| 按鍵 | 功能 |
|------|------|
| 底部工具列 `Esc` | 送出 Escape |
| 底部工具列 `Tab` | 送出 Tab（自動補全） |
| 底部工具列 `Ctrl` → 任意字母 | Ctrl 組合鍵（如 Ctrl+C 中斷、Ctrl+D 結束） |
| 底部工具列方向鍵 | 上下左右移動游標 |
| 手機鍵盤 | 正常文字輸入 |

### 斷線重連

- 網路中斷或 Tailscale 斷線時，畫面顯示「連線中斷」
- 點「重新連線」按鈕即可重連
- 如果持續失敗，確認主機服務存活 + Tailscale 雙方上線

---

## Step 7：帳密輪替（UC-03）

定期或懷疑帳密外洩時：

1. **主機**：停止服務 → 修改 ttyd 帳密 → 重啟服務（用新帳密）
2. **主機**：重跑 `enroll`（用新帳密）→ 終端機顯示新 QR
3. **手機**：重掃 QR → 覆寫舊憑證
4. **驗證**：以新帳密連線成功；舊帳密連線被拒（401）

```bash
# 停止服務
./deploy/scripts/stop.sh

# 用新帳密重啟
./deploy/scripts/start.sh -u "新帳號:新密碼"

# 重新配對
./server/app-tunnel-proxy enroll \
  -endpoint "http://100.64.0.1:8080/ws" \
  -ttyd-user "新帳號" \
  -ttyd-pass "新密碼"
```

---

## Step 8：停止服務（UC-04）

用完就關，不常駐。

```bash
./deploy/scripts/stop.sh
```

或手動：

```bash
pkill -f app-tunnel-proxy
pkill -f ttyd
```

Tailscale daemon 持續運行不影響（只維持 VPN 隧道，不暴露服務）。

---

## 疑難排解

| 問題 | 檢查 |
|------|------|
| 手機連不上 | `tailscale status` 確認雙方在線；`curl http://127.0.0.1:8080/` 確認 proxy 在跑 |
| 401 認證失敗 | 確認 enroll 的帳密和 ttyd 啟動的帳密一致；或重新配對 |
| QR 掃描失敗 | 確認 qrencode 已安裝；終端機字型不要太小；光線充足 |
| 終端機無回應 | proxy log（stderr）查看是否有 502；確認 ttyd 在 7681 port 運行 |
| proxy 啟動失敗 | 確認 port 未被占用：`lsof -i :8080` |
| 手機沒有 Tailscale | 必須安裝 Tailscale app 並加入同一 tailnet |

### 查看 proxy 稽核 log

proxy 的結構化稽核 log 輸出到 stderr（JSON 格式）：

```bash
# 即時查看
./server/app-tunnel-proxy -listen 127.0.0.1:8080 2>&1 | jq .

# 輸出到檔案
./server/app-tunnel-proxy -listen 127.0.0.1:8080 2>proxy-audit.log &
```

---

## 安全提醒

- QR 含 ttyd 帳密明文，掃完即關，**不要截圖**
- ttyd 帳密用強密碼，不要用 `admin:admin`
- 定期輪替帳密（Step 7）
- Tailscale ACL 限制只有你的裝置可連（見 `deploy/configs/tailscale-acl.json.example`）
- proxy 綁 `127.0.0.1`，不監聽公開網路
