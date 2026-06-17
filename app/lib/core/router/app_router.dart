import 'package:go_router/go_router.dart';

import 'package:app_tunnel/features/credential/credential_repository.dart';
import 'package:app_tunnel/features/enrollment/screens/enrollment_screen.dart';
import 'package:app_tunnel/features/terminal/connection/connection_manager.dart';
import 'package:app_tunnel/features/terminal/protocol/terminal_protocol.dart';
import 'package:app_tunnel/features/terminal/screens/terminal_screen.dart';
import 'package:app_tunnel/shared/widgets/home_screen.dart';

/// Application router configuration.
///
/// Requirement: [UC-01] enrollment route, [UC-02] terminal route.
GoRouter createAppRouter({
  required CredentialRepository credentialRepository,
  required ConnectionManager connectionManager,
  required TerminalProtocol protocol,
}) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/enrollment',
        builder: (context, state) => EnrollmentScreen(
          credentialRepository: credentialRepository,
        ),
      ),
      GoRoute(
        path: '/terminal',
        builder: (context, state) => TerminalScreen(
          connectionManager: connectionManager,
          protocol: protocol,
        ),
      ),
    ],
  );
}
