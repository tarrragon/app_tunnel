import 'package:flutter_test/flutter_test.dart';

import 'package:app_tunnel/features/auth/biometric_service.dart';
import 'package:app_tunnel/features/credential/credential.dart';
import 'package:app_tunnel/features/credential/credential_repository.dart';
import 'package:app_tunnel/features/terminal/connection/connection_manager.dart';
import 'package:app_tunnel/features/terminal/protocol/ttyd_protocol.dart';
import 'package:app_tunnel/main.dart';

class _FakeCredentialRepository implements CredentialRepository {
  @override
  Future<void> save(Credential credential) async {}
  @override
  Future<Credential?> load() async => null;
  @override
  Future<void> delete() async {}
  @override
  Future<bool> exists() async => false;
}

class _FakeBiometricService implements BiometricService {
  @override
  Future<bool> isAvailable() async => false;
  @override
  Future<bool> authenticate({required String localizedReason}) async => false;
}

void main() {
  testWidgets('App renders home screen', (WidgetTester tester) async {
    final protocol = TtydProtocol();
    final connectionManager = ConnectionManager(
      biometricService: _FakeBiometricService(),
      credentialRepository: _FakeCredentialRepository(),
      protocol: protocol,
    );

    await tester.pumpWidget(
      AppTunnelApp(
        credentialRepository: _FakeCredentialRepository(),
        connectionManager: connectionManager,
        protocol: protocol,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('App Tunnel'), findsOneWidget);
    expect(find.text('App Tunnel - Remote Terminal'), findsOneWidget);

    addTearDown(connectionManager.dispose);
  });
}
