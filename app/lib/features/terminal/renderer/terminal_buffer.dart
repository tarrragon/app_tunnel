import 'package:app_tunnel/features/terminal/renderer/ansi_parser.dart';

/// 需求：[SPEC-004 FR-04] 終端機緩衝區管理
/// 固定行數的環形緩衝區，支援 ANSI 文字寫入、游標移動、清除。
/// 約束：預設上限 1000 行，超出時丟棄最舊行。

/// 單行內容：一組帶樣式的文字片段。
class TerminalLine {
  TerminalLine([List<StyledSegment>? segments])
      : segments = segments ?? [];

  final List<StyledSegment> segments;

  /// 取得本行的純文字內容。
  String get plainText =>
      segments.map((s) => s.text).join();
}

/// 終端機緩衝區，管理行列資料與游標位置。
class TerminalBuffer {
  TerminalBuffer({this.maxLines = _defaultMaxLines});

  static const int _defaultMaxLines = 1000;

  final int maxLines;
  final List<TerminalLine> _lines = [TerminalLine()];
  int _cursorRow = 0;
  int _cursorCol = 0;

  /// 目前所有行的唯讀快照。
  List<TerminalLine> get lines => List.unmodifiable(_lines);

  /// 目前游標所在行。
  int get cursorRow => _cursorRow;

  /// 目前游標所在欄。
  int get cursorCol => _cursorCol;

  /// 總行數。
  int get lineCount => _lines.length;

  /// 將解析後的 ANSI token 寫入緩衝區。
  void writeTokens(List<AnsiToken> tokens) {
    for (final token in tokens) {
      switch (token) {
        case TextToken(:final segment):
          _writeText(segment);
        case CursorToken(:final move):
          _moveCursor(move);
        case EraseToken(:final command):
          _erase(command);
      }
    }
  }

  /// 清除緩衝區並重置游標。
  void clear() {
    _lines
      ..clear()
      ..add(TerminalLine());
    _cursorRow = 0;
    _cursorCol = 0;
  }

  void _writeText(StyledSegment segment) {
    final parts = segment.text.split('\n');
    for (var i = 0; i < parts.length; i++) {
      if (i > 0) {
        _newLine();
      }
      final text = parts[i];
      if (text.isNotEmpty) {
        _appendToCurrentLine(StyledSegment(
          text: text,
          foreground: segment.foreground,
          background: segment.background,
          isBold: segment.isBold,
        ));
      }
    }
  }

  void _appendToCurrentLine(StyledSegment segment) {
    _ensureCursorRow();
    _lines[_cursorRow].segments.add(segment);
    _cursorCol += segment.text.length;
  }

  void _newLine() {
    _cursorRow++;
    _cursorCol = 0;
    if (_cursorRow >= _lines.length) {
      _lines.add(TerminalLine());
    }
    _trimExcessLines();
  }

  void _trimExcessLines() {
    while (_lines.length > maxLines) {
      _lines.removeAt(0);
      _cursorRow = (_cursorRow - 1).clamp(0, _lines.length - 1);
    }
  }

  void _ensureCursorRow() {
    while (_cursorRow >= _lines.length) {
      _lines.add(TerminalLine());
    }
  }

  void _moveCursor(CursorMove move) {
    switch (move.direction) {
      case CursorDirection.up:
        _cursorRow = (_cursorRow - move.count).clamp(0, _lines.length - 1);
      case CursorDirection.down:
        _cursorRow = (_cursorRow + move.count).clamp(0, _lines.length - 1);
      case CursorDirection.forward:
        _cursorCol += move.count;
      case CursorDirection.backward:
        _cursorCol = (_cursorCol - move.count).clamp(0, _cursorCol);
    }
  }

  void _erase(EraseCommand command) {
    switch (command.type) {
      case EraseType.display:
        _eraseDisplay(command.param);
      case EraseType.line:
        _eraseLine(command.param);
    }
  }

  void _eraseDisplay(int param) {
    switch (param) {
      case 0: // 游標到末尾
        _eraseLine(0);
        for (var i = _cursorRow + 1; i < _lines.length; i++) {
          _lines[i] = TerminalLine();
        }
      case 1: // 開頭到游標
        for (var i = 0; i < _cursorRow; i++) {
          _lines[i] = TerminalLine();
        }
        _eraseLine(1);
      case 2: // 全部
        clear();
    }
  }

  void _eraseLine(int param) {
    _ensureCursorRow();
    switch (param) {
      case 0: // 游標到行尾 — 簡化為清除整行
        _lines[_cursorRow] = TerminalLine();
      case 1: // 行首到游標
        _lines[_cursorRow] = TerminalLine();
      case 2: // 整行
        _lines[_cursorRow] = TerminalLine();
    }
  }
}
