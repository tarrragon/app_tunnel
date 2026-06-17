import 'dart:convert';
import 'dart:typed_data';

import 'package:app_tunnel/features/terminal/protocol/terminal_protocol.dart';

/// 需求：[SPEC-004 FR-03] ttyd tty 子協議實作
/// 訊框格式：input = '0' + data, resize = '1' + JSON, 開場 = AuthToken JSON。
/// 認證：WS 連線帶 Authorization: Basic header（ttyd basic auth）。
class TtydProtocol implements TerminalProtocol {
  /// ttyd input 訊框前綴。
  static const int inputPrefix = 0x30; // ASCII '0'

  /// ttyd resize 訊框前綴。
  static const int resizePrefix = 0x31; // ASCII '1'

  /// ttyd output 訊框前綴。
  static const int outputPrefix = 0x30; // ASCII '0'

  @override
  String get protocolVersion => 'ttyd-tty/v1';

  @override
  String get subprotocol => 'tty';

  @override
  Uint8List encodeInput(String data) {
    final dataBytes = utf8.encode(data);
    final frame = Uint8List(1 + dataBytes.length);
    frame[0] = inputPrefix;
    frame.setRange(1, frame.length, dataBytes);
    return frame;
  }

  @override
  Uint8List encodeResize({required int columns, required int rows}) {
    final json = '{"columns":$columns,"rows":$rows}';
    final jsonBytes = utf8.encode(json);
    final frame = Uint8List(1 + jsonBytes.length);
    frame[0] = resizePrefix;
    frame.setRange(1, frame.length, jsonBytes);
    return frame;
  }

  @override
  String? decodeOutput(dynamic rawFrame) {
    if (rawFrame is String) {
      return rawFrame;
    }
    if (rawFrame is List<int>) {
      if (rawFrame.isEmpty) return null;
      if (rawFrame[0] == outputPrefix) {
        return utf8.decode(rawFrame.sublist(1));
      }
      return null;
    }
    return null;
  }

  @override
  Uri buildUri({required String host, required int port}) {
    return Uri(scheme: 'ws', host: host, port: port, path: '/ws');
  }

  @override
  Map<String, String> buildHeaders({
    required String username,
    required String password,
  }) {
    final credentials = base64Encode(utf8.encode('$username:$password'));
    return {'Authorization': 'Basic $credentials'};
  }

  @override
  String? buildAuthTokenFrame({String? authToken}) {
    if (authToken == null || authToken.isEmpty) return null;
    return jsonEncode({'AuthToken': authToken});
  }
}
