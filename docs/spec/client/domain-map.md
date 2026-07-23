---
id: DOMAIN-MAP-client
domain: "client"
source_specs: [SPEC-004]
related_usecases: [UC-01, UC-02, UC-03]
created: "2026-07-23"
updated: "2026-07-23"
---

# Domain Map — client

> 產出來源：1.2.0-W1-042。本文件界定 DDD domain bundle 邊界，作為切層、派發與測試策略的權威依據。
> 與 `docs/spec/client/flutter-terminal-client.md`（FR 清單）、`docs/spec/client/screen-state-matrix.md`（畫面狀態機）、`docs/contract.md`（WS 子協議 + 憑證包格式）交叉引用。

## 1. 目的與 UC / DDD 正交關係

client domain 負責「手機端連線到遠端終端機並操作」。唯一的自有 domain 計算是 WS 子協議編解碼（`ttyd-tty/v1` 的 input/resize/auth 封包格式轉換），其餘 FR 屬 presentation（終端機 UI、生物辨識 gate、QR 掃描流程）和 data（secure storage 憑證保管）。

## 2. 分層與依賴方向

```
presentation (Flutter widgets + 狀態管理)
   ├── BiometricGate（Face ID / BiometricPrompt 解鎖，FR-01）
   ├── TerminalUI（終端機渲染 + Esc/Ctrl/方向鍵 toolbar，FR-04）
   ├── EnrollmentUI（QR 掃描 + 確認流程，FR-05 掃描部分）
   └── ConnectionManager（畫面狀態機：idle→connecting→connected→...）
        │ 依賴（單向）
        ▼
domain
   └── TerminalProtocol（WS 子協議編解碼，FR-03）
        ▲ 單向
        │
data
   └── CredentialStore（secure storage CRUD，FR-02, FR-05 存取部分）
```

**依賴方向底線**：

- TerminalProtocol 是純函式：輸入 raw bytes ↔ 輸出 typed messages（input/resize/auth），不 import Flutter widget 或 secure storage。
- presentation 層（TerminalUI、ConnectionManager）消費 TerminalProtocol 做封包轉換，不直接操作 WS raw frame。
- CredentialStore 屬 data 層，透過 repository 介面供 presentation 使用。domain 不直接依賴 CredentialStore。
- client 消費 enrollment domain 產出的憑證包格式（contract.md 定義），但不 import enrollment 程式碼（跨語言邊界：Flutter vs Go）。

## 3. Bundle 界定表

| Bundle | 分類 | 納入概念 | 排除 | 目標路徑 | 測試層/方法 |
|---|---|---|---|---|---|
| TerminalProtocol | supporting VO | WS 子協議編解碼：`'0'`+input、`'1'`+JSON(cols,rows) resize、AuthToken 構造（FR-03） | WS 連線管理、UI 渲染 | `app/lib/domain/protocol/` | unit：餵 bytes 斷言 typed message；餵 typed message 斷言 bytes |
| CredentialStore | 非 domain（data/infra） | Keychain/Keystore 的憑證 CRUD：存、讀、刪（FR-02, FR-05 存取部分） | 憑證包組裝邏輯（屬 enrollment） | `app/lib/data/credential/` | unit：mock secure storage 斷言 CRUD |
| BiometricGate | 非 domain（presentation） | Face ID / BiometricPrompt 解鎖 gate（FR-01） | 認證邏輯（委託平台 API） | `app/lib/presentation/auth/` | widget test：mock LocalAuthentication |
| TerminalUI | 非 domain（presentation） | 終端機畫面渲染、輸入處理、Esc/Ctrl/方向鍵 toolbar（FR-04） | 協議編解碼 | `app/lib/presentation/terminal/` | widget test：渲染斷言 + 按鍵事件 |
| EnrollmentUI | 非 domain（presentation） | QR 掃描相機介面、確認流程（FR-05 掃描部分） | 憑證包解析邏輯 | `app/lib/presentation/enrollment/` | widget test：mock 相機 |
| ConnectionManager | 非 domain（presentation/狀態管理） | 畫面狀態機（screen-state-matrix.md）、WS 連線建立/斷開（跨 FR） | 協議細節 | `app/lib/presentation/connection/` | unit：狀態轉換斷言 |

### Bundle 不變式清單（per-bundle）

| Bundle | 不變式（每條可轉一個 unit test） |
|---|---|
| TerminalProtocol | input 封包格式：`'0'` + raw input bytes（contract.md 定義） |
| TerminalProtocol | resize 封包格式：`'1'` + JSON `{"columns":N,"rows":N}`（contract.md 定義） |
| TerminalProtocol | AuthToken 使用 ttyd basic auth header 構造（Base64 編碼） |
| TerminalProtocol | 解碼 server 回傳的 `'0'` + output bytes（雙向對稱） |
| CredentialStore | 讀取不存在的憑證回傳 null（非拋例外） |
| CredentialStore | 刪除後再讀回傳 null |
| ConnectionManager | idle 狀態只能轉 connecting；connected 狀態收到 WS close 轉 disconnected |

## 4. 邊界決策

### 4.1 協議編解碼獨立於 UI

TerminalProtocol 是唯一的 domain bundle，與 TerminalUI 分離。依據：協議格式變更不應需要修改 UI code，反之亦然。TerminalProtocol 是純函式（bytes↔typed messages），可獨立單元測試。

### 4.2 憑證包格式不在 client domain 定義

client 消費 enrollment 產出的憑證包 JSON（contract.md 定義格式），但解析邏輯放 data 層的 CredentialStore，不放 domain。依據：client 只讀取欄位值（endpoint/user/pass），不做格式驗證或轉換計算。

## 5. 對實作票的切分指引

| 票 | 層 | domain map 對齊指引 |
|---|---|---|
| 協議層票 | domain | TerminalProtocol：純函式編解碼，與 UI/WS 連線分離 |
| 憑證管理票 | data | CredentialStore：secure storage CRUD |
| 終端機 UI 票 | presentation | TerminalUI + ConnectionManager：消費 TerminalProtocol |
| 配對流程票 | presentation | EnrollmentUI + BiometricGate |

## 6. 觀察到的技術債（待追蹤）

- 無

## 7. FR → Bundle 覆蓋對照

| FR 群 | 覆蓋 | 備註 |
|---|---|---|
| FR-01 | BiometricGate | 生物辨識解鎖（非 domain，presentation） |
| FR-02 | CredentialStore | secure storage 憑證保管（非 domain，data） |
| FR-03 | TerminalProtocol | WS 子協議編解碼（domain） |
| FR-04 | TerminalUI | 終端機 UI 與打字體驗（非 domain，presentation） |
| FR-05 | EnrollmentUI, CredentialStore | QR 掃描（presentation）+ 解析後存儲（data） |

---

**Last Updated**: 2026-07-23 | **Source**: 1.2.0-W1-042
