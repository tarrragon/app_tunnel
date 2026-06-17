/// 需求：[UC-02] 連線流程端對端整合測試
/// 驗證：生物辨識 -> 載入憑證 -> 建立 WS 連線 -> 雙向資料交換
/// 約束：使用 FakeWebSocketChannel，無需真實 WS server。
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'package:app_tunnel/features/terminal/connection/connection_error.dart';
import 'package:app_tunnel/features/terminal/connection/connection_manager.dart';
import 'package:app_tunnel/features/terminal/connection/connection_state.dart'
    as cs;
import 'package:app_tunnel/features/terminal/protocol/ttyd_protocol.dart';

import 'test_helpers.dart';

void main() {
  group('UC-02: 連線流程端對端', () {
    late InMemoryCredentialRepository repository;
    late FakeBiometricService biometricService;
    late FakeWebSocketChannel fakeChannel;

    WebSocketChannel channelFactory(Uri uri, Map<String, String> headers) {
      return fakeChannel;
    }

    ConnectionManager createManager({
      bool shouldTimeout = false,
      Duration? connectTimeout,
    }) {
      fakeChannel = FakeWebSocketChannel(shouldTimeout: shouldTimeout);
      return ConnectionManager(
        biometricService: biometricService,
        credentialRepository: repository,
        protocol: TtydProtocol(),
        channelFactory: channelFactory,
        connectTimeout: connectTimeout ?? const Duration(seconds: 10),
      );
    }

    setUp(() async {
      repository = InMemoryCredentialRepository();
      biometricService = FakeBiometricService();
      await repository.save(testCredential());
    });

    test('Given enrolled credential and biometric pass, '
        'When connect, Then state transitions to connected', () async {
      final manager = createManager();
      final states = <cs.ConnectionState>[];
      manager.stateStream.listen(states.add);

      await manager.connect();
      await Future<void>.delayed(Duration.zero);

      expect(manager.state, cs.ConnectionState.connected);
      expect(states, [
        cs.ConnectionState.connecting,
        cs.ConnectionState.connected,
      ]);

      await manager.dispose();
    });

    test('Given connected, When server sends data, '
        'Then client receives it via outputStream', () async {
      final manager = createManager();
      final received = <dynamic>[];
      manager.outputStream.listen(received.add);

      await manager.connect();
      fakeChannel.pushServerMessage('hello from server');
      await Future<void>.delayed(Duration.zero);

      expect(received, ['hello from server']);
      await manager.dispose();
    });

    test('Given connected, When client sends data, '
        'Then it reaches the WS channel', () async {
      final manager = createManager();
      await manager.connect();

      manager.sendData('user input');
      expect(fakeChannel.sentFromClient, ['user input']);

      await manager.dispose();
    });

    test('Given biometric fails, When connect, '
        'Then state is error with authenticationFailed', () async {
      biometricService.authResult = false;
      final manager = createManager();

      await manager.connect();

      expect(manager.state, cs.ConnectionState.error);
      expect(
        manager.lastError?.type,
        ConnectionErrorType.authenticationFailed,
      );
      await manager.dispose();
    });

    test('Given no credential enrolled, When connect, '
        'Then state is error', () async {
      await repository.delete();
      final manager = createManager();

      await manager.connect();

      expect(manager.state, cs.ConnectionState.error);
      expect(manager.lastError?.type, ConnectionErrorType.unknown);
      await manager.dispose();
    });

    test('Given WS timeout, When connect, '
        'Then state is error with timeout type', () async {
      final manager = createManager(
        shouldTimeout: true,
        connectTimeout: const Duration(milliseconds: 50),
      );

      await manager.connect();

      expect(manager.state, cs.ConnectionState.error);
      expect(manager.lastError?.type, ConnectionErrorType.timeout);
      await manager.dispose();
    });

    test('Given connected, When server closes, '
        'Then state transitions to disconnected', () async {
      final manager = createManager();
      await manager.connect();

      fakeChannel.closeFromServer();
      await Future<void>.delayed(Duration.zero);

      expect(manager.state, cs.ConnectionState.disconnected);
      await manager.dispose();
    });

    test('Given connected, When disconnect called, '
        'Then state is disconnected and channel is closed', () async {
      final manager = createManager();
      await manager.connect();

      await manager.disconnect();

      expect(manager.state, cs.ConnectionState.disconnected);
      expect(fakeChannel.closed, isTrue);
      await manager.dispose();
    });

    test('Given disconnected, When reconnect, '
        'Then state transitions back to connected', () async {
      final manager = createManager();
      await manager.connect();
      await manager.disconnect();

      await manager.reconnect();

      expect(manager.state, cs.ConnectionState.connected);
      await manager.dispose();
    });

    test('Given connected, When stream error occurs, '
        'Then state is error with networkOffline', () async {
      final manager = createManager();
      await manager.connect();

      fakeChannel.pushError(Exception('network lost'));
      await Future<void>.delayed(Duration.zero);

      expect(manager.state, cs.ConnectionState.error);
      expect(
        manager.lastError?.type,
        ConnectionErrorType.networkOffline,
      );
      await manager.dispose();
    });

    test('Full lifecycle: connect -> exchange data -> disconnect', () async {
      final manager = createManager();
      final states = <cs.ConnectionState>[];
      final received = <dynamic>[];

      manager.stateStream.listen(states.add);
      manager.outputStream.listen(received.add);

      // Connect
      await manager.connect();
      await Future<void>.delayed(Duration.zero);

      // Exchange data
      manager.sendData('ls -la');
      fakeChannel.pushServerMessage('file1.txt\nfile2.txt');
      await Future<void>.delayed(Duration.zero);

      // Disconnect
      await manager.disconnect();
      await Future<void>.delayed(Duration.zero);

      expect(states, [
        cs.ConnectionState.connecting,
        cs.ConnectionState.connected,
        cs.ConnectionState.disconnected,
      ]);
      expect(fakeChannel.sentFromClient, ['ls -la']);
      expect(received, ['file1.txt\nfile2.txt']);
      await manager.dispose();
    });
  });
}
