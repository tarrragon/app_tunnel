import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'package:app_tunnel/features/terminal/keyboard/terminal_key_codes.dart';

/// 需求：[SPEC-004 FR-04] 終端機特殊按鍵工具列
/// 提供 Esc / Tab / Ctrl（toggle）/ 方向鍵，改善手機操作 CLI 的體驗。
/// [onKeyInput] 回傳按鍵對應的 byte 資料（不含 ttyd '0' prefix）。
class TerminalToolbar extends StatefulWidget {
  const TerminalToolbar({required this.onKeyInput, super.key});

  /// 按鍵觸發時回傳對應 byte 資料。
  final ValueChanged<Uint8List> onKeyInput;

  @override
  State<TerminalToolbar> createState() => _TerminalToolbarState();
}

class _TerminalToolbarState extends State<TerminalToolbar> {
  bool _isCtrlActive = false;

  void _sendKey(Uint8List data) {
    widget.onKeyInput(data);
  }

  /// 需求：[SPEC-004 FR-04] Ctrl toggle 模式
  /// Ctrl 按下後高亮，下一個按鍵自動加 Ctrl 修飾後取消高亮。
  void _toggleCtrl() {
    setState(() {
      _isCtrlActive = !_isCtrlActive;
    });
  }

  /// 處理一般按鍵：若 Ctrl 啟用，將字母轉為 Ctrl 組合鍵後自動取消。
  void _handleKeyWithCtrlModifier(String letter) {
    if (_isCtrlActive) {
      _sendKey(TerminalKeyCodes.controlKey(letter));
      setState(() {
        _isCtrlActive = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: Row(
        children: [
          _buildKeyButton('Esc', () => _sendKey(TerminalKeyCodes.escape)),
          _buildKeyButton('Tab', () => _sendKey(TerminalKeyCodes.tab)),
          _buildCtrlButton(),
          const Spacer(),
          _buildKeyButton('C', () => _handleCtrlShortcutOrLetter('C')),
          _buildKeyButton('D', () => _handleCtrlShortcutOrLetter('D')),
          _buildKeyButton('Z', () => _handleCtrlShortcutOrLetter('Z')),
          const Spacer(),
          _buildArrowButtons(),
        ],
      ),
    );
  }

  void _handleCtrlShortcutOrLetter(String letter) {
    if (_isCtrlActive) {
      _handleKeyWithCtrlModifier(letter);
    }
    // 非 Ctrl 模式下，快捷字母鍵不產出（由軟鍵盤處理一般輸入）。
  }

  Widget _buildCtrlButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Material(
        color: _isCtrlActive
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(4),
        child: InkWell(
          key: const Key('toolbar_ctrl'),
          onTap: _toggleCtrl,
          borderRadius: BorderRadius.circular(4),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Text(
              'Ctrl',
              style: TextStyle(
                color: _isCtrlActive
                    ? Theme.of(context).colorScheme.onPrimary
                    : Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildKeyButton(String label, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: InkWell(
        key: Key('toolbar_$label'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Text(label),
        ),
      ),
    );
  }

  Widget _buildArrowButtons() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildKeyButton(
          '←',
          () => _sendKey(TerminalKeyCodes.arrowLeft),
        ),
        _buildKeyButton(
          '↓',
          () => _sendKey(TerminalKeyCodes.arrowDown),
        ),
        _buildKeyButton(
          '↑',
          () => _sendKey(TerminalKeyCodes.arrowUp),
        ),
        _buildKeyButton(
          '→',
          () => _sendKey(TerminalKeyCodes.arrowRight),
        ),
      ],
    );
  }
}
