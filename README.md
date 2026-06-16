# app_tunnel

> 手機透過 Cloudflare Tunnel 遠端操作本機真實終端機的**單人自用工具**。

## 簡介

把真實 shell 透過 ttyd 投到 WebSocket,經 Cloudflare Tunnel 安全地讓手機端的原生終端機 app 操作。三層認證守住「通往完整 shell」這道門。

```
Flutter app(Face ID)→ CF Tunnel → CF Access(邊緣)→ Go proxy(本機密鑰)→ ttyd(basic auth)→ zsh
```

## 結構(monorepo)

| 目錄 | 內容 | 語言 |
|------|------|------|
| `app/` | 手機端,原生終端機 UI | Flutter/Dart |
| `server/` | 本機認證 proxy(驗密鑰 + WS 轉發) | Go |
| `deploy/` | ttyd / cloudflared / CF Access 設定、launchd、systemd | — |
| `docs/` | 契約規格、上游回饋缺口記錄 | — |

## 文件

- 連線/認證契約:[`docs/contract.md`](./docs/contract.md)
- 技術決策(語言 / repo / 安全):[`CLAUDE.md`](./CLAUDE.md) §6
- proxy 建置與密鑰:[`server/README.md`](./server/README.md)
- 部署常駐:[`deploy/README.md`](./deploy/README.md)

## 開發狀態

- [x] 技術選型(Go proxy / monorepo / 原生 Flutter 終端機)
- [x] server 認證閘道 + QR enrollment
- [x] server 硬化(單元測試 / CI gate / 稽核 log / graceful shutdown / timeout)
- [ ] app Flutter 實作
- [ ] 部署實機驗證

## 授權

本專案採用 [MIT License](./LICENSE) 授權。
