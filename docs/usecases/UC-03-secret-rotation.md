---
id: UC-03
title: "密鑰輪替"
status: draft
source_proposal: PROP-001
created: "2026-06-16"
updated: "2026-06-16"
version: "1.0"

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

# UC-03: 密鑰輪替

> **平台欄位說明**：見 UC-01（`both` = app + server，本工具無 Chrome Extension）。

## 基本資訊

| 項目 | 值 |
|------|-----|
| 用例 ID | UC-03 |
| 用例名稱 | 密鑰輪替 |
| 主要行為者 | 使用者（人在主機旁，懷疑密鑰外洩或定期輪替） |
| 利益關係人 | 使用者：要讓舊密鑰失效、新密鑰生效，重建配對 |
| 前置條件 | 已完成過一次配對（UC-01）；人在主機旁 |
| 成功保證 | 主機後端為新密鑰；手機 secure storage 更新為新憑證；舊密鑰不再被接受 |

## 資訊鏈（整合測試對應）

```
重跑 enroll 產新密鑰 → 覆寫後端 → 重顯 QR → 手機重掃覆寫 secure storage
  → 舊密鑰連線被 proxy 拒（404）
```

| 資訊鏈測試名稱 pattern | 測試路徑 | 狀態 |
|----------------------|---------|------|
| `Secret Rotation End-to-End` | （待建立） | 缺少，待建立 |

## 主要成功場景

1. **重產密鑰**
   - 使用者重跑 `enroll`（預設產生新密鑰）
   - 系統以新密鑰覆寫後端

2. **重新配對**
   - 系統重顯 QR
   - 手機重掃，覆寫 secure storage 內舊憑證

3. **驗證舊密鑰失效**
   - 以舊密鑰發起連線被 proxy 拒（404）

## 替代場景

### 03a: 多後端切換時的輪替

**觸發條件**：proxy 從 macOS（keychain）遷至 Linux（file）

1. 在新主機重跑 enroll，密鑰存對應後端
2. 重掃 QR 更新手機憑證
3. 回到主要場景步驟 3 驗證

## 例外場景

### EX-03-01: 手機未重掃即輪替

| 項目 | 值 |
|------|-----|
| 觸發條件 | 主機已換新密鑰，手機仍存舊憑證 |
| 處理方式 | 手機以舊密鑰連線被 proxy 拒（404） |
| 使用者提示 | 「無法連線」（需重新配對） |
| 恢復策略 | 重掃新 QR（主要場景步驟 2） |

## 驗收條件

### 功能驗收

- [ ] 重跑 enroll 產生不同於舊值的新密鑰並覆寫後端
- [ ] 手機重掃後以新憑證可連線
- [ ] 舊密鑰連線被拒（404）

### 邊界條件

- [ ] 輪替不需改 proxy 主路徑（runtime 認證模型不變）

## 變更歷史

| 版本 | 日期 | 變更內容 |
|------|------|---------|
| 1.0 | 2026-06-16 | 初始骨架（PROP-001 轉化） |
