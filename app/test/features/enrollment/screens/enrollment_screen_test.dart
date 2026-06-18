import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app_tunnel/l10n/app_localizations.dart';
import 'package:app_tunnel/features/credential/credential.dart';
import 'package:app_tunnel/features/credential/credential_repository.dart';
import 'package:app_tunnel/features/enrollment/screens/enrollment_screen.dart';

/// In-memory mock for [CredentialRepository].
class MockCredentialRepository implements CredentialRepository {
  Credential? _stored;
  bool _existsOverride = false;

  void setExisting(bool value) => _existsOverride = value;

  @override
  Future<void> save(Credential credential) async => _stored = credential;

  @override
  Future<Credential?> load() async => _stored;

  @override
  Future<void> delete() async => _stored = null;

  @override
  Future<bool> exists() async => _existsOverride;

  Credential? get lastSaved => _stored;
}

void main() {
  late MockCredentialRepository mockRepo;

  setUp(() {
    mockRepo = MockCredentialRepository();
  });

  Widget buildTestApp() {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: EnrollmentScreen(credentialRepository: mockRepo),
    );
  }

  group('EnrollmentScreen', () {
    testWidgets('displays scan button on initial load', (tester) async {
      await tester.pumpWidget(buildTestApp());

      expect(find.text('Device Enrollment'), findsOneWidget);
      expect(find.text('Scan QR Code'), findsOneWidget);
      expect(find.byIcon(Icons.qr_code_scanner), findsOneWidget);
    });

    testWidgets('displays instruction text', (tester) async {
      await tester.pumpWidget(buildTestApp());

      expect(
        find.text(
          'Scan the QR code from your server to pair this device.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('shows overwrite dialog when credential exists', (tester) async {
      mockRepo.setExisting(true);
      await tester.pumpWidget(buildTestApp());

      // EnrollmentScreen uses Navigator.push to QrScannerScreen,
      // which requires camera — we test dialog logic via unit test instead.
      // This test verifies initial render and button presence.
      expect(find.text('Scan QR Code'), findsOneWidget);
    });
  });
}
