# deploy — app_tunnel 部署與常駐

運作姿態(CLAUDE.md 決策):**Named tunnel + 自有網域,手動起停**(不開機自啟、不 24/7 常駐)。
三個行程:`ttyd`(PTY)、`app-tunnel-proxy`(認證閘道)、`cloudflared`(named tunnel)。

## 一次性安裝

```bash
# macOS
brew install ttyd cloudflared
# Linux (Debian/Ubuntu)
sudo apt install ttyd
# cloudflared 依官方 repo 安裝
```

## 一次性設定

### 1. ttyd basic auth(第三道防線)

啟動帶 `-c user:password`(見下方服務檔)。

### 2. Named tunnel + 自有網域

```bash
cloudflared tunnel login
cloudflared tunnel create app-tunnel
cloudflared tunnel route dns app-tunnel term.<你的網域>
```

`~/.cloudflared/config.yml` 把 hostname 指到 **proxy**(不是直接指 ttyd):

```yaml
tunnel: app-tunnel
credentials-file: /Users/<you>/.cloudflared/<UUID>.json
ingress:
  - hostname: term.<你的網域>
    service: http://127.0.0.1:8080   # → app-tunnel-proxy
  - service: http_status:404
```

### 3. Cloudflare Access Service Token(第一道,邊緣)

Zero Trust 後台:為 `term.<你的網域>` 建一個 Access application,新增一組 **Service Token**;
policy 設為「Service Auth = 該 token」。app 連線帶 `CF-Access-Client-Id` / `CF-Access-Client-Secret`。

### 4. proxy 密鑰

見 `../server/README.md`(macOS keychain / Linux file)。

## 啟動順序

`ttyd` → `app-tunnel-proxy` → `cloudflared`(proxy 要先在 8080 待命,cloudflared 才有上游)。

## 常駐(手動起停)

- **macOS / launchd**:`launchd/` 內的 plist 範本。`launchctl bootstrap gui/$(id -u) <plist>` 起、`bootout` 停。
  把三個 plist 視為一組;不放 `~/Library/LaunchAgents` 自啟,改在要用時 bootstrap、用完 bootout(符合「不常駐」姿態)。
- **Linux / systemd**:`systemd/` 內的 unit 範本(`apptunnel-proxy.service`)。
  `systemctl --user start app-tunnel-proxy` 起、`stop` 停;**不** `enable`(不開機自啟)。
  ttyd 與 cloudflared 比照建 user unit,或用 cloudflared 內建 `cloudflared service install`。

## 停用

用完三個行程都關掉(proxy/ttyd/cloudflared),tunnel 網址即失效入口。
