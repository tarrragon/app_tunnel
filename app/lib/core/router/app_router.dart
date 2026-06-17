import 'package:go_router/go_router.dart';

import 'package:app_tunnel/features/credential/credential_repository.dart';
import 'package:app_tunnel/features/enrollment/screens/enrollment_screen.dart';
import 'package:app_tunnel/shared/widgets/home_screen.dart';

/// Application router configuration.
///
/// Requirement: [UC-01] enrollment route for device pairing.
GoRouter createAppRouter({required CredentialRepository credentialRepository}) {
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
    ],
  );
}
