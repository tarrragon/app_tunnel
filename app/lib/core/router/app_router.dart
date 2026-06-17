import 'package:go_router/go_router.dart';
import 'package:app_tunnel/shared/widgets/home_screen.dart';

/// Application router configuration.
final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const HomeScreen(),
    ),
  ],
);
