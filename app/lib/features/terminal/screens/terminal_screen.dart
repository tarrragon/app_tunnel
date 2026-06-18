import 'dart:async';
import 'dart:developer' as developer;
import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'package:app_tunnel/core/constants/terminal_constants.dart';
import 'package:app_tunnel/core/constants/ui_constants.dart';
import 'package:app_tunnel/l10n/app_localizations.dart';
import 'package:app_tunnel/features/terminal/connection/connection_error.dart';
import 'package:app_tunnel/features/terminal/connection/connection_manager.dart';
import 'package:app_tunnel/features/terminal/connection/connection_state.dart'
    as cs;
import 'package:app_tunnel/features/terminal/keyboard/terminal_toolbar.dart';
import 'package:app_tunnel/features/terminal/protocol/terminal_protocol.dart';
import 'package:app_tunnel/features/terminal/renderer/terminal_renderer.dart';
import 'package:app_tunnel/features/terminal/screens/terminal_screen_state.dart';
import 'package:app_tunnel/shared/widgets/primary_action_button.dart';

/// 需求：[UC-02] 終端機主畫面
/// 整合 ConnectionManager + TerminalRenderer + TerminalToolbar，
/// 管理 Face ID -> 讀憑證 -> 連線 -> 終端機全流程。
/// 約束：連線狀態變更驅動 UI；resize 事件自動發送。
class TerminalScreen extends StatefulWidget {
  const TerminalScreen({
    required this.connectionManager,
    required this.protocol,
    super.key,
  });

  final ConnectionManager connectionManager;
  final TerminalProtocol protocol;

  @override
  State<TerminalScreen> createState() => TerminalScreenState();
}

/// 需求：[UC-02] TerminalScreen 的 State
/// 可見類別供測試存取 [screenState]。
class TerminalScreenState extends State<TerminalScreen>
    with WidgetsBindingObserver {
  StreamSubscription<cs.ConnectionState>? _stateSubscription;
  final _decodedOutputController = StreamController<String>.broadcast();
  StreamSubscription<dynamic>? _outputSubscription;
  TerminalScreenUiState _screenState = TerminalScreenUiState.idle;

  /// 目前 UI 狀態（供測試驗證）。
  TerminalScreenUiState get screenState => _screenState;

  /// 上一次通知的終端機尺寸，避免重複發送相同 resize。
  Size? _lastReportedSize;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _subscribeToConnectionState();
    // 延後至首幀後啟動連線：_startConnection 需讀取 AppLocalizations，
    // 而 inherited widget 查詢不可在 initState 完成前執行（1.2.0-W1-027）。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _startConnection();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stateSubscription?.cancel();
    _outputSubscription?.cancel();
    _decodedOutputController.close();
    super.dispose();
  }

  /// 需求：[UC-02] 螢幕旋轉 / 鍵盤彈出時自動發送 resize
  @override
  void didChangeMetrics() {
    _sendResizeIfNeeded();
  }

  // -- 連線狀態管理 --

  void _subscribeToConnectionState() {
    _stateSubscription =
        widget.connectionManager.stateStream.listen(_onConnectionStateChanged);
  }

  void _onConnectionStateChanged(cs.ConnectionState connectionState) {
    switch (connectionState) {
      case cs.ConnectionState.idle:
        _updateScreenState(TerminalScreenUiState.idle);
      case cs.ConnectionState.connecting:
        _updateScreenState(TerminalScreenUiState.connecting);
      case cs.ConnectionState.connected:
        _startListeningOutput();
        _updateScreenState(TerminalScreenUiState.connected);
      case cs.ConnectionState.disconnected:
        _stopListeningOutput();
        _updateScreenState(TerminalScreenUiState.disconnected);
      case cs.ConnectionState.error:
        _stopListeningOutput();
        _updateScreenState(TerminalScreenUiState.error);
    }
  }

  void _updateScreenState(TerminalScreenUiState newState) {
    if (_screenState == newState) return;
    developer.log(
      'UI state: $_screenState -> $newState',
      name: 'TerminalScreen',
    );
    setState(() {
      _screenState = newState;
    });
  }

  // -- 輸出 stream 管理 --

  void _startListeningOutput() {
    _outputSubscription?.cancel();
    _outputSubscription =
        widget.connectionManager.outputStream.listen((rawFrame) {
      final decoded = widget.protocol.decodeOutput(rawFrame);
      if (decoded != null) {
        _decodedOutputController.add(decoded);
      }
    });
  }

  void _stopListeningOutput() {
    _outputSubscription?.cancel();
    _outputSubscription = null;
  }

  // -- 連線操作 --

  /// 需求：[UC-02] 啟動連線流程（Face ID -> 憑證 -> WS）
  /// 由本畫面持有的 BuildContext 取得本地化生物辨識提示文字後注入。
  Future<void> _startConnection() async {
    final biometricReason = AppLocalizations.of(context).authBiometricReason;
    await widget.connectionManager.connect(biometricReason: biometricReason);
  }

  /// 需求：[UC-02] 重新連線
  Future<void> _reconnect() async {
    final biometricReason = AppLocalizations.of(context).authBiometricReason;
    await widget.connectionManager.reconnect(biometricReason: biometricReason);
  }

  // -- resize --

  void _sendResizeIfNeeded() {
    if (_screenState != TerminalScreenUiState.connected) return;
    final mediaQuery = MediaQuery.maybeOf(context);
    if (mediaQuery == null) return;

    final size = mediaQuery.size;
    if (_lastReportedSize == size) return;
    _lastReportedSize = size;

    final columns = _estimateColumns(size.width);
    final rows = _estimateRows(size.height);
    _sendResize(columns: columns, rows: rows);
  }

  /// 以 monospace 字元寬估算欄數（扣除水平 padding）。
  int _estimateColumns(double width) =>
      ((width - TerminalConstants.horizontalPadding) /
              TerminalConstants.charWidth)
          .floor()
          .clamp(TerminalConstants.minColumns, TerminalConstants.maxColumns);

  /// 以行高估算列數（扣除 toolbar 高度）。
  int _estimateRows(double height) =>
      ((height - TerminalConstants.toolbarHeight) /
              TerminalConstants.lineHeight)
          .floor()
          .clamp(TerminalConstants.minRows, TerminalConstants.maxRows);

  void _sendResize({required int columns, required int rows}) {
    developer.log(
      'Sending resize: ${columns}x$rows',
      name: 'TerminalScreen',
    );
    final frame = widget.protocol.encodeResize(
      columns: columns,
      rows: rows,
    );
    widget.connectionManager.sendData(frame);
  }

  // -- 鍵盤輸入 --

  void _onKeyInput(Uint8List data) {
    widget.connectionManager.sendData(data);
  }

  // -- Build --

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E1E),
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    switch (_screenState) {
      case TerminalScreenUiState.idle:
      case TerminalScreenUiState.connecting:
        return _buildConnectingView();
      case TerminalScreenUiState.connected:
        return _buildTerminalView();
      case TerminalScreenUiState.disconnected:
        return _buildDisconnectedView();
      case TerminalScreenUiState.error:
        return _buildErrorView();
    }
  }

  Widget _buildConnectingView() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: Colors.white),
          const SizedBox(height: UiConstants.itemSpacing),
          Text(
            AppLocalizations.of(context).terminalConnecting,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: UiConstants.statusFontSize,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTerminalView() {
    return Column(
      children: [
        Expanded(
          child: TerminalRenderer(
            outputStream: _decodedOutputController.stream,
          ),
        ),
        TerminalToolbar(onKeyInput: _onKeyInput),
      ],
    );
  }

  Widget _buildDisconnectedView() {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.link_off,
            color: Colors.white54,
            size: UiConstants.statusIconSize,
          ),
          const SizedBox(height: UiConstants.itemSpacing),
          Text(
            l10n.terminalDisconnected,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: UiConstants.statusFontSize,
            ),
          ),
          const SizedBox(height: UiConstants.sectionSpacing),
          PrimaryActionButton(
            key: const Key('reconnect_button'),
            onPressed: _reconnect,
            icon: Icons.refresh,
            label: l10n.terminalReconnect,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    final l10n = AppLocalizations.of(context);
    final error = widget.connectionManager.lastError;
    final message = _errorDisplayMessage(l10n, error);

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.error_outline,
            color: Colors.redAccent,
            size: UiConstants.statusIconSize,
          ),
          const SizedBox(height: UiConstants.itemSpacing),
          Text(
            message,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: UiConstants.statusFontSize,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: UiConstants.sectionSpacing),
          PrimaryActionButton(
            key: const Key('reconnect_button'),
            onPressed: _reconnect,
            icon: Icons.refresh,
            label: l10n.terminalReconnect,
          ),
        ],
      ),
    );
  }

  /// 需求：[UC-02] 依錯誤類型顯示使用者可理解的訊息
  String _errorDisplayMessage(AppLocalizations l10n, ConnectionError? error) {
    if (error == null) return l10n.terminalErrorGeneric;
    switch (error.type) {
      case ConnectionErrorType.authenticationFailed:
        return l10n.terminalErrorAuth;
      case ConnectionErrorType.timeout:
        return l10n.terminalErrorTimeout;
      case ConnectionErrorType.networkOffline:
        return l10n.terminalErrorNetwork;
      case ConnectionErrorType.unknown:
        return l10n.terminalErrorGeneric;
    }
  }
}
