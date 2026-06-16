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

**`protocol: ttyd-tty/v1`**(MVP 用 ttyd;見 CLAUDE.md D1 tripwire——Phase 2 若 Go proxy 自開 PTY,將升為 `apptunnel/v1`)。

> **app 端要求**:把 WS 終端機協議包成一層薄抽象(介面化),協議版本切換時只改該抽象一處,不散落在 UI。雙邊以本檔的 `protocol` 欄位為準。

proxy 在 HTTP 層**透明反向代理**,不改 WS 訊框。app 直接講 **ttyd 的 `tty` 子協議**:
- 端點:`/ws`(WebSocket,subprotocol `tty`)
- input:`'0'` + 鍵盤資料
- resize:`'1'` + JSON `{"columns":N,"rows":M}`
- 開場:`'{"AuthToken":"..."}'`(ttyd token,若有設)

### 協議版本演進

| 版本 | server 形態 | 狀態 |
|------|------------|------|
| `ttyd-tty/v1` | ttyd 開 PTY,Go proxy 純認證透明轉發 | **現用(MVP)** |
| `apptunnel/v1` | Go proxy 自開 PTY、拿掉 ttyd,自訂精簡協議 | 保留(Phase 2 觸發條件見 CLAUDE.md D1) |

## 密鑰

- **產生**:`openssl rand -hex 32`(32 bytes / 64 hex)。
- **app 端保管**:iOS Keychain / Android Keystore,**不硬寫進程式碼**(反編譯可挖)。
- **proxy 端保管**(可插拔後端):
  - macOS → `keychain`(`security` CLI)
  - Linux / 通用 → `file`(0600 權限,fallback)
  - CI / 容器 → `env`
- **傳輸**:全程 WSS(CF Tunnel 段加密),放 header 安全。**配對改用 QR**(見下),不經剪貼簿/雲。
- **輪替**:重跑 enroll(預設產生新密鑰)、重顯 QR、手機重掃。tripwire:從單人變多人時改為帳號系統 + 動態下發。

## 憑證配對(QR enrollment,設計 A:對稱)

定位:**一次性配對**,不是每次連線。因為工具本質是遠端(手機在外),掃 QR 只能在**人在主機旁**時做一次,把整包憑證灌進手機,之後遠端用儲存的憑證連。

**流程**:主機 `app-tunnel-proxy enroll`(產生 proxy 密鑰、存後端)→ 組憑證包 → `qrencode -t ANSIUTF8` 在終端機印 ASCII QR(無頭 Linux 亦可)→ 手機 app 掃一次 → 存 `flutter_secure_storage`(Keychain/Keystore)→ 丟棄 QR。

**憑證包(QR payload,JSON)**:

```json
{
  "v": 1,
  "protocol": "ttyd-tty/v1",
  "endpoint": "wss://term.<你的網域>/ws",
  "cf_access_id": "<CF Access service token client id>",
  "cf_access_secret": "<CF Access service token client secret>",
  "proxy_token": "<X-App-Tunnel-Token 密鑰>",
  "ttyd_user": "<ttyd basic auth 帳號>",
  "ttyd_pass": "<ttyd basic auth 密碼>"
}
```

**安全注意**:QR 含全部憑證明文、僅顯示一次,**勿截圖外流**;掃描後主機端密鑰已存後端,QR 即可關閉。

**tripwire → 設計 B(非對稱,反向認證)**:當要「主機端零可重用密鑰 + 私鑰硬體保護」時升級——手機產金鑰對(私鑰鎖 Secure Enclave/Keystore)、QR 配對時回送公鑰給主機、runtime 改挑戰-回應(nonce 簽章 + replay 防護)。屆時 `protocol` 升版、proxy 由「比對 header」改為「驗簽握手」。

## 驗錯行為

proxy 密鑰錯或缺 → 回 **404**(不洩漏服務存在),不 upgrade、不轉發。
