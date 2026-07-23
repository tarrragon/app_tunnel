---
id: DOMAIN-MAP-connectivity
domain: "connectivity"
source_specs: [SPEC-005]
related_usecases: [UC-04]
created: "2026-07-23"
updated: "2026-07-23"
---

# Domain Map — connectivity

> 產出來源：1.2.0-W1-042。本文件界定 DDD domain bundle 邊界，作為切層、派發與測試策略的權威依據。
> 與 `docs/spec/connectivity/cloudflare-tunnel.md`（FR 清單）交叉引用。

## 1. 目的與 UC / DDD 正交關係

connectivity domain 負責「建立手機到本機的安全網路通道」。本專案使用 Tailscale mesh VPN，所有 connectivity FR **屬於部署設定層**（Tailscale daemon 加入 tailnet、MagicDNS 解析、ACL 裝置限制、手動起停 ttyd/proxy），app_tunnel 自身程式碼不包含連線建立邏輯。

因此 connectivity domain **無自有 domain bundle**——所有 FR 歸屬 infra/deploy 層。domain map 列此僅為 FR 覆蓋完整性。

## 2. 分層與依賴方向

```
connectivity（部署設定）
   ├── Tailscale daemon（tailnet 加入 + MagicDNS，FR-01）
   ├── 服務起停（ttyd + proxy 手動起停，FR-02）
   ├── deploy 配置（setup 腳本 + launchd/systemd，FR-03）
   └── ACL 裝置限制（Tailscale 管控台，FR-04）
        │
        ▼
所有其他 domain 依賴 connectivity 提供的網路可達性
```

**依賴方向底線**：

- connectivity 不含自有程式碼計算。Tailscale daemon 由系統服務管理，起停腳本在 `deploy/` 目錄。
- proxy 和 client domain 隱式依賴 connectivity 提供的 Tailscale 網路可達性（前提條件，非程式碼 import）。

## 3. Bundle 界定表

| Bundle | 分類 | 納入概念 | 排除 | 目標路徑 | 測試層/方法 |
|---|---|---|---|---|---|
| TailscaleNetwork | 非 domain（infra/deploy） | Tailscale tailnet 加入、MagicDNS 解析、ACL 裝置白名單（FR-01, FR-04） | 連線邏輯計算 | `deploy/` Tailscale 設定 | 手動驗證（`tailscale status`） |
| ServiceManagement | 非 domain（infra/deploy） | ttyd + proxy 手動起停、launchd/systemd 配置、setup 腳本（FR-02, FR-03） | 連線邏輯計算 | `deploy/` 腳本 + plist | 手動驗證（服務啟停測試） |

### Bundle 不變式清單（per-bundle）

| Bundle | 不變式（每條可轉一個驗證項） |
|---|---|
| TailscaleNetwork | 加入 tailnet 後 MagicDNS 可解析本機 hostname；ACL 限制非授權裝置無法連線 |
| ServiceManagement | 起動腳本啟動 ttyd 和 proxy 兩個進程；停止腳本結束兩個進程且 port 釋放 |

## 4. 邊界決策

### 4.1 連線層完全委託 Tailscale

不自建 VPN 或隧道方案，完全使用 Tailscale mesh VPN。依據：單人自用工具，Tailscale 零設定 P2P 連線已滿足需求，自建 VPN 不符成本效益（技術決策 D5）。

## 5. 對實作票的切分指引

| 票 | 層 | domain map 對齊指引 |
|---|---|---|
| deploy 設定票 | infra | Tailscale 設定 + 起停腳本屬部署層 |

## 6. 觀察到的技術債（待追蹤）

- 無（connectivity domain 無自有程式碼）

## 7. FR → Bundle 覆蓋對照

| FR 群 | 覆蓋 | 備註 |
|---|---|---|
| FR-01 | TailscaleNetwork | Tailscale tailnet 加入與 MagicDNS（非 domain） |
| FR-02 | ServiceManagement | 手動起停姿態（非 domain） |
| FR-03 | ServiceManagement | deploy 配置與 setup 腳本（非 domain） |
| FR-04 | TailscaleNetwork | Tailscale ACL 裝置限制（非 domain） |

---

**Last Updated**: 2026-07-23 | **Source**: 1.2.0-W1-042
