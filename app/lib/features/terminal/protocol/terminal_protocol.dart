import 'dart:typed_data';

/// 需求：[SPEC-004 FR-03] WS 協議抽象層
/// 協議版本切換只改此介面的實作，不散落在 UI。
/// 雙邊以 docs/contract.md 的 protocol 欄位為準。
abstract class TerminalProtocol {
  /// 協議版本識別（如 'ttyd-tty/v1'、'apptunnel/v1'）。
  String get protocolVersion;

  /// WebSocket subprotocol 名稱（用於 WS handshake）。
  String get subprotocol;

  /// 將鍵盤輸入編碼為協議訊框。
  Uint8List encodeInput(String data);

  /// 將 resize 事件編碼為協議訊框。
  Uint8List encodeResize({required int columns, required int rows});

  /// 解碼伺服器傳回的 WS 訊框為終端機輸出文字。
  /// 回傳 null 表示非輸出型訊框（應忽略）。
  String? decodeOutput(dynamic rawFrame);

  /// 組裝 WebSocket 連線 URI。
  Uri buildUri({required String host, required int port});

  /// 組裝 WS 連線 HTTP headers（含認證）。
  Map<String, String> buildHeaders({
    required String username,
    required String password,
  });

  /// 組裝開場訊框（若協議需要），回傳 null 表示無需開場。
  String? buildAuthTokenFrame({String? authToken});
}
