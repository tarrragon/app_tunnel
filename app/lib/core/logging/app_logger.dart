import 'dart:developer' as developer;

/// 需求：[1.2.0-W3-002] Flutter 端統一日誌層
/// 封裝 developer.log，提供 info/warning/error 分級，
/// 統一 name 格式為 [component]。
/// 約束：所有 Flutter 端 log 必須透過此類輸出，禁止直接使用 developer.log。
class AppLogger {
  AppLogger._();

  /// 一般資訊（連線步驟、狀態轉換、操作結果）。
  static void info(String message, {required String component}) {
    developer.log(message, name: component);
  }

  /// 警告（非致命異常、降級處理）。
  static void warning(
    String message, {
    required String component,
    Object? error,
  }) {
    developer.log(
      '[WARNING] $message',
      name: component,
      error: error,
    );
  }

  /// 錯誤（操作失敗、連線中斷）。
  static void error(
    String message, {
    required String component,
    Object? error,
  }) {
    developer.log(
      '[ERROR] $message',
      name: component,
      error: error,
    );
  }
}
