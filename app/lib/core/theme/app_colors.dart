// 需求：[1.2.0-W1-014] 設計 Token — 色彩盤常數檔
// 來源：ANA 1.2.0-W1-014「設計 Token」表，值 1:1 對齊。
// 約束：色彩採 OKLCH 設計、輸出 Flutter Color(0xAARRGGBB)。
//       ANSI 16 色重配僅動明度/彩度，色相語意保真（鐵則 1）；
//       bright 明度恆高於對應 normal（鐵則 2）；
//       原始 xterm 16 色備存於 kAnsiXtermFallback*，不啟用（鐵則 4 可回退）。
import 'package:flutter/painting.dart';

/// 設計 Token 色彩盤。
///
/// 介面色 10 + 語意狀態色 5 + ANSI 16 色重配（standard 8 + bright 8）
/// + ANSI 預設前景/背景 + 原始 xterm fallback 16 色。
abstract final class AppColors {
  // === 1. 介面色（深色「儀表艙」） ===

  /// app 根背景（近黑微冷）。oklch(0.18 0.012 250)。
  static const Color kColorBg = Color(0xFF14171C);

  /// 第二 neutral 層（panel/toolbar/卡片）。採 014 建議值，非沿用終端 0xFF1E1E1E。
  static const Color kColorSurface = Color(0xFF1B1F26);

  /// 浮起層（dialog/banner）。oklch(0.27 0.016 250)。
  static const Color kColorSurfaceRaised = Color(0xFF252A33);

  /// 分隔線/邊框。3:1 vs surface。
  static const Color kColorBorder = Color(0xFF333A45);

  /// 品牌 cobalt，主操作/選中/連線中。4.7:1 vs bg。
  static const Color kColorPrimary = Color(0xFF3D7DF2);

  /// 主操作 hover。oklch(0.68 0.15 250)。
  static const Color kColorPrimaryHover = Color(0xFF5B92F5);

  /// avionics amber，信號/警示強調（稀用）。7:1 vs bg。
  static const Color kColorAccent = Color(0xFFE8A33D);

  /// 主文字（取代 white）。14:1 vs bg。
  static const Color kColorInk = Color(0xFFEDEFF2);

  /// 次要文字（取代 white70，對比校準達標）。5.2:1 vs bg。
  static const Color kColorInkMuted = Color(0xFFA6ACB5);

  /// 弱文字/icon（取代 white54，僅大字/icon 用）。3.4:1 vs bg。
  static const Color kColorInkFaint = Color(0xFF767D87);

  // === 2. 語意狀態色（終端 5 狀態 + enrollment 結果） ===

  /// connected / enrollment success（取代 Colors.green）。6.8:1 vs bg。
  static const Color kColorStatusConnected = Color(0xFF4BC07A);

  /// connecting（= primary）。4.7:1 vs bg。
  static const Color kColorStatusConnecting = kColorPrimary;

  /// error / enrollment failed（取代 redAccent/red）。5.1:1 vs bg。
  static const Color kColorStatusError = Color(0xFFF2604B);

  /// disconnected（中性，非警示，= inkMuted）。5.2:1 vs bg。
  static const Color kColorStatusDisconnected = kColorInkMuted;

  /// QR 遮罩（取代 black.withAlpha(128)，alpha 0x99=60%）。
  static const Color kColorScrim = Color(0x99000000);

  // === 3. 終端 ANSI 16 色重配 ===
  // 設計原則：色相語意保真（SGR 索引語意不動），僅統一明度/彩度。
  // 索引邏輯零改動：standardColors[code-30] / brightColors[code-90]。

  /// ANSI standard 8 色（SGR 30-37）：black, red, green, yellow, blue, magenta, cyan, white。
  static const List<Color> kAnsiStandard = <Color>[
    Color(0xFF2A2E36), // 30 black（結構色，不作前景）
    Color(0xFFE06B5C), // 31 red    5.0:1
    Color(0xFF5DC08A), // 32 green  7.5:1
    Color(0xFFD9B45A), // 33 yellow 9:1
    Color(0xFF5B92F5), // 34 blue   5.0:1
    Color(0xFFC58BD9), // 35 magenta 6:1
    Color(0xFF55C7CE), // 36 cyan   8.5:1
    Color(0xFFC8CCD2), // 37 white  11:1（接近 ink）
  ];

  /// ANSI bright 8 色（SGR 90-97）。明度恆高於對應 standard（鐵則 2）。
  static const List<Color> kAnsiBright = <Color>[
    Color(0xFF6B7280), // 90 br-black（結構色，不作前景）
    Color(0xFFFF8A7A), // 91 br-red    8.2:1
    Color(0xFF7FE0A8), // 92 br-green  11:1
    Color(0xFFF0D483), // 93 br-yellow 13:1
    Color(0xFF8AB4F8), // 94 br-blue   8:1
    Color(0xFFDBABEC), // 95 br-magenta 9.5:1
    Color(0xFF85E2E8), // 96 br-cyan   12:1
    Color(0xFFEDEFF2), // 97 br-white  14:1（= ink）
  ];

  /// ANSI 預設前景（沿用 kColorInk，取代現 0xFFE0E0E0）。
  static const Color kAnsiDefaultForeground = kColorInk;

  /// ANSI 預設背景（= kColorBg）。
  static const Color kAnsiDefaultBackground = kColorBg;

  // === 4. 原始 xterm fallback 16 色（鐵則 4 備存，不啟用） ===

  /// 原始 xterm standard 8 色，僅備存供一鍵回退。
  static const List<Color> kAnsiXtermFallbackStandard = <Color>[
    Color(0xFF000000), // 30 black
    Color(0xFFCD0000), // 31 red
    Color(0xFF00CD00), // 32 green
    Color(0xFFCDCD00), // 33 yellow
    Color(0xFF0000EE), // 34 blue
    Color(0xFFCD00CD), // 35 magenta
    Color(0xFF00CDCD), // 36 cyan
    Color(0xFFE5E5E5), // 37 white
  ];

  /// 原始 xterm bright 8 色，僅備存供一鍵回退。
  static const List<Color> kAnsiXtermFallbackBright = <Color>[
    Color(0xFF7F7F7F), // 90 br-black
    Color(0xFFFF0000), // 91 br-red
    Color(0xFF00FF00), // 92 br-green
    Color(0xFFFFFF00), // 93 br-yellow
    Color(0xFF5C5CFF), // 94 br-blue
    Color(0xFFFF00FF), // 95 br-magenta
    Color(0xFF00FFFF), // 96 br-cyan
    Color(0xFFFFFFFF), // 97 br-white
  ];
}
