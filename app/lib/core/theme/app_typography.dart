// 需求：[1.2.0-W1-014] 設計 Token — 字體階層常數檔
// 來源：ANA 1.2.0-W1-014「設計 Token」表第 5 節，值 1:1 對齊。
// 約束：fixed rem scale（1.2 比例）；UI 與終端共用尺度避免兩套。
//       font family：monospace（終端）+ 系統 sans（UI）。
import 'package:flutter/painting.dart';

/// 設計 Token 字體階層。
///
/// 5 階層各 size + weight，加終端/UI 兩行高常數。
abstract final class AppTypography {
  // === size ===

  /// 首頁標題/品牌。
  static const double kFontDisplaySize = 28;

  /// 畫面標題（AppBar/狀態標題）。
  static const double kFontTitleSize = 20;

  /// 說明文字、狀態訊息（取代終端散落 16）。
  static const double kFontBodySize = 16;

  /// 終端等寬輸出（沿用現 14，可達性可調至 15）。
  static const double kFontTerminalSize = 14;

  /// 按鈕標籤、次要 label。
  static const double kFontLabelSize = 13;

  // === weight ===

  static const FontWeight kFontDisplayWeight = FontWeight.w600;
  static const FontWeight kFontTitleWeight = FontWeight.w600;
  static const FontWeight kFontBodyWeight = FontWeight.w400;
  static const FontWeight kFontTerminalWeight = FontWeight.w400;
  static const FontWeight kFontLabelWeight = FontWeight.w500;

  // === 行高 ===

  /// 終端行高（空行高沿用 fontSize*1.2）。
  static const double kLineHeightTerminal = 1.2;

  /// UI 文字行高。
  static const double kLineHeightUi = 1.4;
}
