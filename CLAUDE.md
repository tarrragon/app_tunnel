# CLAUDE.md

本文件為 Claude Code 在此專案中的開發指導規範。

---

## 0. Behavioral Core Principle

This Claude framework passes information through the ticket system. The reader of any
output or conversation is not necessarily a human — it is often the next session or
another agent. Therefore:

- Do not apologize, praise, encourage, or re-confirm information that is already known.
- When writing code or documentation, do not make assumptions beyond the task at hand.
- If something needs further analysis or adjustment, open a ticket and hand it to the
  next session or agent instead of expanding the current scope.
- Avoid reasoning or complexity that exceeds what the ticket requires.

---

## 1. 專案身份

**專案名稱**: app_tunnel

**專案目標**: 手機透過 Tailscale mesh VPN 遠端操作本機真實終端機的**單人自用工具**。鏈路:`Flutter app（Face ID）→ Tailscale VPN → 本機 Go proxy（稽核 log）→ ttyd（basic auth）→ zsh`。

**專案類型**: 單人自用自架基礎設施工具(非 SaaS、非多租戶、非對外服務)。**Monorepo** 管理:Flutter 手機端 + Go 本機 proxy。

| 項目 | 值 |
|------|------|
| **語言** | Flutter/Dart(`app/` 手機端)、Go(`server/` 本機 proxy) |
| **實作代理人** | `parsley-flutter-developer`(app)、`fennel-go-developer`(server) |
| **識別特徵** | `app/pubspec.yaml`、`server/go.mod` |

**啟用的 MCP/Plugin**:

- dart - Dart/Flutter 開發工具
- serena - 語意程式碼操作
- context7 - 文件查詢

---

## 2. 核心價值

@.claude/rules/core/quality-baseline.md

---

## 3. 規則系統

@.claude/rules/README.md

---

## 4. Skill 指令

@.claude/pm-rules/skill-index.md

---

## 5. 方法論參考

@.claude/pm-rules/methodology-index.md

---

## 6. 技術選型與架構決策

完整決策記錄（§0 定錨 / §1 操作盤點 BDD / §2 Domain Map + 介面契約 / §3 技術維度 D1–D9 / §4 防護底線 / §5 tripwire）見 `docs/tech-decisions.md`。

### 決策索引（按需查詢，不 auto-load 全文）

| 編號 | 維度 | 選型 | 詳見 |
| ---- | ---- | ---- | ---- |
| D1 | server 語言 | Go | `docs/tech-decisions.md` §3 |
| D2 | repo 管理 | Monorepo | `docs/tech-decisions.md` §3 |
| D3 | 手機端 | 原生 Flutter 終端機 UI | `docs/tech-decisions.md` §3 |
| D4 | 認證 | 兩層（Tailscale 裝置認證 + ttyd basic auth） | `docs/tech-decisions.md` §3 |
| D5 | 運作姿態 | Tailscale + 手動起停 ttyd/proxy | `docs/tech-decisions.md` §3 |
| D6 | 密鑰保管 | 可插拔後端 | `docs/tech-decisions.md` §3 |
| D7 | 憑證配對 | QR enrollment 設計 A | `docs/tech-decisions.md` §3 |
| D8 | Observability | 結構化稽核 log | `docs/tech-decisions.md` §3 |
| D9 | Reliability | CI gate + 測試 + timeout | `docs/tech-decisions.md` §3 |
| — | State-Storage | 無 application datastore | `docs/tech-decisions.md` §3 |

### 需求文件索引

| 文件類型 | 位置 | 說明 |
| -------- | ---- | ---- |
| 提案 | `docs/proposals/PROP-001-mvp-remote-terminal.md` | MVP 遠端終端機 |
| 規格（5 domain） | `docs/spec/{auth,proxy,enrollment,client,connectivity}/` | 每個自建 domain 一份 |
| 用例（4 操作） | `docs/usecases/UC-01~04*.md` | 配對、連線、輪替、啟停 |
| 契約 | `docs/contract.md` | app⇄server 共用 SOT |

### 目錄結構

```
app_tunnel/
├── app/          # Flutter 手機端(原生終端機 UI)
├── server/       # Go 本機 proxy(稽核 log + WS 透明轉發)
├── deploy/       # ttyd config、Tailscale 設定指引、launchd plist、起停腳本
├── docs/         # 決策記錄、契約規格、需求文件、upstream-feedback
└── CLAUDE.md
```

### 框架缺口待回饋

套用 saas-tech-selection 時發現的缺口已記於 `docs/upstream-feedback/saas-tech-selection-gaps.md`（交付形態 gate 缺自用工具形態、認證維度缺裝置綁定+共享密鑰、部署維度缺 mesh VPN 形態 + 介面契約段缺口），待回 blog 修正。

---

## 6.5 需求確認協議與框架回饋

### 採用 saas-tech-selection 模式（特例調整）

本專案的初始需求確認**採用 `saas-tech-selection` skill 的訪談協議**(定錨 → 交付形態 gate → BDD 操作盤點 → DDD domain/event 切分 → 技術維度展開)。

**但本專案是特例**:它**與伺服器有關、卻不是架站(site-building)**。而 `saas-tech-selection` 現有內容(v0.6.0)主要針對「架站 / 後端 SaaS」場景設計(交付形態 gate 預設選項為 Shopify / Wix / WordPress / Firebase 等託管平台、commodity domain 假設認證/金流/表單等網站能力)。因此套用時需:

- 沿用其**訪談骨架與防護底線哲學**(行為先於系統、領域事件骨架、問漏才是成本、底線不可沉默跳過)。
- 對**不適用架站假設的維度**做調整判讀(交付形態 gate 的「託管平台」選項、網站導向的 commodity domain check 等,在「伺服器但非架站」場景下需重新詮釋或替換)。

### 缺口回饋上游(強制)

套用過程中**額外確認、發現缺口、或需修正的部分**,不可只停在本專案 —— 必須**回饋給 `saas-tech-selection` skill 做功能擴充與修正**。

**上游關係(authoring upstream)**:`saas-tech-selection` 的權威來源在 **`/Users/mac-eric/project/blog`**(其 `.claude/` 為獨立 git repo,remote `tarrragon/blog.git`)。app_tunnel 是**下游消費端**,本地 skill 會被上游同步覆蓋。

**回饋流向**:

```
app_tunnel(消費端,發現缺口)
        │  記錄「伺服器但非架站」場景的調整與新增需求
        ▼
/Users/mac-eric/project/blog(authoring upstream,實際修改 skill)
        ▼
tarrragon/claude(框架散佈,其他專案受惠)
```

**原則**:修正在 app_tunnel 本地驗證可行後,**回到 blog 修改 skill 本體**再同步散佈。直接改 app_tunnel 本地的 `.claude/skills/saas-tech-selection/` 會在下次同步時遺失,因此本地僅作**驗證與缺口記錄**,正式修改一律在 blog 進行。

---

## 7. 專案文件

### 任務追蹤

| 文件 | 用途 |
|------|------|
| `docs/todolist.yaml` | 結構化版本索引（Source of Truth） |
| `docs/work-logs/` | 版本工作日誌 |
| `CHANGELOG.md` | 版本變更記錄 |
| `docs/work-logs/v{version}/tickets/` | Ticket 文件 |

---

## 8. 里程碑

- v0.0.x: 基礎架構與技術選型
- v0.x.x: 開發階段,逐步實現功能
- v1.0.0: 完整功能

---

## 9. 交付守門（Definition of Done）

本專案為 monorepo（`app/` Flutter + `server/` Go）。除各 ticket 自身 acceptance 外，下列為專案級交付守門，任一不滿足即非「完成」：

| DoD | 要求 | 依據 |
|-----|------|------|
| CI 對稱守門 | 每個可獨立編譯的子端（app / server）都必須有對應 CI job（analyze/vet + test）。新增子端或新可編譯產物時，同版本必須補上 CI job，缺則建 ticket 追蹤，不可只靠本機綠燈 | `PC-TUNL-001` |
| 跨環境可重現 | 版本約束（SDK / 語言版本）不可只在開發者本機驗證；以 CI 獨立環境跑 analyze + test 為最低限度的 reproducibility gate | `PC-TUNL-001`、quality-baseline 規則 1 |
| CI scope 標注 | CI 設定檔若在某張單端 ticket 內誕生/修改，須於 ticket 標注「本 CI 覆蓋哪些端、哪端待補」，避免缺口無人認領 | `PC-TUNL-001` |

> 背景：v1.0.0 開發期 Flutter 端只有本機 `flutter test` 綠燈、未進 CI，且 scaffold 自帶的 Dart SDK 約束在開發者本機恰好相符，遮蔽了「換環境無法編譯」的事實，直到 v1.1.0 才發現並補正。

---

*專案入口文件 - 詳細規則請參考 .claude/rules/ 目錄*
