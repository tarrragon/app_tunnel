---
# 提案（Proposal）

id: PROP-001
title: "MVP：手機遠端操作本機真實終端機"
status: draft                    # draft / discussing / confirmed / implemented / withdrawn
evaluation_level: heavy          # standard / heavy（本提案涵蓋 4 UC + app/server 跨端 + 架構層級 → heavy）
source: development              # 原始規劃功能項
proposed_by: rosemary-project-manager
proposed_date: "2026-06-16"
confirmed_date: null             # 尚未 promote；promote 需補多視角審查記錄 + 綁實作 ticket
target_version: v0.1.0           # MVP（v0.0.x 為基礎架構與技術選型）
priority: P0

# 轉化產出追蹤
outputs:
  spec_refs:
    - spec/auth/three-layer-auth.md
    - spec/proxy/go-reverse-proxy.md
    - spec/enrollment/qr-enrollment.md
    - spec/client/flutter-terminal-client.md
    - spec/connectivity/cloudflare-tunnel.md
  usecase_refs:
    - UC-01
    - UC-02
    - UC-03
    - UC-04
  ticket_refs: []                # confirmed/approved 時須非空（規則 4）

# 關聯
related_proposals: []
supersedes: null
---

# PROP-001: MVP：手機遠端操作本機真實終端機

> **本提案定位（範圍綁定提案）**：本提案源自 `docs/tech-decisions.md`（saas-tech-selection 訪談完整決策記錄），經 saas↔doc 銜接映射生成——§0 定錨 + §3 技術維度 + §4/§5 底線/tripwire 映射為本提案的範圍界定、替代方案、失敗防護與驗收條件。本提案不重複決策論證，只負責三件事：(1) 綁定 v0.1.0 MVP 的明確功能範圍（In/Out Scope）；(2) 提供 spec/usecase/ticket 的上游導航錨點；(3) 列出與 In Scope 一一對應的驗收條件。決策理由一律以 `docs/tech-decisions.md Dx` 形式引用。
>
> **狀態說明**：分級為 heavy（影響面廣）但目前置於 `draft`——範圍已界定，但尚未開立實作 ticket、尚未執行 heavy 級多視角審查。promote 至 `confirmed` 前須補「多視角審查記錄」並綁定 `ticket_refs`（見規則 4）。

## 動機（需求來源與為何做）

單人自用自架基礎設施工具的原始規劃功能項：人在外時，手機透過 Cloudflare Tunnel 遠端操作家中／辦公室本機的真實 zsh 終端機。鏈路為 `Flutter app（Face ID）→ 帶憑證 WSS → CF Tunnel → 本機 Go proxy（驗密鑰）→ ttyd → zsh`，契約細節見 `docs/contract.md`。

**為何做**：手機原生 SSH/終端機 app 在「打字體驗（Esc/Ctrl/方向鍵）」與「安全暴露面」兩端難以兼顧；直接對外開 SSH 暴露窗大、手動複製長密鑰進手機易錯易外洩。本工具用「Cloudflare Tunnel 出站連線（不開入站埠）+ 三層縱深認證 + QR 視覺配對 + 自渲染終端機 UI」解這組問題。失敗代價是「整台機器的 shell 外洩」，故安全底線不可協商。

## 影響範圍

| 影響項目 | 說明 |
|---------|------|
| 模組 | `server/`（Go proxy）、`app/`（Flutter）、`deploy/`（ttyd / cloudflared / launchd） |
| 檔案 | `server/` proxy + enroll 子命令；`app/` 終端機 UI + secure storage；`deploy/` 配置與起停腳本 |
| 契約 | `docs/contract.md`（app⇄server 共用 SOT，本提案不改其內容，只引用） |
| 用例 | UC-01 首次配對、UC-02 遠端連線操作、UC-03 密鑰輪替、UC-04 啟停服務 |

## 範圍界定

> 核心原則：一個提案 = 一個版本的明確功能範圍。

### 本提案要做的（In Scope，v0.1.0 MVP）

- **IS-1 三層認證鏈路**：CF Access Service Token（邊緣）+ Go proxy `X-App-Tunnel-Token`（主機）+ ttyd basic auth（最後防線）；proxy 驗錯／缺密鑰一律回 404、constant-time 比較。對應 docs/tech-decisions.md D4、`docs/contract.md` 三層認證表。
- **IS-2 Go proxy 透明轉發**：`httputil.ReverseProxy` 透明 WS upgrade，驗密鑰後刪除 `X-App-Tunnel-Token` 不上傳、原樣轉發 ttyd `Authorization`；proxy→ttyd timeout、graceful shutdown、結構化稽核 log（記放行與拒絕，真實 client_ip 取自 CF-Connecting-Ip，絕不 log PTY 內容）。對應 D1、D8、D9。
- **IS-3 QR enrollment 一次性配對**：主機 `enroll` 子命令產 proxy 密鑰（`crypto/rand`）、存可插拔後端（keychain/file 0600/env）、組憑證包 JSON、`qrencode -t ANSIUTF8` 印 ASCII QR；手機掃一次存 secure storage。對應 D6、D7。
- **IS-4 Flutter 終端機 UI**：Face ID/BiometricPrompt 解鎖 → 讀 secure storage 憑證 → 自接 ttyd `tty` 子協議的 WSS；WS 協議包成一層薄抽象（協議版本切換只改一處）。對應 D3、`docs/contract.md` WebSocket 子協議。
- **IS-5 運作姿態與部署**：Cloudflare named tunnel + 自有固定網域；手動起停（不開機自啟、不 24/7 常駐）；`deploy/` 提供 ttyd/cloudflared 配置、launchd plist（不放 `~/Library/LaunchAgents`）、setup 腳本。對應 D5。

### 本提案不做的（Out of Scope）

- **設計 B 非對稱認證（挑戰-回應、手機金鑰對、nonce 簽章 + replay 防護）** → D7 tripwire 觸發才做（要「主機端零可重用密鑰 + 私鑰硬體保護」時），屆時 `protocol` 升版、獨立提案。
- **proxy 自開 PTY、拿掉 ttyd（`apptunnel/v1`）** → D1 tripwire，Phase 2 重評協議層，獨立提案。
- **多人／多租戶帳號系統 + 動態密鑰下發** → 從單人變多人才重設計三層認證，獨立提案。
- **always-on 常駐 + WAF／入口限流／告警** → D5 tripwire（暴露窗放大才補）。
- **連線推播到手機（ntfy.sh 類）** → D8 明示本次選不做。
- **PTY 錄影／指令解釋歷史 + embedded SQLite** → State-Storage tripwire（加 session 紀錄才啟用備份/migration）。
- **uptime 監控／pager** → D8，單人無 SLA。

> 「不做」清單項目未來需要時，建立新獨立提案綁定具體版本再設計。

## 替代方案

> heavy 級要求至少 3 候選 + 逐一評估。本提案的方案即 docs/tech-decisions.md D1–D9 已決策內容，下表標示「採用 vs 次選」，理由不重述（指回 Dx）。

| 決策維度 | 採用方案 | 次選方案 A | 次選方案 B | 依據 |
|---------|---------|-----------|-----------|------|
| server 語言 | Go（stdlib 透明 WS 轉發、單一靜態 binary） | PHP（請求-回應模型，逆語言慣性） | Python（拖 venv、async WS 囉嗦） | D1 |
| repo 管理 | Monorepo（契約共用、atomic commit） | Polyrepo（無獨立發布節奏，四條件皆不符） | — | D2 |
| 手機端 | 原生 Flutter 自渲染終端機 | WebView 內嵌 ttyd（打字體驗差） | — | D3（WebView 列為 tripwire 退路） |
| 認證模型 | 三層縱深（CF Access + proxy 密鑰 + ttyd） | 單層 proxy 密鑰（失敗即整機 shell 外洩，不可接受） | 僅靠 tunnel 網址保密（網址不是密碼） | D4 |
| 配對方式 | QR enrollment 對稱設計 A | 手動複製 64-hex 密鑰（最易錯/易外洩） | 非對稱設計 B（過度，列為 tripwire 升級） | D7 |

### 建議方案

維持 D1–D9 決策。本提案的增量價值在「範圍綁定 + 文件導航錨點」，技術選型已在前置訪談完成，不另起爐灶。

## 失敗防護

> heavy 級要求至少 3 個失敗情境 + 對應防護。

| 失敗情境 | 後果 | 防護 |
|---------|------|------|
| proxy 密鑰驗證出現 fallback 放行 | 拿到 tunnel 網址的外人直通 shell | 驗錯/缺密鑰一律回 404、不 fallback、constant-time 比較；ttyd basic auth 為最後防線（D4） |
| 稽核 log 誤記 PTY 內容 | 你打的密碼進 log 外洩 | 透明 proxy 天然不接觸 PTY；Phase 2 自開 PTY 時硬性禁止 log PTY 內容（D8） |
| QR 截圖外流 | 全套憑證明文外洩 | QR 僅顯示一次、掃後即關、勿截圖；輪替走重 enroll（D7） |
| 忘記關閉服務 | always-on 暴露窗放大 | 手動起停 + 一鍵關三行程；不開機自啟、launchd 不放 LaunchAgents（D5） |
| 跨平台密鑰後端權限過寬 | file 後端被 group/other 讀取 | file 後端啟動檢查 0600 權限，過寬即拒絕（D6） |

## 機會成本

不做本提案的替代是「沿用對外 SSH 或商用遠端 app」——前者暴露面大且需自管入站防火牆，後者打字體驗與信任邊界不可控。投入本提案的主要機會成本是 Flutter 自渲染終端機的工程量（D3 已標 tripwire 退路：投報率不如預期退回 WebView）。server 端 proxy 職責極小（約 50 行 + 認證閘道），邊際成本低。

## 驗收條件

> 與「要做的」清單一一對應。

- [ ] **AC-1（對應 IS-1）**：proxy 在密鑰正確時放行、錯誤或缺失時回 404（不 upgrade、不轉發），且比較為 constant-time；三層憑證可串接通過完整鏈路。
- [ ] **AC-2（對應 IS-2）**：proxy 透明轉發 WS 訊框不改動、驗密鑰後刪除 `X-App-Tunnel-Token`；具 proxy→ttyd timeout、graceful shutdown、結構化稽核 log（含 client_ip，不含 PTY 內容）。
- [ ] **AC-3（對應 IS-3）**：`enroll` 子命令產生 64-hex 密鑰、存指定後端、印出可掃描的 ASCII QR；手機掃描後憑證落 secure storage。
- [ ] **AC-4（對應 IS-4）**：app 過 Face ID/BiometricPrompt 後，以儲存憑證連線並正常操作 zsh；WS 協議抽象層使協議版本切換只需改一處。
- [ ] **AC-5（對應 IS-5）**：named tunnel 固定網域可達；提供手動起停機制（起 / 用完關三個行程），不開機自啟。

## Reality Test / 觸發案例實證

### 觸發案例

使用者（單人，本機 owner）實際需求：人在外時需操作家中本機 CLI（執行長任務、查看輸出、臨時修改）。既有方案（對外開 SSH / 商用遠端 app）在「手機打字體驗」與「最小暴露面」間無法兼顧，且手動搬運長密鑰易錯。

### 假設列舉

- 假設 1：Cloudflare named tunnel 出站連線可在不開放入站埠的前提下提供固定可達網址。
- 假設 2：Go stdlib `httputil.ReverseProxy` 自 1.12 起可透明轉發 WebSocket upgrade，無需額外 WS 函式庫。
- 假設 3：`qrencode -t ANSIUTF8` 可在無頭 Linux 終端機印出可被手機掃描的 ASCII QR。

### 實驗驗證

| 假設 | 驗證方式 | 執行的實驗/觀察 | 結果 |
|------|---------|----------------|------|
| 假設 2 | 既有 server 實作 | git log 顯示 proxy + 認證閘道 + 測試已 commit（3f85498、29ac897） | 已驗證可行（透明轉發 + 測試綠燈） |
| 假設 1 | 待 deploy 階段實機 | 尚未實機建立 named tunnel | 未驗證（列為部署階段風險） |
| 假設 3 | 待 enroll 實機 | enroll 子命令已實作，ASCII QR 實機掃描待測 | 部分驗證（程式已寫，掃描端到端待測） |

### 已驗證 vs 未驗證

| 類別 | 內容 |
|------|------|
| 已驗證 | Go proxy 透明 WS 轉發 + 三層認證閘道邏輯 + enroll 子命令（已有實作與單元測試） |
| 未驗證 | named tunnel 端到端可達性、ASCII QR 手機實機掃描、Flutter 終端機打字體驗（app 端尚未開工） |

## 多視角審查記錄

> heavy 級必填。本提案 promote（draft → confirmed）前須派發多視角審查（至少 linux + 1 安全視角，如 clove-security-reviewer，因失敗代價為整機 shell 外洩）。

**狀態**：待執行。promote 前以 `/parallel-evaluation` 派發，記錄結論後方可 confirmed。

## 分階段實施計畫

本提案綁定單一大版本 v0.1.0，**不跨 2+ 大版本**，故規則 2 的「分階段實施計畫」不適用（N/A）。版本內的 Wave 拆分待 promote 開 ticket 時規劃。

## 風險與權衡

| 風險 | 影響 | 緩解措施 |
|------|------|---------|
| Flutter 自渲染終端機工程量大於 WebView | app 開發拖長 | D3 tripwire：投報率不如預期則退回 WebView 內嵌 ttyd |
| named tunnel/CF Access 設定錯誤 | 鏈路不通或邊緣未擋 | 部署階段以 AC-1 三層串接測試驗證 |
| 手動起停依賴人為紀律 | 忘記關閉放大暴露窗 | 起停腳本一鍵關三行程；D5 不做 always-on |

## 討論記錄

### 2026-06-16

PM 與用戶確認 doc 流程方向：(1) 採輕量單一 MVP 提案，引用 CLAUDE.md 不重複論證；(2) domain 切分先建骨架後調整。

提案分級判定為 **heavy**（涵蓋 4 個 UC + app/server 跨端 + 整個 MVP 架構層級，符合 proposal-evaluation-gate 規則 1 多項 heavy 條件）。當前狀態置於 `draft`：範圍已界定但尚未開 ticket、尚未跑 heavy 級多視角審查，故不直接標 confirmed（confirmed 須綁 ticket_refs + 多視角審查記錄）。promote 路徑：補多視角審查 → 開實作 ticket → status 改 confirmed。

同時確認框架特例：doc skill 內建 domain 列表（extraction/page/messaging 等）與 `platform: both/app/extension`、`extension_status` 欄位為 Chrome Extension 書籍 app 遺留，與本「伺服器但非架站」工具不符，spec/usecase 中以本專案語意重新詮釋，缺口回饋 `docs/upstream-feedback/`。

## 轉化記錄

| 轉化類型 | 檔案 | 日期 | 狀態 |
|---------|------|------|------|
| 規格 | spec/auth/three-layer-auth.md | 2026-06-16 | created（骨架） |
| 規格 | spec/proxy/go-reverse-proxy.md | 2026-06-16 | created（骨架） |
| 規格 | spec/enrollment/qr-enrollment.md | 2026-06-16 | created（骨架） |
| 規格 | spec/client/flutter-terminal-client.md | 2026-06-16 | created（骨架） |
| 規格 | spec/connectivity/cloudflare-tunnel.md | 2026-06-16 | created（骨架） |
| 用例 | usecases/UC-01-first-pairing.md | 2026-06-16 | created（骨架） |
| 用例 | usecases/UC-02-remote-session.md | 2026-06-16 | created（骨架） |
| 用例 | usecases/UC-03-secret-rotation.md | 2026-06-16 | created（骨架） |
| 用例 | usecases/UC-04-start-stop.md | 2026-06-16 | created（骨架） |
| Ticket | （待 spec 完整化後開立） | - | pending |
