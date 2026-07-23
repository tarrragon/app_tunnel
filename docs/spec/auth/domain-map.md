---
id: DOMAIN-MAP-auth
domain: "auth"
source_specs: [SPEC-001]
related_usecases: [UC-01, UC-02]
created: "2026-07-23"
updated: "2026-07-23"
---

# Domain Map — auth

> 產出來源：1.2.0-W1-042。本文件界定 DDD domain bundle 邊界，作為切層、派發與測試策略的權威依據。
> 與 `docs/spec/auth/three-layer-auth.md`（FR 清單）交叉引用。

## 1. 目的與 UC / DDD 正交關係

auth domain 負責「誰能存取終端機」的策略宣告。本專案的認證行為**完全委託給外部元件**（Tailscale daemon 做裝置認證、ttyd 做 basic auth 驗證），proxy 只透明轉發 header，app_tunnel 自身程式碼不包含認證邏輯計算。

因此 auth domain **無自有 domain bundle**——所有 FR 歸屬 infra/deploy 層。domain map 列此僅為 FR 覆蓋完整性。

## 2. 分層與依賴方向

```
connectivity (Tailscale daemon 提供網路可達性)
        │
        ▼
auth（策略宣告）
  ├── Tailscale ACL（裝置認證，FR-01）──── deploy/ 設定
  └── ttyd basic auth（應用層，FR-02）──── deploy/ 設定 + proxy 透明轉發
        │
        ▼
proxy (Go server，透明轉發 Authorization header)
```

**依賴方向底線**：

- auth 不含自有程式碼計算。Tailscale ACL 由管控台設定，ttyd basic auth 由配置檔決定。
- proxy 透明轉發 auth header 但不驗證（FR-02 的驗證者是 ttyd，非 proxy）。

## 3. Bundle 界定表

| Bundle | 分類 | 納入概念 | 排除 | 目標路徑 | 測試層/方法 |
|---|---|---|---|---|---|
| TailscaleACL | 非 domain（infra/deploy） | Tailscale ACL 裝置白名單、MagicDNS 可達性（FR-01） | 認證邏輯計算 | `deploy/` Tailscale 設定 | 手動驗證（外部管控台） |
| TtydBasicAuth | 非 domain（infra/deploy） | ttyd --credential 配置、proxy Authorization header 透明轉發（FR-02） | 認證邏輯計算 | `deploy/` ttyd 配置 | 手動驗證（curl + header 檢查） |

### Bundle 不變式清單（per-bundle）

| Bundle | 不變式（每條可轉一個驗證項） |
|---|---|
| TailscaleACL | Tailscale ACL 限制連線來源為特定裝置；非 tailnet 成員無法觸達 proxy 端點 |
| TtydBasicAuth | ttyd 拒絕無 Authorization header 或錯誤憑證的請求；proxy 不修改 Authorization header（透明轉發） |

## 4. 邊界決策

### 4.1 認證邏輯不自建

認證行為委託 Tailscale（裝置層）和 ttyd（應用層），proxy 不做認證計算。依據：單人自用工具，自建認證中介件不符成本效益，兩層外部認證已滿足安全需求（SPEC-001 設計決策）。

## 5. 對實作票的切分指引

| 票 | 層 | domain map 對齊指引 |
|---|---|---|
| deploy 設定票 | infra | Tailscale ACL + ttyd 配置屬部署層，非程式碼 |

## 6. 觀察到的技術債（待追蹤）

- 無（auth domain 無自有程式碼）

## 7. FR → Bundle 覆蓋對照

| FR 群 | 覆蓋 | 備註 |
|---|---|---|
| FR-01 | TailscaleACL | Tailscale 裝置認證（非 domain） |
| FR-02 | TtydBasicAuth | ttyd basic auth + proxy 透明轉發（非 domain） |
| NFR-01 | TailscaleACL | 服務端點不對外暴露（Tailscale 網路隔離的結果） |

---

**Last Updated**: 2026-07-23 | **Source**: 1.2.0-W1-042
