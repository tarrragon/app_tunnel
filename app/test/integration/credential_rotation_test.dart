// 需求：[UC-03] 帳密輪替端對端整合測試
// 驗證：舊憑證覆寫 -> 新憑證生效 -> 使用新憑證連線
// 約束：使用 mock server，驗證 repository 覆寫行為與 ConnectionManager 讀取一致。
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'package:app_tunnel/features/enrollment/credential_payload_parser.dart';
import 'package:app_tunnel/features/terminal/connection/connection_manager.dart';
import 'package:app_tunnel/features/terminal/connection/connection_state.dart'
    as cs;
import 'package:app_tunnel/features/terminal/protocol/ttyd_protocol.dart';

import 'test_helpers.dart';

void main() {
  group('UC-03: 帳密輪替端對端', () {
    late InMemoryCredentialRepository repository;
    late FakeBiometricService biometricService;
    late FakeWebSocketChannel fakeChannel;
    late Map<String, String> lastHeaders;

    WebSocketChannel channelFactory(Uri uri, Map<String, String> headers) {
      lastHeaders = headers;
      return fakeChannel;
    }

    ConnectionManager createManager() {
      fakeChannel = FakeWebSocketChannel();
      return ConnectionManager(
        biometricService: biometricService,
        credentialRepository: repository,
        protocol: TtydProtocol(),
        channelFactory: channelFactory,
      );
    }

    setUp(() async {
      repository = InMemoryCredentialRepository();
      biometricService = FakeBiometricService();
      lastHeaders = {};
    });

    test('Given old credential saved, When new QR scanned and saved, '
        'Then old credential is overwritten', () async {
      // Given: old credential exists
      await repository.save(testCredential());
      final oldLoaded = await repository.load();
      expect(oldLoaded!.ttydPass, 'secret123');

      // When: new QR payload parsed and saved (overwrites)
      const parser = CredentialPayloadParser();
      final newCredential = parser.parse(rotatedQrPayloadJson());
      await repository.save(newCredential);

      // Then: loaded credential reflects the new password
      final loaded = await repository.load();
      expect(loaded!.ttydPass, 'newpass456');
      expect(loaded.ttydUser, 'admin');
    });

    test('Given credential rotated, When connect, '
        'Then WS uses new credential in auth headers', () async {
      // Given: save rotated credential
      await repository.save(rotatedCredential());

      // When: connect
      final manager = createManager();
      await manager.connect();

      // Then: Authorization header uses new credentials
      expect(lastHeaders.containsKey('Authorization'), isTrue);
      final expectedAuth =
          base64Encode(utf8.encode('admin:newpass456'));
      expect(lastHeaders['Authorization'], 'Basic $expectedAuth');

      await manager.dispose();
    });

    test('Given connected with old credential, When rotated and reconnected, '
        'Then new credential is used', () async {
      // Given: connect with old credential
      await repository.save(testCredential());
      var manager = createManager();
      await manager.connect();
      expect(manager.state, cs.ConnectionState.connected);

      final oldAuth =
          base64Encode(utf8.encode('admin:secret123'));
      expect(lastHeaders['Authorization'], 'Basic $oldAuth');
      await manager.dispose();

      // When: rotate credential and create new connection
      await repository.save(rotatedCredential());
      manager = createManager();
      await manager.connect();

      // Then: new auth header
      final newAuth =
          base64Encode(utf8.encode('admin:newpass456'));
      expect(lastHeaders['Authorization'], 'Basic $newAuth');
      expect(manager.state, cs.ConnectionState.connected);

      await manager.dispose();
    });

    test('Given credential deleted after rotation, When connect, '
        'Then state is error due to missing credential', () async {
      await repository.save(rotatedCredential());
      await repository.delete();

      final manager = createManager();
      await manager.connect();

      expect(manager.state, cs.ConnectionState.error);
      await manager.dispose();
    });

    test('Full rotation lifecycle: '
        'enroll -> connect -> rotate -> reconnect with new cred', () async {
      // Step 1: Initial enrollment
      const parser = CredentialPayloadParser();
      final initialCredential = parser.parse(testQrPayloadJson);
      await repository.save(initialCredential);

      // Step 2: Connect with initial credential
      var manager = createManager();
      await manager.connect();
      expect(manager.state, cs.ConnectionState.connected);
      await manager.disconnect();
      await manager.dispose();

      // Step 3: Rotate credential (new QR scan)
      final rotatedCredential = parser.parse(rotatedQrPayloadJson());
      await repository.save(rotatedCredential);

      // Step 4: Reconnect with rotated credential
      manager = createManager();
      await manager.connect();
      expect(manager.state, cs.ConnectionState.connected);

      final expectedAuth =
          base64Encode(utf8.encode('admin:newpass456'));
      expect(lastHeaders['Authorization'], 'Basic $expectedAuth');

      await manager.dispose();
    });
  });
}
