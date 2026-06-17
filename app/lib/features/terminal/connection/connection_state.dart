/// 需求：[UC-02] 連線狀態機
/// 狀態轉換：idle -> connecting -> connected -> disconnected | error
enum ConnectionState {
  /// 初始狀態，尚未連線。
  idle,

  /// 正在建立連線（生物辨識 + 憑證載入 + WS handshake）。
  connecting,

  /// WebSocket 連線已建立。
  connected,

  /// 連線已正常斷開。
  disconnected,

  /// 連線發生錯誤（401 / timeout / 網路離線）。
  error,
}
