import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'package:app_tunnel/features/auth/biometric_service.dart';
import 'package:app_tunnel/features/credential/credential.dart';
import 'package:app_tunnel/features/credential/credential_repository.dart';
import 'package:app_tunnel/features/terminal/connection/connection_error.dart';
import 'package:app_tunnel/features/terminal/connection/connection_manager.dart';
import 'package:app_tunnel/features/terminal/connection/connection_state.dart'
    as cs;
import 'package:app_tunnel/features/terminal/protocol/ttyd_protocol.dart';

// -- Fakes --

class _FakeBiometricService implements BiometricService {
  _FakeBiometricService({this.authResult = true});
  final bool authResult;

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<bool> authenticate({required String localizedReason}) async =>
      authResult;
}

class _FakeCredentialRepository implements CredentialRepository {
  _FakeCredentialRepository({this.credential});
  final Credential? credential;

  @override
  Future<Credential?> load() async => credential;

  @override
  Future<void> save(Credential credential) async {}

  @override
  Future<void> delete() async {}

  @override
  Future<bool> exists() async => credential != null;
}

/// Fake WebSocketChannel that completes ready immediately.
class _FakeWebSocketChannel extends Fake implements WebSocketChannel {
  _FakeWebSocketChannel({this.shouldTimeout = false});

  final bool shouldTimeout;
  final _streamController = StreamController<dynamic>.broadcast();
  bool closed = false;

  @override
  Future<void> get ready {
    if (shouldTimeout) return Completer<void>().future; // never completes
    return Future.value();
  }

  @override
  Stream<dynamic> get stream => _streamController.stream;

  @override
  WebSocketSink get sink => _FakeWebSocketSink(
        onClose: () {
          closed = true;
          _streamController.close();
        },
      );

  void simulateServerClose() => _streamController.close();

  void simulateError(Object error) => _streamController.addError(error);
}

class _FakeWebSocketSink extends Fake implements WebSocketSink {
  _FakeWebSocketSink({required this.onClose});
  final void Function() onClose;

  @override
  Future<void> close([int? closeCode, String? closeReason]) async => onClose();

  @override
  void add(dynamic data) {}
}

// -- Helpers --

Credential _testCredential() => const Credential(
      version: 2,
      protocol: 'ttyd',
      endpoint: 'http://100.64.0.1:7681',
      ttydUser: 'user',
      ttydPass: 'pass',
    );

// -- Tests --

void main() {
  late _FakeWebSocketChannel fakeChannel;

  WebSocketChannel channelFactory(Uri uri, Map<String, String> headers) {
    return fakeChannel;
  }

  ConnectionManager createManager({
    bool biometricResult = true,
    Credential? credential,
    bool hasCredential = true,
    bool shouldTimeout = false,
    Duration? connectTimeout,
  }) {
    fakeChannel = _FakeWebSocketChannel(shouldTimeout: shouldTimeout);
    return ConnectionManager(
      biometricService: _FakeBiometricService(authResult: biometricResult),
      credentialRepository: _FakeCredentialRepository(
        credential: hasCredential ? (credential ?? _testCredential()) : null,
      ),
      protocol: TtydProtocol(),
      channelFactory: channelFactory,
      connectTimeout: connectTimeout ?? const Duration(seconds: 10),
    );
  }

  group('connect - 正常連線', () {
    test('transitions idle -> connecting -> connected', () async {
      final manager = createManager();
      final states = <cs.ConnectionState>[];
      manager.stateStream.listen(states.add);

      await manager.connect(biometricReason: 'test reason');
      // Allow broadcast stream events to propagate
      await Future<void>.delayed(Duration.zero);

      expect(manager.state, cs.ConnectionState.connected);
      expect(states, [
        cs.ConnectionState.connecting,
        cs.ConnectionState.connected,
      ]);

      await manager.dispose();
    });

    test('does nothing if already connected', () async {
      final manager = createManager();
      await manager.connect(biometricReason: 'test reason');

      final states = <cs.ConnectionState>[];
      manager.stateStream.listen(states.add);
      await manager.connect(biometricReason: 'test reason'); // second call should be no-op

      expect(states, isEmpty);
      await manager.dispose();
    });
  });

  group('connect - 認證失敗', () {
    test('biometric failure transitions to error', () async {
      final manager = createManager(biometricResult: false);
      await manager.connect(biometricReason: 'test reason');

      expect(manager.state, cs.ConnectionState.error);
      expect(
        manager.lastError?.type,
        ConnectionErrorType.authenticationFailed,
      );

      await manager.dispose();
    });

    test('missing credential transitions to error', () async {
      final manager = createManager(hasCredential: false);
      // biometric passes, but no credential
      await manager.connect(biometricReason: 'test reason');

      expect(manager.state, cs.ConnectionState.error);
      expect(manager.lastError?.type, ConnectionErrorType.unknown);

      await manager.dispose();
    });
  });

  group('connect - timeout', () {
    test('timeout transitions to error', () async {
      final manager = createManager(
        shouldTimeout: true,
        connectTimeout: const Duration(milliseconds: 50),
      );
      await manager.connect(biometricReason: 'test reason');

      expect(manager.state, cs.ConnectionState.error);
      expect(manager.lastError?.type, ConnectionErrorType.timeout);

      await manager.dispose();
    });
  });

  group('disconnect', () {
    test('transitions to disconnected', () async {
      final manager = createManager();
      await manager.connect(biometricReason: 'test reason');
      await manager.disconnect();

      expect(manager.state, cs.ConnectionState.disconnected);
      await manager.dispose();
    });
  });

  group('reconnect', () {
    test('disconnect then reconnect transitions back to connected', () async {
      final manager = createManager();
      await manager.connect(biometricReason: 'test reason');
      expect(manager.state, cs.ConnectionState.connected);

      // Reconnect will close old channel, create new one via factory
      await manager.reconnect(biometricReason: 'test reason');
      expect(manager.state, cs.ConnectionState.connected);

      await manager.dispose();
    });
  });

  group('server-initiated disconnect', () {
    test('server close transitions connected -> disconnected', () async {
      final manager = createManager();
      await manager.connect(biometricReason: 'test reason');

      fakeChannel.simulateServerClose();
      // Allow microtask to process
      await Future<void>.delayed(Duration.zero);

      expect(manager.state, cs.ConnectionState.disconnected);
      await manager.dispose();
    });

    test('stream error transitions to error state', () async {
      final manager = createManager();
      await manager.connect(biometricReason: 'test reason');

      fakeChannel.simulateError(Exception('network lost'));
      await Future<void>.delayed(Duration.zero);

      expect(manager.state, cs.ConnectionState.error);
      expect(
        manager.lastError?.type,
        ConnectionErrorType.networkOffline,
      );
      await manager.dispose();
    });
  });

  group('state stream', () {
    test('emits all transitions', () async {
      final manager = createManager();
      final states = <cs.ConnectionState>[];
      manager.stateStream.listen(states.add);

      await manager.connect(biometricReason: 'test reason');
      await Future<void>.delayed(Duration.zero);
      await manager.disconnect();
      await Future<void>.delayed(Duration.zero);

      expect(states, [
        cs.ConnectionState.connecting,
        cs.ConnectionState.connected,
        cs.ConnectionState.disconnected,
      ]);

      await manager.dispose();
    });
  });
}
