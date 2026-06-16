# /doc skill 缺口記錄（回饋上游 blog）

> **用途**：app_tunnel 套用 `/doc` 需求追蹤文件系統（proposals/spec/usecases）過程中發現的缺口與修正建議。
> **回饋對象**：`/Users/mac-eric/project/blog`（skill authoring upstream，remote `tarrragon/blog.git`）。
> **原則**（見 CLAUDE.md 6.5）：本檔僅作缺口記錄與驗證，**正式修改一律在 blog 進行**，改完同步散佈回 app_tunnel。直接改本地 `.claude/skills/doc/` 會在下次 sync-pull 遺失。
> **發現版本**：doc skill v1.5.0
> **狀態（2026-06-16）**：三缺口**已記錄，待回饋 blog**。

---

## GAP-01：spec domain 列表硬編碼為 Chrome Extension 書籍 app domain

**現況**：`SKILL.md` 與 `references/spec.md` 的 Domain 列表寫死為特定專案的 domain——`extraction`（核心責任明文寫「從網頁提取書籍資料」）、`page`（頁面偵測、Content Script）、`messaging`（跨 context 通訊）、`user-experience`（UI、搜尋、篩選）。這是某個 Chrome Extension 書籍 app 專案的 domain 切分，被當成 doc skill 的通用規範。

**缺口**：domain 切分本應是**每個專案自己的領域知識**，不該由框架預設。本專案（app_tunnel：終端機 tunnel 工具）的合理 domain 是 `auth` / `proxy` / `enrollment` / `client` / `connectivity`，與書籍 app domain 零交集。新專案套用時，內建列表既不適用又有誤導性（讓人以為要硬塞進 extraction/page）。

**建議修正**：把 Domain 列表從「規範」降級為「範例」，明示「domain 由各專案依自身領域定義」；或抽離為專案層級的可覆寫設定（如 `docs/spec/domains.yaml`），SKILL.md 只定義「spec 必須依 domain 子目錄組織」這個 project-agnostic 規則，不預設具體 domain 名稱。

---

## GAP-02：usecase platform 欄位綁定 Chrome Extension + Flutter APP 雙端假設

**現況**：`references/usecases.md` 與 usecase 模板的 `platform` 欄位限 `both` / `app` / `extension`，並有 `extension_status`（implemented / partial / not-applicable）欄位。這假設了「Chrome Extension + Flutter APP 雙產品」的特定專案形態。

**缺口**：本專案是「Flutter app + Go server proxy」的形態，沒有 Chrome Extension。`platform: extension` 與整個 `extension_status` 欄位完全不適用。本專案被迫把 `extension` 重新詮釋為 `server`、`extension_status` 一律標 `not-applicable`，是對框架欄位的扭曲使用。其他形態（純 CLI、純 backend、web + mobile）也都會撞到同樣問題。

**建議修正**：`platform` 不應是固定 enum，改為各專案可定義的值集合（如本專案 `app` / `server` / `both`）；移除 `extension_status` 這個專案專屬欄位，或泛化為「per-platform 實作狀態」的通用結構。

---

## GAP-03：usecases.md 規範文件混入書籍 app 的具體測試對應範例

**現況**：`references/usecases.md` 的「UC 測試對應要求」章節直接列出書籍 app 的具體 UC 與測試路徑（UC-01「頁面偵測 → Content Script → DOM 擷取」、`tests/integration/chrome-extension/data-flow-end-to-end.test.js` 等）。

**缺口**：規範文件（定義「UC 必須有資訊鏈整合測試」這個原則）混入了某專案的具體案例與測試檔路徑。新專案讀規範時，這些 Chrome Extension 測試路徑是噪音，且讓人誤以為是框架要求的固定測試。

**建議修正**：規範只保留 project-agnostic 原則（「每個 UC 必須有至少一個完整資訊鏈整合測試 + 外部依賴邊界測試」），具體 UC 測試對應表移到範例附錄或標明「以下為某專案範例」。

---

## 處理紀錄

- 2026-06-16 — 套用 doc skill 建立 PROP-001 + 5 spec + 4 usecase 時發現三缺口，記錄待回饋 blog。本地 spec/usecase 已用本專案語意（domain 重定義、platform=server、extension_status=not-applicable）並於檔內註記。

## 待補充

<!-- 後續使用 doc skill 若再發現缺口，持續往下追加 GAP-0x。回饋 blog 後在此標記已處理。 -->
