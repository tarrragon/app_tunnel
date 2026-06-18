import 'package:app_tunnel/features/terminal/renderer/ansi_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AnsiParser parser;

  setUp(() {
    parser = AnsiParser();
  });

  group('AnsiParser 純文字解析', () {
    test('無 escape 的純文字產生單一 TextToken', () {
      final tokens = parser.parse('hello world');

      expect(tokens, hasLength(1));
      expect(tokens.first, isA<TextToken>());
      expect((tokens.first as TextToken).segment.text, 'hello world');
    });

    test('空字串產生空列表', () {
      expect(parser.parse(''), isEmpty);
    });
  });

  group('AnsiParser SGR 色彩解析', () {
    test('前景色 30-37 對應標準色', () {
      final tokens = parser.parse('\x1B[31mred text');

      expect(tokens, hasLength(1));
      final segment = (tokens.first as TextToken).segment;
      expect(segment.text, 'red text');
      expect(segment.foreground, AnsiParser.standardColors[1]);
    });

    test('背景色 40-47 對應標準色', () {
      final tokens = parser.parse('\x1B[42mgreen bg');

      final segment = (tokens.first as TextToken).segment;
      expect(segment.background, AnsiParser.standardColors[2]);
    });

    test('亮色前景 90-97', () {
      final tokens = parser.parse('\x1B[91mbright red');

      final segment = (tokens.first as TextToken).segment;
      expect(segment.foreground, AnsiParser.brightColors[1]);
    });

    test('亮色背景 100-107', () {
      final tokens = parser.parse('\x1B[104mbright blue bg');

      final segment = (tokens.first as TextToken).segment;
      expect(segment.background, AnsiParser.brightColors[4]);
    });

    test('粗體 SGR 1', () {
      final tokens = parser.parse('\x1B[1mbold');

      final segment = (tokens.first as TextToken).segment;
      expect(segment.isBold, isTrue);
    });

    test('SGR 0 重置所有樣式', () {
      // 先設色彩再重置
      final tokens = parser.parse('\x1B[31mred\x1B[0mnormal');

      expect(tokens, hasLength(2));
      final redSegment = (tokens[0] as TextToken).segment;
      final normalSegment = (tokens[1] as TextToken).segment;
      expect(redSegment.foreground, isNotNull);
      expect(normalSegment.foreground, isNull);
      expect(normalSegment.isBold, isFalse);
    });

    test('SGR 39 重置前景色', () {
      final tokens = parser.parse('\x1B[31mred\x1B[39mdefault');

      final defaultSegment = (tokens[1] as TextToken).segment;
      expect(defaultSegment.foreground, isNull);
    });

    test('複合 SGR 參數 1;31', () {
      final tokens = parser.parse('\x1B[1;31mbold red');

      final segment = (tokens.first as TextToken).segment;
      expect(segment.isBold, isTrue);
      expect(segment.foreground, AnsiParser.standardColors[1]);
    });
  });

  group('AnsiParser 游標移動', () {
    test('CUU (A) 上移', () {
      final tokens = parser.parse('\x1B[3A');

      expect(tokens.first, isA<CursorToken>());
      final move = (tokens.first as CursorToken).move;
      expect(move.direction, CursorDirection.up);
      expect(move.count, 3);
    });

    test('CUD (B) 下移預設 1', () {
      final tokens = parser.parse('\x1B[B');

      final move = (tokens.first as CursorToken).move;
      expect(move.direction, CursorDirection.down);
      expect(move.count, 1);
    });

    test('CUF (C) 右移', () {
      final tokens = parser.parse('\x1B[5C');

      final move = (tokens.first as CursorToken).move;
      expect(move.direction, CursorDirection.forward);
      expect(move.count, 5);
    });

    test('CUB (D) 左移', () {
      final tokens = parser.parse('\x1B[2D');

      final move = (tokens.first as CursorToken).move;
      expect(move.direction, CursorDirection.backward);
      expect(move.count, 2);
    });
  });

  group('AnsiParser 清除指令', () {
    test('ED (J) 清除螢幕', () {
      final tokens = parser.parse('\x1B[2J');

      expect(tokens.first, isA<EraseToken>());
      final cmd = (tokens.first as EraseToken).command;
      expect(cmd.type, EraseType.display);
      expect(cmd.param, 2);
    });

    test('EL (K) 清除行', () {
      final tokens = parser.parse('\x1B[K');

      final cmd = (tokens.first as EraseToken).command;
      expect(cmd.type, EraseType.line);
      expect(cmd.param, 0);
    });
  });

  group('AnsiParser 混合內容', () {
    test('文字與 escape 交錯解析正確', () {
      final tokens = parser.parse('before\x1B[31mred\x1B[0mafter');

      expect(tokens, hasLength(3));
      expect((tokens[0] as TextToken).segment.text, 'before');
      expect((tokens[1] as TextToken).segment.text, 'red');
      expect((tokens[1] as TextToken).segment.foreground, isNotNull);
      expect((tokens[2] as TextToken).segment.text, 'after');
      expect((tokens[2] as TextToken).segment.foreground, isNull);
    });
  });

  group('AnsiParser reset', () {
    test('reset 清除累積狀態', () {
      parser.parse('\x1B[1;31mcolored');
      parser.reset();
      final tokens = parser.parse('plain');

      final segment = (tokens.first as TextToken).segment;
      expect(segment.foreground, isNull);
      expect(segment.isBold, isFalse);
    });
  });
}
