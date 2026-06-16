# CLAUDE.md

本文件為 Claude Code 在此專案中的開發指導規範。

---

## 1. 專案身份

**專案名稱**: app_tunnel

**專案目標**: <!-- 待補充:app_tunnel 的用途與願景尚未定義 -->

**專案類型**: <!-- 待決定:技術棧尚未選定（見 README 開發狀態） -->

| 項目 | 值 |
|------|------|
| **語言** | 待決定 |
| **實作代理人** | 待決定（選定技術棧後指派） |
| **識別特徵** | 待決定（如 pubspec.yaml / package.json / go.mod 等） |

**啟用的 MCP/Plugin**:

<!-- 選定技術棧後補上語言相關 MCP；以下為通用工具 -->

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

<!-- 技術棧尚未決定。選定後在此記錄架構模式、目錄結構、狀態管理等決策。 -->

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

*專案入口文件 - 詳細規則請參考 .claude/rules/ 目錄*
