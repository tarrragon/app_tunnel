# 技術選型決策記錄 — app_tunnel

產出日期：2026-06-16（Stage 3-5 初版）/ 2026-06-17（§1/§2 補完）
訪談依據：saas-tech-selection skill v0.6.0（特例調整，見 CLAUDE.md §6.5）

---

## 0. 專案定錨

- 產品形態：單人自用工具（非 SaaS、非多租戶、非對外服務）
- 租戶模型：單租戶（只有 owner 一人）
- 規模假設：1 人、1 台主機、1 支手機
- 團隊能力：1 人（owner = 開發 = 維運 = 唯一用戶）
- 上線時程：MVP 先行，自用驗證
- 成本模型：Tailscale 免費方案（個人，100 裝置內）+ 自有主機，月成本趨近零
- 交付形態：自建（交付形態 gate 判讀：無託管平台涵蓋「手機遠端操作本機 shell」這個需求）

## 1. 使用者操作與風險表

（Stage 1 操作盤點產物。操作主體 = 使用者一人、四種操作情境。）

| 操作 | 角色 | 主情境 | 失敗情境 | 風險類型 | 前端引導 | 後端防護 |
| ---- | ---- | ------ | -------- | -------- | -------- | -------- |
| 首次配對（掃 QR） | owner（人在主機旁） | enroll 產密鑰 → QR 顯示 → 手機掃描 → 憑證入 secure storage | qrencode 未裝；file 後端權限過寬；掃描失敗/payload 格式錯 | 憑證外洩（QR 含全部明文） | app 解析失敗不寫入、提示重掃 | enroll 用 crypto/rand；file 後端啟動檢查權限過寬即拒 |
| 日常遠端連線 | owner（人在外） | Face ID 解鎖 → 讀憑證 → Tailscale VPN 連線 → ttyd basic auth → 雙向 zsh I/O | 生物辨識失敗；Tailscale 離線；ttyd 認證失敗；ttyd 無回應/斷線 | 整台主機 shell 外洩（失敗代價最高） | 辨識失敗不讀憑證；連線失敗顯示「無法連線」 | Tailscale 裝置認證（網路層）；ttyd basic auth；proxy 稽核 log 記錄連線 |
| 密鑰輪替 | owner（人在主機旁） | 更換 ttyd 帳密 → 重跑 enroll → 重顯 QR → 手機重掃 | 手機未重掃即連線（舊帳密） | 舊帳密仍可用（輪替未生效） | （無前端動作，主機端操作） | 更換 ttyd 帳密後舊憑證被拒 |
| 啟停服務 | owner（本機） | 起動腳本啟 ttyd→proxy → Tailscale 網路內可達；停止腳本關兩行程 → 不可達 | port 被占用；停止後行程殘留 | 暴露窗（服務常駐 = 攻擊面放大，但 Tailscale 私有網路內攻擊面遠小於公開 URL） | （無前端動作） | ttyd+proxy 手動起停；Tailscale daemon 常駐但不暴露服務 |

範圍外操作（不做）：
- 多人共用（從單人變多人 → 認證模型全面重設計，D4 tripwire）
- 常駐模式（always-on → 暴露窗放大，D5 tripwire）
- PTY 內容錄影（D8 明確禁 log PTY 內容）

## 2. Domain Map 與 Event Catalog

### Domain Map

| Domain | 責任（一個變更理由） | 自建 / 外包 | 處理的 commands | 公開面（events + 查詢介面） | 內部面要點 |
| ------ | -------------------- | ----------- | --------------- | --------------------------- | ---------- |
| auth | 兩層認證（Tailscale 裝置認證 + ttyd basic auth） | 自建 + 外包 | Tailscale 裝置認證（網路層）、ttyd basic auth（應用層） | 認證結果（連線/拒絕）、稽核 log | Tailscale ACL 控制裝置存取；ttyd 帳密為最後防線 |
| proxy | HTTP/WS 透明反向代理（稽核 log + 轉發，不做認證） | 自建 | 接收連線、記錄稽核 log、轉發至 ttyd、graceful shutdown | 監聽端點、稽核 log（JSON、client_ip） | httputil.ReverseProxy WS upgrade、純透明轉發 |
| enrollment | QR 一次性配對（精簡版） | 自建 | enroll 組憑證包、顯 QR | enroll CLI 子命令 | 憑證包含 endpoint + ttyd 帳密 + protocol version |
| client | Flutter 原生終端機 UI | 自建 | Face ID 解鎖、讀憑證、建 WS、渲染終端機、傳鍵盤/resize | app UI | WS 協議薄抽象層、flutter_secure_storage |
| connectivity | Tailscale mesh VPN | 外包（Tailscale） | 裝置加入 tailnet、MagicDNS 解析 | 私有網路內可達性 | WireGuard 加密、裝置級認證、DERP relay fallback |

### Event Catalog

本專案 Go proxy 為**透明反向代理**，無領域事件流——proxy 不解讀 WS 訊框、不產生領域事件、不訂閱事件。Event Catalog 不適用。

### 介面契約（無 event 流、契約不在 event payload）

完整契約規格見 `docs/contract.md`（app 與 server 的 SOT）。

| 契約項 | 形態 | 雙方（產生 / 消費） | 版本標記 |
| ------ | ---- | ------------------- | -------- |
| ttyd 認證 Header | HTTP header（Authorization: Basic） | app 產生 / ttyd 消費（proxy 透傳） | 固定（變更走 contract.md） |
| WS 子協議 ttyd-tty/v1 | WebSocket 訊框（`'0'`+鍵盤、`'1'`+JSON resize） | app 產生 / ttyd 消費（proxy 透傳） | `protocol: ttyd-tty/v1`（Phase 2 升 `apptunnel/v1`） |
| QR 憑證包 | JSON payload 4 欄位（v/protocol/endpoint/ttyd_user/ttyd_pass） | enroll 產生 / app 消費（一次性） | `"v": 2` |

## 3. 技術維度決策

每個展開維度含理由 / 防護 / tripwire。

### D1 — server 語言:Go

- **需求判讀**:proxy 職責極小(稽核 log + 透明轉發 WS 到 localhost:7681)
- **選型**:Go stdlib httputil.ReverseProxy(從 1.12 起透明支援 WS upgrade)
- **理由**:編譯成單一靜態 binary,launchd 常駐零執行期依賴;靜態型別 + 小攻擊面適合安全敏感長駐服務。PHP(請求-回應模型,逆語言慣性)、Python(拖 venv,async WS 較囉嗦)皆次之
- **防護**:proxy 負責稽核 log（誰連上了）+ 透明轉發;認證由 Tailscale（網路層）+ ttyd basic auth（應用層）處理
- **tripwire**:proxy 自行用 creack/pty 開 PTY、拿掉 ttyd → 重評協議層;從單人變多人 → Go 仍適用但認證模型需整個重設計

### D2 — repo 管理:Monorepo

- **需求判讀**:app 與 proxy 共用同一份契約(密鑰格式、WS 握手),一起改一起發
- **選型**:單一 repo app_tunnel
- **理由**:需 atomic commit;單人單產品、無獨立發布節奏、無不同可見性、無跨多消費端重用——polyrepo 四條件一個不符
- **防護**:契約集中在 docs/,app 與 server 共同引用,避免雙邊定義漂移
- **tripwire**:server 被多專案重用,或開源其一而另一私有 → 評估 polyrepo

### D3 — 手機端:原生 Flutter 終端機 UI(自接 WebSocket)

- **需求判讀**:手機操 CLI 最有感的改善是打字體驗(Esc/Ctrl/方向鍵)
- **選型**:自渲染終端機(xterm 類)+ 自接 ttyd WS 子協議
- **理由**:可大幅改善手機打字體驗;代價是工程量大於 WebView 內嵌
- **防護**:secret 存 iOS Keychain / Android Keystore、不硬寫進 app;傳輸走 WSS;每次連線前過 Face ID / BiometricPrompt
- **tripwire**:打字體驗投報率不如預期 → 退回 WebView 內嵌 ttyd 方案

### D4 — 兩層認證(Tailscale 裝置認證 + ttyd basic auth)

- **需求判讀**:失敗代價是「整台機器的 shell 外洩」,單層不可接受
- **選型**:兩層各自獨立——① Tailscale 裝置認證（網路層,未加入 tailnet 的裝置連 IP 都到不了） ② ttyd basic auth（應用層最後防線）。Go proxy 不再做認證,只做稽核 log + 轉發
- **理由**:Tailscale mesh VPN 讓服務端點不存在於公開網路,攻擊面從「保護公開 URL」降為「端點不存在」;ttyd basic auth 保留為縱深第二層
- **防護**:Tailscale ACL 限制只有 owner 裝置可連;ttyd 綁 Tailscale 介面或 localhost
- **tripwire**:從單人變多人 → Tailscale ACL + ttyd 帳密需重設計為帳號系統
- **變更記錄**:原為三層（CF Access + proxy token + ttyd），2026-06-17 改用 Tailscale 後簡化為兩層（Tailscale 裝置認證取代 CF Access + proxy token）

### D5 — 運作姿態:Tailscale + 手動起停 ttyd/proxy

- **需求判讀**:私有網路內可達(app 寫死 Tailscale IP 或 MagicDNS),ttyd+proxy 不需 24/7 常駐
- **選型**:Tailscale daemon 常駐（只維持 VPN 隧道,不暴露服務）;ttyd+proxy 用時起、用完關
- **理由**:Tailscale 常駐不等於服務暴露——daemon 只維持加密隧道,ttyd 不啟動就沒有 shell 可連;比 CF Tunnel 的公開 URL 攻擊面更小
- **防護**:ttyd+proxy 的 launchd 不放 ~/Library/LaunchAgents、systemd 不 enable;停用即關兩行程
- **tripwire**:改 ttyd always-on 常駐 → 雖在私有網路內攻擊面有限,仍建議補 Tailscale ACL tag 限制
- **變更記錄**:原為 Cloudflare named tunnel + 自有網域 + 三行程起停,2026-06-17 改用 Tailscale 後簡化為兩行程起停

### D6 — 密鑰保管:簡化（僅 ttyd 帳密）

- **需求判讀**:proxy 不再驗 token,密鑰保管範圍縮為 ttyd basic auth 帳密
- **選型**:ttyd 帳密由 enroll 設定,存在 deploy 配置或環境變數
- **理由**:原可插拔後端（keychain/file/env）是為 proxy token 設計;proxy token 移除後,複雜度可大幅降低
- **防護**:ttyd 帳密不進 repo（.gitignore）;QR 傳輸後存 app secure storage
- **tripwire**:secret 數量增加或多人共用 → 引入 secret manager
- **變更記錄**:原為可插拔多後端（keychain/file 0600/env）管理 proxy token,2026-06-17 隨 proxy token 移除而簡化

### D7 — 憑證配對:QR enrollment(精簡版)

- **需求判讀**:手動輸入 ttyd 帳密 + Tailscale endpoint 仍易錯
- **選型**:視覺 air-gap 掃描——主機 enroll 組憑證包（endpoint + ttyd 帳密 + protocol version）、qrencode ASCII QR,手機掃一次存 Keychain
- **理由**:定位為一次性配對;憑證包從 8 欄縮為 ~4 欄（無 CF Access 憑證、無 proxy token）
- **防護**:QR 含 ttyd 帳密明文、僅顯示一次;掃描後即關
- **tripwire → 設計 B(非對稱)**:仍保留——要「私鑰硬體保護」時升級。詳見 docs/contract.md
- **變更記錄**:原憑證包 8 欄（含 CF Access + proxy token）,2026-06-17 縮為 ~4 欄

### D8 — Observability:結構化稽核 log,不建 pager

- **需求判讀**:單人、無 SLA,shell 閘道的關鍵訊號是「誰連上了」
- **選型**:proxy 記錄每次連線(結構化 JSON、client_ip 取自 Tailscale 對端 IP req.RemoteAddr)
- **理由**:掛了連線即知,不需 uptime 監控/pager;依賴(ttyd)失敗分類為 ERROR
- **防護**:絕不 log PTY 內容(指令含密碼)——透明 proxy 天然滿足
- **tripwire**:想「有人連上即時知道」→ 加連線推播(ntfy.sh 類)到手機
- **變更記錄**:client_ip 來源從 CF-Connecting-Ip header 改為 req.RemoteAddr（Tailscale 內為真實對端 IP）

### D9 — Reliability:CI gate + 測試 + timeout

- **需求判讀**:proxy 是安全敏感程式,可靠性最低標
- **選型**:go test gate + CI(vet+test+跨平台 build) + graceful shutdown + proxy→ttyd timeout
- **理由**:測試覆蓋 log / 轉發 / shutdown / enroll
- **防護**:外部呼叫有 timeout;go.mod/go.sum 鎖依賴
- **N/A**:重試/idempotency(無編排操作)、webhook 驗簽(無 webhook)
- **變更記錄**:認證閘道測試隨 proxy token 移除而刪減

### State-Storage — 無 application datastore

- 本工具無 source-of-truth 資料庫:ttyd 帳密(enroll 可重設)、Tailscale 裝置授權(tailscale up 可重建)皆可重建
- 觸發型維度:cache / async-queue / capacity-performance 皆未觸發(無高頻讀、無不可丟 event、單人無高峰)
- **tripwire**:加 session 紀錄/指令解釋歷史(embedded SQLite) → state-storage 變真,啟用備份/migration 底線

未展開維度：

| 維度 | 未展開原因 | 觸發條件 |
| ---- | ---------- | -------- |
| cache | 無高頻重複讀（單人、無 session pool） | 加 session 錄影/歷史 |
| async-queue | 無不可丟 event（透明 proxy 無事件流） | Phase 2 自開 PTY + 錄影 |
| capacity-performance | 單人無高峰 | 從單人變多人 |

## 4. 防護底線總表

| 底線 | 狀態 | 備註 |
| ---- | ---- | ---- |
| Secret 不進 repo | 已納入 | .gitignore 涵蓋帳密檔 |
| Tailscale ACL 限制裝置 | 已納入 | D4 防護（網路層認證） |
| ttyd basic auth | 已納入 | D4 防護（應用層最後防線） |
| 不 log PTY 內容 | 已納入 | D8 防護 |
| ttyd 綁 Tailscale 介面或 localhost | 已納入 | D4 不對外暴露 |
| ttyd+proxy 不開機自啟 | 已納入 | D5 防護 |
| CI gate（go vet + go test） | 已納入 | D9 防護 |

## 5. 規模成長 tripwire 總表

| 撞牆訊號 | 偵測手段 | 觸發後重評 |
| -------- | -------- | ---------- |
| 從單人變多人 | owner 意圖（主觀） | D4 Tailscale ACL + ttyd 帳密重設計為帳號系統 |
| 改 ttyd always-on 常駐 | 改 launchd/systemd 設定 | D5 補 Tailscale ACL tag 限制 |
| 自開 PTY 拿掉 ttyd | 開發決策 | D1 重評協議層、protocol 升版 |
| secret 數量 > 10 | 計數 | D6 引入 secret manager |
| 加 session 紀錄 | 開發決策 | State-Storage 變真、啟用備份/migration |

## 6. Scaffold 清單

（本專案已有部分 scaffold：`server/` Go proxy、`app/` Flutter 骨架、`deploy/` 設定、`docs/contract.md`。）
