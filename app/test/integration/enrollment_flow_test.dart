/// 需求：[UC-01] 配對流程端對端整合測試
/// 驗證：QR payload 解析 -> 轉換為 Credential -> 儲存至 repository
/// 約束：使用 mock server（InMemoryCredentialRepository），無需真實後端。
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:app_tunnel/core/errors/enrollment_errors.dart';
import 'package:app_tunnel/features/credential/credential.dart';
import 'package:app_tunnel/features/enrollment/credential_payload_parser.dart';

import 'test_helpers.dart';

void main() {
  group('UC-01: 配對流程端對端', () {
    late CredentialPayloadParser parser;
    late InMemoryCredentialRepository repository;

    setUp(() {
      parser = const CredentialPayloadParser();
      repository = InMemoryCredentialRepository();
    });

    test('Given valid QR payload, When parsed and saved, '
        'Then credential is persisted correctly', () async {
      // Given: valid QR payload JSON string
      const raw = testQrPayloadJson;

      // When: parse and convert to Credential, then save
      final payload = parser.parse(raw);
      final credential = Credential(
        version: payload.version,
        protocol: payload.protocol,
        endpoint: payload.endpoint,
        ttydUser: payload.ttydUser,
        ttydPass: payload.ttydPass,
      );
      await repository.save(credential);

      // Then: credential is retrievable and matches original payload
      final loaded = await repository.load();
      expect(loaded, isNotNull);
      expect(loaded!.version, 2);
      expect(loaded.protocol, 'ttyd-tty/v1');
      expect(loaded.endpoint, 'http://100.64.0.1:7681');
      expect(loaded.ttydUser, 'admin');
      expect(loaded.ttydPass, 'secret123');
      expect(await repository.exists(), isTrue);
    });

    test('Given invalid JSON QR payload, When parsed, '
        'Then throws InvalidJsonError and storage remains empty', () async {
      // Given
      const badRaw = 'not-json';

      // When / Then
      expect(() => parser.parse(badRaw), throwsA(isA<InvalidJsonError>()));
      expect(await repository.exists(), isFalse);
    });

    test('Given QR payload with wrong version, When parsed, '
        'Then throws UnsupportedVersionError', () {
      final wrongVersion = jsonEncode({
        'v': 1,
        'protocol': 'ttyd-tty/v1',
        'endpoint': 'http://100.64.0.1:7681',
        'ttyd_user': 'admin',
        'ttyd_pass': 'secret',
      });

      expect(
        () => parser.parse(wrongVersion),
        throwsA(isA<UnsupportedVersionError>()),
      );
    });

    test('Given QR payload with missing field, When parsed, '
        'Then throws MissingFieldError', () {
      final missingUser = jsonEncode({
        'v': 2,
        'protocol': 'ttyd-tty/v1',
        'endpoint': 'http://100.64.0.1:7681',
        'ttyd_pass': 'secret',
      });

      expect(
        () => parser.parse(missingUser),
        throwsA(isA<MissingFieldError>()),
      );
    });

    test('Given QR payload with invalid endpoint, When parsed, '
        'Then throws InvalidEndpointError', () {
      final badEndpoint = jsonEncode({
        'v': 2,
        'protocol': 'ttyd-tty/v1',
        'endpoint': 'not-a-url',
        'ttyd_user': 'admin',
        'ttyd_pass': 'secret',
      });

      expect(
        () => parser.parse(badEndpoint),
        throwsA(isA<InvalidEndpointError>()),
      );
    });

    test('Given credential saved, When delete called, '
        'Then credential no longer exists', () async {
      await repository.save(testCredential());
      expect(await repository.exists(), isTrue);

      await repository.delete();
      expect(await repository.exists(), isFalse);
      expect(await repository.load(), isNull);
    });
  });
}
