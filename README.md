# app_tunnel

> 手機透過 Tailscale mesh VPN 遠端操作本機真實終端機的**單人自用工具**。

## 簡介

把真實 shell 透過 ttyd 轉發到 WebSocket，經 Tailscale 私有網路讓手機端的原生終端機 app 安全操作。服務端點不存在於公開網路，並以 Tailscale 裝置認證 + ttyd basic auth 兩層認證限制對完整 shell 的存取。

```
Flutter app(Face ID)→ Tailscale VPN → Go proxy(稽核 log)→ ttyd(basic auth)→ zsh
```

## 結構（monorepo）

| 目錄 | 內容 | 語言 |
|------|------|------|
| `app/` | 手機端，原生終端機 UI | Flutter/Dart |
| `server/` | 本機 proxy（稽核 log + WS 透明轉發） | Go |
| `deploy/` | ttyd 設定、Tailscale 設定指引、launchd、systemd | — |
| `docs/` | 決策記錄、契約規格、需求文件、上游回饋 | — |

## 快速開始

完整使用說明：[`docs/USAGE.md`](./docs/USAGE.md)

> 前置：主機與手機需先加入**同一個** Tailscale tailnet（`tailscale up`），否則拿不到可連線的 IP。詳見 [`docs/USAGE.md`](./docs/USAGE.md) 前置需求與 Step 3。手機↔主機實機連線尚未經完整驗證。

自動化啟動（檢查依賴、缺則安裝、編譯、起服務）：

```bash
./bootstrap.sh -u "帳號:密碼"
```

或手動分步（前置：已裝 Go 1.21+、ttyd；`bootstrap.sh` 會自動補裝）：

```bash
# 1. 編譯 proxy
cd server && go build -o app-tunnel-proxy . && cd ..

# 2. 啟動服務
./deploy/scripts/start.sh -u "帳號:密碼"

# 3. 配對（手機掃 QR）。-ttyd-user / -ttyd-pass 須與步驟 2 的帳密一致，否則連線必遭 401
./server/app-tunnel-proxy enroll \
  -endpoint "http://<tailscale-ip>:8080/ws" \
  -ttyd-user "帳號" -ttyd-pass "密碼"

# 4. 手機開 app → Face ID → Connect Terminal
```

## 文件

- 使用說明：[`docs/USAGE.md`](./docs/USAGE.md)
- 連線/認證契約：[`docs/contract.md`](./docs/contract.md)
- 技術決策記錄：[`docs/tech-decisions.md`](./docs/tech-decisions.md)
- 部署指引：[`deploy/README.md`](./deploy/README.md)
- 變更記錄：[`CHANGELOG.md`](./CHANGELOG.md)

## 開發狀態

- [x] 技術選型（Go proxy / monorepo / 原生 Flutter 終端機 / Tailscale）
- [x] Server proxy + QR enrollment + 稽核 log + graceful shutdown
- [x] Server 適配 Tailscale（移除認證閘道、簡化 enroll v2）
- [x] App Flutter 完整實作（生物辨識 / secure storage / QR 配對 / WS 協議 / 終端機 UI）
- [x] Deploy 腳本與設定指引
- [x] 整合測試 + 安全審查（B+）+ Phase 4 品質評估（A 級）
- [x] CI 涵蓋雙端（server：vet + test + build；app：analyze + test，v1.1.0 補上）
- [ ] 部署實機驗證（Tailscale 手機→主機連線）

## 授權

本專案採用 [MIT License](./LICENSE) 授權。
