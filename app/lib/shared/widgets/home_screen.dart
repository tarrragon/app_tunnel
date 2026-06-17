import 'package:flutter/material.dart';

import 'package:go_router/go_router.dart';

/// Placeholder home screen for initial project scaffold.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('App Tunnel')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('App Tunnel - Remote Terminal'),
            const SizedBox(height: 24),
            FilledButton.icon(
              key: const Key('connect_terminal_button'),
              onPressed: () => context.go('/terminal'),
              icon: const Icon(Icons.terminal),
              label: const Text('Connect Terminal'),
            ),
          ],
        ),
      ),
    );
  }
}
