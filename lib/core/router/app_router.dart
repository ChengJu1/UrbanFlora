import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/auth_gate.dart';
import '../../features/auth/sign_in_screen.dart';
import '../../features/capture/capture_screen.dart';
import '../../features/codex/codex_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/identification/identification_screen.dart';
import '../../features/identification/identification_args.dart';
import '../../features/map/map_screen.dart';
import '../../features/observation/observation_detail_screen.dart';
import '../../features/onboarding/onboarding_screen.dart';
import '../../features/shell/home_shell.dart';
import '../../features/splash/splash_screen.dart';
import '../models/observation.dart';

/// All route paths in one place so screens never hard-code strings.
class AppRoutes {
  const AppRoutes._();
  static const splash = '/';
  static const onboarding = '/onboarding';
  static const signIn = '/sign-in';
  static const home = '/home';
  static const map = '/map';
  static const codex = '/codex';
  static const capture = '/capture';
  static const identify = '/identify';
  static const observation = '/observation';
}

final _shellNavigatorKey = GlobalKey<NavigatorState>();

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: AppRoutes.splash,
    debugLogDiagnostics: false,
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (_, __) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (_, __) => const OnboardingScreen(),
      ),
      GoRoute(
        path: AppRoutes.signIn,
        builder: (_, __) => const SignInScreen(),
      ),
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (_, __, child) => AuthGate(child: child),
        routes: [
          StatefulShellRoute.indexedStack(
            builder: (_, __, navigationShell) =>
                HomeShell(navigationShell: navigationShell),
            branches: [
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: AppRoutes.home,
                    builder: (_, __) => const HomeScreen(),
                  ),
                ],
              ),
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: AppRoutes.map,
                    builder: (_, __) => const MapScreen(),
                  ),
                ],
              ),
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: AppRoutes.codex,
                    builder: (_, __) => const CodexScreen(),
                  ),
                ],
              ),
            ],
          ),
          // full screen pages, no bottom nav
          GoRoute(
            path: AppRoutes.capture,
            parentNavigatorKey: _shellNavigatorKey,
            builder: (_, __) => const CaptureScreen(),
          ),
          GoRoute(
            path: AppRoutes.identify,
            parentNavigatorKey: _shellNavigatorKey,
            builder: (context, state) {
              final args = state.extra as IdentificationArgs?;
              if (args == null) return const _MissingArgs(screen: 'identify');
              return IdentificationScreen(args: args);
            },
          ),
          GoRoute(
            path: AppRoutes.observation,
            parentNavigatorKey: _shellNavigatorKey,
            builder: (context, state) {
              final obs = state.extra as Observation?;
              if (obs == null) return const _MissingArgs(screen: 'observation');
              return ObservationDetailScreen(observation: obs);
            },
          ),
        ],
      ),
    ],
    errorBuilder: (_, state) => Scaffold(
      body: Center(child: Text('Route not found: ${state.uri}')),
    ),
  );
});

class _MissingArgs extends StatelessWidget {
  const _MissingArgs({required this.screen});
  final String screen;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(child: Text('Missing arguments for $screen')),
      );
}
