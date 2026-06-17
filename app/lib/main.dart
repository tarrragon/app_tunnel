import 'package:flutter/material.dart';

import 'package:go_router/go_router.dart';

import 'package:app_tunnel/core/router/app_router.dart';
import 'package:app_tunnel/features/auth/biometric_service.dart';
import 'package:app_tunnel/features/auth/local_auth_biometric_service.dart';
import 'package:app_tunnel/features/credential/credential_repository.dart';
import 'package:app_tunnel/features/credential/secure_storage_credential_repository.dart';
import 'package:app_tunnel/features/terminal/connection/connection_manager.dart';
import 'package:app_tunnel/features/terminal/protocol/terminal_protocol.dart';
import 'package:app_tunnel/features/terminal/protocol/ttyd_protocol.dart';

void main() {
  final credentialRepository = SecureStorageCredentialRepository();
  final BiometricService biometricService = LocalAuthBiometricService();
  final TerminalProtocol protocol = TtydProtocol();
  final connectionManager = ConnectionManager(
    biometricService: biometricService,
    credentialRepository: credentialRepository,
    protocol: protocol,
  );

  runApp(AppTunnelApp(
    credentialRepository: credentialRepository,
    connectionManager: connectionManager,
    protocol: protocol,
  ));
}

/// Root widget for the app_tunnel application.
class AppTunnelApp extends StatelessWidget {
  AppTunnelApp({
    required CredentialRepository credentialRepository,
    required ConnectionManager connectionManager,
    required TerminalProtocol protocol,
    super.key,
  }) : _router = createAppRouter(
          credentialRepository: credentialRepository,
          connectionManager: connectionManager,
          protocol: protocol,
        );

  final GoRouter _router;

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'App Tunnel',
      theme: ThemeData(
        colorSchemeSeed: Colors.blue,
        useMaterial3: true,
      ),
      routerConfig: _router,
    );
  }
}
