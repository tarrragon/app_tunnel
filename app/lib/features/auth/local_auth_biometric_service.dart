import 'package:local_auth/local_auth.dart';

import 'package:app_tunnel/core/logging/app_logger.dart';
import 'package:app_tunnel/features/auth/biometric_service.dart';

/// 需求：[SPEC-004 FR-01] local_auth 封裝實作
/// 透過 local_auth package 提供 Face ID / BiometricPrompt 驗證。
class LocalAuthBiometricService implements BiometricService {
  LocalAuthBiometricService({LocalAuthentication? localAuth})
      : _localAuth = localAuth ?? LocalAuthentication();

  final LocalAuthentication _localAuth;

  @override
  Future<bool> isAvailable() async {
    final supported = await _localAuth.isDeviceSupported();
    AppLogger.info(
      'isAvailable: $supported', // i18n-exempt
      component: 'BiometricService',
    );
    return supported;
  }

  @override
  Future<bool> authenticate({required String localizedReason}) async {
    AppLogger.info(
      'authenticate: starting', // i18n-exempt
      component: 'BiometricService',
    );
    final available = await isAvailable();
    if (!available) {
      AppLogger.warning(
        'authenticate: device not supported', // i18n-exempt
        component: 'BiometricService',
      );
      return false;
    }
    // OS 提示文字由呼叫端透過 AppLocalizations.authBiometricReason 注入
    // （1.2.0-W1-027），服務層不持有 BuildContext，不直接查詢 l10n。
    final result = await _localAuth.authenticate(
      localizedReason: localizedReason,
      options: const AuthenticationOptions(
        stickyAuth: true,
        biometricOnly: false,
      ),
    );
    AppLogger.info(
      'authenticate: result=$result', // i18n-exempt
      component: 'BiometricService',
    );
    return result;
  }
}
