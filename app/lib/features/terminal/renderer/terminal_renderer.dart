import 'dart:async';

import 'package:app_tunnel/core/constants/terminal_constants.dart';
import 'package:app_tunnel/core/theme/app_colors.dart';
import 'package:app_tunnel/features/terminal/renderer/ansi_parser.dart';
import 'package:app_tunnel/features/terminal/renderer/terminal_buffer.dart';
import 'package:flutter/material.dart';

/// 需求：[SPEC-004 FR-04] 終端機文字渲染 Widget
/// 接收終端機輸出 Stream，解析 ANSI escape 並渲染為帶色彩的文字。
/// 約束：monospace 字型、黑色背景、自動捲動到底部。
class TerminalRenderer extends StatefulWidget {
  const TerminalRenderer({
    required this.outputStream,
    this.maxBufferLines = 1000,
    this.fontSize = TerminalConstants.fontSize,
    this.defaultForeground = _defaultForegroundColor,
    super.key,
  });

  final Stream<String> outputStream;
  final int maxBufferLines;
  final double fontSize;
  final Color defaultForeground;

  // 需求：[1.2.0-W1-023] 套用 014 重配：ANSI 預設前景/背景改引 AppColors。
  static const Color _defaultForegroundColor = AppColors.kAnsiDefaultForeground;
  static const Color _backgroundColor = AppColors.kAnsiDefaultBackground;

  @override
  State<TerminalRenderer> createState() => _TerminalRendererState();
}

class _TerminalRendererState extends State<TerminalRenderer> {
  late final AnsiParser _parser;
  late final TerminalBuffer _buffer;
  late final ScrollController _scrollController;
  StreamSubscription<String>? _subscription;

  @override
  void initState() {
    super.initState();
    _parser = AnsiParser();
    _buffer = TerminalBuffer(maxLines: widget.maxBufferLines);
    _scrollController = ScrollController();
    _subscribeToOutput();
  }

  @override
  void didUpdateWidget(TerminalRenderer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.outputStream != widget.outputStream) {
      _subscription?.cancel();
      _subscribeToOutput();
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _subscribeToOutput() {
    _subscription = widget.outputStream.listen(_onData);
  }

  void _onData(String data) {
    final tokens = _parser.parse(data);
    setState(() {
      _buffer.writeTokens(tokens);
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(
          _scrollController.position.maxScrollExtent,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: TerminalRenderer._backgroundColor,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(8),
        itemCount: _buffer.lineCount,
        itemBuilder: (context, index) =>
            _buildLine(_buffer.lines[index]),
      ),
    );
  }

  Widget _buildLine(TerminalLine line) {
    if (line.segments.isEmpty) {
      return SizedBox(height: widget.fontSize * 1.2);
    }
    return RichText(
      text: TextSpan(
        children: line.segments
            .map(_buildTextSpan)
            .toList(),
      ),
    );
  }

  TextSpan _buildTextSpan(StyledSegment segment) {
    return TextSpan(
      text: segment.text,
      style: TextStyle(
        fontFamily: 'monospace',
        fontSize: widget.fontSize,
        color: segment.foreground ?? widget.defaultForeground,
        backgroundColor: segment.background,
        fontWeight: segment.isBold ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }
}
