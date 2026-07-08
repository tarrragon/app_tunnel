---
# 提案（Proposal）

id: PROP-002
title: "Agent 工作機工作流的功能對齊（擴充鍵列、斷線重連、多 endpoint、TUI 相容）"
status: draft                    # draft / discussing / confirmed / implemented / withdrawn
evaluation_level: standard       # standard / heavy（單端為主、不動架構與認證模型 → standard）
source: usage                    # 外部工作流（遠端 agent 工作機）產生的實際使用需求
proposed_by: tarrragon
proposed_date: "2026-07-08"
confirmed_date: null             # promote 前置：外部工作流 Phase 1 完成、驗收規格凍結、綁實作 ticket
target_version: v0.2.0           # 在 v0.1.0 MVP 之後
priority: P1                     # 工作流已由現成 client 解鎖，本提案不在關鍵路徑上

# 轉化產出追蹤
outputs:
  spec_refs: []                  # 待範圍凍結後轉化（預期落點：spec/client/ 擴充、spec/enrollment/ 多目標）
  usecase_refs: []               # 預期新增 UC：agent 工作機日常操作（丟任務 / 斷線 / 回來看結果）
  ticket_refs: []                # confirmed 時須非空（規則 4）

# 關聯
related_proposals:
  - PROP-001                     # 依賴其 IS-4（Flutter 終端機 UI）為基礎
supersedes: null
---

# PROP-002: Agent 工作機工作流的功能對齊

> **本提案定位（範圍綁定提案、驗收規格外部凍結）**：本提案讓 app_tunnel 成為「遠端 agent 工作機工作流」的可替換連線層。該工作流（VM + Tailscale + zellij + coding agent + ntfy 通知 + 手機連線）的 Phase 1 以現成 client（Termius 這類）跑通全部驗證判準——**Phase 1 跑通後凍結的判準清單，就是本提案的驗收規格**。因此本提案目前置於 `draft`：In Scope 為候選清單，Phase 1 完成後凍結範圍、開 ticket、再 promote。
>
> **範圍鎖**：parity 的對象是「該工作流實際依賴的功能子集」，而非現成 client 的全功能。Phase 1 沒用到的功能，一律不進本提案。

## 動機（需求來源與為何做）

遠端 agent 工作機工作流需要手機端 client 承擔四件事：終端 UI 的完整按鍵操作、網路切換後的斷線復原、連到本機以外的目標（VM）、全螢幕 TUI 的正確渲染。Phase 1 用現成 client 驗證工作流成立——選現成工具的理由是控制變數：工作流本身未驗證時，client 端用成熟工具把變數歸零。

**為何仍要做 parity**：兩個收益。其一是開發經驗累積——終端 client 的按鍵注入、WebSocket 重連策略、TUI 相容性都是可遷移的工程能力。其二是差異化——Face ID 解鎖、稽核 log、體驗完全可客製，是現成 client 給不了的（PROP-001 動機的延伸）。工作流已被現成工具解鎖，本提案可以按自己的節奏做、且每一步都有 Phase 1 的 baseline 可對照。

## 影響範圍

| 影響項目 | 說明 |
|---------|------|
| 模組 | `app/`（主要：鍵列 UI、重連邏輯、TUI 相容）、`server/`（enroll 多目標支援）、`deploy/`（VM 目標的 ttyd 配置指引，含起始指令 attach multiplexer） |
| 契約 | `docs/contract.md` 預期不動認證模型；憑證包若需支援多 endpoint，v2 憑證包結構需評估是否升版 |
| 用例 | 預期新增 UC：agent 工作機日常操作循環（連入 → 丟任務 → 斷線 → 通知後回來看結果） |

## 範圍界定

> 核心原則：一個提案 = 一個版本的明確功能範圍。以下為候選清單，Phase 1 完成後凍結。

### 本提案要做的（In Scope 候選，v0.2.0）

- **IS-1 擴充鍵列**：終端 UI 上方常駐鍵列，至少含 Esc / Ctrl（組合鍵模式）/ Tab / Shift+Tab / 方向鍵；支援長按重複。對應工作流依賴：coding agent TUI 的中斷（Esc）與模式切換（Shift+Tab）。
- **IS-2 WebSocket 斷線自動重連**：偵測連線中斷（網路切換、app 回前景、tailnet 短暫不可達）後自動重連並恢復畫面。session 內容的存活由遠端 multiplexer 承擔（ttyd 起始指令設為 attach 既有 session）；client 只負責「重連後回到同一個 session」的正確性。
- **IS-3 多 endpoint 管理**：enroll 與 app 支援一台以上目標（本機之外加 VM）；連線畫面可選目標。憑證包結構的相容性處理一併評估。
- **IS-4 全螢幕 TUI 相容性**：coding agent 的全螢幕介面在 app 內渲染正確——色彩、游標定位、畫面更新頻率、scrollback 行為以 Phase 1 的現成 client 表現為 baseline 對照。

### 本提案不做的（Out of Scope）

- **mosh 式本地回顯預測** → tailnet 內 RTT 低（同城直連），預測回顯的工程量對體感增益不成比例；接受為與現成 client（mosh 路線）的 known gap，對照測時記錄體感差距，差距顯著再開獨立提案。
- **完成通知** → ntfy 的職責（工作流層已解），client 不重複做推播。PROP-001 Out of Scope 的延續。
- **session 持久化** → 遠端 multiplexer（zellij / tmux）的職責；client 只需 IS-2 的正確 re-attach。
- **多人／多租戶** → 維持 PROP-001 的單人自用定位。

> 「不做」清單項目未來需要時，建立新獨立提案綁定具體版本再設計。

## 替代方案

| 選項 | 內容 | 評估 |
|------|------|------|
| A 不做 parity | 長期用現成 client | 工作流可用，但放棄開發經驗與 Face ID / 稽核 / 客製三項差異化；app_tunnel 停在「連本機」的原始定位 |
| B 功能對齊（本提案） | 補齊工作流依賴的功能子集 | 範圍由 Phase 1 凍結、不會膨脹；每項有 baseline 可對照驗收 |
| C 全面對標現成 client | 對齊 Termius 級功能面 | 範圍無鎖、單人自用工具做不完也不需要；反模式——違反「一個提案一個版本明確範圍」 |

### 建議方案

B。A 保留為 tripwire 退路：對照測若顯示 parity 後體驗仍明顯落後、且差距來自 Out of Scope 的 mosh 回顯層，接受「現成 client 為日常主力、app_tunnel 為稽核 / 客製場景」的分工，不無限追趕。

## 機會成本

不做本提案的替代是現成 client（已可用），所以本提案的成本幾乎全是投資型：投入的是 app/ 端工程時間，換的是可遷移的終端 client 工程經驗與長期客製空間。主要機會成本是同時間可投入 blog 內容或其他專案；緩解方式是本提案不在關鍵路徑（P1）、可分小步做、每步有獨立驗收。

## 驗收條件

> 總驗收與分項驗收兩層。分項對應 In Scope；總驗收引用外部工作流的凍結判準。

- [ ] **AC-0（總驗收）**：外部工作流 Phase 1 凍結的驗證判準（十步驟 + 三個端到端情境：fire-and-forget / 斷線復原 / 資源保護），把 client 換成 app_tunnel 後全數重跑通過。
- [ ] **AC-1（對應 IS-1）**：手機端完成一次完整互動——attach session、對 agent 下指令、Esc 中斷一次、方向鍵翻歷史；鍵列全部按鍵注入正確。
- [ ] **AC-2（對應 IS-2）**：任務進行中 Wi-Fi 切行動網路再切回，app 自動重連並回到同一個 multiplexer session、任務未中斷、畫面恢復正確。
- [ ] **AC-3（對應 IS-3）**：兩個 endpoint（本機 + VM）都完成 enroll、app 內可切換連線、憑證各自獨立存放。
- [ ] **AC-4（對應 IS-4）**：coding agent 全螢幕 TUI 的渲染與 Phase 1 baseline 對照無阻礙性差異（色彩 / 游標 / 更新 / scrollback 逐項記錄）。

## Reality Test / 觸發案例實證

### 觸發案例

使用者要在 VM 上架「遠端 agent 工作機」（丟長任務給 coding agent、斷線走人、通知後回來看結果），手機端連線工具評估時確認：app_tunnel 現況缺擴充鍵列與斷線重連、且只設計了連本機——用於該工作流前有明確功能缺口。決策為 Phase 1 用現成 client 驗證工作流、Phase 2 由本提案補齊 parity。

### 假設列舉

- 假設 1：遠端 multiplexer attach 足以承擔斷線復原的 session 層，client 端只需重連正確（無需 mosh 級協定）。
- 假設 2：WebSocket 在網路切換場景的重連（走 Tailscale、位址不變）工程上可控，體感可接受。
- 假設 3：Flutter 端的終端渲染元件足以正確呈現 coding agent 的全螢幕 TUI。

### 已驗證 vs 未驗證

| 類別 | 內容 |
|------|------|
| 已驗證 | （無——三個假設都待實測） |
| 未驗證 | 假設 1-3 全部；Phase 1 會先用現成 client 驗證假設 1（zellij attach 的復原行為），為本提案降一項風險 |

## 多視角審查記錄

standard 級。promote（draft → confirmed）前補審查：至少一個終端相容性 / UX 視角（IS-1、IS-4 的鍵位與渲染細節），安全視角確認 IS-3 多憑證存放不弱化 PROP-001 的認證模型。

**狀態**：待執行。

## 前置依賴與分階段

本提案綁定單一版本 v0.2.0，不跨版本。兩個前置：

1. **PROP-001 IS-4**（Flutter 終端機 UI）落地——本提案的四項都疊在它上面。
2. **外部工作流 Phase 1 完成**——驗收規格（AC-0 引用的判準清單）在那之後才凍結，凍結前本提案維持 draft、不開 ticket。

## 風險與權衡

| 風險 | 影響 | 緩解措施 |
|------|------|---------|
| parity 後體感仍輸現成 client（mosh 回顯層差距） | 投入後日常仍用回 Termius | tripwire：對照測記錄逐項差距；差距集中在 Out of Scope 層則接受分工定位（見替代方案 A 退路） |
| 多 endpoint 改動波及 v2 憑證包結構 | 契約升版、既有配對失效 | 評估相容策略（憑證包內含版本欄位）；必要時 enroll 重跑而非遷移 |
| IS-4 渲染相容是未知深水區 | 工期不可控 | 先用 Phase 1 baseline 逐項列差異再估工；差異大時允許分兩個 ticket 批次 |

## 討論記錄

### 2026-07-08

提案源自遠端 agent 工作機工作流的連線層選型討論（記錄於 blog 專案的選型文與實作骨架文）。確認三件事：(1) 理想是現成工具先解鎖工作流、開發經驗累積由本提案承擔，兩者分軌不互擋；(2) parity 範圍鎖定為「工作流實際依賴的功能子集」、由 Phase 1 實測凍結，不對標現成 client 全功能；(3) mosh 式本地回顯明確列為 Out of Scope 的 known gap，對照測後再決定要不要獨立提案。

分級判定為 **standard**：主要改動集中在 app/ 單端、不動認證模型與架構層（IS-3 的憑證包相容性是唯一可能觸及契約的點、已列風險）。promote 路徑：Phase 1 完成凍結驗收 → 補審查 → 開 ticket → confirmed。

## 轉化記錄

| 轉化類型 | 檔案 | 日期 | 狀態 |
|---------|------|------|------|
| 規格 | （待範圍凍結後轉化） | - | pending |
| 用例 | （待範圍凍結後轉化） | - | pending |
| Ticket | （待 promote 時開立） | - | pending |
