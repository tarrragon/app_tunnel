---
id: SPEC-001
title: "三層縱深認證"
status: draft                    # draft / review / approved / deprecated
source_proposal: PROP-001
created: "2026-06-16"
updated: "2026-06-16"
version: "1.0"
owner: fennel-go-developer

# Domain 歸屬
domain: auth
subdomain: null

# 關聯
related_usecases: [UC-01, UC-02, UC-03]
related_specs:
  - spec/proxy/go-reverse-proxy.md
  - spec/enrollment/qr-enrollment.md
depends_on_domains: [proxy, enrollment]
---

# 三層縱深認證

## 概述

定義 app→shell 鏈路的三道獨立認證關卡（CLAUDE.md D4、`docs/contract.md` 三層認證表）。失敗代價為整機 shell 外洩，故任一層失敗一律拒絕、不得 fallback 放行。tunnel 網址不是密碼，不可當安全機制。

> **核實標記（2026-06-16，對照 `server/` 程式碼）**：proxy 端認證閘道（FR-02）已實作並有單元測試。CF Access（FR-01）屬部署層設定，proxy 程式碼不涉及——`server/main.go` 讀 `CF-Connecting-Ip` 證明預期運行於 CF 之後。

## 功能需求

### FR-01: Cloudflare Access 邊緣驗證（第一層）

| 項目 | 值 |
|------|-----|
| 優先級 | P0 |
| 來源 | PROP-001 IS-1 |
| 對應用例 | UC-02 |
| 狀態 | 外部設定（CF 後台，proxy 程式碼不涉及） |

**描述**：未授權流量在 Cloudflare 邊緣被擋，到不了主機。app 連線時帶 `CF-Access-Client-Id` / `CF-Access-Client-Secret`，由 Cloudflare 消費。

**驗收標準**：

- [ ] 缺少或錯誤的 Service Token 在邊緣被拒，請求到不了本機 proxy

---

### FR-02: Go proxy 共享密鑰驗證（第二層）

| 項目 | 值 |
|------|-----|
| 優先級 | P0 |
| 來源 | PROP-001 IS-1 |
| 對應用例 | UC-02 |
| 狀態 | [x] 已實作（`server/main.go` authProxyHandler，3 個單元測試） |

**描述**：proxy 驗 `X-App-Tunnel-Token`，擋拿到 tunnel 網址的外人。

**約束條件**：

- constant-time 比較，避免時序側信道
- 驗錯或缺密鑰一律回 404（不洩漏服務存在），不 upgrade、不轉發
- 驗證通過後刪除 `X-App-Tunnel-Token`，不上傳 ttyd

**驗收標準**：

- [x] 密鑰正確 → 放行；錯誤/缺失 → 404（TestAuthGate_NoToken_404 / TestAuthGate_WrongToken_404）
- [x] 比較為 constant-time（`crypto/subtle.ConstantTimeCompare`）
- [x] 通過後 header 已移除（TestAuthGate_GoodToken_Forwarded_AndStripsToken）

---

### FR-03: ttyd basic auth（第三層，最後防線）

| 項目 | 值 |
|------|-----|
| 優先級 | P0 |
| 來源 | PROP-001 IS-1 |
| 對應用例 | UC-02 |
| 狀態 | 部分實作（proxy 透明代理涵蓋 Authorization 轉發；ttyd basic auth 屬部署設定；無轉發專門測試） |

**描述**：proxy 萬一破口時的最後一道。proxy 原樣轉發 app 帶的 `Authorization: Basic`，不改動。

**驗收標準**：

- [ ] proxy 透明轉發 `Authorization` header 至 ttyd
- [ ] ttyd 在 basic auth 失敗時拒絕

---

## 非功能需求

### NFR-01: 不洩漏服務存在

| 項目 | 值 |
|------|-----|
| 類型 | 安全性 |
| 指標 | 認證失敗回應與「路徑不存在」不可區分（404） |

**描述**：proxy 對驗錯/缺密鑰回 404，回應碼與內容不洩漏「此處有服務」。

## 設計約束

| 約束 | 說明 | 影響 |
|------|------|------|
| 三層獨立 | 各層認證機制互不依賴 | 單層被攻破仍有後續防線 |
| 不可 fallback 放行 | 任一層驗證失敗即拒絕 | 禁止「驗不過就放行」的便利退路 |

## 變更歷史

| 版本 | 日期 | 變更內容 |
|------|------|---------|
| 1.0 | 2026-06-16 | 初始骨架（PROP-001 轉化） |
