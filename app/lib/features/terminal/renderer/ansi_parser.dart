import 'package:app_tunnel/core/theme/app_colors.dart';
import 'package:flutter/painting.dart';

/// 需求：[SPEC-004 FR-04] ANSI escape sequence 解析
/// 將終端機輸出中的 ANSI 控制碼解析為結構化的文字片段。
/// 支援 SGR 色彩（前景/背景 8+16 色）與基本游標控制。

/// 單一文字片段，帶有 ANSI 樣式屬性。
class StyledSegment {
  const StyledSegment({
    required this.text,
    this.foreground,
    this.background,
    this.isBold = false,
  });

  final String text;
  final Color? foreground;
  final Color? background;
  final bool isBold;
}

/// 游標移動指令（CUU/CUD/CUF/CUB）。
class CursorMove {
  const CursorMove({required this.direction, this.count = 1});

  final CursorDirection direction;
  final int count;
}

enum CursorDirection { up, down, forward, backward }

/// 清除指令（ED/EL）。
class EraseCommand {
  const EraseCommand({required this.type, this.param = 0});

  final EraseType type;

  /// 0 = 游標到末尾, 1 = 開頭到游標, 2 = 全部
  final int param;
}

enum EraseType { display, line }

/// ANSI 解析結果：文字片段、游標移動、或清除指令。
sealed class AnsiToken {}

class TextToken extends AnsiToken {
  TextToken(this.segment);
  final StyledSegment segment;
}

class CursorToken extends AnsiToken {
  CursorToken(this.move);
  final CursorMove move;
}

class EraseToken extends AnsiToken {
  EraseToken(this.command);
  final EraseCommand command;
}

/// 需求：[SPEC-004 FR-04] ANSI 色彩與控制碼解析器
/// 約束：初版支援 SGR 8+16 色、CUU/CUD/CUF/CUB、ED/EL
class AnsiParser {
  Color? _currentForeground;
  Color? _currentBackground;
  bool _currentBold = false;

  /// 標準 8 色 ANSI 調色盤。
  /// 需求：[1.2.0-W1-023] 套用 014 重配常數（語意保真：索引邏輯與色相身分不動，僅換值）。
  static const List<Color> standardColors = AppColors.kAnsiStandard;

  /// 亮色 8 色 ANSI 調色盤。
  /// 需求：[1.2.0-W1-023] 套用 014 重配常數（bright 明度恆高於對應 normal）。
  static const List<Color> brightColors = AppColors.kAnsiBright;

  /// CSI 序列（ESC[...X），不含 private mode（?前綴）。
  static final RegExp _escapePattern = RegExp(r'\x1B\[([0-9;]*)([A-Za-z])');

  /// OSC 序列（ESC]...BEL 或 ESC]...ST）— 終端標題、目錄提示等，靜默忽略。
  static final RegExp _oscPattern = RegExp(r'\x1B\].*?(?:\x07|\x1B\\)');

  /// CSI private mode 序列（ESC[?...h/l 等）— 括號貼上、游標隱藏等，靜默忽略。
  static final RegExp _csiPrivatePattern = RegExp(r'\x1B\[\?[0-9;]*[A-Za-z]');

  /// 其他 escape 序列（ESC(B 字元集指定、ESC= 等），靜默忽略。
  static final RegExp _otherEscPattern = RegExp(r'\x1B[()#][A-Za-z0-9]|\x1B[=>]');

  /// 解析含 ANSI escape 的原始文字為 token 串列。
  List<AnsiToken> parse(String input) {
    // Strip non-renderable escape sequences before CSI parsing
    final cleaned = input
        .replaceAll(_oscPattern, '')
        .replaceAll(_csiPrivatePattern, '')
        .replaceAll(_otherEscPattern, '');

    final tokens = <AnsiToken>[];
    var lastEnd = 0;

    for (final match in _escapePattern.allMatches(cleaned)) {
      // 收集 escape 前的純文字
      if (match.start > lastEnd) {
        final text = cleaned.substring(lastEnd, match.start);
        if (text.isNotEmpty) {
          tokens.add(TextToken(_buildSegment(text)));
        }
      }

      final params = match.group(1) ?? '';
      final command = match.group(2) ?? '';
      _processEscapeSequence(params, command, tokens);

      lastEnd = match.end;
    }

    // 收集最後一段純文字
    if (lastEnd < cleaned.length) {
      final text = cleaned.substring(lastEnd);
      if (text.isNotEmpty) {
        tokens.add(TextToken(_buildSegment(text)));
      }
    }

    return tokens;
  }

  /// 重置解析器狀態。
  void reset() {
    _currentForeground = null;
    _currentBackground = null;
    _currentBold = false;
  }

  StyledSegment _buildSegment(String text) {
    return StyledSegment(
      text: text,
      foreground: _currentForeground,
      background: _currentBackground,
      isBold: _currentBold,
    );
  }

  void _processEscapeSequence(
    String params,
    String command,
    List<AnsiToken> tokens,
  ) {
    switch (command) {
      case 'm':
        _applySgr(params);
      case 'A':
        tokens.add(CursorToken(CursorMove(
          direction: CursorDirection.up,
          count: _parseIntParam(params),
        )));
      case 'B':
        tokens.add(CursorToken(CursorMove(
          direction: CursorDirection.down,
          count: _parseIntParam(params),
        )));
      case 'C':
        tokens.add(CursorToken(CursorMove(
          direction: CursorDirection.forward,
          count: _parseIntParam(params),
        )));
      case 'D':
        tokens.add(CursorToken(CursorMove(
          direction: CursorDirection.backward,
          count: _parseIntParam(params),
        )));
      case 'J':
        tokens.add(EraseToken(EraseCommand(
          type: EraseType.display,
          param: _parseIntParamOrZero(params),
        )));
      case 'K':
        tokens.add(EraseToken(EraseCommand(
          type: EraseType.line,
          param: _parseIntParamOrZero(params),
        )));
    }
  }

  int _parseIntParam(String params) {
    if (params.isEmpty) return 1;
    return int.tryParse(params) ?? 1;
  }

  int _parseIntParamOrZero(String params) {
    if (params.isEmpty) return 0;
    return int.tryParse(params) ?? 0;
  }

  /// 套用 SGR（Select Graphic Rendition）參數。
  void _applySgr(String params) {
    if (params.isEmpty) {
      reset();
      return;
    }

    final codes = params.split(';').map((s) => int.tryParse(s) ?? 0);
    for (final code in codes) {
      _applySingleSgrCode(code);
    }
  }

  void _applySingleSgrCode(int code) {
    switch (code) {
      case 0:
        reset();
      case 1:
        _currentBold = true;
      case 22:
        _currentBold = false;
      case >= 30 && <= 37:
        _currentForeground = standardColors[code - 30];
      case 39:
        _currentForeground = null;
      case >= 40 && <= 47:
        _currentBackground = standardColors[code - 40];
      case 49:
        _currentBackground = null;
      case >= 90 && <= 97:
        _currentForeground = brightColors[code - 90];
      case >= 100 && <= 107:
        _currentBackground = brightColors[code - 100];
    }
  }
}
