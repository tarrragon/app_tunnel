---
id: DOMAIN-MAP-proxy
domain: "proxy"
source_specs: [SPEC-002]
related_usecases: [UC-02, UC-04]
created: "2026-07-23"
updated: "2026-07-23"
---

# Domain Map — proxy

> 產出來源：1.2.0-W1-042。本文件界定 DDD domain bundle 邊界，作為切層、派發與測試策略的權威依據。
> 與 `docs/spec/proxy/go-reverse-proxy.md`（FR 清單）、`docs/contract.md`（WS 子協議）交叉引用。

## 1. 目的與 UC / DDD 正交關係

proxy domain 負責「透明反向代理 WebSocket 連線至 ttyd」。核心 domain 計算是 WS upgrade 判定和雙向轉發行為——判斷是否為合法 WebSocket upgrade 請求，透明轉發包含 auth header，並管理連線 timeout。

## 2. 分層與依賴方向

```
client (Flutter app，透過 Tailscale 網路連入)
        │ HTTP/WS 請求
        ▼
domain
   └── ReverseProxy（WS upgrade 判定 + 雙向轉發 + timeout 策略）
        │ 依賴（單向）
        ▼
data / infra
   ├── AuditLogger（結構化稽核 log，cross-cutting）
   └── ProcessLifecycle（signal handling + graceful shutdown）
        │
        ▼
ttyd（外部程序，localhost:7681）
```

**依賴方向底線**：

- ReverseProxy 的核心代理邏輯（upgrade 判定、header 轉發、timeout）是 domain 行為。
- ReverseProxy 不 import 稽核 log 格式或 shutdown 邏輯。AuditLogger 是 cross-cutting 觀測層，ProcessLifecycle 是 infra 層。
- proxy 隱式依賴 auth（透明轉發 Authorization header 但不驗證）和 connectivity（Tailscale 提供網路可達性）。

## 3. Bundle 界定表

| Bundle | 分類 | 納入概念 | 排除 | 目標路徑 | 測試層/方法 |
|---|---|---|---|---|---|
| ReverseProxy | aggregate root | WS upgrade 判定、雙向 WS 轉發、Authorization header 透明轉發、proxy→ttyd timeout 策略（FR-01, FR-02） | 稽核 log、進程生命週期 | `server/internal/proxy/` | unit：upgrade 判定邏輯；integration：真實 ttyd WS 轉發 |
| AuditLogger | 非 domain（cross-cutting） | 結構化 JSON 稽核 log：client_ip, timestamp, accepted/rejected, session_duration（FR-04） | 代理邏輯 | `server/internal/audit/` | unit：log 格式斷言 |
| ProcessLifecycle | 非 domain（infra） | SIGTERM/SIGINT 攔截、graceful shutdown（等待活躍連線結束）（FR-03） | 代理邏輯 | `server/cmd/` | integration：signal 發送後連線收斂驗證 |

### Bundle 不變式清單（per-bundle）

| Bundle | 不變式（每條可轉一個 unit test） |
|---|---|
| ReverseProxy | 非 WebSocket upgrade 請求被拒絕（回 4xx） |
| ReverseProxy | Authorization header 原封不動轉發至 ttyd（不修改、不解碼） |
| ReverseProxy | proxy→ttyd 連線 timeout 後斷開並記錄 log |
| ReverseProxy | client→proxy 與 proxy→ttyd 雙向 WS frame 對稱轉發（不丟幀） |
| AuditLogger | 每個 accepted/rejected 請求產出一筆 JSON log（包含 client_ip 和 timestamp） |
| ProcessLifecycle | SIGTERM 後不接新連線，但等待已有連線自然結束或 grace period 到期 |

## 4. 邊界決策

### 4.1 proxy 不做認證驗證

proxy 只透明轉發 Authorization header，認證驗證由 ttyd 執行。依據：proxy 定位為「透明代理 + 稽核」，不介入認證決策（SPEC-002 設計原則）。

### 4.2 稽核 log 與代理邏輯分層

AuditLogger 是 cross-cutting 觀測層，不混入 ReverseProxy 的 domain 判定。依據：稽核 log 格式變更不應影響代理行為。

## 5. 對實作票的切分指引

| 票 | 層 | domain map 對齊指引 |
|---|---|---|
| 代理核心票 | domain | ReverseProxy：upgrade 判定 + 轉發 + timeout |
| 稽核 log 票 | cross-cutting | AuditLogger：結構化 JSON 輸出 |
| 進程管理票 | infra | ProcessLifecycle：signal + graceful shutdown |

## 6. 觀察到的技術債（待追蹤）

- 無

## 7. FR → Bundle 覆蓋對照

| FR 群 | 覆蓋 | 備註 |
|---|---|---|
| FR-01 | ReverseProxy | 透明 WebSocket 反向代理 |
| FR-02 | ReverseProxy | proxy→ttyd timeout 策略 |
| FR-03 | ProcessLifecycle | Graceful shutdown（非 domain） |
| FR-04 | AuditLogger | 結構化稽核 log（非 domain） |
| NFR-01 | ReverseProxy | 單一進程簡潔架構 |

---

**Last Updated**: 2026-07-23 | **Source**: 1.2.0-W1-042
