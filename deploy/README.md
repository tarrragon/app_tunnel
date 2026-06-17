# deploy -- app_tunnel 部署與常駐

運作姿態(docs/tech-decisions.md D5):**Tailscale daemon 常駐 + ttyd/proxy 手動起停**(不開機自啟、不 24/7 暴露服務)。
兩個手動行程:`ttyd`(PTY)、`app-tunnel-proxy`(稽核 log + 轉發)。Tailscale daemon 常駐維持 VPN 隧道。

## 連線鏈路

```
Flutter app (Face ID)
   |  WS, 帶 ttyd basic auth 憑證
   v
Tailscale mesh VPN (WireGuard 加密隧道, 裝置級認證)  -- Layer 1
   v
Go proxy (localhost:8765, 稽核 log + 透明轉發, 不做認證)
   v
ttyd (localhost:7681, basic auth)  -- Layer 2
   v
zsh (真實 shell)
```

兩層認證詳見 `docs/contract.md`。

---

## 1. 安裝

### macOS

```bash
brew install ttyd
# Tailscale: 下載 macOS app (https://tailscale.com/download/mac)
# 或
brew install tailscale
```

### Linux (Debian/Ubuntu)

```bash
sudo apt install ttyd
curl -fsSL https://tailscale.com/install.sh | sh
```

### Go proxy (從原始碼編譯)

```bash
cd server
go build -o app-tunnel-proxy .
# binary 產出於 server/app-tunnel-proxy
```

---

## 2. 設定

### 2.1 Tailscale 加入 tailnet

```bash
tailscale up
# 瀏覽器跳 SSO 登入, 裝置加入 tailnet
```

手機端也安裝 Tailscale app 並加入同一 tailnet。

### 2.2 Tailscale ACL (建議)

在 Tailscale Admin Console -> Access Controls 套用 ACL, 限制只有 owner 裝置可存取 proxy port。

範本: `configs/tailscale-acl.json.example`

```bash
cp configs/tailscale-acl.json.example configs/tailscale-acl.json
# 編輯 tailscale-acl.json:
#   YOUR_EMAIL  -> 你的 Tailscale 登入 email
#   PROXY_HOST  -> 執行 proxy 的主機名稱 (tailscale status 可查)
#   PROXY_PORT  -> proxy 監聽 port (預設 8765)
# 將內容貼到 Tailscale Admin Console
```

Tailscale 預設 deny all, 只有 ACL 明確允許的流量才會通過(Layer 1 防護)。

### 2.3 ttyd basic auth (必要)

ttyd basic auth 是應用層最後防線(Layer 2)。

```bash
cp configs/ttyd.conf.example configs/ttyd.conf
# 編輯 ttyd.conf, 至少修改 credential 為強密碼
```

範本: `configs/ttyd.conf.example`

設定要點:
- `credential`: 改為強密碼, 禁止使用預設值
- `interface`: 維持 `127.0.0.1`(僅本機, proxy 透過 localhost 連接)
- `port`: 預設 `7681`, 與 proxy 的 upstream 設定一致

---

## 3. 啟動

**啟動順序**: ttyd -> app-tunnel-proxy (proxy 需要 ttyd 在 7681 待命)。Tailscale daemon 已常駐。

### 手動啟動

```bash
# 1. 啟動 ttyd (背景)
ttyd --config deploy/configs/ttyd.conf /bin/zsh &

# 2. 啟動 proxy (背景)
./server/app-tunnel-proxy &
```

### macOS / launchd

`launchd/` 內的 plist 範本。

```bash
# 載入 (啟動)
launchctl bootstrap gui/$(id -u) launchd/com.apptunnel.proxy.plist

# 卸載 (停止)
launchctl bootout gui/$(id -u) launchd/com.apptunnel.proxy.plist
```

把兩個 plist 視為一組; 不放 `~/Library/LaunchAgents` 自啟, 改在要用時 bootstrap、用完 bootout。

### Linux / systemd

`systemd/` 內的 unit 範本。

```bash
# 啟動
systemctl --user start app-tunnel-proxy

# 停止
systemctl --user stop app-tunnel-proxy
```

**不** `enable`(不開機自啟)。ttyd 比照建 user unit。

---

## 4. 驗證

### 4.1 確認 Tailscale 連線

```bash
tailscale status
# 確認本機和手機都在 tailnet 內, 狀態為 active
```

### 4.2 確認 ttyd 運行

```bash
# ttyd 應監聽在 127.0.0.1:7681
curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:7681/
# 預期: 401 (未帶 auth) 或 200 (帶正確 auth)
```

### 4.3 確認 proxy 運行

```bash
# proxy 應監聽在 0.0.0.0:8765 (或設定的 port)
curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:8765/
# 預期: 502 (ttyd 未回應) 或透明轉發 ttyd 回應
```

### 4.4 端到端測試

從手機 Tailscale 網路內:
1. 開啟 Flutter app
2. Face ID 解鎖
3. 連線至 `ws://<PROXY_HOST>:8765/ws`
4. 確認 shell 互動正常

---

## 5. 停用

用完兩個行程都關掉(proxy + ttyd), 服務即不可達。Tailscale daemon 持續運行不影響。

```bash
# 手動停止
kill %1 %2  # 若用背景行程

# 或 launchd
launchctl bootout gui/$(id -u) launchd/com.apptunnel.proxy.plist

# 或 systemd
systemctl --user stop app-tunnel-proxy
```

---

## 目錄結構

```
deploy/
  configs/
    ttyd.conf.example           # ttyd 配置範本 (basic auth + binding)
    tailscale-acl.json.example  # Tailscale ACL 建議配置
  launchd/
    com.apptunnel.proxy.plist   # macOS launchd 範本
  systemd/
    apptunnel-proxy.service     # Linux systemd user unit 範本
  README.md                     # 本文件
```

---

## 相關文件

- `docs/contract.md` -- 兩層認證契約與 WS 子協議
- `docs/tech-decisions.md` -- 技術選型 (D4 認證、D5 運作姿態)
- `docs/spec/proxy/go-reverse-proxy.md` -- Go proxy 規格
