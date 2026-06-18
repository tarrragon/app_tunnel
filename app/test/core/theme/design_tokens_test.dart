// 需求：[1.2.0-W1-018] 驗證設計 Token 常數值對齊 ANA 1.2.0-W1-014 表
// 驗證：介面色/狀態色/ANSI 16 色重配/預設前景背景/明度序鐵則/xterm fallback/間距/字級/字重/行高
// 約束：值 1:1 對齊 014 表；ANSI bright 明度恆高於對應 normal（鐵則 2）。
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app_tunnel/core/theme/app_colors.dart';
import 'package:app_tunnel/core/theme/app_spacing.dart';
import 'package:app_tunnel/core/theme/app_typography.dart';

void main() {
  group('介面色 — 對齊 014 表第 1 節', () {
    test('值 1:1 對齊', () {
      expect(AppColors.kColorBg, const Color(0xFF14171C));
      expect(AppColors.kColorSurface, const Color(0xFF1B1F26)); // 建議值，非終端 0xFF1E1E1E
      expect(AppColors.kColorSurfaceRaised, const Color(0xFF252A33));
      expect(AppColors.kColorBorder, const Color(0xFF333A45));
      expect(AppColors.kColorPrimary, const Color(0xFF3D7DF2));
      expect(AppColors.kColorPrimaryHover, const Color(0xFF5B92F5));
      expect(AppColors.kColorAccent, const Color(0xFFE8A33D));
      expect(AppColors.kColorInk, const Color(0xFFEDEFF2));
      expect(AppColors.kColorInkMuted, const Color(0xFFA6ACB5));
      expect(AppColors.kColorInkFaint, const Color(0xFF767D87));
    });
  });

  group('語意狀態色 — 對齊 014 表第 2 節', () {
    test('值 1:1 對齊', () {
      expect(AppColors.kColorStatusConnected, const Color(0xFF4BC07A));
      expect(AppColors.kColorStatusError, const Color(0xFFF2604B));
      expect(AppColors.kColorScrim, const Color(0x99000000));
    });

    test('別名等同性：connecting=primary, disconnected=inkMuted', () {
      expect(AppColors.kColorStatusConnecting, AppColors.kColorPrimary);
      expect(AppColors.kColorStatusDisconnected, AppColors.kColorInkMuted);
    });
  });

  group('ANSI standard 8 色 — 對齊 014 表第 3 節', () {
    test('值 1:1 對齊（SGR 30-37）', () {
      expect(AppColors.kAnsiStandard, <Color>[
        const Color(0xFF2A2E36),
        const Color(0xFFE06B5C),
        const Color(0xFF5DC08A),
        const Color(0xFFD9B45A),
        const Color(0xFF5B92F5),
        const Color(0xFFC58BD9),
        const Color(0xFF55C7CE),
        const Color(0xFFC8CCD2),
      ]);
    });
  });

  group('ANSI bright 8 色 — 對齊 014 表第 3 節', () {
    test('值 1:1 對齊（SGR 90-97）', () {
      expect(AppColors.kAnsiBright, <Color>[
        const Color(0xFF6B7280),
        const Color(0xFFFF8A7A),
        const Color(0xFF7FE0A8),
        const Color(0xFFF0D483),
        const Color(0xFF8AB4F8),
        const Color(0xFFDBABEC),
        const Color(0xFF85E2E8),
        const Color(0xFFEDEFF2),
      ]);
    });
  });

  group('ANSI 預設前景/背景', () {
    test('前景=ink, 背景=bg', () {
      expect(AppColors.kAnsiDefaultForeground, AppColors.kColorInk);
      expect(AppColors.kAnsiDefaultBackground, AppColors.kColorBg);
    });
  });

  group('鐵則 2：bright 明度恆高於對應 normal', () {
    test('每個 SGR 索引 bright luminance > standard luminance', () {
      for (var i = 0; i < 8; i++) {
        final standardLum = AppColors.kAnsiStandard[i].computeLuminance();
        final brightLum = AppColors.kAnsiBright[i].computeLuminance();
        expect(brightLum, greaterThan(standardLum),
            reason: 'SGR index $i: bright 應比 normal 亮');
      }
    });
  });

  group('xterm fallback 16 色 — 鐵則 4 備存', () {
    test('standard 原始 xterm 值', () {
      expect(AppColors.kAnsiXtermFallbackStandard, <Color>[
        const Color(0xFF000000),
        const Color(0xFFCD0000),
        const Color(0xFF00CD00),
        const Color(0xFFCDCD00),
        const Color(0xFF0000EE),
        const Color(0xFFCD00CD),
        const Color(0xFF00CDCD),
        const Color(0xFFE5E5E5),
      ]);
    });

    test('bright 原始 xterm 值', () {
      expect(AppColors.kAnsiXtermFallbackBright, <Color>[
        const Color(0xFF7F7F7F),
        const Color(0xFFFF0000),
        const Color(0xFF00FF00),
        const Color(0xFFFFFF00),
        const Color(0xFF5C5CFF),
        const Color(0xFFFF00FF),
        const Color(0xFF00FFFF),
        const Color(0xFFFFFFFF),
      ]);
    });
  });

  group('間距尺度 — 對齊 014 表第 4 節', () {
    test('4px 基準 5 級', () {
      expect(AppSpacing.kSpaceXs, 4);
      expect(AppSpacing.kSpaceSm, 8);
      expect(AppSpacing.kSpaceMd, 16);
      expect(AppSpacing.kSpaceLg, 24);
      expect(AppSpacing.kSpaceXl, 48);
    });
  });

  group('字級 — 對齊 014 表第 5 節', () {
    test('5 階層 size', () {
      expect(AppTypography.kFontDisplaySize, 28);
      expect(AppTypography.kFontTitleSize, 20);
      expect(AppTypography.kFontBodySize, 16);
      expect(AppTypography.kFontTerminalSize, 14);
      expect(AppTypography.kFontLabelSize, 13);
    });
  });

  group('字重 — 對齊 014 表第 5 節', () {
    test('5 階層 weight', () {
      expect(AppTypography.kFontDisplayWeight, FontWeight.w600);
      expect(AppTypography.kFontTitleWeight, FontWeight.w600);
      expect(AppTypography.kFontBodyWeight, FontWeight.w400);
      expect(AppTypography.kFontTerminalWeight, FontWeight.w400);
      expect(AppTypography.kFontLabelWeight, FontWeight.w500);
    });
  });

  group('行高 — 對齊 014 表第 5 節', () {
    test('終端 1.2 / UI 1.4', () {
      expect(AppTypography.kLineHeightTerminal, 1.2);
      expect(AppTypography.kLineHeightUi, 1.4);
    });
  });
}
