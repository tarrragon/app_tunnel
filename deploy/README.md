# deploy — app_tunnel 部署與常駐

運作姿態(docs/tech-decisions.md D5):**Tailscale daemon 常駐 + ttyd/proxy 手動起停**(不開機自啟、不 24/7 暴露服務)。
兩個手動行程:`ttyd`(PTY)、`app-tunnel-proxy`(稽核 log + 轉發)。Tailscale daemon 常駐維持 VPN 隧道。

## 一次性安裝

```bash
# macOS
brew install ttyd
# Tailscale:下載 macOS app 或 brew install tailscale
# Linux (Debian/Ubuntu)
sudo apt install ttyd
curl -fsSL https://tailscale.com/install.sh | sh
```

## 一次性設定

### 1. Tailscale 加入 tailnet

```bash
tailscale up
# 瀏覽器跳 SSO 登入,裝置加入 tailnet
```

手機端也安裝 Tailscale app 並加入同一 tailnet。

### 2. Tailscale ACL(建議)

在 Tailscale admin console 設定 ACL,限制只有 owner 裝置可存取 proxy port。

### 3. ttyd basic auth(最後防線)

啟動帶 `-c user:password`(見下方服務檔)。

## 啟動順序

`ttyd` → `app-tunnel-proxy`(proxy 要先在 8080 待命)。Tailscale daemon 已常駐。

## 常駐(手動起停)

- **macOS / launchd**:`launchd/` 內的 plist 範本。`launchctl bootstrap gui/$(id -u) <plist>` 起、`bootout` 停。
  把兩個 plist 視為一組;不放 `~/Library/LaunchAgents` 自啟,改在要用時 bootstrap、用完 bootout。
- **Linux / systemd**:`systemd/` 內的 unit 範本(`apptunnel-proxy.service`)。
  `systemctl --user start app-tunnel-proxy` 起、`stop` 停;**不** `enable`(不開機自啟)。
  ttyd 比照建 user unit。

## 停用

用完兩個行程都關掉(proxy + ttyd),服務即不可達。Tailscale daemon 持續運行不影響。
