---
id: SPEC-005
title: "Cloudflare Tunnel 連線與運作姿態"
status: draft
source_proposal: PROP-001
created: "2026-06-16"
updated: "2026-06-16"
version: "1.0"
owner: sumac-system-engineer

# Domain 歸屬
domain: connectivity
subdomain: null

# 關聯
related_usecases: [UC-02, UC-04]
related_specs:
  - spec/proxy/go-reverse-proxy.md
depends_on_domains: [proxy]
---

# Cloudflare Tunnel 連線與運作姿態

## 概述

固定網址（app 寫死 endpoint）但不開機自啟、不 24/7 常駐——用時起、用完關，把暴露窗壓到最小（CLAUDE.md D5）。出站 tunnel 不需開放入站埠。

> **骨架階段標記**：deploy 配置與起停腳本尚未建立，下列 FR 全部標未實作。

## 功能需求

### FR-01: Named tunnel + 自有固定網域

| 項目 | 值 |
|------|-----|
| 優先級 | P0 |
| 來源 | PROP-001 IS-5 / CLAUDE.md D5 |
| 對應用例 | UC-02 |
| 狀態 | [ ] 未實作 |

**描述**：cloudflared named tunnel 綁自有固定網域（`term.<網域>`），app endpoint 可寫死。

**驗收標準**：

- [ ] named tunnel 建立後固定網域可達 proxy
- [ ] 不需在本機開放任何入站埠

---

### FR-02: 手動起停姿態

| 項目 | 值 |
|------|-----|
| 優先級 | P0 |
| 來源 | PROP-001 IS-5 / CLAUDE.md D5 |
| 對應用例 | UC-04 |
| 狀態 | [ ] 未實作 |

**描述**：用時起、用完關。停用即關三個行程（proxy / ttyd / cloudflared）。

**約束條件**：

- launchd plist 不放 `~/Library/LaunchAgents`（不自啟）
- systemd 不 `enable`

**驗收標準**：

- [ ] 提供一鍵起 / 一鍵關三行程的機制
- [ ] 重開機後不自動啟動

---

### FR-03: deploy 配置與 setup 腳本

| 項目 | 值 |
|------|-----|
| 優先級 | P1 |
| 來源 | PROP-001 IS-5 |
| 對應用例 | UC-04 |
| 狀態 | [ ] 未實作 |

**描述**：`deploy/` 提供 ttyd / cloudflared config、launchd plist、setup 腳本。

**驗收標準**：

- [ ] `deploy/` 含可用的 ttyd / cloudflared 配置範本與 setup 腳本

---

## 設計約束

| 約束 | 說明 | 影響 |
|------|------|------|
| 不 always-on | 暴露窗最小化 | tripwire：改 always-on 需補 WAF / 入口限流 / 告警 |
| 憑證可重建 | tunnel 憑證 `tunnel create` 可重建 | 無 source-of-truth datastore，不需備份（State-Storage 決策） |

## 變更歷史

| 版本 | 日期 | 變更內容 |
|------|------|---------|
| 1.0 | 2026-06-16 | 初始骨架（PROP-001 轉化） |
