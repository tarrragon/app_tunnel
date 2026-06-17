import 'dart:typed_data';

/// 需求：[SPEC-004 FR-04] 終端機特殊按鍵的 byte 編碼對應表
/// 所有按鍵資料不含 ttyd '0' prefix（由 caller 透過 TtydProtocol.encodeInput 處理）。
class TerminalKeyCodes {
  TerminalKeyCodes._();

  /// Esc 鍵 → 0x1B
  static Uint8List get escape => Uint8List.fromList([0x1B]);

  /// Tab 鍵 → 0x09
  static Uint8List get tab => Uint8List.fromList([0x09]);

  /// 方向鍵 Up → ESC [ A
  static Uint8List get arrowUp => Uint8List.fromList([0x1B, 0x5B, 0x41]);

  /// 方向鍵 Down → ESC [ B
  static Uint8List get arrowDown => Uint8List.fromList([0x1B, 0x5B, 0x42]);

  /// 方向鍵 Right → ESC [ C
  static Uint8List get arrowRight => Uint8List.fromList([0x1B, 0x5B, 0x43]);

  /// 方向鍵 Left → ESC [ D
  static Uint8List get arrowLeft => Uint8List.fromList([0x1B, 0x5B, 0x44]);

  /// 需求：[SPEC-004 FR-04] Ctrl 組合鍵編碼
  /// Ctrl+字母 = 字母的 ASCII 值 - 0x40（大寫基準）
  /// 例：Ctrl+C = 0x43 - 0x40 = 0x03
  static Uint8List controlKey(String letter) {
    if (letter.isEmpty) {
      throw ArgumentError.value(letter, 'letter', 'must not be empty');
    }
    final codeUnit = letter.toUpperCase().codeUnitAt(0);
    if (codeUnit < 0x41 || codeUnit > 0x5A) {
      throw ArgumentError.value(letter, 'letter', 'must be A-Z');
    }
    return Uint8List.fromList([codeUnit - 0x40]);
  }
}
