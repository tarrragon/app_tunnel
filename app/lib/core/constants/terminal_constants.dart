// 需求：[1.2.0-W1-020] 集中 app 數字魔術常數
// 來源：ANA 1.2.0-W1-013 §1.2 數字類盤點清單。
// 約束：僅集中終端機相關的尺寸/逾時數字字面，不含文字（019）、顏色（021）。

/// 終端機 UI 相關常數（字體、尺寸估算、逾時）。
abstract final class TerminalConstants {
  /// 終端機 monospace 字體大小。
  static const double fontSize = 14.0;

  /// 以 monospace 估算每字元寬度（px）。
  static const double charWidth = 8.0;

  /// 行高（fontSize * 1.2 的固定估算值）。
  static const double lineHeight = 16.8;

  /// 欄數估算時扣除的水平 padding（px）。
  static const double horizontalPadding = 16.0;

  /// 列數估算時扣除的 toolbar 高度（px）。
  static const double toolbarHeight = 48.0;

  /// 欄數估算下限。
  static const int minColumns = 20;

  /// 欄數估算上限。
  static const int maxColumns = 500;

  /// 列數估算下限。
  static const int minRows = 5;

  /// 列數估算上限。
  static const int maxRows = 200;

  /// WebSocket 連線逾時。
  static const Duration connectTimeout = Duration(seconds: 10);
}
