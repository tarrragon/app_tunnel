# app_tunnel 契約規格(app ⇄ server 共用 SOT)

> 依 CLAUDE.md D2 防護:app 與 server 共用同一份契約,雙邊都引用本檔,避免定義漂移。

## 連線鏈路(MVP)

```
Flutter app(Face ID 解鎖)
   │  WSS,帶三組憑證(見下)
   ▼
Cloudflare Tunnel(named,固定網域 term.<你的網域>)
   ▼
Cloudflare Access(邊緣:驗 Service Token)── 未授權流量在此被擋,到不了主機
   ▼
Go proxy(本機:驗 X-App-Tunnel-Token)── 第二道,驗「這條連線是我的 app」
   ▼
ttyd(本機:basic auth)── 第三道,最後防線
   ▼
zsh(真實 shell)
```

## 三層認證憑證(app 連線時一併帶上)

| 層 | 擋什麼 | 機制 | Header |
|----|--------|------|--------|
| 1 邊緣 | 未授權流量到達主機 | Cloudflare Access Service Token | `CF-Access-Client-Id`、`CF-Access-Client-Secret`(由 Cloudflare 消費) |
| 2 主機 proxy | 拿到 tunnel 網址的外人 | 共享密鑰(app-bound) | `X-App-Tunnel-Token: <secret>` |
| 3 主機 ttyd | proxy 萬一破口 | basic auth | `Authorization: Basic base64(user:pass)` |

**Header 不衝突**:proxy 驗 `X-App-Tunnel-Token`(通過後**刪除不上傳**),ttyd 的 `Authorization` 原樣轉發。

## WebSocket 子協議

proxy 在 HTTP 層**透明反向代理**,不改 WS 訊框。app 直接講 **ttyd 的 `tty` 子協議**:
- 端點:`/ws`(WebSocket,subprotocol `tty`)
- input:`'0'` + 鍵盤資料
- resize:`'1'` + JSON `{"columns":N,"rows":M}`
- 開場:`'{"AuthToken":"..."}'`(ttyd token,若有設)

## 密鑰

- **產生**:`openssl rand -hex 32`(32 bytes / 64 hex)。
- **app 端保管**:iOS Keychain / Android Keystore,**不硬寫進程式碼**(反編譯可挖)。
- **proxy 端保管**(可插拔後端):
  - macOS → `keychain`(`security` CLI)
  - Linux / 通用 → `file`(0600 權限,fallback)
  - CI / 容器 → `env`
- **傳輸**:全程 WSS(CF Tunnel 段加密),放 header 安全。
- **輪替**:手動。重產一組、兩端同步替換。tripwire:從單人變多人時改為帳號系統 + 動態下發。

## 驗錯行為

proxy 密鑰錯或缺 → 回 **404**(不洩漏服務存在),不 upgrade、不轉發。
