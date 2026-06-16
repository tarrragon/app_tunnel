# app — app_tunnel 手機端(Flutter)

原生終端機 UI:自渲染終端機(xterm 類)、自接 WebSocket,大幅改善手機打字體驗
(Esc / Ctrl / 方向鍵)。連線契約見 `../docs/contract.md`。

## 職責

- **生物辨識**:每次連線前過 Face ID / BiometricPrompt(`local_auth`)。
- **憑證保管**:ttyd basic auth 帳密 + endpoint 存
  iOS Keychain / Android Keystore(`flutter_secure_storage`),**不硬寫進程式碼**。
- **連線**:透過 Tailscale VPN 連線至主機 proxy,帶 ttyd basic auth header,
  講 ttyd `tty` 子協議。
- **終端機渲染**:xterm 類元件(候選 `xterm.dart`)+ 可調字體/視窗、聚焦模式。

## 前置條件

手機需安裝 Tailscale app 並加入與主機同一 tailnet。

## 狀態

尚未 scaffold(`flutter create`)。實作走框架 TDD 流程,由 `parsley-flutter-developer`
依 `docs/contract.md` 與功能規格進行。

## 待辦

- [ ] `flutter create` 初始化專案結構(`app/pubspec.yaml`)
- [ ] WS client:ttyd `tty` 子協議(input `'0'`、resize `'1'`)
- [ ] ttyd basic auth header 注入,secret 走 `flutter_secure_storage`
- [ ] 生物辨識閘門(`local_auth`)
- [ ] 終端機渲染 + 可調字體/聚焦模式
