---
id: UC-02
title: "日常遠端連線操作終端機"
status: draft
source_proposal: PROP-001
created: "2026-06-16"
updated: "2026-06-17"
version: "2.0"

# 行為者
primary_actor: "使用者（人在外）"
secondary_actors: ["Tailscale", "Go proxy", "ttyd", "zsh"]

# 平台歸屬（both = app + server）
platform: both
extension_status: not-applicable

# 關聯
related_specs:
  - spec/auth/three-layer-auth.md
  - spec/proxy/go-reverse-proxy.md
  - spec/client/flutter-terminal-client.md
  - spec/connectivity/tailscale.md
related_usecases: [UC-01, UC-04]
ticket_refs: []
---

# UC-02: 日常遠端連線操作終端機

## 基本資訊

| 項目 | 值 |
|------|-----|
| 用例 ID | UC-02 |
| 用例名稱 | 日常遠端連線操作終端機 |
| 主要行為者 | 使用者（人在外，已完成 UC-01 配對） |
| 利益關係人 | 使用者：要安全、低延遲地操作本機 zsh |
| 前置條件 | 已配對（secure storage 有憑證）；手機已加入 tailnet；主機服務已啟動（UC-04）；Tailscale 連線正常 |
| 成功保證 | app 顯示可互動的 zsh 終端機，輸入輸出雙向流通 |

## 資訊鏈（整合測試對應）

```
Face ID 解鎖 → 讀 secure storage 憑證
  → Tailscale VPN 連線至主機 → proxy(稽核 log) → ttyd basic auth → zsh PTY → 雙向 WS 訊框
```

| 資訊鏈測試名稱 pattern | 測試路徑 | 狀態 |
|----------------------|---------|------|
| `Remote Session End-to-End` | （待建立） | 缺少，待建立 |

## 主要成功場景

1. **解鎖**
   - 使用者開 app，過 Face ID / BiometricPrompt
   - app 解鎖 secure storage 讀取憑證

2. **建立連線**
   - app 透過 Tailscale VPN 連線至主機 endpoint，帶 ttyd basic auth header
   - proxy 記錄稽核 log（client_ip 取自 Tailscale 對端 IP）→ 透明轉發至 ttyd → ttyd basic auth 通過

3. **操作終端機**
   - 使用者輸入指令（含 Esc/Ctrl/方向鍵）
   - WS `'0'` 傳鍵盤資料，zsh 回傳輸出，app 渲染

4. **resize / 結束**
   - 視窗變更以 WS `'1'` + JSON 傳 columns/rows
   - 使用者關閉連線

## 例外場景

### EX-02-01: 生物辨識失敗

| 項目 | 值 |
|------|-----|
| 觸發條件 | Face ID / BiometricPrompt 未通過 |
| 處理方式 | 不讀取憑證、不發起連線 |
| 使用者提示 | 「驗證失敗，請重試」 |
| 恢復策略 | 重新辨識 |

### EX-02-02: Tailscale 離線

| 項目 | 值 |
|------|-----|
| 觸發條件 | 手機或主機 Tailscale 未連線 |
| 處理方式 | 連線逾時 |
| 使用者提示 | 「無法連線，請確認 Tailscale 已啟用」 |
| 恢復策略 | 確認雙方 Tailscale 已上線 |

### EX-02-03: ttyd 認證失敗

| 項目 | 值 |
|------|-----|
| 觸發條件 | ttyd basic auth 帳密錯誤 |
| 處理方式 | ttyd 回 401 |
| 使用者提示 | 「認證失敗，請確認憑證或重新配對（UC-01）」 |
| 恢復策略 | 重新配對取得正確帳密 |

### EX-02-04: ttyd 無回應 / 網路中斷

| 項目 | 值 |
|------|-----|
| 觸發條件 | proxy→ttyd timeout，或 Tailscale 隧道中途斷線 |
| 處理方式 | proxy 在 timeout 後明確失敗並記 ERROR log |
| 使用者提示 | 「連線中斷」 |
| 恢復策略 | 確認主機服務存活（UC-04），重新連線 |

## 驗收條件

### 功能驗收

- [ ] 主要場景：解鎖 → Tailscale 連線 → ttyd 認證 → 操作 zsh → 雙向 I/O 全鏈路走通
- [ ] EX-02-03：ttyd 認證失敗時回 401
- [ ] EX-02-04：ttyd 無回應時 timeout 明確失敗並記 log

### 邊界條件

- [ ] 可輸入 Esc / Ctrl 組合 / 方向鍵
- [ ] proxy 稽核 log 記錄本次連線（含 client_ip），不含 PTY 內容

### 效能要求（如適用）

| 指標 | 目標值 |
|------|--------|
| 按鍵到回顯延遲 | 體感即時（受 Tailscale 隧道網路影響，不設硬性 SLA） |

## UI 互動流程

```
[啟動 app] --Face ID--> [連線中] --Tailscale + ttyd auth OK--> [終端機畫面]
                  \--辨識失敗--> [重試提示]
[終端機畫面] --斷線--> [連線中斷提示] --重連--> [連線中]
```

## 變更歷史

| 版本 | 日期 | 變更內容 |
|------|------|---------|
| 1.0 | 2026-06-16 | 初始骨架（PROP-001 轉化） |
| 2.0 | 2026-06-17 | 改用 Tailscale：三層認證→兩層、新增 Tailscale 離線例外、移除 CF Access 相關 |
