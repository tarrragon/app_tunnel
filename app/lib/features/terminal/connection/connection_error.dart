/// 需求：[UC-02] 連線錯誤分類
/// 區分認證失敗、逾時、網路離線三種錯誤以便 UI 顯示對應訊息。
enum ConnectionErrorType {
  /// ttyd basic auth 失敗（HTTP 401）。
  authenticationFailed,

  /// 連線逾時。
  timeout,

  /// Tailscale 網路不可達或裝置離線。
  networkOffline,

  /// 其他未分類錯誤。
  unknown,
}

/// 需求：[UC-02] 連線錯誤封裝
/// 約束：每個錯誤必須帶 type 和可讀訊息，供 UI 層判斷和顯示。
class ConnectionError implements Exception {
  const ConnectionError({
    required this.type,
    required this.message,
    this.cause,
  });

  final ConnectionErrorType type;
  final String message;
  final Object? cause;

  @override
  String toString() => 'ConnectionError($type): $message';
}
