import 'dart:convert';
import 'dart:typed_data';

import 'package:app_tunnel/features/terminal/protocol/terminal_protocol.dart';
import 'package:app_tunnel/features/terminal/protocol/ttyd_protocol.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late TtydProtocol protocol;

  setUp(() {
    protocol = TtydProtocol();
  });

  group('TtydProtocol 協議元資料', () {
    test('protocolVersion 為 ttyd-tty/v1', () {
      expect(protocol.protocolVersion, equals('ttyd-tty/v1'));
    });

    test('subprotocol 為 tty', () {
      expect(protocol.subprotocol, equals('tty'));
    });

    test('實作 TerminalProtocol 介面', () {
      expect(protocol, isA<TerminalProtocol>());
    });
  });

  group('encodeInput 訊框編碼', () {
    test('前綴為 ASCII 0 後接 UTF-8 資料', () {
      final frame = protocol.encodeInput('ls');
      // '0' = 0x30, 'l' = 0x6C, 's' = 0x73
      expect(frame, equals(Uint8List.fromList([0x30, 0x6C, 0x73])));
    });

    test('空字串只有前綴', () {
      final frame = protocol.encodeInput('');
      expect(frame, equals(Uint8List.fromList([0x30])));
    });

    test('中文字元正確編碼為 UTF-8', () {
      final frame = protocol.encodeInput('你');
      final expected = Uint8List.fromList([0x30, ...utf8.encode('你')]);
      expect(frame, equals(expected));
    });
  });

  group('encodeResize 訊框編碼', () {
    test('前綴為 ASCII 1 後接 JSON', () {
      final frame = protocol.encodeResize(columns: 80, rows: 24);
      final jsonPart = utf8.decode(frame.sublist(1));
      expect(frame[0], equals(0x31));
      expect(jsonDecode(jsonPart), equals({'columns': 80, 'rows': 24}));
    });
  });

  group('decodeOutput 訊框解碼', () {
    test('String 型訊框直接回傳', () {
      expect(protocol.decodeOutput('hello'), equals('hello'));
    });

    test('binary 訊框前綴 0x30 解碼為 UTF-8 文字', () {
      final raw = [0x30, ...utf8.encode('world')];
      expect(protocol.decodeOutput(raw), equals('world'));
    });

    test('空 binary 訊框回傳 null', () {
      expect(protocol.decodeOutput(<int>[]), isNull);
    });

    test('非 0x30 前綴的 binary 訊框回傳 null', () {
      expect(protocol.decodeOutput([0x31, 0x41]), isNull);
    });

    test('非 String 非 List 型別回傳 null', () {
      expect(protocol.decodeOutput(42), isNull);
    });
  });

  group('buildUri 組裝', () {
    test('組裝 ws://host:port/ws', () {
      final uri = protocol.buildUri(host: '100.64.0.1', port: 7681);
      expect(uri.toString(), equals('ws://100.64.0.1:7681/ws'));
    });
  });

  group('buildHeaders 認證 header', () {
    test('產出 Authorization: Basic header', () {
      final headers = protocol.buildHeaders(
        username: 'admin',
        password: 'secret',
      );
      final expected = base64Encode(utf8.encode('admin:secret'));
      expect(headers['Authorization'], equals('Basic $expected'));
    });

    test('header map 只包含 Authorization', () {
      final headers = protocol.buildHeaders(
        username: 'u',
        password: 'p',
      );
      expect(headers.length, equals(1));
      expect(headers.containsKey('Authorization'), isTrue);
    });
  });

  group('buildAuthTokenFrame 開場訊框', () {
    test('有 token 時回傳 AuthToken JSON', () {
      final frame = protocol.buildAuthTokenFrame(authToken: 'abc123');
      expect(jsonDecode(frame!), equals({'AuthToken': 'abc123'}));
    });

    test('null token 回傳 null', () {
      expect(protocol.buildAuthTokenFrame(authToken: null), isNull);
    });

    test('空字串 token 回傳 null', () {
      expect(protocol.buildAuthTokenFrame(authToken: ''), isNull);
    });
  });

  group('協議切換驗證', () {
    test('TerminalProtocol 介面可替換不同實作', () {
      // 驗證介面多型：同一變數可持有不同實作
      final TerminalProtocol proto = TtydProtocol();
      expect(proto.protocolVersion, equals('ttyd-tty/v1'));
      // 未來 apptunnel/v1 實作替換此處即可
    });
  });
}
