import 'package:flutter_test/flutter_test.dart';

import 'package:app_tunnel/features/credential/credential.dart';
import 'package:app_tunnel/features/credential/credential_repository.dart';
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

void main() {
  testWidgets('App renders home screen', (WidgetTester tester) async {
    await tester.pumpWidget(
      AppTunnelApp(credentialRepository: _FakeCredentialRepository()),
    );
    await tester.pumpAndSettle();

    expect(find.text('App Tunnel'), findsOneWidget);
    expect(find.text('App Tunnel - Remote Terminal'), findsOneWidget);
  });
}
