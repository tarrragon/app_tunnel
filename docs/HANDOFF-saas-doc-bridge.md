# 交接：框架 saas-tech-selection ↔ doc 雙向銜接

> 本檔是給「乾淨 session」的交接規格，取代 ticket（前一 session 的 ticket CLI 假成功、work-logs 不存在、ticket 全是 confabulation，勿信）。
> **第一條鐵律**：不要信任任何敘述性「進度」。一切用 `find` / `git status` / `Read` 確認。真實錨點是 FS 上的檔案內容本身。

---

## 0. 接手前先確認真實狀態（必做）

前一 session 有嚴重 confabulation。先跑這些確認，不要憑本檔或記憶假設：

```bash
git ls-files docs/ | wc -l          # 前一 session 結束時為 0（docs 全 untracked、無 commit）
ls docs/work-logs 2>&1              # 前一 session 結束時不存在（無任何 ticket）
git status --porcelain .claude/skills/saas-tech-selection/ .claude/skills/doc/   # 應為空（本任務尚未開始）
find .claude/skills/saas-tech-selection -type f   # 確認 saas 真實檔案清單
```

**docs/ 下的既存 untracked 檔**（PROP-001、spec、usecases、tracking、todolist、framework-bloat-problem、本檔）是前一 session 的產物，**與本任務（改 saas/doc skill）無關**，可忽略，不要被它們牽動。

---

## 1. 任務

修補 `saas-tech-selection` 與 `doc` 兩個框架 skill 的斷鏈：saas 訪談走完產出「決策記錄」後，沒有把它移交給 doc 長成 proposal/spec/usecase，使用者得手動重述。做**雙向銜接**，且兩端各自仍能單獨運作（無對方時不報錯）。

**斷鏈本質**：saas 的決策記錄其實已含 doc 需要的全部原料（BDD 操作表、DDD domain map、技術決策），只缺「移交」這一步。

---

## 2. 流程定位（重要前置脈絡）

- 這是改**框架本體**（`.claude/skills/`），走**輕量流程**：改的是 markdown 指令、非程式邏輯。**不**走 spec/usecase/TDD/heavy proposal（那是給產品開發的，套到改框架文件是層次錯置）。
- 改完會 `sync-push` 散佈到**所有**用框架的專案。
- **saas 的改動要額外手動同步到 blog**：blog 在 `/Users/tarragon/Projects/blog`（同機可達，是 saas 的另一使用地、獨立於框架 sync）。doc 的改動只走 claude.git。
- 框架規則 PC-053「改 skill 要有 ticket」：本任務的追蹤錨點就是本交接檔 + 最後的 commit message（記錄為什麼改、改了什麼、影響哪些專案）。

---

## 3. confabulation 警告（前一 session 的教訓）

前一 session **虛構了 saas references 的整個內容**（聲稱有 `output-format.md` / `stage5-decision-record.md` / `interview-protocol.md`，這些**都不存在**）。

**真實的 saas 關鍵檔**（已用 find 確認）：
- `SKILL.md`
- `references/decision-record-template.md`（產出規格 = 決策記錄模板）
- `references/user-operations-bdd.md`（BDD 操作盤點）
- `references/domain-event-modeling.md`（DDD domain/event 切分）
- `references/interview-core.md`（定錨 + 核心問題 + 收斂判準）
- 另有 `references/dimensions/*`、`references/principles/`、`baseline-protections.md`、`scale-stage-triggers.md`

**動手前務必 Read 真實檔案確認錨點，不要照本檔的引文照貼**（本檔引文也可能有偏差）。

---

## 4. 映射表（saas 決策記錄 → doc）

> **實測修正（2026-06-17 回溯對帳）**：原映射表（下方劃線版）假設源頭三段（§1/§2/§3）都在。實測拿本專案 D1–D9 對帳前 session 手動產物，發現 **D1–D9 只有 §3 技術維度，§1/§2 不存在**——前 session 套 saas 時跳過 Stage 1/2 只記技術維度。三條線可行度因此分化：§3→proposal 高（省 ~80%）、§2→spec 中（FR 有源、domain 切分無源）、§1→usecase 低（操作盤點原料不存在，幾乎全省不掉）。斷鏈是症狀，**上游漏產 §1/§2** 才是病。修補主力＝管線 + 紀律雙管（決策見正文）。

修正後映射表（四條線 + 雙源 + 前置檢查）：

| saas 決策記錄段落 | → doc 文件 | 映射 |
|---|---|---|
| §1 使用者操作與風險表（BDD，Given/When/Then） | **usecase**（每個操作主體一個 UC） | 操作→用例、主情境→主成功場景、失敗情境→例外場景、風險+前端引導+後端防護→驗收條件 |
| §2 Domain Map | **spec**（每個自建 domain 一份）的 domain 邊界 + 責任 | domain→spec 目錄、責任→概述、command→FR（與 §3 雙源） |
| §3 技術維度決策 | **spec** 的 FR/NFR（與 §2 雙源）+ **proposal** 的技術決策 | 需求判讀→FR、選型/防護→NFR + proposal 決策依據 |
| §2 介面契約段（無 event 流時，見改動 B） | **spec** 的資料模型 + 介面規格章節 | payload schema / 子協議 / 資料模型→spec 介面規格 |
| §0 定錨 + 交付形態 gate + §4/5 底線/tripwire | **proposal** | 定錨+gate→需求來源/範圍界定、防護底線→驗收條件、tripwire→Out-of-Scope |

**前置檢查（紀律閘門）**：移交前確認 §1/§2 非空。任一為空＝訪談未走完 Stage 1/2，**回頭補盤點，不可硬生 usecase/spec**。
買掉（外包 vendor）的 domain：在 spec 標整合邊界、不展開內部 FR。

---

## 5. 六處改動（全部加節 / 改造現有，不新增檔案）

> 下列內容是草稿，動手前 Read 真實檔案確認插入位置與既有措辭。saas 檔用全形頓號「、」。
> **實測後新增改動 A（紀律）、B（契約）**；改動 1-4 沿用、但改動 3 的映射表改用第 4 節「修正後映射表」（四條線 + 雙源 + 前置檢查）。

### 改動 A：saas `decision-record-template.md` 填寫規則加一條（紀律閘門 — 修補主力）

「填寫規則」現有 4 條（理由回指 / 次選項留名 / 三欄齊備 / 原話保留）後加第 5 條：§1 操作風險表、§2 Domain Map 是強制段、不可空白交付。只填 §3 技術維度跳過 §1/§2 的決策記錄是「Stage 1/2 沒走完」的半成品 — §3 需求判讀無從回指、下游長不出 usecase（§1 空）與 domain spec（§2 空）。空白即回補 Stage 1/2、不可進 scaffold 或交付。

### 改動 B：saas `decision-record-template.md` §2 補「無 event 流時的介面契約段」

Event Catalog 表後加說明：透明轉發 / 無領域事件流架構（contract 不藏在 event payload）時、§2 補一個「介面契約」小段（client⇄server 共用 payload schema / 子協議 / 資料模型），供下游 spec 的「資料模型 + 介面規格」章節取用。對應 CLAUDE.md 已記的「saas 缺自用工具形態」缺口具體化。

### 改動 1：saas `SKILL.md` — Stage 5 後加 Stage 6

位置：「### Stage 5：決策收斂…」段落結尾、`---`、`## 訪談互動原則` 之前。插入：

```markdown
### Stage 6：銜接 doc 需求文件系統（條件式，專案有 doc skill 才執行）

決策記錄產出後、偵測專案是否載入 doc skill（檢查 `.claude/skills/doc/` 是否存在）：

- **有 doc skill** → 決策記錄不只進 `docs/tech-decisions.md`、還移交 doc 系統長成需求文件：操作風險表（BDD）→ usecase、domain map + event catalog（DDD）→ spec、定錨 + 交付形態 gate + 技術決策 → proposal。映射細節與移交步驟見 `references/decision-record-template.md` 的「銜接 doc 系統」節。
- **無 doc skill** → 維持現狀、決策記錄獨立產出（saas 單獨運作、不依賴 doc）。

這一步是「需求確認（saas）」到「需求文件化（doc）」的接點：saas 已產出 doc 需要的全部原料、此處只做格式移交、不重新訪談。
```

### 改動 2：saas `SKILL.md` — 觸發路由表加一列

在「訪談收斂、要產出決策文件與 scaffold 建議 → decision-record-template.md」那列之後加：

```markdown
| 決策記錄產出後、專案有 doc skill、要移交需求文件                                            | `references/decision-record-template.md`（銜接 doc 系統節）                                     |
```

### 改動 3：saas `references/decision-record-template.md` — 末尾加「銜接 doc 系統」節

在檔案最末（「決策改、scaffold 跟著重生」那段之後）加：

```markdown
## 銜接 doc 系統（專案有 doc skill 時）

決策記錄是 saas 的終點、也是 doc 需求文件系統的起點 — 它已含 doc 需要的全部原料、銜接只做格式移交、不重新訪談。偵測 `.claude/skills/doc/` 存在時、依下表把決策記錄各段移交為 doc 文件：

| 決策記錄段落 | → doc 文件 | 映射 |
| --- | --- | --- |
| §1 使用者操作與風險表（BDD） | usecase（每個操作主體一個 UC） | 操作→用例、主情境→主成功場景、失敗情境→例外場景、風險+前端引導+後端防護→驗收條件 |
| §2 Domain Map + Event Catalog（DDD） | spec（每個自建 domain 一份 spec） | domain→spec 的 domain 目錄、責任→概述、command→FR、event/公開面→介面規格、tripwire→設計約束 |
| §0 定錨 + 交付形態 gate + §3 技術維度決策 + §4/5 底線/tripwire | proposal | 定錨+gate→需求來源/範圍界定、技術決策→提案方案/決策依據、防護底線→驗收條件 |

移交步驟：(1) 先生成 proposal（綁範圍）、(2) 再依 domain map 生成各 spec、(3) 再依操作表生成各 usecase、(4) 補雙向交叉引用（proposal.outputs / spec.related_usecases / usecase.related_specs）。doc 端的接手細節見 doc skill 的「與 saas-tech-selection 的銜接」節。

買掉（外包 vendor）的 domain：在 spec 標整合邊界、不展開內部 FR；其 reliability 第三方依賴訪談結論進 spec 的設計約束。
```

### 改動 4：doc `SKILL.md` — 「## 與現有系統的整合」節加子節

在「## 與現有系統的整合」之後、「### 與 doc-flow 的分工」之前，加：

```markdown
### 與 saas-tech-selection 的銜接（需求上游）

saas-tech-selection skill 做完技術選型訪談後產出「決策記錄」，doc 是它的下游 — 把決策記錄長成 proposal/spec/usecase。偵測到 saas 決策記錄（`docs/tech-decisions.md` 或訪談產出）時，依下表接手：

| saas 決策記錄段落 | → doc 文件 | 接手動作 |
|------|------|---------|
| §1 操作與風險表（BDD） | usecase | 每個操作主體生成一個 UC：操作→用例、主/失敗情境→主/例外場景、風險+防護→驗收 |
| §2 Domain Map + Event Catalog（DDD） | spec | 每個自建 domain 一份 spec：責任→概述、command→FR、event/公開面→介面規格 |
| §0 定錨 + gate + §3-5 決策 | proposal | 範圍界定 + 決策依據 + 驗收，spec_refs/usecase_refs 指向上面生成的 |

接手順序：proposal（綁範圍）→ spec（依 domain map）→ usecase（依操作表）→ 補雙向交叉引用。saas 側的移交規格見 saas skill 的 `references/decision-record-template.md`「銜接 doc 系統」節。doc 單獨使用（無 saas）時此節不觸發、照常從模板建立。
```

---

## 6. 驗收

- [ ] saas `SKILL.md` 有 Stage 6 + 觸發路由列
- [ ] saas `decision-record-template.md` 有「銜接 doc 系統」節
- [ ] doc `SKILL.md` 有「與 saas-tech-selection 的銜接」子節
- [ ] 兩端各自含映射、各自能單獨運作（無對方時不觸發、不報錯）
- [ ] 在 app_tunnel 實測：實際走一遍 saas 訪談→產出決策記錄→Stage 6 偵測 doc→生成 proposal/spec/usecase，確認指令可被執行（孵化器對 markdown 指令的「測試」）
- [ ] `sync-push` 到 claude.git
- [ ] saas 的改動手動同步到 `/Users/tarragon/Projects/blog`

## 7. 範圍外（不做）

- spec/usecase/TDD/heavy proposal（層次錯置）
- doc 的 Domain 列表胎記清理（extraction/page/messaging 是別專案遺留，另案處理）
- doc CLI（`doc_system/*.py`）程式碼改動（本任務只寫指引，不寫 CLI）
- 前一 session 在 docs/ 留的 untracked 檔之清理（與本任務無關）
