---
id: SPEC-003
title: "QR enrollment 一次性配對（精簡版）"
status: draft
source_proposal: PROP-001
created: "2026-06-16"
updated: "2026-06-17"
version: "2.0"
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

# QR enrollment 一次性配對（精簡版）

## 概述

把「手動輸入 ttyd 帳密 + Tailscale endpoint」這個易錯環節，換成視覺 air-gap 掃描（不經剪貼簿/雲）。定位為**一次性配對**（遠端情境無法每次掃），runtime 認證由 Tailscale + ttyd basic auth 處理（docs/tech-decisions.md D7）。

> **變更記錄（2026-06-17）**：原為產 proxy 密鑰 + 組 8 欄憑證包，改用 Tailscale 後 proxy token 移除、CF Access 移除，憑證包縮為 ~4 欄（endpoint + ttyd 帳密 + protocol version）。FR-01（密鑰產生）和 FR-02（可插拔後端）隨 proxy token 移除而簡化/移除。

## 功能需求

### FR-01: enroll 子命令組憑證包

| 項目 | 值 |
|------|-----|
| 優先級 | P0 |
| 來源 | PROP-001 IS-3 |
| 對應用例 | UC-01, UC-03 |
| 狀態 | 需修改（現有實作含 proxy token 產生，需移除） |

**描述**：主機 `enroll` 子命令收集 Tailscale endpoint 與 ttyd 帳密，組成憑證包 JSON。不再需要產生 proxy token。

**驗收標準**：

- [ ] 產出符合資料模型的憑證包 JSON（v2 格式）
- [ ] 重跑 enroll 可更新憑證包（支援帳密輪替，UC-03）

---

### FR-02: ASCII QR 顯示

| 項目 | 值 |
|------|-----|
| 優先級 | P0 |
| 來源 | PROP-001 IS-3 |
| 對應用例 | UC-01 |
| 狀態 | 部分實作（現有 QR 產生邏輯可沿用，payload 需更新） |

**描述**：`qrencode -t ANSIUTF8` 在終端機印 ASCII QR（無頭 Linux 亦可），手機掃一次。

**驗收標準**：

- [ ] 印出可被手機掃描的 ASCII QR
- [ ] QR payload 為 v2 格式憑證包

---

## 資料模型

憑證包（QR payload，JSON，見 `docs/contract.md`）：

| 欄位 | 型別 | 必填 | 說明 |
|------|------|------|------|
| v | int | 是 | payload 版本（2） |
| protocol | string | 是 | `ttyd-tty/v1` |
| endpoint | string | 是 | `http://<tailscale-ip-or-magicDNS>:<port>/ws` |
| ttyd_user | string | 是 | ttyd basic auth 帳號 |
| ttyd_pass | string | 是 | ttyd basic auth 密碼 |

## 設計約束

| 約束 | 說明 | 影響 |
|------|------|------|
| QR 含 ttyd 帳密明文 | 僅顯示一次，勿截圖 | 配對只在人在主機旁做，掃後即關 QR |
| 一次性配對 | 非每次連線 | runtime 認證由 Tailscale + ttyd 處理 |

## 變更歷史

| 版本 | 日期 | 變更內容 |
|------|------|---------|
| 1.0 | 2026-06-16 | 初始骨架（8 欄憑證包，含 CF Access + proxy token） |
| 2.0 | 2026-06-17 | 改用 Tailscale：移除密鑰產生 + 可插拔後端、憑證包縮為 5 欄 |

## 相關文件

- [`domain-map.md`](domain-map.md) — 本 domain 的 DDD bundle 邊界與依賴方向
