/// 需求：[UC-02] 終端機畫面 UI 狀態
/// 對應 ConnectionState 但語意屬 UI 層，解耦表現層與連線層。
enum TerminalScreenUiState {
  /// 初始或閒置。
  idle,

  /// 連線中（Face ID / 憑證載入 / WS handshake）。
  connecting,

  /// 已連線，顯示終端機。
  connected,

  /// 已斷線，顯示重連按鈕。
  disconnected,

  /// 連線錯誤，顯示錯誤訊息 + 重連按鈕。
  error,
}
