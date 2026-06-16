---
id: UC-01
title: "首次配對（掃 QR enrollment）"
status: draft
source_proposal: PROP-001
created: "2026-06-16"
updated: "2026-06-17"
version: "2.0"

# 行為者
primary_actor: "使用者（本機 owner）"
secondary_actors: ["主機 enroll 子命令", "Flutter app"]

# 平台歸屬
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

## 基本資訊

| 項目 | 值 |
|------|-----|
| 用例 ID | UC-01 |
| 用例名稱 | 首次配對（掃 QR enrollment） |
| 主要行為者 | 使用者（人在主機旁） |
| 利益關係人 | 使用者：要把 ttyd 帳密 + endpoint 安全灌進手機，不經剪貼簿/雲 |
| 前置條件 | 主機已裝 proxy binary 與 `qrencode`；主機與手機皆已加入同一 Tailscale tailnet；ttyd 帳密已備妥 |
| 成功保證 | 手機 secure storage 內有完整憑證包（endpoint + ttyd 帳密）；QR 已關閉 |

## 資訊鏈（整合測試對應）

```
enroll 收集 endpoint + ttyd 帳密 → 組憑證包 JSON → qrencode ASCII QR
  → 手機掃描 → 解析 payload → 存 flutter_secure_storage
```

| 資訊鏈測試名稱 pattern | 測試路徑 | 狀態 |
|----------------------|---------|------|
| `Enrollment Pairing End-to-End` | （待建立） | 缺少，待建立 |

## 主要成功場景

1. **組憑證包**
   - 使用者在主機執行 `app-tunnel-proxy enroll`
   - 系統收集 Tailscale endpoint（IP 或 MagicDNS）與 ttyd 帳密，組成 v2 憑證包

2. **顯示 QR**
   - 系統以 `qrencode -t ANSIUTF8` 在終端機印出 ASCII QR

3. **手機掃描**
   - 使用者開 app 掃描 QR
   - app 解析 payload，存入 `flutter_secure_storage`

4. **收尾**
   - 使用者關閉終端機 QR 顯示

## 例外場景

### EX-01-01: qrencode 未安裝

| 項目 | 值 |
|------|-----|
| 觸發條件 | 主機無 `qrencode` |
| 處理方式 | enroll 明確報錯，提示安裝指令 |
| 使用者提示 | 「找不到 qrencode，請先安裝」 |
| 恢復策略 | 安裝後重跑 enroll |

### EX-01-02: 手機掃描失敗

| 項目 | 值 |
|------|-----|
| 觸發條件 | QR 解析失敗或 payload 格式不符 |
| 處理方式 | app 不寫入 secure storage，提示重掃 |
| 使用者提示 | 「憑證格式無法辨識，請重新掃描」 |
| 恢復策略 | 重新顯示 QR 再掃 |

### EX-01-03: 手機未加入 tailnet

| 項目 | 值 |
|------|-----|
| 觸發條件 | 手機未安裝 Tailscale 或未加入同一 tailnet |
| 處理方式 | 配對成功但後續連線會失敗（無法觸及 endpoint） |
| 使用者提示 | 建議 enroll 流程提示「請確認手機已加入 Tailscale」 |
| 恢復策略 | 安裝 Tailscale 並加入 tailnet |

## 驗收條件

### 功能驗收

- [ ] 主要場景：enroll → 顯示 QR → 手機掃描 → 憑證落 secure storage 全鏈路可走通
- [ ] EX-01-02：格式錯誤的掃描不污染 secure storage

### 邊界條件

- [ ] QR 僅顯示一次，掃描後可關閉
- [ ] 憑證包為 v2 格式（5 欄）

## 變更歷史

| 版本 | 日期 | 變更內容 |
|------|------|---------|
| 1.0 | 2026-06-16 | 初始骨架（PROP-001 轉化） |
| 2.0 | 2026-06-17 | 改用 Tailscale：移除 proxy token 產生、憑證包縮欄、移除 file 權限例外、新增 tailnet 例外 |
