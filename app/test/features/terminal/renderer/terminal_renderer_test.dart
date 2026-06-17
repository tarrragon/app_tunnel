import 'dart:async';

import 'package:app_tunnel/features/terminal/renderer/terminal_renderer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TerminalRenderer Widget', () {
    testWidgets('渲染純文字輸出', (tester) async {
      final controller = StreamController<String>();

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: TerminalRenderer(outputStream: controller.stream),
        ),
      ));

      controller.add('hello world');
      await tester.pumpAndSettle();

      expect(find.text('hello world'), findsOneWidget);

      await controller.close();
    });

    testWidgets('渲染多行輸出', (tester) async {
      final controller = StreamController<String>();

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: TerminalRenderer(outputStream: controller.stream),
        ),
      ));

      controller.add('line1\nline2\nline3');
      await tester.pumpAndSettle();

      expect(find.text('line1'), findsOneWidget);
      expect(find.text('line2'), findsOneWidget);
      expect(find.text('line3'), findsOneWidget);

      await controller.close();
    });

    testWidgets('渲染帶 ANSI 色彩的文字（色彩不影響文字內容）', (tester) async {
      final controller = StreamController<String>();

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: TerminalRenderer(outputStream: controller.stream),
        ),
      ));

      controller.add('\x1B[31mred text\x1B[0m');
      await tester.pumpAndSettle();

      expect(find.text('red text'), findsOneWidget);

      await controller.close();
    });

    testWidgets('背景色為深色', (tester) async {
      final controller = StreamController<String>();

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: TerminalRenderer(outputStream: controller.stream),
        ),
      ));

      // 驗證 Container 背景色
      final container = tester.widget<Container>(find.byType(Container));
      expect(container.color, const Color(0xFF1E1E1E));

      await controller.close();
    });

    testWidgets('dispose 不拋出異常', (tester) async {
      final controller = StreamController<String>();

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: TerminalRenderer(outputStream: controller.stream),
        ),
      ));

      // 透過替換 widget 觸發 dispose
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: Container()),
      ));

      await controller.close();
    });
  });
}
