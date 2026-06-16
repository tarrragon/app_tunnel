---
id: SPEC-002
title: "Go 透明反向代理"
status: draft
source_proposal: PROP-001
created: "2026-06-16"
updated: "2026-06-17"
version: "1.1"
owner: fennel-go-developer

# Domain 歸屬
domain: proxy
subdomain: null

# 關聯
related_usecases: [UC-02, UC-04]
related_specs:
  - spec/auth/three-layer-auth.md
  - spec/connectivity/tailscale.md
depends_on_domains: [auth, connectivity]
---

# Go 透明反向代理

## 概述

本機 Go proxy 負責稽核 log + 透明轉發 WS 到 `localhost:7681`（ttyd）。不做認證——認證由 Tailscale（網路層）+ ttyd basic auth（應用層）處理（見 SPEC-001）。職責極小（docs/tech-decisions.md D1），用 stdlib `httputil.ReverseProxy`，編譯為單一靜態 binary。

> **核實標記（2026-06-16，對照 `server/main.go`）**：proxy 主體（透明代理、timeout、graceful shutdown、稽核 log）程式碼皆已實作。改用 Tailscale 後認證閘道程式碼將移除，測試對應調整。
> **變更記錄（2026-06-17）**：proxy 不再做認證（原 X-App-Tunnel-Token 驗證移除），只保留稽核 log + 透明轉發 + timeout + shutdown。

## 功能需求

### FR-01: 透明 WebSocket 反向代理

| 項目 | 值 |
|------|-----|
| 優先級 | P0 |
| 來源 | PROP-001 IS-2 |
| 對應用例 | UC-02 |
| 狀態 | 部分實作（`httputil` 透明代理 + `isWebSocketUpgrade` 已實作；HTTP 轉發有測試；WS upgrade 端到端未測） |

**描述**：HTTP 層透明反向代理，不改 WS 訊框。app 直接講 ttyd `tty` 子協議（`docs/contract.md`）。

**約束條件**：

- 不改寫 WS 訊框內容（透明）
- 端點 `/ws`，subprotocol `tty`

**驗收標準**：

- [ ] WS upgrade 透明轉發成功，訊框不被改動（透明代理機制已實作，端到端未測）

---

### FR-02: proxy→ttyd 明確 timeout

| 項目 | 值 |
|------|-----|
| 優先級 | P1 |
| 來源 | PROP-001 IS-2 / CLAUDE.md D9 |
| 對應用例 | UC-02 |
| 狀態 | 已實作（程式碼完整，無觸發測試）：`DialContext` timeout + `ErrorHandler` 回 502 記 ERROR log |

**描述**：外部呼叫（連 ttyd）必須有 timeout，避免依賴失敗時無限等待。

**驗收標準**：

- [x] ttyd 無回應時 timeout 後明確失敗並記 ERROR log（程式碼層達成；無觸發測試）

---

### FR-03: Graceful shutdown

| 項目 | 值 |
|------|-----|
| 優先級 | P1 |
| 來源 | PROP-001 IS-2 / CLAUDE.md D9 |
| 對應用例 | UC-04 |
| 狀態 | 已實作（程式碼完整，無專門測試）：`signal.NotifyContext` + `srv.Shutdown` 5s timeout |

**描述**：收到停止訊號（SIGINT/SIGTERM）時停止接收新連線並在 5s 內優雅關閉。

> **限制**：WebSocket 為 hijacked 連線，`srv.Shutdown` 不追蹤，進行中終端機 session 會在工具停止時斷開（`main.go` 註解明示）。對 UC-04「手動用完關掉」的姿態可接受，不視為缺陷。

**驗收標準**：

- [x] 停止訊號觸發後停止接收新連線、5s 內 graceful shutdown（`signal.NotifyContext` + `srv.Shutdown`）

---

### FR-04: 結構化稽核 log

| 項目 | 值 |
|------|-----|
| 優先級 | P0 |
| 來源 | PROP-001 IS-2 / CLAUDE.md D8 |
| 對應用例 | UC-02 |
| 狀態 | 已實作：slog JSON accepted/rejected 事件 + `clientIP`（有 2 測試）；log 事件本身無斷言測試 |

**描述**：shell 閘道的關鍵訊號是「誰連上了」。記錄放行與拒絕連線（結構化 JSON），依賴（ttyd）失敗分類為 ERROR。

**約束條件**：

- client_ip 取自 `req.RemoteAddr`（Tailscale 內為真實對端 IP）
- **絕不 log PTY 內容**（含密碼）——透明 proxy 天然滿足；Phase 2 自開 PTY 時必須遵守

**驗收標準**：

- [x] 放行與拒絕連線皆有結構化 log（含 client_ip；`clientIP` 有 2 測試，log 事件本身無斷言測試）
- [x] log 不含任何 PTY 傳輸內容（透明代理天然不接觸 PTY）

---

## 非功能需求

### NFR-01: 最小攻擊面

| 項目 | 值 |
|------|-----|
| 類型 | 安全性 |
| 指標 | 零外部依賴（MVP）；go.mod/go.sum 鎖依賴 |

**描述**：靜態型別 + 小攻擊面適合「通往完整 shell」的安全敏感長駐服務。

## 設計約束

| 約束 | 說明 | 影響 |
|------|------|------|
| 跨平台 | 同一 binary 跨編譯 darwin/linux | proxy 可能跑在 Linux（影響密鑰後端，見 SPEC-003） |

## 變更歷史

| 版本 | 日期 | 變更內容 |
|------|------|---------|
| 1.0 | 2026-06-16 | 初始骨架（PROP-001 轉化） |
| 1.1 | 2026-06-17 | 改用 Tailscale：移除認證職責、client_ip 改取 RemoteAddr |
