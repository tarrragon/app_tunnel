// 需求：[1.2.0-W1-014] 設計 Token — 間距尺度常數檔
// 來源：ANA 1.2.0-W1-014「設計 Token」表第 4 節，值 1:1 對齊。
// 約束：4px 基準尺度，取代裸 SizedBox 散落數值。

/// 設計 Token 間距尺度（4px 基準）。
abstract final class AppSpacing {
  /// icon 與文字間隙。
  static const double kSpaceXs = 4;

  /// 終端 padding（沿用現 8）。
  static const double kSpaceSm = 8;

  /// 元件內距、狀態訊息上距。
  static const double kSpaceMd = 16;

  /// 主要區塊間距（沿用現 24）。
  static const double kSpaceLg = 24;

  /// 大留白、置中內容上下緩衝。
  static const double kSpaceXl = 48;
}
