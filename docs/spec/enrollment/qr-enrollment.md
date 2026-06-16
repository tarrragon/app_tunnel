---
id: SPEC-003
title: "QR enrollment 一次性配對（設計 A 對稱）"
status: draft
source_proposal: PROP-001
created: "2026-06-16"
updated: "2026-06-16"
version: "1.0"
owner: fennel-go-developer

# Domain 歸屬
domain: enrollment
subdomain: null

# 關聯
related_usecases: [UC-01, UC-03]
related_specs:
  - spec/auth/three-layer-auth.md
  - spec/client/flutter-terminal-client.md
depends_on_domains: [auth, client]
---

# QR enrollment 一次性配對（設計 A 對稱）

## 概述

把「手動複製 64 字元密鑰」這個最易錯/易外洩環節，換成視覺 air-gap 掃描（不經剪貼簿/雲）。定位為**一次性配對**（遠端情境無法每次掃），runtime 認證不變（仍靜態 header），proxy 主路徑不改（CLAUDE.md D7）。

> **骨架階段標記**：enroll 子命令依 git log（29ac897「QR 配對 enrollment（設計 A）」）已有實作；下列 FR 完整驗收（尤其 ASCII QR 手機實機掃描）待對照 `server/` 核實。

## 功能需求

### FR-01: enroll 子命令產生密鑰

| 項目 | 值 |
|------|-----|
| 優先級 | P0 |
| 來源 | PROP-001 IS-3 |
| 對應用例 | UC-01, UC-03 |
| 狀態 | 部分實作（待核實） |

**描述**：主機 `enroll` 子命令以 `crypto/rand` 產生 proxy 密鑰（32 bytes / 64 hex），存可插拔後端。

**驗收標準**：

- [ ] 密鑰由 `crypto/rand` 產生，64 hex
- [ ] 重跑 enroll 預設產生新密鑰（支援輪替，UC-03）

---

### FR-02: 可插拔密鑰後端

| 項目 | 值 |
|------|-----|
| 優先級 | P0 |
| 來源 | PROP-001 IS-3 / CLAUDE.md D6 |
| 對應用例 | UC-01 |
| 狀態 | 部分實作（待核實） |

**描述**：密鑰載入抽象成多後端，跨平台零改碼。

**約束條件**：

- `keychain`（macOS 預設，不落明文）
- `file`（0600，Linux / 通用 fallback）— 啟動時檢查權限，過寬即拒絕
- `env`（CI / 容器）

**驗收標準**：

- [ ] 三後端可切換，binary 跨編譯 darwin/linux 不改碼
- [ ] file 後端權限過寬（group/other 可讀）時啟動拒絕

---

### FR-03: 憑證包與 ASCII QR

| 項目 | 值 |
|------|-----|
| 優先級 | P0 |
| 來源 | PROP-001 IS-3 |
| 對應用例 | UC-01 |
| 狀態 | 部分實作（待核實） |

**描述**：組憑證包 JSON（見資料模型），`qrencode -t ANSIUTF8` 在終端機印 ASCII QR（無頭 Linux 亦可），手機掃一次。

**驗收標準**：

- [ ] 產出符合資料模型的憑證包 JSON
- [ ] 印出可被手機掃描的 ASCII QR

---

## 資料模型

憑證包（QR payload，JSON，見 `docs/contract.md`）：

| 欄位 | 型別 | 必填 | 說明 |
|------|------|------|------|
| v | int | 是 | payload 版本（目前 1） |
| protocol | string | 是 | `ttyd-tty/v1` |
| endpoint | string | 是 | `wss://term.<網域>/ws` |
| cf_access_id | string | 是 | CF Access service token client id |
| cf_access_secret | string | 是 | CF Access service token client secret |
| proxy_token | string | 是 | `X-App-Tunnel-Token` 密鑰 |
| ttyd_user | string | 是 | ttyd basic auth 帳號 |
| ttyd_pass | string | 是 | ttyd basic auth 密碼 |

## 設計約束

| 約束 | 說明 | 影響 |
|------|------|------|
| QR 含全部憑證明文 | 僅顯示一次，勿截圖 | 配對只在人在主機旁做，掃後即關 QR |
| 一次性配對 | 非每次連線 | runtime 認證仍走靜態 header，proxy 主路徑不改 |

## 變更歷史

| 版本 | 日期 | 變更內容 |
|------|------|---------|
| 1.0 | 2026-06-16 | 初始骨架（PROP-001 轉化） |
