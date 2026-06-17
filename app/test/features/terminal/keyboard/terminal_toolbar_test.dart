import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app_tunnel/features/terminal/keyboard/terminal_toolbar.dart';

void main() {
  group('TerminalToolbar', () {
    late List<Uint8List> capturedKeys;

    setUp(() {
      capturedKeys = [];
    });

    Widget buildTestWidget() {
      return MaterialApp(
        home: Scaffold(
          body: TerminalToolbar(
            onKeyInput: (data) => capturedKeys.add(data),
          ),
        ),
      );
    }

    testWidgets('Esc button sends 0x1B', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.tap(find.byKey(const Key('toolbar_Esc')));
      await tester.pump();

      expect(capturedKeys, hasLength(1));
      expect(capturedKeys.first, [0x1B]);
    });

    testWidgets('Tab button sends 0x09', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.tap(find.byKey(const Key('toolbar_Tab')));
      await tester.pump();

      expect(capturedKeys, hasLength(1));
      expect(capturedKeys.first, [0x09]);
    });

    testWidgets('arrow left sends ESC [ D', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      final leftArrow = find.text('←');
      await tester.tap(leftArrow);
      await tester.pump();

      expect(capturedKeys, hasLength(1));
      expect(capturedKeys.first, [0x1B, 0x5B, 0x44]);
    });

    testWidgets('arrow up sends ESC [ A', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      final upArrow = find.text('↑');
      await tester.tap(upArrow);
      await tester.pump();

      expect(capturedKeys, hasLength(1));
      expect(capturedKeys.first, [0x1B, 0x5B, 0x41]);
    });

    testWidgets('arrow down sends ESC [ B', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      final downArrow = find.text('↓');
      await tester.tap(downArrow);
      await tester.pump();

      expect(capturedKeys, hasLength(1));
      expect(capturedKeys.first, [0x1B, 0x5B, 0x42]);
    });

    testWidgets('arrow right sends ESC [ C', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      final rightArrow = find.text('→');
      await tester.tap(rightArrow);
      await tester.pump();

      expect(capturedKeys, hasLength(1));
      expect(capturedKeys.first, [0x1B, 0x5B, 0x43]);
    });

    testWidgets('Ctrl toggle then C sends Ctrl+C (0x03)', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      // Tap Ctrl to activate
      await tester.tap(find.byKey(const Key('toolbar_ctrl')));
      await tester.pump();

      // Tap C
      await tester.tap(find.byKey(const Key('toolbar_C')));
      await tester.pump();

      expect(capturedKeys, hasLength(1));
      expect(capturedKeys.first, [0x03]);
    });

    testWidgets('Ctrl toggle then D sends Ctrl+D (0x04)', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      await tester.tap(find.byKey(const Key('toolbar_ctrl')));
      await tester.pump();

      await tester.tap(find.byKey(const Key('toolbar_D')));
      await tester.pump();

      expect(capturedKeys, hasLength(1));
      expect(capturedKeys.first, [0x04]);
    });

    testWidgets('Ctrl toggle then Z sends Ctrl+Z (0x1A)', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      await tester.tap(find.byKey(const Key('toolbar_ctrl')));
      await tester.pump();

      await tester.tap(find.byKey(const Key('toolbar_Z')));
      await tester.pump();

      expect(capturedKeys, hasLength(1));
      expect(capturedKeys.first, [0x1A]);
    });

    testWidgets('Ctrl auto-deactivates after combo key', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      // Activate Ctrl
      await tester.tap(find.byKey(const Key('toolbar_ctrl')));
      await tester.pump();

      // Send Ctrl+C
      await tester.tap(find.byKey(const Key('toolbar_C')));
      await tester.pump();

      // Second tap on C without Ctrl should not produce output
      await tester.tap(find.byKey(const Key('toolbar_C')));
      await tester.pump();

      expect(capturedKeys, hasLength(1));
      expect(capturedKeys.first, [0x03]);
    });

    testWidgets('C/D/Z without Ctrl does not send', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      await tester.tap(find.byKey(const Key('toolbar_C')));
      await tester.tap(find.byKey(const Key('toolbar_D')));
      await tester.tap(find.byKey(const Key('toolbar_Z')));
      await tester.pump();

      expect(capturedKeys, isEmpty);
    });

    testWidgets('Ctrl toggle twice deactivates', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      await tester.tap(find.byKey(const Key('toolbar_ctrl')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('toolbar_ctrl')));
      await tester.pump();

      // Now C should not send
      await tester.tap(find.byKey(const Key('toolbar_C')));
      await tester.pump();

      expect(capturedKeys, isEmpty);
    });
  });
}
