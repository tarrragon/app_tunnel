// 需求：[1.2.0-W1-020] 集中 app 數字魔術常數
// 來源：ANA 1.2.0-W1-013 §1.2 數字類盤點清單。
// 約束：僅集中共用 UI 間距/尺寸數字字面，不含文字（019）、顏色（021）。

/// 共用 UI 間距與尺寸常數。
abstract final class UiConstants {
  /// 區段間距（大）。
  static const double sectionSpacing = 24.0;

  /// 項目間距（中）。
  static const double itemSpacing = 16.0;

  /// 狀態 icon 尺寸。
  static const double statusIconSize = 48.0;

  /// 狀態文字字體大小。
  static const double statusFontSize = 16.0;

  /// 配對畫面 QR icon 尺寸。
  static const double enrollmentIconSize = 96.0;

  /// 工具列按鍵水平內距。
  static const double toolbarButtonPaddingH = 12.0;

  /// 工具列按鍵垂直內距。
  static const double toolbarButtonPaddingV = 8.0;
}
