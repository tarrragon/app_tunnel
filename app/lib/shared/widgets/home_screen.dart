import 'package:flutter/material.dart';

import 'package:go_router/go_router.dart';

import 'package:app_tunnel/l10n/app_localizations.dart';

/// Placeholder home screen for initial project scaffold.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.homeAppBarTitle)),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.homeHeadline),
            const SizedBox(height: 24),
            FilledButton.icon(
              key: const Key('connect_terminal_button'),
              onPressed: () => context.go('/terminal'),
              icon: const Icon(Icons.terminal),
              label: Text(l10n.homeConnectButton),
            ),
          ],
        ),
      ),
    );
  }
}
