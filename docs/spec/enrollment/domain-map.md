---
id: DOMAIN-MAP-enrollment
domain: "enrollment"
source_specs: [SPEC-003]
related_usecases: [UC-01]
created: "2026-07-23"
updated: "2026-07-23"
---

# Domain Map — enrollment

> 產出來源：1.2.0-W1-042。本文件界定 DDD domain bundle 邊界，作為切層、派發與測試策略的權威依據。
> 與 `docs/spec/enrollment/qr-enrollment.md`（FR 清單）、`docs/contract.md`（憑證包 JSON 格式）交叉引用。

## 1. 目的與 UC / DDD 正交關係

enrollment domain 負責「組裝憑證包並透過 QR 碼傳遞給手機」。核心 domain 計算是憑證包的資料模型和組裝邏輯——收集 endpoint/user/password/protocol 欄位後產出 JSON，是純函式可測的 aggregate。

## 2. 分層與依賴方向

```
presentation (CLI)
   └── QrPresenter（ASCII QR 輸出）
        │ 依賴（單向）
        ▼
domain
   └── CredentialBundle（憑證包組裝 + 不變式驗證）
        ▲ 單向
        │
data（無持久化——一次性產出，不存儲）
```

**依賴方向底線**：

- CredentialBundle 是純 domain 計算，不 import I/O、CLI 框架或外部服務。
- QrPresenter 依賴 CredentialBundle 產出的 JSON，呼叫外部 `qrencode` 工具。
- enrollment 不依賴其他 domain（auth/proxy/client），但 client domain 消費 enrollment 產出的憑證包格式（單向依賴，contract.md 定義介面）。

## 3. Bundle 界定表

| Bundle | 分類 | 納入概念 | 排除 | 目標路徑 | 測試層/方法 |
|---|---|---|---|---|---|
| CredentialBundle | aggregate root | 憑證包資料模型（v/endpoint/ttyd_user/ttyd_pass/protocol）、組裝邏輯、格式不變式（FR-01） | QR 編碼/顯示 | `server/cmd/enroll/` | unit：餵欄位組合斷言 JSON 結構 |
| QrPresenter | 非 domain（presentation/CLI） | ASCII QR 碼產生（FR-02） | 憑證包邏輯 | `server/cmd/enroll/` | 手動驗證（QR 可掃描性） |

### Bundle 不變式清單（per-bundle）

| Bundle | 不變式（每條可轉一個 unit test） |
|---|---|
| CredentialBundle | `v` 欄位固定為 2（版本號不變式） |
| CredentialBundle | `protocol` 欄位固定為 `ttyd-tty/v1`（協議名稱不變式） |
| CredentialBundle | `endpoint` 格式為 `http://{MagicDNS}:{port}`（合法 URL） |
| CredentialBundle | `ttyd_user` 和 `ttyd_pass` 不可為空字串 |
| CredentialBundle | JSON 輸出包含且僅包含 contract.md 定義的五個欄位 |

## 4. 邊界決策

### 4.1 憑證包為一次性產出，不持久化

enrollment 是設定時操作（`enroll` 子命令），產出 QR 碼後即完成。憑證包不存入資料庫——手機端掃描後存入 secure storage（client domain 的 CredentialStore 負責）。依據：單人自用，無需多裝置管理或憑證輪替伺服器端狀態。

## 5. 對實作票的切分指引

| 票 | 層 | domain map 對齊指引 |
|---|---|---|
| 憑證包模型票 | domain | CredentialBundle 純函式；格式與 contract.md 一致 |
| QR 輸出票 | presentation | QrPresenter 只負責呼叫 qrencode，不含組裝邏輯 |

## 6. 觀察到的技術債（待追蹤）

- 無

## 7. FR → Bundle 覆蓋對照

| FR 群 | 覆蓋 | 備註 |
|---|---|---|
| FR-01 | CredentialBundle | `enroll` 子命令組裝憑證包 JSON |
| FR-02 | QrPresenter | ASCII QR 碼顯示（非 domain） |

---

**Last Updated**: 2026-07-23 | **Source**: 1.2.0-W1-042
