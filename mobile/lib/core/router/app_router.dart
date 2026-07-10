import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../deep_link/deep_link_service.dart';
import '../../features/auth/application/auth_controller.dart';
import '../../features/auth/application/auth_state.dart';
import '../../features/auth/presentation/check_email_screen.dart';
import '../../features/auth/presentation/forgot_password_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/auth/presentation/reset_password_screen.dart';
import '../../features/auth/presentation/role_select_screen.dart';
import '../../features/auth/presentation/welcome_screen.dart';
import '../../features/family/presentation/accept_invite_screen.dart';
import '../../features/family/presentation/create_circle_screen.dart';
import '../../features/family/presentation/invite_member_screen.dart';
import '../../features/family/presentation/manage_permissions_screen.dart';
import '../../features/home/presentation/landing_stub_screen.dart';
import '../../features/splash/application/splash_providers.dart';
import '../../features/splash/presentation/splash_screen.dart';

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

/// Authenticated-only routes: an unauthenticated user hitting any of these
/// (e.g. a stale deep link) is redirected to Welcome instead of being shown
/// the screen. Family-circle routes call authenticated-only backend
/// endpoints (T-07-01 — the server is the authoritative check; this guard is
/// convenience/defense-in-depth, not the security boundary).
const _authenticatedOnlyRoutes = {
  '/home',
  '/circle/create',
  '/circle/invite',
  '/circle/permissions',
  '/invite/accept',
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
    ref.listen<bool>(
      splashAnimationCompleteProvider,
      (previous, next) => notifyListeners(),
    );
  }
}

/// SafePath app router - Welcome/Register/Role-select/Login + the
/// authenticated landing stub and the password-reset flow.
final routerProvider = Provider<GoRouter>((ref) {
  final refreshListenable = _AuthRefreshListenable(ref);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: refreshListenable,
    redirect: (context, state) {
      final authState = ref.read(authControllerProvider);
      final isAuthenticated = authState is AuthAuthenticated;
      final isRecovery = authState is AuthRecovery;
      final goingToAuthenticatedRoute = _authenticatedOnlyRoutes.contains(
        state.matchedLocation,
      );
      final onResetPassword = state.matchedLocation == '/reset-password';

      if (state.matchedLocation == '/splash') {
        if (!ref.read(splashAnimationCompleteProvider)) {
          return null;
        }
        if (isRecovery) return '/reset-password';
        if (isAuthenticated) return '/home';
        return '/';
      }
      if (isRecovery && !onResetPassword) {
        return '/reset-password';
      }
      if (!isAuthenticated && state.matchedLocation == '/invite/accept') {
        final token = state.uri.queryParameters['token'];
        final code = state.uri.queryParameters['code'];
        if ((token?.isNotEmpty ?? false) || (code?.isNotEmpty ?? false)) {
          ref
              .read(pendingInviteProvider.notifier)
              .set(PendingInviteLink(token: token, code: code));
        }
        return '/';
      }
      if (isAuthenticated && state.matchedLocation != '/invite/accept') {
        final pendingInvite = ref.read(pendingInviteProvider);
        if (pendingInvite != null) {
          ref.read(pendingInviteProvider.notifier).set(null);
          return pendingInvite.location;
        }
      }
      if (!isAuthenticated && goingToAuthenticatedRoute) {
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
        path: '/splash',
        name: 'splash',
        builder: (context, state) => const SplashScreen(),
      ),
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
      GoRoute(
        path: '/circle/create',
        name: 'circle-create',
        builder: (context, state) => const CreateCircleScreen(),
      ),
      GoRoute(
        path: '/circle/invite',
        name: 'circle-invite',
        builder: (context, state) => const InviteMemberScreen(),
      ),
      GoRoute(
        path: '/invite/accept',
        name: 'invite-accept',
        builder: (context, state) => AcceptInviteScreen(
          initialCode: state.uri.queryParameters['code'],
          initialLinkToken: state.uri.queryParameters['token'],
        ),
      ),
      GoRoute(
        path: '/circle/permissions',
        name: 'circle-permissions',
        builder: (context, state) => const ManagePermissionsScreen(),
      ),
    ],
  );
});
