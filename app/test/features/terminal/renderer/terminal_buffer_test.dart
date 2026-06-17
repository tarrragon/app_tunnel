import 'package:app_tunnel/features/terminal/renderer/ansi_parser.dart';
import 'package:app_tunnel/features/terminal/renderer/terminal_buffer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late TerminalBuffer buffer;
  late AnsiParser parser;

  setUp(() {
    buffer = TerminalBuffer();
    parser = AnsiParser();
  });

  group('TerminalBuffer 初始狀態', () {
    test('初始有一空行', () {
      expect(buffer.lineCount, 1);
      expect(buffer.lines.first.plainText, '');
    });

    test('游標起始在 (0, 0)', () {
      expect(buffer.cursorRow, 0);
      expect(buffer.cursorCol, 0);
    });
  });

  group('TerminalBuffer 文字寫入', () {
    test('寫入純文字', () {
      buffer.writeTokens(parser.parse('hello'));

      expect(buffer.lines[0].plainText, 'hello');
      expect(buffer.cursorCol, 5);
    });

    test('換行產生新行', () {
      buffer.writeTokens(parser.parse('line1\nline2'));

      expect(buffer.lineCount, 2);
      expect(buffer.lines[0].plainText, 'line1');
      expect(buffer.lines[1].plainText, 'line2');
    });

    test('多次寫入附加到同行', () {
      buffer.writeTokens(parser.parse('hello'));
      buffer.writeTokens(parser.parse(' world'));

      expect(buffer.lines[0].plainText, 'hello world');
    });
  });

  group('TerminalBuffer 緩衝區上限', () {
    test('超出 maxLines 時丟棄最舊行', () {
      final smallBuffer = TerminalBuffer(maxLines: 3);
      final lines = List.generate(5, (i) => 'line$i').join('\n');
      smallBuffer.writeTokens(parser.parse(lines));

      expect(smallBuffer.lineCount, 3);
      expect(smallBuffer.lines[0].plainText, 'line2');
      expect(smallBuffer.lines[2].plainText, 'line4');
    });
  });

  group('TerminalBuffer 游標移動', () {
    test('CUU 上移游標', () {
      buffer.writeTokens(parser.parse('line1\nline2\nline3'));
      buffer.writeTokens(parser.parse('\x1B[2A'));

      expect(buffer.cursorRow, 0);
    });

    test('CUD 下移游標', () {
      buffer.writeTokens(parser.parse('line1\nline2\nline3'));
      buffer.writeTokens(parser.parse('\x1B[2A'));
      buffer.writeTokens(parser.parse('\x1B[1B'));

      expect(buffer.cursorRow, 1);
    });

    test('上移不超出第 0 行', () {
      buffer.writeTokens(parser.parse('only'));
      buffer.writeTokens(parser.parse('\x1B[99A'));

      expect(buffer.cursorRow, 0);
    });
  });

  group('TerminalBuffer 清除', () {
    test('ED 2 (全螢幕清除) 清空緩衝區', () {
      buffer.writeTokens(parser.parse('line1\nline2'));
      buffer.writeTokens(parser.parse('\x1B[2J'));

      expect(buffer.lineCount, 1);
      expect(buffer.lines[0].plainText, '');
    });

    test('EL 0 清除游標到行尾', () {
      buffer.writeTokens(parser.parse('hello world'));
      // 游標回到 col 5
      buffer.writeTokens(parser.parse('\x1B[6D'));
      // EL 0：清除 col 5 到行尾，保留 "hello"
      buffer.writeTokens(parser.parse('\x1B[K'));

      expect(buffer.lines[0].plainText, 'hello');
    });

    test('EL 1 清除行首到游標', () {
      buffer.writeTokens(parser.parse('hello world'));
      // 游標回到 col 5
      buffer.writeTokens(parser.parse('\x1B[6D'));
      // EL 1：清除行首到 col 5，保留 " world"
      buffer.writeTokens(parser.parse('\x1B[1K'));

      expect(buffer.lines[0].plainText, ' world');
    });

    test('EL 2 清除整行', () {
      buffer.writeTokens(parser.parse('hello'));
      buffer.writeTokens(parser.parse('\x1B[2K'));

      expect(buffer.lines[0].plainText, '');
    });

    test('clear() 重置緩衝區', () {
      buffer.writeTokens(parser.parse('line1\nline2\nline3'));
      buffer.clear();

      expect(buffer.lineCount, 1);
      expect(buffer.cursorRow, 0);
      expect(buffer.cursorCol, 0);
    });
  });

  group('TerminalBuffer 帶色彩文字', () {
    test('寫入 ANSI 色彩文字保留樣式', () {
      buffer.writeTokens(parser.parse('\x1B[31mred text'));

      final segment = buffer.lines[0].segments.first;
      expect(segment.text, 'red text');
      expect(segment.foreground, isNotNull);
    });
  });
}
