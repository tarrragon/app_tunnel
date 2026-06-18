// 需求：[1.2.0-W1-023] 終端 renderer ANSI 16 色重配（語意保真）驗證
// 鐵則（來源 ANA 1.2.0-W1-014）：
//   1. 索引邏輯零改動：SGR code → palette 索引對應不變，僅換常數值。
//   2. normal vs bright 明度序保留：bright[i] 明度恆高於對應 standard[i]。
import 'dart:math' as math;

import 'package:app_tunnel/core/theme/app_colors.dart';
import 'package:app_tunnel/features/terminal/renderer/ansi_parser.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

/// 相對亮度（sRGB → 線性 → WCAG 加權），用於驗證明度序。
double _relativeLuminance(Color color) {
  double channel(int value) {
    final c = value / 255.0;
    return c <= 0.03928 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
  }

  final argb = color.toARGB32();
  final r = channel((argb >> 16) & 0xFF);
  final g = channel((argb >> 8) & 0xFF);
  final b = channel(argb & 0xFF);
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}

void main() {
  group('ANSI 16 色重配（1.2.0-W1-023 語意保真）', () {
    test('parser palette 引用 AppColors 重配常數（值 1:1 對應）', () {
      expect(AnsiParser.standardColors, equals(AppColors.kAnsiStandard));
      expect(AnsiParser.brightColors, equals(AppColors.kAnsiBright));
    });

    test('SGR 30-37 索引→重配 standard 值對應不變', () {
      final parser = AnsiParser();
      for (var code = 30; code <= 37; code++) {
        parser.reset();
        final tokens = parser.parse('\x1B[${code}mX');
        final segment = (tokens.first as TextToken).segment;
        expect(segment.foreground, AppColors.kAnsiStandard[code - 30],
            reason: 'SGR $code 必須映射 kAnsiStandard[${code - 30}]');
      }
    });

    test('SGR 90-97 索引→重配 bright 值對應不變', () {
      final parser = AnsiParser();
      for (var code = 90; code <= 97; code++) {
        parser.reset();
        final tokens = parser.parse('\x1B[${code}mX');
        final segment = (tokens.first as TextToken).segment;
        expect(segment.foreground, AppColors.kAnsiBright[code - 90],
            reason: 'SGR $code 必須映射 kAnsiBright[${code - 90}]');
      }
    });

    test('明度序不變：bright[i] 明度 > 對應 standard[i]（鐵則 2）', () {
      for (var i = 0; i < 8; i++) {
        final standardLum = _relativeLuminance(AppColors.kAnsiStandard[i]);
        final brightLum = _relativeLuminance(AppColors.kAnsiBright[i]);
        expect(brightLum, greaterThan(standardLum),
            reason: '索引 $i：bright 明度必須高於 standard（normal/bright 序保留）');
      }
    });
  });
}
