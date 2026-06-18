import 'dart:async';
import 'dart:developer' as developer;
import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'package:go_router/go_router.dart';

import 'package:app_tunnel/core/constants/terminal_constants.dart';
import 'package:app_tunnel/core/constants/ui_constants.dart';
import 'package:app_tunnel/core/theme/app_colors.dart';
import 'package:app_tunnel/core/theme/app_spacing.dart';
import 'package:app_tunnel/core/theme/app_typography.dart';
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
  final _decodedOutputController = StreamController<String>();
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
    _inputFocusNode.dispose();
    _inputController.dispose();
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
      // i18n-exempt: debug logging for output pipeline
      developer.log('rawFrame type=${rawFrame.runtimeType}', name: 'Output');
      final decoded = widget.protocol.decodeOutput(rawFrame);
      // i18n-exempt
      developer.log('decoded=${decoded != null ? "${decoded.length}chars" : "null"}', name: 'Output');
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

  void _onTextInput(String value) {
    // No-op: input is sent on submit, not per-character
  }

  void _submitInput(String value) {
    if (value.isEmpty) return;
    // i18n-exempt
    developer.log('submitInput: "$value"', name: 'TerminalScreen');
    _onKeyInput(widget.protocol.encodeInput('$value\n'));
    _inputController.clear();
    _inputFocusNode.requestFocus();
  }

  // -- Build --

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.kAnsiDefaultBackground,
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
          const CircularProgressIndicator(color: AppColors.kColorInk),
          const SizedBox(height: UiConstants.itemSpacing),
          Text(
            AppLocalizations.of(context).terminalConnecting,
            style: const TextStyle(
              color: AppColors.kColorInkMuted,
              fontSize: UiConstants.statusFontSize,
            ),
          ),
          const SizedBox(height: UiConstants.sectionSpacing),
          _buildBackButton(context),
        ],
      ),
    );
  }

  final _inputFocusNode = FocusNode();
  final _inputController = TextEditingController();

  Widget _buildTerminalView() {
    return Column(
      children: [
        _buildStatusBar(),
        Expanded(
          child: TerminalRenderer(
            outputStream: _decodedOutputController.stream,
          ),
        ),
        Container(
          color: AppColors.kColorSurface,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.kSpaceSm,
            vertical: AppSpacing.kSpaceXs,
          ),
          child: TextField(
            focusNode: _inputFocusNode,
            controller: _inputController,
            autofocus: true,
            keyboardType: TextInputType.visiblePassword,
            enableSuggestions: false,
            autocorrect: false,
            enableIMEPersonalizedLearning: false,
            onChanged: _onTextInput,
            onSubmitted: _submitInput,
            textInputAction: TextInputAction.send,
            style: const TextStyle(
              color: AppColors.kColorInk,
              fontSize: AppTypography.kFontBodySize,
              fontFamily: 'monospace', // i18n-exempt
            ),
            cursorColor: AppColors.kColorPrimary,
            decoration: InputDecoration(
              hintText: 'Type here...', // i18n-exempt
              hintStyle: const TextStyle(color: AppColors.kColorInkFaint),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSpacing.kSpaceXs),
                borderSide: const BorderSide(color: AppColors.kColorBorder),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.kSpaceSm,
                vertical: AppSpacing.kSpaceXs,
              ),
              isDense: true,
            ),
          ),
        ),
        TerminalToolbar(onKeyInput: _onKeyInput),
      ],
    );
  }

  /// 需求：[UC-02][1.2.0-W1-025] 終端機畫面頂部狀態列（外框/狀態列）。
  /// 以 surface token 作第二 neutral 層、底部 token 邊框與終端輸出區分隔，
  /// 顯示終端標題與連線狀態語意色點，保留下方輸出區擬真渲染不動。
  Widget _buildStatusBar() {
    final l10n = AppLocalizations.of(context);
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.kColorSurface,
        border: Border(
          bottom: BorderSide(color: AppColors.kColorBorder),
        ),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.kSpaceMd,
        vertical: AppSpacing.kSpaceSm,
      ),
      child: Row(
        children: [
          const _StatusDot(color: AppColors.kColorStatusConnected),
          const SizedBox(width: AppSpacing.kSpaceSm),
          Text(
            l10n.terminalTitle,
            style: const TextStyle(
              color: AppColors.kColorInk,
              fontSize: AppTypography.kFontLabelSize,
              fontWeight: AppTypography.kFontTitleWeight,
            ),
          ),
          const Spacer(),
          Text(
            l10n.terminalStatusConnected,
            style: const TextStyle(
              color: AppColors.kColorInkMuted,
              fontSize: AppTypography.kFontLabelSize,
            ),
          ),
        ],
      ),
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
            color: AppColors.kColorInkFaint,
            size: UiConstants.statusIconSize,
          ),
          const SizedBox(height: UiConstants.itemSpacing),
          Text(
            l10n.terminalDisconnected,
            style: const TextStyle(
              color: AppColors.kColorInkMuted,
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
          const SizedBox(height: UiConstants.itemSpacing),
          _buildBackButton(context),
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
            color: AppColors.kColorStatusError,
            size: UiConstants.statusIconSize,
          ),
          const SizedBox(height: UiConstants.itemSpacing),
          Text(
            message,
            style: const TextStyle(
              color: AppColors.kColorInkMuted,
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
          const SizedBox(height: UiConstants.itemSpacing),
          _buildBackButton(context),
        ],
      ),
    );
  }

  Widget _buildBackButton(BuildContext context) {
    return TextButton.icon(
      onPressed: () => context.go('/'),
      icon: const Icon(Icons.arrow_back, color: AppColors.kColorInkMuted),
      label: Text(
        'Back', // i18n-exempt
        style: const TextStyle(color: AppColors.kColorInkMuted),
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

/// 狀態列的連線狀態指示點（語意色圓點）。
class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: AppSpacing.kSpaceSm,
      height: AppSpacing.kSpaceSm,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
}
