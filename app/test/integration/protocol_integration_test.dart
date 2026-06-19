// 需求：[1.2.0-W3-006] Protocol integration test 對真實 ttyd 驗證
// 驗證：WS 握手（101 + tty subprotocol）、auth token frame、binary frame I/O
// 約束：需要 /opt/homebrew/bin/ttyd v1.7.7；CI 環境需 ttyd 可用。
@TestOn('mac-os')
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:web_socket_channel/io.dart';

import 'package:app_tunnel/features/terminal/protocol/ttyd_protocol.dart';

/// 需求：[1.2.0-W3-006] ttyd test fixture
/// 啟動真實 ttyd process（隨機 port、basic auth、writable）供 integration test 使用。
class TtydFixture {
  TtydFixture._({
    required this.process,
    required this.port,
    required this.username,
    required this.password,
  });

  final Process process;
  final int port;
  final String username;
  final String password;

  static const _ttydPath = '/opt/homebrew/bin/ttyd'; // i18n-exempt

  static Future<TtydFixture> start({
    List<String> command = const ['bash', '--norc', '--noprofile'], // i18n-exempt
  }) async {
    final port = await _findFreePort();
    const username = 'testuser'; // i18n-exempt
    const password = 'testpass'; // i18n-exempt

    final process = await Process.start(
      _ttydPath,
      [
        '--port', '$port', // i18n-exempt
        '--writable', // i18n-exempt
        '--credential', '$username:$password', // i18n-exempt
        ...command,
      ],
    );

    await _waitForListening(port);

    return TtydFixture._(
      process: process,
      port: port,
      username: username,
      password: password,
    );
  }

  Future<void> stop() async {
    process.kill(ProcessSignal.sigterm);
    await process.exitCode.timeout(
      const Duration(seconds: 5), // magic-exempt
      onTimeout: () {
        process.kill(ProcessSignal.sigkill);
        return -1; // magic-exempt
      },
    );
  }

  static Future<int> _findFreePort() async {
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = server.port;
    await server.close();
    return port;
  }

  // magic-exempt — polling interval and retry count are test infrastructure
  static Future<void> _waitForListening(int port) async {
    for (var i = 0; i < 50; i++) {
      try {
        final socket = await Socket.connect(
          '127.0.0.1', port, // i18n-exempt
          timeout: const Duration(milliseconds: 100),
        );
        await socket.close();
        return;
      } on SocketException {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
    }
    throw StateError('ttyd did not start within 5s on port $port'); // i18n-exempt
  }
}

void main() {
  late TtydFixture ttyd;
  late TtydProtocol protocol;

  setUpAll(() async {
    if (!File(TtydFixture._ttydPath).existsSync()) {
      fail('ttyd not found at ${TtydFixture._ttydPath}'); // i18n-exempt
    }
  });

  setUp(() async {
    ttyd = await TtydFixture.start();
    protocol = TtydProtocol();
  });

  tearDown(() async {
    await ttyd.stop();
  });

  group('[1.2.0-W3-006] Protocol integration: real ttyd', () {
    test('WS handshake succeeds with tty subprotocol and basic auth', () async {
      final uri = protocol.buildUri(host: '127.0.0.1', port: ttyd.port);
      final headers = protocol.buildHeaders(
        username: ttyd.username,
        password: ttyd.password,
      );

      final channel = IOWebSocketChannel.connect(
        uri,
        protocols: [protocol.subprotocol],
        headers: headers,
      );

      await channel.ready;
      expect(channel.protocol, equals('tty')); // i18n-exempt

      await channel.sink.close();
    });

    test('WS handshake rejects wrong credentials', () async {
      final uri = protocol.buildUri(host: '127.0.0.1', port: ttyd.port);
      final headers = protocol.buildHeaders(
        username: 'wrong', // i18n-exempt
        password: 'wrong', // i18n-exempt
      );

      final channel = IOWebSocketChannel.connect(
        uri,
        protocols: [protocol.subprotocol],
        headers: headers,
      );

      expect(
        () => channel.ready,
        throwsA(isA<Exception>()),
      );
    });

    test('Auth token frame authenticates and spawns shell', () async {
      final uri = protocol.buildUri(host: '127.0.0.1', port: ttyd.port);
      final headers = protocol.buildHeaders(
        username: ttyd.username,
        password: ttyd.password,
      );

      final channel = IOWebSocketChannel.connect(
        uri,
        protocols: [protocol.subprotocol],
        headers: headers,
      );
      await channel.ready;

      // ttyd v1.7.7: auth token = base64(user:pass)
      final token = base64Encode(
        utf8.encode('${ttyd.username}:${ttyd.password}'),
      );
      final authFrame = protocol.buildAuthTokenFrame(authToken: token);
      expect(authFrame, isNotNull);
      channel.sink.add(authFrame!);

      // ttyd 送 binary frames（List<int>），prefix '0' = output
      final received = <String>[];
      final completer = Completer<void>();

      final subscription = channel.stream.listen((data) {
        expect(data, isA<List<int>>(),
            reason: 'ttyd sends binary WS frames'); // i18n-exempt
        final decoded = protocol.decodeOutput(data);
        if (decoded != null) {
          received.add(decoded);
          // bash prompt 包含 '$'
          if (received.join().contains('\$')) {
            if (!completer.isCompleted) completer.complete();
          }
        }
      });

      await completer.future.timeout(const Duration(seconds: 5)); // magic-exempt
      expect(received, isNotEmpty);

      await subscription.cancel();
      await channel.sink.close();
    });

    test('Input binary frame is received by shell (round-trip)', () async {
      // 使用 dart:io WebSocket 直接控制 frame opcode
      final cred = base64Encode(
        utf8.encode('${ttyd.username}:${ttyd.password}'),
      );

      final ws = await WebSocket.connect(
        'ws://127.0.0.1:${ttyd.port}/ws', // i18n-exempt
        protocols: ['tty'], // i18n-exempt
        headers: {'Authorization': 'Basic $cred'}, // i18n-exempt
      );

      // 送 auth token（text frame，第一個 byte 是 '{'）
      ws.add(jsonEncode({'AuthToken': cred})); // i18n-exempt

      final allOutput = StringBuffer();
      final promptReady = Completer<void>();
      final echoReady = Completer<void>();

      ws.listen((data) {
        if (data is List<int> && data.isNotEmpty && data[0] == 0x30) { // magic-exempt
          final text = utf8.decode(data.sublist(1), allowMalformed: true);
          allOutput.write(text);
          if (!promptReady.isCompleted && text.contains('\$')) {
            promptReady.complete();
          }
          if (!echoReady.isCompleted &&
              allOutput.toString().contains('INTEGRATION_TEST_MARKER')) { // i18n-exempt
            echoReady.complete();
          }
        }
      });

      // 等 shell prompt
      await promptReady.future.timeout(const Duration(seconds: 5)); // magic-exempt

      // ttyd input: binary frame, byte[0] = 0x30 ('0') + data
      ws.add([0x30, ...utf8.encode('echo INTEGRATION_TEST_MARKER\n')]); // i18n-exempt magic-exempt

      await echoReady.future.timeout(const Duration(seconds: 5)); // magic-exempt
      expect(allOutput.toString(), contains('INTEGRATION_TEST_MARKER')); // i18n-exempt

      await ws.close();
    });
  });
}
