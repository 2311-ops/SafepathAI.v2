import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/application/auth_controller.dart';
import '../../features/auth/application/auth_state.dart';
import '../../features/auth/presentation/check_email_screen.dart';
import '../../features/auth/presentation/forgot_password_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/auth/presentation/reset_password_screen.dart';
import '../../features/auth/presentation/role_select_screen.dart';
import '../../features/auth/presentation/welcome_screen.dart';
import '../../features/home/presentation/landing_stub_screen.dart';

/// Routes that belong to the pre-auth onboarding flow. An authenticated user
/// landing on any of these gets redirected to `/home` instead.
const _unauthenticatedOnlyRoutes = {
  '/',
  '/register',
  '/register/role',
  '/login',
  '/forgot-password',
  '/verify-email',
};

/// Bridges [authControllerProvider] changes to go_router's
/// [GoRouter.refreshListenable] so the redirect below re-runs whenever auth
/// state changes, without recreating the [GoRouter] instance itself.
class _AuthRefreshListenable extends ChangeNotifier {
  _AuthRefreshListenable(Ref ref) {
    ref.listen<AuthState>(
      authControllerProvider,
      (previous, next) => notifyListeners(),
    );
  }
}

/// SafePath app router - Welcome/Register/Role-select/Login + the
/// authenticated landing stub and the password-reset flow.
final routerProvider = Provider<GoRouter>((ref) {
  final refreshListenable = _AuthRefreshListenable(ref);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: refreshListenable,
    redirect: (context, state) {
      final authState = ref.read(authControllerProvider);
      final isAuthenticated = authState is AuthAuthenticated;
      final isRecovery = authState is AuthRecovery;
      final goingHome = state.matchedLocation == '/home';
      final onResetPassword = state.matchedLocation == '/reset-password';

      if (isRecovery && !onResetPassword) {
        return '/reset-password';
      }
      if (!isAuthenticated && goingHome) {
        return '/';
      }
      if (isAuthenticated &&
          (_unauthenticatedOnlyRoutes.contains(state.matchedLocation) ||
              (onResetPassword && !isRecovery))) {
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
        builder: (context, state) => const RoleSelectScreen(),
      ),
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/forgot-password',
        name: 'forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/verify-email',
        name: 'verify-email',
        builder: (context, state) =>
            CheckEmailScreen(email: state.extra as String?),
      ),
      GoRoute(
        path: '/reset-password',
        name: 'reset-password',
        builder: (context, state) => const ResetPasswordScreen(),
      ),
      GoRoute(
        path: '/home',
        name: 'home',
        builder: (context, state) => const LandingStubScreen(),
      ),
    ],
  );
});
