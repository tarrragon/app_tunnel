---
id: UC-01
title: "首次配對（掃 QR enrollment）"
status: draft
source_proposal: PROP-001
created: "2026-06-16"
updated: "2026-06-16"
version: "1.0"

# 行為者
primary_actor: "使用者（本機 owner）"
secondary_actors: ["主機 enroll 子命令", "Flutter app"]

# 平台歸屬（本專案語意：both = app + server 兩端；本工具無 Chrome Extension）
platform: both
extension_status: not-applicable

# 關聯
related_specs:
  - spec/enrollment/qr-enrollment.md
  - spec/auth/three-layer-auth.md
  - spec/client/flutter-terminal-client.md
related_usecases: [UC-03]
ticket_refs: []
---

# UC-01: 首次配對（掃 QR enrollment）

> **平台欄位說明**：本專案為「伺服器但非架站」工具，`platform`/`extension_status` 沿用 doc skill 的 Chrome Extension 欄位但重新詮釋——`both` 代表 app + server 兩端皆涉及，`extension_status: not-applicable` 表本工具無 Chrome Extension。缺口已記 `docs/upstream-feedback/`。

## 基本資訊

| 項目 | 值 |
|------|-----|
| 用例 ID | UC-01 |
| 用例名稱 | 首次配對（掃 QR enrollment） |
| 主要行為者 | 使用者（人在主機旁） |
| 利益關係人 | 使用者：要把整包憑證安全灌進手機，不經剪貼簿/雲 |
| 前置條件 | 主機已裝 proxy binary 與 `qrencode`；CF Access service token 與 ttyd 帳密已備妥 |
| 成功保證 | 手機 secure storage 內有完整憑證包；主機密鑰已落後端；QR 已關閉 |

## 資訊鏈（整合測試對應）

```
enroll 產密鑰（crypto/rand）→ 存可插拔後端 → 組憑證包 JSON → qrencode ASCII QR
  → 手機掃描 → 解析 payload → 存 flutter_secure_storage
```

| 資訊鏈測試名稱 pattern | 測試路徑 | 狀態 |
|----------------------|---------|------|
| `Enrollment Pairing End-to-End` | （待建立） | 缺少，待建立 |

## 主要成功場景

1. **主機產憑證**
   - 使用者在主機執行 `app-tunnel-proxy enroll`
   - 系統以 `crypto/rand` 產生 64-hex 密鑰、存入後端（macOS keychain / Linux file 0600 / env）

2. **顯示 QR**
   - 系統組憑證包 JSON（含 endpoint、cf_access、proxy_token、ttyd 帳密）
   - 系統以 `qrencode -t ANSIUTF8` 在終端機印出 ASCII QR

3. **手機掃描**
   - 使用者開 app 掃描 QR
   - app 解析 payload，存入 `flutter_secure_storage`

4. **收尾**
   - 使用者關閉終端機 QR 顯示
   - 系統確認密鑰已落後端

## 例外場景

### EX-01-01: qrencode 未安裝

| 項目 | 值 |
|------|-----|
| 觸發條件 | 主機無 `qrencode` |
| 處理方式 | enroll 明確報錯，提示安裝指令；密鑰是否保留依實作定義 |
| 使用者提示 | 「找不到 qrencode，請先安裝」 |
| 恢復策略 | 安裝後重跑 enroll |

### EX-01-02: file 後端權限過寬

| 項目 | 值 |
|------|-----|
| 觸發條件 | file 後端密鑰檔 group/other 可讀 |
| 處理方式 | 啟動時檢查權限，過寬即拒絕（SPEC-003 FR-02） |
| 使用者提示 | 「密鑰檔權限過寬，請設為 0600」 |
| 恢復策略 | `chmod 600` 後重試 |

### EX-01-03: 手機掃描失敗

| 項目 | 值 |
|------|-----|
| 觸發條件 | QR 解析失敗或 payload 格式不符 |
| 處理方式 | app 不寫入 secure storage，提示重掃 |
| 使用者提示 | 「憑證格式無法辨識，請重新掃描」 |
| 恢復策略 | 重新顯示 QR 再掃 |

## 驗收條件

### 功能驗收

- [ ] 主要場景：enroll → 顯示 QR → 手機掃描 → 憑證落 secure storage 全鏈路可走通
- [ ] EX-01-02：file 後端權限過寬被拒絕
- [ ] EX-01-03：格式錯誤的掃描不污染 secure storage

### 邊界條件

- [ ] QR 僅顯示一次，掃描後可關閉
- [ ] 密鑰為 64-hex、由 `crypto/rand` 產生

## 變更歷史

| 版本 | 日期 | 變更內容 |
|------|------|---------|
| 1.0 | 2026-06-16 | 初始骨架（PROP-001 轉化） |
