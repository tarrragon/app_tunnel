import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app_tunnel/l10n/app_localizations.dart';

/// 需求：[1.2.0-W1-019] 驗證 i18n 設施已建置且關鍵 key 可載入。
/// 確認 gen-l10n 產出的 AppLocalizations delegate 可解析，並涵蓋
/// 013 清單遷移的所有 user-facing 字串 key。
void main() {
  late AppLocalizations l10n;

  setUp(() {
    l10n = lookupAppLocalizations(const Locale('en'));
  });

  test('支援語言包含英文', () {
    expect(AppLocalizations.supportedLocales, contains(const Locale('en')));
  });

  test('關鍵 key 載入英文字串', () {
    expect(l10n.appTitle, 'App Tunnel');
    expect(l10n.homeHeadline, 'App Tunnel - Remote Terminal');
    expect(l10n.homeConnectButton, 'Connect Terminal');
    expect(l10n.enrollmentScanTitle, 'Scan QR Code');
    expect(l10n.commonDismiss, 'Dismiss');
    expect(l10n.commonCancel, 'Cancel');
    expect(l10n.enrollmentOverwriteTitle, 'Overwrite Credential');
    expect(l10n.enrollmentReplaceButton, 'Replace');
    expect(l10n.enrollmentSaveSuccess, 'Credential saved successfully');
    expect(l10n.enrollmentTitle, 'Device Enrollment');
    expect(l10n.enrollmentScanButton, 'Scan QR Code');
    expect(l10n.authBiometricReason, 'Authenticate to access remote terminal');
    expect(l10n.terminalConnecting, 'Connecting...');
    expect(l10n.terminalDisconnected, 'Disconnected');
    expect(l10n.terminalReconnect, 'Reconnect');
    expect(l10n.terminalErrorGeneric, 'Connection error');
    expect(l10n.terminalErrorAuth, 'Authentication failed');
    expect(l10n.terminalErrorTimeout, 'Connection timed out');
    expect(l10n.terminalErrorNetwork, 'Network unreachable');
  });
}
