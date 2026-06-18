// Shared fakes and helpers for integration tests.
//
// Requirement: [1.0.0-W7-002] Reusable mock infrastructure for
// enrollment, connection, and credential rotation integration tests.
import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'package:app_tunnel/features/auth/biometric_service.dart';
import 'package:app_tunnel/features/credential/credential.dart';
import 'package:app_tunnel/features/credential/credential_repository.dart';

// -- Test constants --

const testQrPayloadJson = '{'
    '"v":2,'
    '"protocol":"ttyd-tty/v1",'
    '"endpoint":"http://100.64.0.1:7681",'
    '"ttyd_user":"admin",'
    '"ttyd_pass":"secret123"'
    '}';

Credential testCredential() => const Credential(
      version: 2,
      protocol: 'ttyd-tty/v1',
      endpoint: 'http://100.64.0.1:7681',
      ttydUser: 'admin',
      ttydPass: 'secret123',
    );

Credential rotatedCredential() => const Credential(
      version: 2,
      protocol: 'ttyd-tty/v1',
      endpoint: 'http://100.64.0.1:7681',
      ttydUser: 'admin',
      ttydPass: 'newpass456',
    );

String rotatedQrPayloadJson() => jsonEncode({
      'v': 2,
      'protocol': 'ttyd-tty/v1',
      'endpoint': 'http://100.64.0.1:7681',
      'ttyd_user': 'admin',
      'ttyd_pass': 'newpass456',
    });

// -- Fakes --

/// In-memory credential repository for integration tests.
/// Behaves like SecureStorageCredentialRepository but without platform deps.
class InMemoryCredentialRepository implements CredentialRepository {
  Credential? _stored;

  @override
  Future<void> save(Credential credential) async => _stored = credential;

  @override
  Future<Credential?> load() async => _stored;

  @override
  Future<void> delete() async => _stored = null;

  @override
  Future<bool> exists() async => _stored != null;
}

/// Configurable fake biometric service.
class FakeBiometricService implements BiometricService {
  FakeBiometricService({this.available = true, this.authResult = true});

  bool available;
  bool authResult;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<bool> authenticate({required String localizedReason}) async =>
      authResult;
}

/// Fake WebSocket channel that supports bidirectional message exchange.
class FakeWebSocketChannel extends Fake implements WebSocketChannel {
  FakeWebSocketChannel({this.shouldTimeout = false});

  final bool shouldTimeout;
  final _serverToClient = StreamController<dynamic>.broadcast();
  final List<dynamic> sentFromClient = [];
  bool closed = false;

  @override
  Future<void> get ready {
    if (shouldTimeout) return Completer<void>().future;
    return Future.value();
  }

  @override
  Stream<dynamic> get stream => _serverToClient.stream;

  @override
  WebSocketSink get sink => _FakeWebSocketSinkImpl(
        onAdd: sentFromClient.add,
        onClose: () {
          closed = true;
          _serverToClient.close();
        },
      );

  /// Simulate server sending data to client.
  void pushServerMessage(dynamic data) => _serverToClient.add(data);

  /// Simulate server closing the connection.
  void closeFromServer() => _serverToClient.close();

  /// Simulate a stream error.
  void pushError(Object error) => _serverToClient.addError(error);
}

class _FakeWebSocketSinkImpl extends Fake implements WebSocketSink {
  _FakeWebSocketSinkImpl({required this.onAdd, required this.onClose});
  final void Function(dynamic) onAdd;
  final void Function() onClose;

  @override
  void add(dynamic data) => onAdd(data);

  @override
  Future<void> close([int? closeCode, String? closeReason]) async => onClose();
}
