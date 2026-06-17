import 'package:flutter/material.dart';
import 'package:app_tunnel/core/router/app_router.dart';

void main() {
  runApp(const AppTunnelApp());
}

/// Root widget for the app_tunnel application.
class AppTunnelApp extends StatelessWidget {
  const AppTunnelApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'App Tunnel',
      theme: ThemeData(
        colorSchemeSeed: Colors.blue,
        useMaterial3: true,
      ),
      routerConfig: appRouter,
    );
  }
}
