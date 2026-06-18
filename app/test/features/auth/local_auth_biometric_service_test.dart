import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth/local_auth.dart';
import 'package:app_tunnel/features/auth/biometric_service.dart';
import 'package:app_tunnel/features/auth/local_auth_biometric_service.dart';

/// 需求：[SPEC-004 FR-01] 生物辨識三路徑測試
/// 覆蓋：成功、失敗、裝置不支援。

// -- Mock --

class _FakeLocalAuth extends Fake implements LocalAuthentication {
  _FakeLocalAuth({
    this.deviceSupported = true,
    this.biometrics = const [BiometricType.face],
    this.authResult = true,
  });

  final bool deviceSupported;
  final List<BiometricType> biometrics;
  final bool authResult;

  @override
  Future<bool> isDeviceSupported() async => deviceSupported;

  @override
  Future<List<BiometricType>> getAvailableBiometrics() async => biometrics;

  @override
  Future<bool> authenticate({
    required String localizedReason,
    Iterable<Object> authMessages = const [],
    AuthenticationOptions options = const AuthenticationOptions(),
  }) async =>
      authResult;
}

// -- Tests --

void main() {
  late BiometricService service;

  group('isAvailable', () {
    test('returns true when device supports biometrics', () async {
      service = LocalAuthBiometricService(
        localAuth: _FakeLocalAuth(),
      );
      expect(await service.isAvailable(), isTrue);
    });

    test('returns false when device is not supported', () async {
      service = LocalAuthBiometricService(
        localAuth: _FakeLocalAuth(deviceSupported: false),
      );
      expect(await service.isAvailable(), isFalse);
    });

    test('returns true when no biometrics enrolled but device supported', () async {
      service = LocalAuthBiometricService(
        localAuth: _FakeLocalAuth(biometrics: []),
      );
      expect(await service.isAvailable(), isTrue);
    });
  });

  group('authenticate', () {
    test('returns true on successful authentication', () async {
      service = LocalAuthBiometricService(
        localAuth: _FakeLocalAuth(),
      );
      expect(await service.authenticate(localizedReason: 'test reason'), isTrue);
    });

    test('returns false on failed authentication', () async {
      service = LocalAuthBiometricService(
        localAuth: _FakeLocalAuth(authResult: false),
      );
      expect(await service.authenticate(localizedReason: 'test reason'), isFalse);
    });

    test('returns false when biometrics unavailable', () async {
      service = LocalAuthBiometricService(
        localAuth: _FakeLocalAuth(deviceSupported: false),
      );
      expect(await service.authenticate(localizedReason: 'test reason'), isFalse);
    });
  });
}
