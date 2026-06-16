# app_tunnel

> 手機透過 Tailscale mesh VPN 遠端操作本機真實終端機的**單人自用工具**。

## 簡介

把真實 shell 透過 ttyd 投到 WebSocket,經 Tailscale 私有網路讓手機端的原生終端機 app 安全操作。服務端點不存在於公開網路,Tailscale 裝置認證 + ttyd basic auth 兩層守住「通往完整 shell」這道門。

```
Flutter app(Face ID)→ Tailscale VPN → Go proxy(稽核 log)→ ttyd(basic auth)→ zsh
```

## 結構(monorepo)

| 目錄 | 內容 | 語言 |
|------|------|------|
| `app/` | 手機端,原生終端機 UI | Flutter/Dart |
| `server/` | 本機 proxy(稽核 log + WS 透明轉發) | Go |
| `deploy/` | ttyd 設定、Tailscale 設定指引、launchd、systemd | — |
| `docs/` | 決策記錄、契約規格、需求文件、上游回饋 | — |

## 文件

- 連線/認證契約:[`docs/contract.md`](./docs/contract.md)
- 技術決策記錄:[`docs/tech-decisions.md`](./docs/tech-decisions.md)
- proxy 建置:[`server/README.md`](./server/README.md)
- 部署常駐:[`deploy/README.md`](./deploy/README.md)

## 開發狀態

- [x] 技術選型(Go proxy / monorepo / 原生 Flutter 終端機 / Tailscale)
- [x] server proxy + QR enrollment
- [x] server 硬化(單元測試 / CI gate / 稽核 log / graceful shutdown / timeout)
- [ ] server 適配 Tailscale(移除認證閘道、簡化 enroll)
- [ ] app Flutter 實作
- [ ] 部署實機驗證(Tailscale 手機→主機連線)

## 授權

本專案採用 [MIT License](./LICENSE) 授權。
