# app_tunnel 使用說明

從零到可用的完整指引。依照順序執行即可完成：主機設定 → 配對 → 手機連線。

---

## 快速開始（一鍵）

根目錄的 `bootstrap.sh` 會自動完成「檢查依賴 → 缺就安裝（ttyd/qrencode/Go）→ 編譯 proxy → 起服務」：

```bash
./bootstrap.sh -u "你的帳號:你的密碼"

# 或用環境變數
export TTYD_CRED="你的帳號:你的密碼"
./bootstrap.sh
```

旗標與 `deploy/scripts/start.sh` 一致（`-p` proxy port、`-t` ttyd port、`-b` proxy binary）。`-u` 和 `TTYD_CRED` 環境變數二選一，必須提供 ttyd basic auth 帳密。

啟動成功後會看到類似輸出：

```
==> 環境：macos（安裝指令：brew install）
==> 檢查 / 安裝外部依賴
  [OK] ttyd 已安裝
  [OK] qrencode 已安裝
  [OK] go 1.26.1（符合 1.21+）
==> 檢查 Tailscale
  [OK] tailscale 已連線
==> 檢查 / 編譯 Go proxy
  [OK] proxy binary 已存在：./server/app-tunnel-proxy
==> 啟動服務
Starting ttyd on 127.0.0.1:7681 ...
  ttyd PID: 12345
Starting app-tunnel-proxy on 127.0.0.1:8080 ...
  proxy PID: 12346
All services started.
```

> ttyd 啟動時 libwebsockets 可能印出 `[WARNING]` 訊息（如 `Can't open /etc/lws-test-sshd-server-key`、`ssh pvo "ops" is mandatory` 等），這些是 libwebsockets 內建功能模組的提示，與 ttyd 運作無關，可安全忽略。看到 `Listening on port: 7681` 即代表 ttyd 啟動成功。

> Tailscale 例外：`bootstrap.sh` 只檢查不自動安裝（`tailscale up` 需互動式瀏覽器登入），缺失時會印出安裝指引。請先依 Step 3 把主機與手機加入同一 tailnet。
>
> 完成後跳到 Step 5 配對。仍想了解每一步細節，往下讀 Step 1-8。

---

## 前置需求

| 項目 | 主機 | 手機（iPad / iPhone） |
|------|------|------|
| 作業系統 | macOS / Linux | iOS / Android |
| Tailscale | 已安裝並加入 tailnet | App Store 安裝並加入**同一** tailnet |
| ttyd | 已安裝 | - |
| Go 1.21+ | 編譯 proxy 用 | - |
| qrencode | 產生 QR 用（建議） | - |
| Xcode | 編譯 Flutter app 用（免費 Apple ID 即可） | - |
| Flutter app | - | 透過 Xcode 或 `flutter run` 安裝 |

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

手機端：App Store 搜尋「Tailscale」→ 安裝 → 開啟 → 用同一帳號登入 → 裝置自動加入 tailnet。

確認雙方已連線：

```bash
tailscale status
# 應看到主機和手機都列在 tailnet 中，狀態 active
```

記下主機的 Tailscale IP（100.x.y.z）或 MagicDNS 名稱，後續配對要用。

---

## Step 3.5：安裝 Flutter app 到 iOS 裝置

### 3.5.1 Xcode 簽章設定（免費 Apple ID 即可）

不需要付費 Apple Developer 帳號，免費 Apple ID 就能在自己的裝置上開發測試。

1. 開啟 Xcode → **Settings → Accounts** → 點 `+` 加入你的 Apple ID
2. 開啟專案：
   ```bash
   open app/ios/Runner.xcworkspace
   ```
3. 左側選 **Runner** project → 選 **Runner** target → **Signing & Capabilities** 頁籤
4. **Team** 下拉選你的 Apple ID（顯示為「Personal Team」）
5. 確認 **Bundle Identifier** 是唯一的（例如改成 `com.你的名字.apptunnel`）

> 如果 Xcode 彈出「Runner.xcworkspace has been modified by another application」，選 **Use the version on Disk**。

### 3.5.2 安裝到裝置

接上 iPad / iPhone，從專案根目錄執行：

```bash
# debug mode（需保持接線，適合開發測試）
cd app && flutter run

# release mode（可脫離電腦獨立使用，推薦）
cd app && flutter run --release
```

> **debug vs release**：debug mode 的 app 只能從 `flutter run` 或 Xcode 啟動，無法從主畫面直接開啟。如果要脫離電腦獨立使用，必須用 `flutter run --release` 安裝。

### 3.5.3 信任開發者憑證（首次安裝）

第一次安裝後直接開啟 app 會顯示「未受信任的開發者」，需在裝置上手動信任：

1. 開啟 **設定 → 一般 → VPN 與裝置管理**
2. 在「開發者 App」區塊點選你的 Apple ID
3. 點 **信任** → 確認

完成後即可正常開啟 app。

> 免費 Apple ID 限制：app 簽章 7 天過期需重新安裝（再跑一次 `flutter run --release`）、同時最多安裝 3 個 app、無法上架 App Store。自用開發測試不受影響。

### 3.5.4 清理編譯快取（磁碟空間不足時）

Flutter build 和 Xcode DerivedData 可能佔用超過 1 GB，空間不足時可清除：

```bash
# Flutter build 產物
rm -rf app/build

# Xcode 快取
rm -rf ~/Library/Developer/Xcode/DerivedData
```

下次 `flutter run` 會自動重建。

---

## Step 4：啟動服務

### 方式 A：使用 bootstrap.sh（推薦）

從專案根目錄執行，自動檢查依賴、編譯、啟動：

```bash
./bootstrap.sh -u "你的帳號:你的密碼"
```

### 方式 B：使用起停腳本

已自行安裝依賴並編譯 proxy 後，直接用起停腳本：

```bash
./deploy/scripts/start.sh -u "你的帳號:你的密碼" -p 8080
```

參數說明（`bootstrap.sh` 與 `start.sh` 共用）：
- `-u user:pass`：ttyd basic auth 帳密（**必填**，或設定環境變數 `TTYD_CRED`）
- `-p 8080`：proxy 監聯 port（預設 8080）
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

### 方式 C：手動啟動

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
| `ERROR: ttyd basic auth required` | 啟動時未提供帳密。用 `-u "帳號:密碼"` 或設定 `export TTYD_CRED="帳號:密碼"` |
| ttyd 印出 `[WARNING]` 訊息 | libwebsockets 內建模組的提示（SSH demo、raw file test 等），與 ttyd 無關。看到 `Listening on port: 7681` 即成功 |
| 手機連不上 | `tailscale status` 確認雙方在線；`curl http://127.0.0.1:8080/` 確認 proxy 在跑 |
| 401 認證失敗 | 確認 enroll 的帳密和 ttyd 啟動的帳密一致；或重新配對 |
| QR 掃描失敗 | 確認 qrencode 已安裝；終端機字型不要太小；光線充足 |
| 終端機無回應 | proxy log（stderr）查看是否有 502；確認 ttyd 在 7681 port 運行 |
| proxy 啟動失敗 | 確認 port 未被占用：`lsof -i :8080` |
| 手機沒有 Tailscale | 必須安裝 Tailscale app 並加入同一 tailnet |
| `No valid code signing certificates` | Xcode 未設定簽章。依 Step 3.5.1 加入 Apple ID 並設定 Team |
| iPad 顯示「未受信任的開發者」 | 依 Step 3.5.3 到設定 → 一般 → VPN 與裝置管理 信任開發者 |
| app 從主畫面開啟顯示 debug mode 提示 | debug mode 不能從主畫面啟動，改用 `flutter run --release` 安裝 |
| 編譯時磁碟空間不足 | 清除 `app/build/` 和 `~/Library/Developer/Xcode/DerivedData/`（見 Step 3.5.4） |

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
