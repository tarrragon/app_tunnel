# Changelog

## [Unreleased]

### Added
- 根目錄一鍵啟動腳本 `bootstrap.sh`：自動檢查依賴 → 缺就安裝（ttyd/qrencode/Go）→ 編譯 proxy → 起服務，旗標與 `deploy/scripts/start.sh` 一致並原樣轉發（Tailscale 只檢查不自動處理，因 `tailscale up` 需互動式 SSO）

## [1.0.0] - 2026-06-18

### Added

**Server (Go)**
- 透明反向代理（httputil.ReverseProxy → ttyd），結構化稽核 log（slog JSON）
- Enroll 子命令：組 v2 憑證包 + ASCII QR 顯示（qrencode）
- 可插拔憑證儲存後端（file/keychain/env）
- Graceful shutdown（SIGINT/SIGTERM，5s timeout）
- Proxy→ttyd 連線 timeout

**App (Flutter)**
- 生物辨識解鎖（Face ID / BiometricPrompt，biometricOnly 無 PIN fallback）
- Secure Storage 憑證保管（iOS Keychain / Android Keystore）
- QR 掃描配對（mobile_scanner + v2 payload 解析驗證）
- WS 協議抽象層（ttyd tty subprotocol，版本切換只改一處）
- 終端機渲染器（ANSI SGR 8+16 色 + 游標移動 + 清除 + 1000 行緩衝區）
- 終端機鍵盤工具列（Esc/Tab/Ctrl toggle/方向鍵/Ctrl+C/D/Z）
- 連線管理器（狀態機 + 錯誤處理 + 重連）
- 配對畫面（UC-01 全流程 + 覆寫確認）
- 終端機主畫面（UC-02 全流程 + 斷線重連 + resize）

**Deploy**
- ttyd + proxy 起停腳本（start.sh / stop.sh + 殘留檢查）
- launchd plist 範本（手動載入，不自啟）
- ttyd 配置範本 + Tailscale ACL 建議 + setup 指引

### Changed
- Server 從 Cloudflare Tunnel 架構遷移至 Tailscale mesh VPN
- Proxy 移除 token auth（X-App-Tunnel-Token），簡化為透明轉發
- clientIP 改用 RemoteAddr（Tailscale 對端 IP）
- 憑證包從 v1（8 欄）縮為 v2（5 欄）

### Fixed
- ConnectionManager auth headers 未傳遞至 WebSocket（IOWebSocketChannel）
- TerminalBuffer _eraseLine case 0/1/2 語意修正（游標到行尾 / 行首到游標 / 整行）
- terminal_renderer_test widget test 超時（pumpAndSettle → pump 精確控制）
- CredentialPayload / Credential duplicate value object 合併

### Security
- 安全審查 B+：0 嚴重漏洞、2 中風險（ws:// + keychain process args）已有緩解
- 憑證不洩漏：Credential.toString() 遮蔽密碼、原始碼無硬編碼密鑰
- file 後端強制 0600 權限、biometricOnly 排除 PIN fallback
