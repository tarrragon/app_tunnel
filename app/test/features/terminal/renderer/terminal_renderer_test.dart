import 'dart:async';

import 'package:app_tunnel/core/theme/app_colors.dart';
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
      await tester.pump();
      await tester.pump();

      // TerminalRenderer 使用 RichText + TextSpan 渲染
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is RichText &&
              widget.text.toPlainText().contains('hello world'),
        ),
        findsOneWidget,
      );

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
      await tester.pump();
      await tester.pump();

      for (final line in ['line1', 'line2', 'line3']) {
        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is RichText &&
                widget.text.toPlainText().contains(line),
          ),
          findsOneWidget,
        );
      }

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
      await tester.pump();
      await tester.pump();

      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is RichText &&
              widget.text.toPlainText().contains('red text'),
        ),
        findsOneWidget,
      );

      await controller.close();
    });

    testWidgets('背景色為深色', (tester) async {
      final controller = StreamController<String>();

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: TerminalRenderer(outputStream: controller.stream),
        ),
      ));

      // 驗證 Container 背景色（1.2.0-W1-023：套用 014 重配的 ANSI 預設背景）
      final container = tester.widget<Container>(find.byType(Container));
      expect(container.color, AppColors.kAnsiDefaultBackground);

      await controller.close();
    });

    testWidgets('dispose 不拋出異常', (tester) async {
      final controller = StreamController<String>();

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: TerminalRenderer(outputStream: controller.stream),
        ),
      ));

      // 先關閉 stream 避免 dispose 後仍有 pending async 操作
      await controller.close();

      // 透過替換 widget 觸發 dispose
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: Container()),
      ));
    });
  });
}
