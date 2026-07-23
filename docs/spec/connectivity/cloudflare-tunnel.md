---
id: SPEC-005
title: "Tailscale mesh VPN 連線與運作姿態"
status: draft
source_proposal: PROP-001
created: "2026-06-16"
updated: "2026-06-17"
version: "2.0"
owner: sumac-system-engineer

# Domain 歸屬
domain: connectivity
subdomain: null

# 關聯
related_usecases: [UC-02, UC-04]
related_specs:
  - spec/proxy/go-reverse-proxy.md
  - spec/auth/three-layer-auth.md
depends_on_domains: [proxy, auth]
---

# Tailscale mesh VPN 連線與運作姿態

## 概述

Tailscale mesh VPN 在網路層提供裝置級認證與 WireGuard 加密隧道（docs/tech-decisions.md D4/D5）。服務端點僅在 tailnet 內可達，不存在於公開網路。Tailscale daemon 常駐維持隧道；ttyd+proxy 手動起停。

> **變更記錄（2026-06-17）**：原為 Cloudflare named tunnel + 自有網域 + 三行程起停，改用 Tailscale 後簡化。

## 功能需求

### FR-01: Tailscale tailnet 加入與 MagicDNS

| 項目 | 值 |
|------|-----|
| 優先級 | P0 |
| 來源 | PROP-001 IS-5 / docs/tech-decisions.md D5 |
| 對應用例 | UC-02 |
| 狀態 | [ ] 未實作 |

**描述**：主機與手機均加入同一 tailnet。主機可透過 Tailscale IP（100.x.x.x）或 MagicDNS 名稱被手機存取。不需開放任何入站埠、不需自有網域。

**驗收標準**：

- [ ] 主機 `tailscale up` 後手機可 ping 主機 Tailscale IP
- [ ] MagicDNS 名稱可解析為 Tailscale IP

---

### FR-02: 手動起停姿態（ttyd + proxy）

| 項目 | 值 |
|------|-----|
| 優先級 | P0 |
| 來源 | PROP-001 IS-5 / docs/tech-decisions.md D5 |
| 對應用例 | UC-04 |
| 狀態 | [ ] 未實作 |

**描述**：Tailscale daemon 常駐（只維持加密隧道，不暴露服務）。ttyd + proxy 用時起、用完關——停用即關兩行程。

**約束條件**：

- ttyd / proxy 的 launchd plist 不放 `~/Library/LaunchAgents`（不自啟）
- systemd 不 `enable`
- Tailscale daemon 可常駐（不等於服務暴露）

**驗收標準**：

- [ ] 提供一鍵起 / 一鍵關兩行程（ttyd + proxy）的機制
- [ ] 重開機後 ttyd / proxy 不自動啟動
- [ ] Tailscale daemon 重開機後自動恢復連線

---

### FR-03: deploy 配置與 setup 腳本

| 項目 | 值 |
|------|-----|
| 優先級 | P1 |
| 來源 | PROP-001 IS-5 |
| 對應用例 | UC-04 |
| 狀態 | [ ] 未實作 |

**描述**：`deploy/` 提供 ttyd 配置、Tailscale 設定指引、起停腳本。

**驗收標準**：

- [ ] `deploy/` 含可用的 ttyd 配置範本、Tailscale ACL 建議、起停腳本

---

### FR-04: Tailscale ACL 裝置限制

| 項目 | 值 |
|------|-----|
| 優先級 | P1 |
| 來源 | docs/tech-decisions.md D4 |
| 對應用例 | UC-02 |
| 狀態 | [ ] 未實作 |

**描述**：Tailscale ACL 限制只有 owner 裝置可存取 proxy 監聽 port。

**驗收標準**：

- [ ] ACL 設定後，同 tailnet 非 owner 裝置無法連線至 proxy port

---

## 設計約束

| 約束 | 說明 | 影響 |
|------|------|------|
| ttyd+proxy 不 always-on | 手動起停最小化服務暴露 | tripwire：改 always-on 需補 Tailscale ACL tag 限制 |
| Tailscale 裝置可重建 | `tailscale up` 可重新加入 tailnet | 無 source-of-truth datastore，不需備份 |

## 變更歷史

| 版本 | 日期 | 變更內容 |
|------|------|---------|
| 1.0 | 2026-06-16 | 初始骨架（Cloudflare Tunnel） |
| 2.0 | 2026-06-17 | 改用 Tailscale：移除 cloudflared、三行程→兩行程、新增 ACL FR |

## 相關文件

- [`domain-map.md`](domain-map.md) — 本 domain 的 DDD bundle 邊界與依賴方向
