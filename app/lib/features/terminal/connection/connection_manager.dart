import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io' as io;
import 'dart:typed_data';

import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'package:app_tunnel/core/constants/terminal_constants.dart';
import 'package:app_tunnel/features/auth/biometric_service.dart';
import 'package:app_tunnel/features/credential/credential.dart';
import 'package:app_tunnel/features/credential/credential_repository.dart';
import 'package:app_tunnel/features/terminal/connection/connection_error.dart';
import 'package:app_tunnel/features/terminal/connection/connection_state.dart';
import 'package:app_tunnel/features/terminal/protocol/terminal_protocol.dart';

/// 需求：[UC-02] 連線管理器
/// 整合 BiometricService + CredentialRepository + TerminalProtocol，
/// 管理 WebSocket 連線的完整生命週期。
/// 約束：連線前必須通過生物辨識；狀態變更透過 Stream 通知。
class ConnectionManager {
  ConnectionManager({
    required BiometricService biometricService,
    required CredentialRepository credentialRepository,
    required TerminalProtocol protocol,
    WebSocketChannelFactory? channelFactory,
    Duration connectTimeout = TerminalConstants.connectTimeout,
  })  : _biometricService = biometricService,
        _credentialRepository = credentialRepository,
        _protocol = protocol,
        _channelFactory = channelFactory ?? _defaultChannelFactory,
        _connectTimeout = connectTimeout;

  final BiometricService _biometricService;
  final CredentialRepository _credentialRepository;
  final TerminalProtocol _protocol;
  final WebSocketChannelFactory _channelFactory;
  final Duration _connectTimeout;

  final _stateController = StreamController<ConnectionState>.broadcast();
  final _outputController = StreamController<dynamic>.broadcast();
  ConnectionState _state = ConnectionState.idle;
  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _channelSubscription;
  ConnectionError? _lastError;

  /// 目前連線狀態。
  ConnectionState get state => _state;

  /// 最近一次連線錯誤（僅在 state == error 時有意義）。
  ConnectionError? get lastError => _lastError;

  /// 狀態變更事件流。
  Stream<ConnectionState> get stateStream => _stateController.stream;

  /// 需求：[UC-02] 伺服器輸出事件流（WS 收到的 raw frame）。
  /// broadcast stream，訂閱者在連線後收到資料。
  Stream<dynamic> get outputStream => _outputController.stream;

  /// 需求：[UC-02] 發送資料到 WS（鍵盤輸入 / resize 訊框）。
  /// ttyd tty 協議期望 text WebSocket frame，非 binary frame。
  void sendData(dynamic data) {
    if (_state != ConnectionState.connected || _channel == null) return;
    if (data is Uint8List) {
      _channel!.sink.add(String.fromCharCodes(data));
    } else {
      _channel!.sink.add(data);
    }
  }

  /// 需求：[UC-02] 主場景 — 建立連線
  /// 流程：生物辨識 -> 載入憑證 -> 建立 WS 連線
  ///
  /// [biometricReason] 為 OS 生物辨識提示文字，由持有 BuildContext 的呼叫端
  /// （TerminalScreen）透過 AppLocalizations 注入（1.2.0-W1-027）。
  Future<void> connect({required String biometricReason}) async {
    if (_state == ConnectionState.connecting ||
        _state == ConnectionState.connected) {
      return;
    }
    _transitionTo(ConnectionState.connecting);

    try {
      developer.log('Step 1: biometric auth...', name: 'ConnectionManager'); // i18n-exempt
      await _authenticateWithBiometrics(biometricReason);
      developer.log('Step 2: loading credential...', name: 'ConnectionManager'); // i18n-exempt
      final credential = await _loadCredential();
      // i18n-exempt
      developer.log('Step 3: connecting WS to ${credential.endpoint}...', name: 'ConnectionManager');
      await _establishWebSocket(credential);
      _transitionTo(ConnectionState.connected);
    } on ConnectionError catch (error) {
      // i18n-exempt
      developer.log('Connect failed: ${error.type} - ${error.message}', name: 'ConnectionManager', error: error.cause);
      _lastError = error;
      _transitionTo(ConnectionState.error);
    }
  }

  /// 需求：[UC-02] 斷開連線
  Future<void> disconnect() async {
    await _closeChannel();
    _transitionTo(ConnectionState.disconnected);
  }

  /// 需求：[UC-02] 重新連線
  /// 先斷開既有連線再重新執行 connect 流程。
  Future<void> reconnect({required String biometricReason}) async {
    await _closeChannel();
    _transitionTo(ConnectionState.idle);
    await connect(biometricReason: biometricReason);
  }

  /// 釋放資源。
  Future<void> dispose() async {
    await _closeChannel();
    await _outputController.close();
    await _stateController.close();
  }

  // -- 私有方法 --

  /// 需求：[SPEC-004 FR-01] 連線前生物辨識驗證
  Future<void> _authenticateWithBiometrics(String localizedReason) async {
    final passed =
        await _biometricService.authenticate(localizedReason: localizedReason);
    if (!passed) {
      throw const ConnectionError(
        type: ConnectionErrorType.authenticationFailed,
        message: 'Biometric authentication failed or cancelled',
      );
    }
  }

  /// 需求：[SPEC-004 FR-02] 載入憑證
  Future<Credential> _loadCredential() async {
    final credential = await _credentialRepository.load();
    if (credential == null) {
      throw const ConnectionError(
        type: ConnectionErrorType.unknown,
        message: 'No credential found; run enrollment first',
      );
    }
    return credential;
  }

  /// 需求：[SPEC-004 FR-03] 建立 WebSocket 連線
  Future<void> _establishWebSocket(Credential credential) async {
    final uri = _parseEndpointUri(credential);
    final headers = _protocol.buildHeaders(
      username: credential.ttydUser,
      password: credential.ttydPass,
    );

    try {
      _channel = _channelFactory(uri, headers);
      // 先訂閱 stream 再等 ready，避免 ready 內部消耗 stream 事件
      _listenForDisconnection();
      await _channel!.ready.timeout(_connectTimeout);
      _sendAuthTokenIfNeeded(credential);
    } on TimeoutException {
      await _closeChannel();
      throw ConnectionError(
        type: ConnectionErrorType.timeout,
        message: 'Connection timed out after ${_connectTimeout.inSeconds}s',
      );
    } on WebSocketChannelException catch (e) {
      await _closeChannel();
      throw ConnectionError(
        type: _classifyWebSocketError(e),
        message: 'WebSocket error: ${e.message}',
        cause: e,
      );
    }
  }

  Stream<dynamic>? _broadcastStream;

  /// 監聽 WS 斷線事件。
  void _listenForDisconnection() {
    _channelSubscription?.cancel();
    _broadcastStream = _channel?.stream.asBroadcastStream();
    _channelSubscription = _broadcastStream?.listen(
      (data) {
        developer.log('WS recv: type=${data.runtimeType}', name: 'WS'); // i18n-exempt
        _outputController.add(data);
      },
      onDone: () {
        if (_state == ConnectionState.connected) {
          _transitionTo(ConnectionState.disconnected);
        }
      },
      onError: (Object error) {
        developer.log(
          'WebSocket stream error',
          name: 'ConnectionManager',
          error: error,
        );
        _lastError = ConnectionError(
          type: ConnectionErrorType.networkOffline,
          message: 'Connection lost: $error',
          cause: error,
        );
        _transitionTo(ConnectionState.error);
      },
    );
  }

  void _sendAuthTokenIfNeeded(Credential credential) {
    final token = base64Encode(
      utf8.encode('${credential.ttydUser}:${credential.ttydPass}'),
    );
    final frame = _protocol.buildAuthTokenFrame(authToken: token);
    if (frame != null) {
      _channel!.sink.add(frame);
    }
  }

  Uri _parseEndpointUri(Credential credential) {
    final hostPort = Uri.parse(credential.endpoint);
    return _protocol.buildUri(
      host: hostPort.host,
      port: hostPort.port,
    );
  }

  ConnectionErrorType _classifyWebSocketError(WebSocketChannelException e) {
    final message = e.message?.toString() ?? '';
    if (message.contains('401')) {
      return ConnectionErrorType.authenticationFailed;
    }
    return ConnectionErrorType.unknown;
  }

  void _transitionTo(ConnectionState newState) {
    if (_state == newState) return;
    developer.log(
      'State: $_state -> $newState',
      name: 'ConnectionManager',
    );
    _state = newState;
    _stateController.add(newState);
  }

  Future<void> _closeChannel() async {
    await _channelSubscription?.cancel();
    _channelSubscription = null;
    // sink.close() 不會拋出；即使已關閉也安全呼叫。
    await _channel?.sink.close();
    _channel = null;
  }

  static WebSocketChannel _defaultChannelFactory(
    Uri uri,
    Map<String, String> headers,
  ) {
    return IOWebSocketChannel.connect(
      uri,
      protocols: ['tty'],
      headers: headers,
    );
  }
}

/// WebSocket channel 工廠函式型別，方便測試注入。
typedef WebSocketChannelFactory = WebSocketChannel Function(
  Uri uri,
  Map<String, String> headers,
);
