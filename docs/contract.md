# app_tunnel 契約規格(app ⇄ server 共用 SOT)

> 依 docs/tech-decisions.md D2 防護:app 與 server 共用同一份契約,雙邊都引用本檔,避免定義漂移。

## 連線鏈路(MVP)

```
Flutter app(Face ID 解鎖)
   │  WS,帶 ttyd basic auth 憑證
   ▼
Tailscale mesh VPN(WireGuard 加密隧道,裝置級認證)
   ▼
Go proxy(本機:稽核 log + 透明轉發,不做認證)
   ▼
ttyd(本機:basic auth)── 應用層最後防線
   ▼
zsh(真實 shell)
```

## 兩層認證

| 層 | 擋什麼 | 機制 | 說明 |
|----|--------|------|------|
| 1 網路層 | 未加入 tailnet 的裝置 | Tailscale 裝置認證 + ACL | 服務端點不存在於公開網路,攻擊者連 IP 都到不了 |
| 2 應用層 | tailnet 內未授權連線(縱深) | ttyd basic auth | `Authorization: Basic base64(user:pass)`,proxy 原樣轉發 |

Go proxy **不做認證**,只做稽核 log（結構化 JSON、client_ip 取自 req.RemoteAddr）+ 透明轉發。

## WebSocket 子協議

**`protocol: ttyd-tty/v1`**(MVP 用 ttyd;見 docs/tech-decisions.md D1 tripwire——Phase 2 若 Go proxy 自開 PTY,將升為 `apptunnel/v1`)。

> **app 端要求**:把 WS 終端機協議包成一層薄抽象(介面化),協議版本切換時只改該抽象一處,不散落在 UI。雙邊以本檔的 `protocol` 欄位為準。

proxy 在 HTTP 層**透明反向代理**,不改 WS 訊框。app 直接講 **ttyd 的 `tty` 子協議**:
- 端點:`/ws`(WebSocket,subprotocol `tty`)
- input:`'0'` + 鍵盤資料
- resize:`'1'` + JSON `{"columns":N,"rows":M}`
- 開場:`'{"AuthToken":"..."}'`(ttyd token,若有設)

### 協議版本演進

| 版本 | server 形態 | 狀態 |
|------|------------|------|
| `ttyd-tty/v1` | ttyd 開 PTY,Go proxy 稽核 log + 透明轉發 | **現用(MVP)** |
| `apptunnel/v1` | Go proxy 自開 PTY、拿掉 ttyd,自訂精簡協議 | 保留(Phase 2 觸發條件見 docs/tech-decisions.md D1) |

## 認證憑證

- **ttyd 帳密**:enroll 時設定,存在 deploy 配置或環境變數
- **app 端保管**:iOS Keychain / Android Keystore,**不硬寫進程式碼**(反編譯可挖)
- **傳輸**:全程經 Tailscale WireGuard 加密隧道。**配對用 QR**(見下),不經剪貼簿/雲
- **輪替**:更換 ttyd 帳密 → 重跑 enroll → 重顯 QR → 手機重掃。tripwire:從單人變多人時改為帳號系統

## 憑證配對(QR enrollment,精簡版)

定位:**一次性配對**,不是每次連線。因為工具本質是遠端(手機在外),掃 QR 只能在**人在主機旁**時做一次,把整包憑證灌進手機,之後遠端用儲存的憑證連。

**流程**:主機 `app-tunnel-proxy enroll`(設定 ttyd 帳密)→ 組憑證包 → `qrencode -t ANSIUTF8` 在終端機印 ASCII QR(無頭 Linux 亦可)→ 手機 app 掃一次 → 存 `flutter_secure_storage`(Keychain/Keystore)→ 丟棄 QR。

**憑證包(QR payload,JSON)**:

```json
{
  "v": 2,
  "protocol": "ttyd-tty/v1",
  "endpoint": "http://<tailscale-ip-or-magicDNS>:<port>/ws",
  "ttyd_user": "<ttyd basic auth 帳號>",
  "ttyd_pass": "<ttyd basic auth 密碼>"
}
```

**安全注意**:QR 含 ttyd 帳密明文、僅顯示一次,**勿截圖外流**;掃描後 QR 即可關閉。

**tripwire → 設計 B(非對稱,反向認證)**:當要「私鑰硬體保護」時升級——手機產金鑰對(私鑰鎖 Secure Enclave/Keystore)、QR 配對時回送公鑰給主機、runtime 改挑戰-回應(nonce 簽章 + replay 防護)。屆時 `protocol` 升版。

## 驗錯行為

ttyd basic auth 失敗 → ttyd 回 401;proxy 記錄連線失敗(稽核 log)。
