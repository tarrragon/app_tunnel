import 'package:local_auth/local_auth.dart';
import 'package:app_tunnel/features/auth/biometric_service.dart';

/// 需求：[SPEC-004 FR-01] local_auth 封裝實作
/// 透過 local_auth package 提供 Face ID / BiometricPrompt 驗證。
class LocalAuthBiometricService implements BiometricService {
  LocalAuthBiometricService({LocalAuthentication? localAuth})
      : _localAuth = localAuth ?? LocalAuthentication();

  final LocalAuthentication _localAuth;

  @override
  Future<bool> isAvailable() async {
    final isDeviceSupported = await _localAuth.isDeviceSupported();
    if (!isDeviceSupported) return false;
    final biometrics = await _localAuth.getAvailableBiometrics();
    return biometrics.isNotEmpty;
  }

  @override
  Future<bool> authenticate() async {
    final available = await isAvailable();
    if (!available) return false;
    // i18n 例外（1.2.0-W1-019）：此 OS 生物辨識提示文字位於不持有
    // BuildContext 的服務層，呼叫鏈（ConnectionManager.connect）亦無 context，
    // 無法直接引用 AppLocalizations。對應 ARB key authBiometricReason 已預留，
    // 待 1.2.0-W1-027 將 context 注入認證鏈後遷移。
    return _localAuth.authenticate(
      localizedReason: 'Authenticate to access remote terminal',
      options: const AuthenticationOptions(
        stickyAuth: true,
        biometricOnly: true,
      ),
    );
  }
}
