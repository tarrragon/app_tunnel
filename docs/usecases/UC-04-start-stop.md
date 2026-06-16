---
id: UC-04
title: "啟停服務（手動起停姿態）"
status: draft
source_proposal: PROP-001
created: "2026-06-16"
updated: "2026-06-17"
version: "2.0"

# 行為者
primary_actor: "使用者（本機 owner）"
secondary_actors: ["ttyd", "Go proxy"]

# 平台歸屬（server = 僅主機端）
platform: server
extension_status: not-applicable

# 關聯
related_specs:
  - spec/connectivity/tailscale.md
  - spec/proxy/go-reverse-proxy.md
related_usecases: [UC-02]
ticket_refs: []
---

# UC-04: 啟停服務（手動起停姿態）

## 基本資訊

| 項目 | 值 |
|------|-----|
| 用例 ID | UC-04 |
| 用例名稱 | 啟停服務（手動起停姿態） |
| 主要行為者 | 使用者（本機 owner） |
| 利益關係人 | 使用者：要用時起、用完關，ttyd+proxy 不常駐 |
| 前置條件 | 主機已裝 proxy / ttyd；主機已加入 Tailscale tailnet（Tailscale daemon 常駐） |
| 成功保證 | 啟動後 Tailscale 網路內可達 proxy；關閉後兩行程皆停 |

## 資訊鏈（整合測試對應）

```
起：啟 ttyd + proxy → Tailscale 網路內 endpoint 可達
關：停兩行程 → endpoint 不可達
（Tailscale daemon 常駐，不受起停影響）
```

| 資訊鏈測試名稱 pattern | 測試路徑 | 狀態 |
|----------------------|---------|------|
| `Start Stop Lifecycle` | （待建立） | 缺少，待建立 |

## 主要成功場景

1. **啟動**
   - 使用者執行起動腳本（`deploy/`）
   - 系統依序啟 ttyd → proxy

2. **確認可達**
   - Tailscale 網路內 endpoint 可達 proxy（供 UC-02 連線）

3. **關閉**
   - 使用者執行停止腳本
   - 系統關閉兩個行程；proxy graceful shutdown 釋放連線

4. **確認不可達**
   - endpoint 不再可達（ttyd+proxy 已停）

## 例外場景

### EX-04-01: port 被占用

| 項目 | 值 |
|------|-----|
| 觸發條件 | ttyd / proxy 監聽 port 已被其他行程占用 |
| 處理方式 | 啟動失敗並明確報錯（不靜默） |
| 使用者提示 | 「port 已被占用」 |
| 恢復策略 | 釋放 port 或調整設定後重啟 |

### EX-04-02: 關閉後行程殘留

| 項目 | 值 |
|------|-----|
| 觸發條件 | 停止腳本未能關閉全部兩行程 |
| 處理方式 | 腳本回報殘留行程清單 |
| 使用者提示 | 「以下行程仍在執行：…」 |
| 恢復策略 | 手動結束殘留行程 |

## 驗收條件

### 功能驗收

- [ ] 啟動後 Tailscale 網路內 endpoint 可達 proxy
- [ ] 關閉後兩行程皆停、endpoint 不可達
- [ ] proxy 收到停止訊號時 graceful shutdown

### 邊界條件

- [ ] 重開機後 ttyd/proxy 不自動啟動（launchd 不放 LaunchAgents、systemd 不 enable）
- [ ] Tailscale daemon 重開機後自動恢復連線（不受起停影響）

## 變更歷史

| 版本 | 日期 | 變更內容 |
|------|------|---------|
| 1.0 | 2026-06-16 | 初始骨架（PROP-001 轉化，含 cloudflared 三行程） |
| 2.0 | 2026-06-17 | 改用 Tailscale：移除 cloudflared、三行程→兩行程、Tailscale daemon 常駐 |
