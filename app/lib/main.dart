import 'package:flutter/material.dart';

import 'package:go_router/go_router.dart';

import 'package:app_tunnel/core/router/app_router.dart';
import 'package:app_tunnel/features/credential/credential_repository.dart';
import 'package:app_tunnel/features/credential/secure_storage_credential_repository.dart';

void main() {
  final credentialRepository = SecureStorageCredentialRepository();
  runApp(AppTunnelApp(credentialRepository: credentialRepository));
}

/// Root widget for the app_tunnel application.
class AppTunnelApp extends StatelessWidget {
  AppTunnelApp({required CredentialRepository credentialRepository, super.key})
      : _router = createAppRouter(credentialRepository: credentialRepository);

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
