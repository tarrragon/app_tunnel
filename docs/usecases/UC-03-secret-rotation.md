---
id: UC-03
title: "帳密輪替"
status: draft
source_proposal: PROP-001
created: "2026-06-16"
updated: "2026-06-17"
version: "2.0"

# 行為者
primary_actor: "使用者（本機 owner）"
secondary_actors: ["主機 enroll 子命令", "Flutter app"]

# 平台歸屬（both = app + server）
platform: both
extension_status: not-applicable

# 關聯
related_specs:
  - spec/enrollment/qr-enrollment.md
  - spec/auth/three-layer-auth.md
related_usecases: [UC-01]
ticket_refs: []
---

# UC-03: 帳密輪替

## 基本資訊

| 項目 | 值 |
|------|-----|
| 用例 ID | UC-03 |
| 用例名稱 | 帳密輪替 |
| 主要行為者 | 使用者（人在主機旁，定期輪替或懷疑帳密外洩） |
| 利益關係人 | 使用者：要讓舊帳密失效、新帳密生效，重建配對 |
| 前置條件 | 已完成過一次配對（UC-01）；人在主機旁 |
| 成功保證 | ttyd 使用新帳密；手機 secure storage 更新為新憑證；舊帳密不再被接受 |

## 資訊鏈（整合測試對應）

```
更換 ttyd 帳密 → 重跑 enroll 組新憑證包 → 重顯 QR → 手機重掃覆寫 secure storage
  → 舊帳密連線被 ttyd 拒（401）
```

| 資訊鏈測試名稱 pattern | 測試路徑 | 狀態 |
|----------------------|---------|------|
| `Credential Rotation End-to-End` | （待建立） | 缺少，待建立 |

## 主要成功場景

1. **更換帳密**
   - 使用者更換 ttyd 帳密（修改 ttyd 啟動設定）

2. **重新配對**
   - 使用者重跑 `enroll`（組新憑證包含更新的帳密）
   - 系統重顯 QR
   - 手機重掃，覆寫 secure storage 內舊憑證

3. **驗證舊帳密失效**
   - 以舊帳密發起連線被 ttyd 拒（401）

## 例外場景

### EX-03-01: 手機未重掃即連線

| 項目 | 值 |
|------|-----|
| 觸發條件 | 主機已換新帳密，手機仍存舊憑證 |
| 處理方式 | 手機以舊帳密連線被 ttyd 拒（401） |
| 使用者提示 | 「認證失敗」（需重新配對） |
| 恢復策略 | 重掃新 QR（主要場景步驟 2） |

## 驗收條件

### 功能驗收

- [ ] 更換帳密後重跑 enroll 產生新憑證包
- [ ] 手機重掃後以新帳密可連線
- [ ] 舊帳密連線被拒（401）

## 變更歷史

| 版本 | 日期 | 變更內容 |
|------|------|---------|
| 1.0 | 2026-06-16 | 初始骨架（密鑰輪替，含 proxy token） |
| 2.0 | 2026-06-17 | 改用 Tailscale：密鑰輪替→帳密輪替、移除 proxy token、拒絕碼 404→401 |
