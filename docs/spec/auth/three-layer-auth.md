---
id: SPEC-001
title: "兩層認證（Tailscale 裝置認證 + ttyd basic auth）"
status: draft
source_proposal: PROP-001
created: "2026-06-16"
updated: "2026-06-17"
version: "2.0"
owner: fennel-go-developer

# Domain 歸屬
domain: auth
subdomain: null

# 關聯
related_usecases: [UC-01, UC-02, UC-03]
related_specs:
  - spec/proxy/go-reverse-proxy.md
  - spec/enrollment/qr-enrollment.md
  - spec/connectivity/tailscale.md
depends_on_domains: [proxy, enrollment, connectivity]
---

# 兩層認證（Tailscale 裝置認證 + ttyd basic auth）

## 概述

定義 app→shell 鏈路的兩道獨立認證關卡（docs/tech-decisions.md D4、`docs/contract.md` 兩層認證表）。失敗代價為整機 shell 外洩。Tailscale 在網路層讓服務端點不存在於公開網路（攻擊者連 IP 都到不了）；ttyd basic auth 為應用層最後防線。Go proxy 不做認證，只做稽核 log + 透明轉發。

> **變更記錄（2026-06-17）**：原為三層縱深認證（CF Access + proxy token + ttyd），改用 Tailscale 後簡化為兩層。原 FR-01（CF Access）、FR-02（proxy token 驗證）移除；原 FR-03（ttyd basic auth）升為 FR-01。

## 功能需求

### FR-01: Tailscale 裝置認證（第一層，網路層）

| 項目 | 值 |
|------|-----|
| 優先級 | P0 |
| 來源 | PROP-001 IS-1 |
| 對應用例 | UC-02 |
| 狀態 | 外部設定（Tailscale ACL，proxy 程式碼不涉及） |

**描述**：未加入 tailnet 的裝置連服務端點的 IP 都到不了。手機需安裝 Tailscale 並加入同一 tailnet。ACL 可進一步限制只有 owner 裝置可連。

**驗收標準**：

- [ ] 未加入 tailnet 的裝置無法連線至 proxy 監聽端點
- [ ] Tailscale ACL 限制只有 owner 裝置可存取 proxy port

---

### FR-02: ttyd basic auth（第二層，應用層最後防線）

| 項目 | 值 |
|------|-----|
| 優先級 | P0 |
| 來源 | PROP-001 IS-1 |
| 對應用例 | UC-02 |
| 狀態 | 部分實作（proxy 透明轉發 Authorization header；ttyd basic auth 屬部署設定） |

**描述**：Tailscale 萬一被穿越時的最後一道。app 帶 `Authorization: Basic`，proxy 原樣轉發，ttyd 驗證。

**驗收標準**：

- [ ] proxy 透明轉發 `Authorization` header 至 ttyd
- [ ] ttyd 在 basic auth 失敗時拒絕（401）

---

## 非功能需求

### NFR-01: 服務端點不對外暴露

| 項目 | 值 |
|------|-----|
| 類型 | 安全性 |
| 指標 | 服務端點僅在 Tailscale 私有網路內可達 |

**描述**：ttyd + proxy 綁 Tailscale 介面或 localhost，不監聽公開網路介面。

## 設計約束

| 約束 | 說明 | 影響 |
|------|------|------|
| 兩層獨立 | Tailscale（網路層）與 ttyd（應用層）認證互不依賴 | 單層被攻破仍有後續防線 |
| proxy 不做認證 | proxy 只負責稽核 log + 透明轉發 | 認證邏輯不在 proxy 程式碼中 |

## 變更歷史

| 版本 | 日期 | 變更內容 |
|------|------|---------|
| 1.0 | 2026-06-16 | 初始骨架（三層縱深認證） |
| 2.0 | 2026-06-17 | 改用 Tailscale：三層→兩層，移除 CF Access + proxy token |
