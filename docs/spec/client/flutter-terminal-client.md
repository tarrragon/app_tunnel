---
id: SPEC-004
title: "Flutter 原生終端機客戶端"
status: draft
source_proposal: PROP-001
created: "2026-06-16"
updated: "2026-06-17"
version: "1.1"
owner: parsley-flutter-developer

# Domain 歸屬
domain: client
subdomain: null

# 關聯
related_usecases: [UC-01, UC-02]
related_specs:
  - spec/auth/three-layer-auth.md
  - spec/enrollment/qr-enrollment.md
depends_on_domains: [auth, enrollment]
---

# Flutter 原生終端機客戶端

## 概述

手機端原生 Flutter 終端機 UI（自渲染 xterm 類 + 自接 ttyd WS 子協議），改善手機操 CLI 的打字體驗（Esc/Ctrl/方向鍵）。憑證存 secure storage、不硬寫進 app；每次連線前過 Face ID/BiometricPrompt（docs/tech-decisions.md D3）。手機需安裝 Tailscale 加入 tailnet，透過 Tailscale 私有網路連線至主機。

> **骨架階段標記**：app 端尚未開工，下列 FR 全部標未實作。

## 功能需求

### FR-01: 生物辨識解鎖

| 項目 | 值 |
|------|-----|
| 優先級 | P0 |
| 來源 | PROP-001 IS-4 / CLAUDE.md D3 |
| 對應用例 | UC-02 |
| 狀態 | [ ] 未實作 |

**描述**：每次連線前過一次 Face ID / BiometricPrompt 才解鎖憑證存取。

**驗收標準**：

- [ ] 連線前生物辨識通過才讀取憑證
- [ ] 辨識失敗不洩漏憑證、不發起連線

---

### FR-02: secure storage 憑證保管

| 項目 | 值 |
|------|-----|
| 優先級 | P0 |
| 來源 | PROP-001 IS-4 / CLAUDE.md D3 |
| 對應用例 | UC-01, UC-02 |
| 狀態 | [ ] 未實作 |

**描述**：憑證包存 `flutter_secure_storage`（iOS Keychain / Android Keystore），不硬寫進程式碼（反編譯可挖）。

**驗收標準**：

- [ ] 憑證僅存於 Keychain/Keystore，原始碼無硬編碼密鑰

---

### FR-03: WS 協議薄抽象層

| 項目 | 值 |
|------|-----|
| 優先級 | P0 |
| 來源 | PROP-001 IS-4 / `docs/contract.md` |
| 對應用例 | UC-02 |
| 狀態 | [ ] 未實作 |

**描述**：把 WS 終端機協議包成一層薄抽象，協議版本切換（`ttyd-tty/v1` → 未來 `apptunnel/v1`）只改該抽象一處，不散落在 UI。

**約束條件**：

- 自接 ttyd `tty` 子協議：input `'0'`+鍵盤資料、resize `'1'`+JSON、開場 `'{"AuthToken":"..."}'`
- 以 `docs/contract.md` 的 `protocol` 欄位為準

**驗收標準**：

- [ ] 協議版本切換只需改抽象層一處
- [ ] WS 連線帶 ttyd basic auth header（Tailscale 網路層已處理裝置認證）

---

### FR-04: 終端機 UI 與打字體驗

| 項目 | 值 |
|------|-----|
| 優先級 | P1 |
| 來源 | PROP-001 IS-4 |
| 對應用例 | UC-02 |
| 狀態 | [ ] 未實作 |

**描述**：自渲染終端機，提供 Esc/Ctrl/方向鍵等手機原生鍵盤缺乏的按鍵。

**驗收標準**：

- [ ] 可輸入 Esc / Ctrl 組合鍵 / 方向鍵
- [ ] 終端機輸出正確渲染

---

### FR-05: QR 掃描配對

| 項目 | 值 |
|------|-----|
| 優先級 | P0 |
| 來源 | PROP-001 IS-3 |
| 對應用例 | UC-01, UC-03 |
| 狀態 | [ ] 未實作 |

**描述**：掃描主機 enroll 印出的 ASCII QR，解析憑證包存入 secure storage。

**驗收標準**：

- [ ] 掃描憑證包 QR 成功解析並存入 secure storage

---

## 設計約束

| 約束 | 說明 | 影響 |
|------|------|------|
| 自渲染工程量 | 大於 WebView 內嵌 | D3 tripwire：投報率不如預期退回 WebView 內嵌 ttyd |

## 變更歷史

| 版本 | 日期 | 變更內容 |
|------|------|---------|
| 1.0 | 2026-06-16 | 初始骨架（PROP-001 轉化） |
| 1.1 | 2026-06-17 | 改用 Tailscale：三層 header→ttyd basic auth only、加 Tailscale 依賴 |
