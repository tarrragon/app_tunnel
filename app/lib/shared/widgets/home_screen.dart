import 'package:flutter/material.dart';

/// Placeholder home screen for initial project scaffold.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('App Tunnel')),
      body: const Center(
        child: Text('App Tunnel - Remote Terminal'),
      ),
    );
  }
}
