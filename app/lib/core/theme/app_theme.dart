// 需求：[1.2.0-W1-022] 全域深色「儀表艙」ThemeData
// 來源：ANA 1.2.0-W1-014 方案 C（深 cobalt 夜空 + amber accent）。
// 約束：套 AppColors/AppSpacing/AppTypography token，取代 main.dart 的
//       colorSchemeSeed: Colors.blue；顏色一律引用 AppColors 常數，不行內硬編碼。
//       只定義 theme 結構，不碰 renderer（023）/畫面重設計（024/025）。
import 'package:flutter/material.dart';

import 'package:app_tunnel/core/theme/app_colors.dart';
import 'package:app_tunnel/core/theme/app_typography.dart';

/// 全域深色主題工廠。
abstract final class AppTheme {
  /// 建立深色「儀表艙」ThemeData。
  static ThemeData dark() {
    final colorScheme = _darkColorScheme();
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.kColorBg,
      canvasColor: AppColors.kColorBg,
      dividerColor: AppColors.kColorBorder,
      appBarTheme: _appBarTheme(),
      filledButtonTheme: _filledButtonTheme(),
      textTheme: _textTheme(),
    );
  }

  /// 深色 ColorScheme，由品牌 cobalt + amber accent + 中性墨色構成。
  static ColorScheme _darkColorScheme() {
    return const ColorScheme.dark(
      primary: AppColors.kColorPrimary,
      onPrimary: AppColors.kColorInk,
      secondary: AppColors.kColorAccent,
      onSecondary: AppColors.kColorBg,
      surface: AppColors.kColorSurface,
      onSurface: AppColors.kColorInk,
      error: AppColors.kColorStatusError,
      onError: AppColors.kColorInk,
      outline: AppColors.kColorBorder,
    );
  }

  /// AppBar：surface 背景 + 主文字色標題。
  static AppBarTheme _appBarTheme() {
    return const AppBarTheme(
      backgroundColor: AppColors.kColorSurface,
      foregroundColor: AppColors.kColorInk,
      elevation: 0,
      titleTextStyle: TextStyle(
        color: AppColors.kColorInk,
        fontSize: AppTypography.kFontTitleSize,
        fontWeight: AppTypography.kFontTitleWeight,
      ),
    );
  }

  /// 唯一主操作按鈕樣式（承載 PrimaryActionButton 的視覺）。
  static FilledButtonThemeData _filledButtonTheme() {
    return FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.kColorPrimary,
        foregroundColor: AppColors.kColorInk,
        disabledBackgroundColor: AppColors.kColorBorder,
        disabledForegroundColor: AppColors.kColorInkFaint,
        textStyle: const TextStyle(
          fontSize: AppTypography.kFontLabelSize,
          fontWeight: AppTypography.kFontLabelWeight,
        ),
      ),
    );
  }

  /// 文字階層，套字體 token + 墨色。
  static TextTheme _textTheme() {
    return const TextTheme(
      displaySmall: TextStyle(
        color: AppColors.kColorInk,
        fontSize: AppTypography.kFontDisplaySize,
        fontWeight: AppTypography.kFontDisplayWeight,
        height: AppTypography.kLineHeightUi,
      ),
      titleLarge: TextStyle(
        color: AppColors.kColorInk,
        fontSize: AppTypography.kFontTitleSize,
        fontWeight: AppTypography.kFontTitleWeight,
        height: AppTypography.kLineHeightUi,
      ),
      bodyLarge: TextStyle(
        color: AppColors.kColorInk,
        fontSize: AppTypography.kFontBodySize,
        fontWeight: AppTypography.kFontBodyWeight,
        height: AppTypography.kLineHeightUi,
      ),
      bodyMedium: TextStyle(
        color: AppColors.kColorInkMuted,
        fontSize: AppTypography.kFontBodySize,
        fontWeight: AppTypography.kFontBodyWeight,
        height: AppTypography.kLineHeightUi,
      ),
      labelLarge: TextStyle(
        color: AppColors.kColorInk,
        fontSize: AppTypography.kFontLabelSize,
        fontWeight: AppTypography.kFontLabelWeight,
      ),
    );
  }
}
