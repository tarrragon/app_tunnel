import 'package:flutter_test/flutter_test.dart';

import 'package:app_tunnel/features/terminal/keyboard/terminal_key_codes.dart';

void main() {
  group('TerminalKeyCodes', () {
    test('escape returns 0x1B', () {
      expect(TerminalKeyCodes.escape, [0x1B]);
    });

    test('tab returns 0x09', () {
      expect(TerminalKeyCodes.tab, [0x09]);
    });

    test('arrowUp returns ESC [ A', () {
      expect(TerminalKeyCodes.arrowUp, [0x1B, 0x5B, 0x41]);
    });

    test('arrowDown returns ESC [ B', () {
      expect(TerminalKeyCodes.arrowDown, [0x1B, 0x5B, 0x42]);
    });

    test('arrowRight returns ESC [ C', () {
      expect(TerminalKeyCodes.arrowRight, [0x1B, 0x5B, 0x43]);
    });

    test('arrowLeft returns ESC [ D', () {
      expect(TerminalKeyCodes.arrowLeft, [0x1B, 0x5B, 0x44]);
    });

    group('controlKey', () {
      test('Ctrl+C returns 0x03', () {
        expect(TerminalKeyCodes.controlKey('C'), [0x03]);
      });

      test('Ctrl+D returns 0x04', () {
        expect(TerminalKeyCodes.controlKey('D'), [0x04]);
      });

      test('Ctrl+Z returns 0x1A', () {
        expect(TerminalKeyCodes.controlKey('Z'), [0x1A]);
      });

      test('Ctrl+A returns 0x01', () {
        expect(TerminalKeyCodes.controlKey('A'), [0x01]);
      });

      test('accepts lowercase letter', () {
        expect(TerminalKeyCodes.controlKey('c'), [0x03]);
      });

      test('throws on empty string', () {
        expect(
          () => TerminalKeyCodes.controlKey(''),
          throwsArgumentError,
        );
      });

      test('throws on non-letter', () {
        expect(
          () => TerminalKeyCodes.controlKey('1'),
          throwsArgumentError,
        );
      });
    });
  });
}
