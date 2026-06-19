---
id: SPEC-004-SM
title: "畫面狀態機矩陣"
status: draft
source_proposal: PROP-001
source_ticket: 1.2.0-W3-005
created: "2026-06-20"
updated: "2026-06-20"
version: "1.0"
owner: rosemary-project-manager

# Domain 歸屬
domain: client
subdomain: null

# 關聯
related_usecases: [UC-01, UC-02]
parent_spec: SPEC-004
---

# 畫面狀態機矩陣

本文件定義 app_tunnel Flutter 客戶端的所有畫面、狀態、使用者操作、退出路徑。
根因：v1.2.0-W3-001 分析發現 UX 導航缺口（idle/connected 缺 back/disconnect），
原因是企劃階段未產出畫面狀態矩陣，導致實作時遺漏退出路徑。

---

## 1. 路由結構

| 路由 | 畫面 | 進入方式 | GoRouter |
|------|------|---------|----------|
| `/` | HomeScreen | app 啟動 | `initialLocation` |
| `/enrollment` | EnrollmentScreen | HomeScreen 按鈕 | `context.push` |
| `/enrollment` > QrScannerScreen | QrScannerScreen | EnrollmentScreen 觸發 | `Navigator.push` (modal) |
| `/terminal` | TerminalScreen | HomeScreen 按鈕 | `context.go` |

---

## 2. HomeScreen 狀態矩陣

HomeScreen 為靜態畫面，無內部狀態機。

| 操作 | 觸發 | 導航目標 |
|------|------|---------|
| 點擊「Enroll」 | `context.push('/enrollment')` | EnrollmentScreen |
| 點擊「Connect」 | `context.go('/terminal')` | TerminalScreen |

---

## 3. EnrollmentScreen 狀態矩陣

| 狀態 | UI 呈現 | 使用者操作 | 操作結果 |
|------|---------|----------|---------|
| initial | 掃描按鈕 | 點擊掃描 | push QrScannerScreen |
| scanning (QrScannerScreen) | 相機取景 | 掃到 QR / 手動返回 | pop 回 EnrollmentScreen（帶 credential 或 null） |
| confirm | 確認對話框 | 確認儲存 / 取消 | 儲存→成功提示 / 取消→回 initial |
| success | 成功提示 | 自動或手動返回 | pop 回 HomeScreen |

退出路徑：
- 系統返回鍵 / 手勢返回：pop 回 HomeScreen（`context.push` 保留 stack）

---

## 4. TerminalScreen 狀態矩陣

TerminalScreen 由 `TerminalScreenUiState` 驅動，對應 `ConnectionState`。

### 4.1 狀態轉換圖

```
idle ──(自動)──> connecting ──(成功)──> connected
                    │                     │
                    │(失敗)               │(server close)
                    ▼                     ▼
                  error              disconnected
                    │                     │
                    │(reconnect)          │(reconnect)
                    └─────────────────────┘
                              │
                              ▼
                          connecting
```

### 4.2 狀態 × 操作矩陣

| 狀態 | UI 呈現 | 使用者操作 | 操作結果 | 退出路徑 |
|------|---------|----------|---------|---------|
| **idle** | spinner + back 按鈕 | 點擊 back | `context.go('/')` → HomeScreen | back 按鈕 |
| **connecting** | spinner + "Connecting" + back 按鈕 | 點擊 back | `context.go('/')` → HomeScreen | back 按鈕 |
| **connected** | status bar + terminal + input + toolbar | 點擊 disconnect (status bar) | `connectionManager.disconnect()` → disconnected | disconnect 按鈕 |
| **connected** | (同上) | 輸入文字 + submit | `protocol.encodeInput` → `sendData` | — |
| **connected** | (同上) | 螢幕旋轉/鍵盤 | `sendResize` | — |
| **disconnected** | link_off icon + reconnect + back | 點擊 reconnect | `connectionManager.reconnect()` → connecting | back 按鈕 |
| **disconnected** | (同上) | 點擊 back | `context.go('/')` → HomeScreen | back 按鈕 |
| **error** | error icon + 訊息 + reconnect + back | 點擊 reconnect | `connectionManager.reconnect()` → connecting | back 按鈕 |
| **error** | (同上) | 點擊 back | `context.go('/')` → HomeScreen | back 按鈕 |

### 4.3 錯誤類型對應

| ConnectionErrorType | 顯示訊息 key | 使用者理解 |
|---------------------|-------------|----------|
| authenticationFailed | `terminalErrorAuth` | 生物辨識或憑證認證失敗 |
| timeout | `terminalErrorTimeout` | 連線逾時 |
| networkOffline | `terminalErrorNetwork` | 網路不可達 |
| unknown | `terminalErrorGeneric` | 未知錯誤 |

---

## 5. 完整性檢查清單

每個狀態至少有一條退出路徑（back / reconnect / disconnect）：

- [x] HomeScreen：兩個導航按鈕
- [x] EnrollmentScreen initial：系統返回
- [x] EnrollmentScreen scanning：pop 返回
- [x] TerminalScreen idle：back 按鈕
- [x] TerminalScreen connecting：back 按鈕
- [x] TerminalScreen connected：disconnect 按鈕（v1.2.0-W3-004 補全）
- [x] TerminalScreen disconnected：back + reconnect
- [x] TerminalScreen error：back + reconnect

---

## 6. 未來擴充點

新增畫面或狀態時，必須同步更新本矩陣，確認：
1. 新狀態至少有一條退出路徑
2. 所有狀態轉換在矩陣中有對應行
3. 新增操作有對應 widget test 覆蓋
