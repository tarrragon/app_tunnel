/// 需求：[SPEC-004 FR-01] 連線前必須通過生物辨識
/// 定義生物辨識服務的抽象介面，供 caller 在連線前驗證身份。
abstract interface class BiometricService {
  /// 檢查裝置是否支援生物辨識。
  Future<bool> isAvailable();

  /// 執行生物辨識驗證。
  ///
  /// [localizedReason] 為 OS 生物辨識提示文字，由持有 BuildContext 的呼叫端
  /// 透過 AppLocalizations 取得後注入；服務層不查詢 l10n（本身無 context）。
  ///
  /// 回傳 `true` 表示驗證成功；`false` 表示使用者取消或驗證失敗。
  /// 驗證失敗時不洩漏任何憑證資訊。
  Future<bool> authenticate({required String localizedReason});
}
