import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/application/auth_controller.dart';
import '../../features/auth/application/auth_state.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/auth/presentation/role_select_screen.dart';
import '../../features/auth/presentation/welcome_screen.dart';
import '../../features/home/presentation/landing_stub_screen.dart';

/// Routes that belong to the pre-auth onboarding flow — an authenticated
/// user landing on any of these gets redirected to `/home` instead.
const _unauthenticatedOnlyRoutes = {'/', '/register', '/register/role', '/login'};

/// Bridges [authControllerProvider] changes to go_router's
/// [GoRouter.refreshListenable] so the redirect below re-runs whenever auth
/// state changes, without recreating the [GoRouter] instance itself (which
/// would otherwise reset in-flight navigation on every state change).
class _AuthRefreshListenable extends ChangeNotifier {
  _AuthRefreshListenable(Ref ref) {
    ref.listen<AuthState>(
      authControllerProvider,
      (previous, next) => notifyListeners(),
    );
  }
}

/// SafePath app router — Welcome/Register/Role-select/Login + the
/// authenticated landing stub, gated by [AuthController]'s state.
final routerProvider = Provider<GoRouter>((ref) {
  final refreshListenable = _AuthRefreshListenable(ref);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: refreshListenable,
    redirect: (context, state) {
      final isAuthenticated = ref.read(authControllerProvider) is AuthAuthenticated;
      final goingHome = state.matchedLocation == '/home';

      if (!isAuthenticated && goingHome) {
        return '/';
      }
      if (isAuthenticated && _unauthenticatedOnlyRoutes.contains(state.matchedLocation)) {
        return '/home';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        name: 'welcome',
        builder: (context, state) => const WelcomeScreen(),
      ),
      GoRoute(
        path: '/register',
        name: 'register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/register/role',
        name: 'register-role',
        builder: (context, state) {
          final draft = state.extra as RegisterDraft?;
          if (draft == null) {
            // Defensive fallback — this route is only ever reached via
            // RegisterScreen's Continue CTA, which always supplies extra.
            return const RegisterScreen();
          }
          return RoleSelectScreen(draft: draft);
        },
      ),
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/home',
        name: 'home',
        builder: (context, state) => const LandingStubScreen(),
      ),
    ],
  );
});
