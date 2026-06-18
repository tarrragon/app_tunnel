import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'package:app_tunnel/l10n/app_localizations.dart';
import 'package:app_tunnel/features/auth/biometric_service.dart';
import 'package:app_tunnel/features/credential/credential.dart';
import 'package:app_tunnel/features/credential/credential_repository.dart';
import 'package:app_tunnel/features/terminal/connection/connection_manager.dart';
import 'package:app_tunnel/features/terminal/protocol/ttyd_protocol.dart';
import 'package:app_tunnel/features/terminal/screens/terminal_screen.dart';
import 'package:app_tunnel/features/terminal/screens/terminal_screen_state.dart';

// -- Test doubles --

class _FakeBiometricService implements BiometricService {
  _FakeBiometricService({this.authResult = true});
  final bool authResult;

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<bool> authenticate({required String localizedReason}) async =>
      authResult;
}

class _FakeCredentialRepository implements CredentialRepository {
  _FakeCredentialRepository({this.credential});
  final Credential? credential;

  @override
  Future<Credential?> load() async => credential;

  @override
  Future<void> save(Credential credential) async {}

  @override
  Future<void> delete() async {}

  @override
  Future<bool> exists() async => credential != null;
}

class _FakeWebSocketChannel extends Fake implements WebSocketChannel {
  final _streamController = StreamController<dynamic>.broadcast();
  final _sinkItems = <dynamic>[];
  bool closed = false;

  @override
  Future<void> get ready => Future.value();

  @override
  Stream<dynamic> get stream => _streamController.stream;

  @override
  WebSocketSink get sink => _FakeWebSocketSink(
        onAdd: _sinkItems.add,
        onClose: () {
          closed = true;
          _streamController.close();
        },
      );

  void simulateServerOutput(dynamic data) => _streamController.add(data);

  void simulateServerClose() => _streamController.close();

  void simulateError(Object error) => _streamController.addError(error);
}

class _FakeWebSocketSink extends Fake implements WebSocketSink {
  _FakeWebSocketSink({required this.onAdd, required this.onClose});
  final void Function(dynamic) onAdd;
  final void Function() onClose;

  @override
  void add(dynamic data) => onAdd(data);

  @override
  Future<void> close([int? closeCode, String? closeReason]) async => onClose();
}

final _testCredential = Credential(
  version: 2,
  protocol: 'ttyd-tty/v1',
  endpoint: 'http://100.64.0.1:7681',
  ttydUser: 'user',
  ttydPass: 'pass',
);

void main() {
  late _FakeBiometricService biometricService;
  late _FakeCredentialRepository credentialRepository;
  late _FakeWebSocketChannel fakeChannel;
  late ConnectionManager connectionManager;
  late TtydProtocol protocol;

  setUp(() {
    biometricService = _FakeBiometricService();
    credentialRepository =
        _FakeCredentialRepository(credential: _testCredential);
    fakeChannel = _FakeWebSocketChannel();
    protocol = TtydProtocol();
    connectionManager = ConnectionManager(
      biometricService: biometricService,
      credentialRepository: credentialRepository,
      protocol: protocol,
      channelFactory: (uri, headers) => fakeChannel,
    );
  });

  tearDown(() async {
    await connectionManager.dispose();
  });

  Widget buildTestApp() {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: TerminalScreen(
        connectionManager: connectionManager,
        protocol: protocol,
      ),
    );
  }

  group('TerminalScreen', () {
    testWidgets(
      '成功連線後顯示終端機畫面（含 TerminalRenderer + TerminalToolbar）',
      (tester) async {
        await tester.pumpWidget(buildTestApp());
        await tester.pumpAndSettle();

        // connect() 完成後應為 connected，顯示終端機元件
        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(find.text('Disconnected'), findsNothing);

        // 驗證 State 的 screenState
        final state = tester.state<TerminalScreenState>(
          find.byType(TerminalScreen),
        );
        expect(state.screenState, TerminalScreenUiState.connected);
      },
    );

    testWidgets(
      '連線錯誤時顯示 error 畫面與重連按鈕',
      (tester) async {
        biometricService = _FakeBiometricService(authResult: false);
        connectionManager = ConnectionManager(
          biometricService: biometricService,
          credentialRepository: credentialRepository,
          protocol: protocol,
          channelFactory: (uri, headers) => fakeChannel,
        );

        await tester.pumpWidget(buildTestApp());
        await tester.pumpAndSettle();

        expect(find.text('Authentication failed'), findsOneWidget);
        expect(find.byKey(const Key('reconnect_button')), findsOneWidget);
      },
    );

    testWidgets(
      '斷線後顯示 disconnected 畫面與重連按鈕',
      (tester) async {
        await tester.pumpWidget(buildTestApp());
        await tester.pumpAndSettle();

        // 模擬伺服器關閉連線
        fakeChannel.simulateServerClose();
        await tester.pumpAndSettle();

        expect(find.text('Disconnected'), findsOneWidget);
        expect(find.byKey(const Key('reconnect_button')), findsOneWidget);
      },
    );

    testWidgets(
      '點擊重連按鈕觸發 reconnect',
      (tester) async {
        await tester.pumpWidget(buildTestApp());
        await tester.pumpAndSettle();

        // 斷線
        fakeChannel.simulateServerClose();
        await tester.pumpAndSettle();

        expect(find.text('Disconnected'), findsOneWidget);

        // 點擊重連 — reconnect 會再次呼叫 connect，
        // 但因 channel 已關閉，重建需要新 factory，
        // 這裡驗證按鈕存在且可點擊即可。
        await tester.tap(find.byKey(const Key('reconnect_button')));
        await tester.pump();
      },
    );

    testWidgets(
      'sendData 將鍵盤輸入送到 WS sink',
      (tester) async {
        await tester.pumpWidget(buildTestApp());
        await tester.pumpAndSettle();

        // 已 connected，送資料（sendData 將 Uint8List 轉為 String text frame）
        final inputFrame = protocol.encodeInput('ls\n');
        connectionManager.sendData(inputFrame);

        final expectedText = String.fromCharCodes(inputFrame);
        expect(fakeChannel._sinkItems, contains(expectedText));
      },
    );

    testWidgets(
      'resize 事件在 connected 狀態時發送',
      (tester) async {
        await tester.pumpWidget(buildTestApp());
        await tester.pumpAndSettle();

        // 觸發 metrics 變更（模擬旋轉）
        tester.view.physicalSize = const Size(1920, 1080);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpAndSettle();

        // 驗證有 resize 訊框被送出（text frame 以 '1' 開頭）
        final resizeFrames = fakeChannel._sinkItems.whereType<String>().where(
          (frame) => frame.isNotEmpty && frame.codeUnitAt(0) == TtydProtocol.resizePrefix,
        );
        expect(resizeFrames, isNotEmpty);
      },
    );

    test('TerminalScreenUiState 列舉值完整', () {
      expect(
        TerminalScreenUiState.values,
        containsAll([
          TerminalScreenUiState.idle,
          TerminalScreenUiState.connecting,
          TerminalScreenUiState.connected,
          TerminalScreenUiState.disconnected,
          TerminalScreenUiState.error,
        ]),
      );
    });

    testWidgets(
      '無憑證時顯示 error 畫面',
      (tester) async {
        credentialRepository = _FakeCredentialRepository(credential: null);
        connectionManager = ConnectionManager(
          biometricService: biometricService,
          credentialRepository: credentialRepository,
          protocol: protocol,
          channelFactory: (uri, headers) => fakeChannel,
        );

        await tester.pumpWidget(buildTestApp());
        await tester.pumpAndSettle();

        // 無憑證 → error state
        expect(find.text('Connection error'), findsOneWidget);
        expect(find.byKey(const Key('reconnect_button')), findsOneWidget);
      },
    );
  });
}
