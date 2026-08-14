import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../deep_link/deep_link_service.dart';
import '../push/push_service.dart';
import '../push/routine_push_service.dart';
import '../../features/auth/application/auth_controller.dart';
import '../../features/auth/application/auth_state.dart';
import '../../features/auth/data/auth_api.dart';
import '../../features/auth/data/auth_models.dart';
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
import '../../features/geofencing/data/geofence_models.dart';
import '../../features/geofencing/presentation/notifications_screen.dart';
import '../../features/geofencing/presentation/quiet_hours_screen.dart';
import '../../features/geofencing/presentation/safe_zones_page.dart';
import '../../features/home/presentation/main_shell.dart';
import '../../features/location/application/permission_controller.dart';
import '../../features/location/presentation/battery_transparency_screen.dart';
import '../../features/location/presentation/location_permission_gate.dart';
import '../../features/location/presentation/permission_priming_screen.dart';
import '../../features/privacy/presentation/privacy_policy_screen.dart';
import '../../features/profile/application/profile_controller.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/sos/presentation/emergency_contacts_screen.dart';
import '../../features/sos/presentation/responder_alert_screen.dart';
import '../../features/sos/presentation/sender_emergency_session_screen.dart';
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
  '/onboarding/role',
  '/circle/create',
  '/circle/invite',
  '/circle/permissions',
  '/invite/accept',
  '/permission-priming',
  '/battery-info',
  '/privacy/policy',
  '/profile',
  '/safe-zones',
  '/safe-zones/add',
  '/safe-zones/add/review',
  '/safe-zones/:zoneId',
  '/safe-zones/:zoneId/edit',
  '/notifications',
  '/notifications/quiet-hours',
  '/zone-activity',
  '/sos/session',
  '/sos/responder/:sessionId',
  '/settings/emergency-contacts',
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
    ref.listen<AsyncValue<ProfileState>>(
      profileControllerProvider,
      (previous, next) => notifyListeners(),
    );
    ref.listen<PermissionPrimingState>(
      permissionControllerProvider,
      (previous, next) => notifyListeners(),
    );
  }
}

/// SafePath app router - Welcome/Register/Role-select/Login + the
/// authenticated landing stub and the password-reset flow.
final routerProvider = Provider<GoRouter>((ref) {
  final refreshListenable = _AuthRefreshListenable(ref);

  final router = GoRouter(
    initialLocation: '/splash',
    overridePlatformDefaultLocation: true,
    refreshListenable: refreshListenable,
    redirect: (context, state) {
      final authState = ref.read(authControllerProvider);
      final isAuthenticated = authState is AuthAuthenticated;
      final isRecovery = authState is AuthRecovery;
      final profileState = ref.read(profileControllerProvider).value;
      final profile = profileState?.profile;
      final profileIsLoading = profileState?.isLoading ?? true;
      final sessionRoleValue = ref
          .read(authApiProvider)
          .currentSession
          ?.user
          .userMetadata?['role'];
      final sessionHasRoleMetadata =
          sessionRoleValue is String && sessionRoleValue.trim().isNotEmpty;
      final legacyGoogleDefaultedToMember =
          profile?.role == Role.member &&
          !sessionHasRoleMetadata &&
          !(profileState?.roleMetadataSynced ?? false);
      final needsRoleOnboarding =
          isAuthenticated &&
          profile != null &&
          (profile.role == null || legacyGoogleDefaultedToMember) &&
          !profileIsLoading;
      // `matchedLocation` is the *resolved* path (e.g. `/sos/responder/abc`)
      // — for parameterized routes like `/sos/responder/:sessionId` the set
      // must be checked against `fullPath` (the route's pattern, e.g.
      // `/sos/responder/:sessionId`) instead, or the guard would never fire
      // for any real deep link. Static routes' `fullPath` equals their own
      // literal path, so this generalizes without changing existing
      // behaviour for the rest of the set.
      final goingToAuthenticatedRoute = _authenticatedOnlyRoutes.contains(
        state.fullPath ?? state.matchedLocation,
      );
      final onSplash = state.matchedLocation == '/splash';
      final splashComplete = ref.read(splashAnimationCompleteProvider);
      final onInviteAccept = state.uri.path == '/invite/accept';
      final onRoleOnboarding = state.matchedLocation == '/onboarding/role';
      final onResetPassword = state.matchedLocation == '/reset-password';

      if (onSplash && !splashComplete) {
        return null;
      }
      if (isAuthenticated) {
        final pendingInvite = ref.read(pendingInviteProvider);
        if (pendingInvite != null && onInviteAccept) {
          ref.read(pendingInviteProvider.notifier).set(null);
        } else if (pendingInvite != null) {
          return pendingInvite.location;
        }
      }
      if (onSplash) {
        if (isRecovery) return '/reset-password';
        if (needsRoleOnboarding) return '/onboarding/role';
        if (isAuthenticated) return '/home';
        return '/';
      }
      if (isRecovery && !onResetPassword) {
        return '/reset-password';
      }
      if (!isAuthenticated && onInviteAccept) {
        final token = state.uri.queryParameters['token'];
        final code = state.uri.queryParameters['code'];
        if ((token?.isNotEmpty ?? false) || (code?.isNotEmpty ?? false)) {
          ref
              .read(pendingInviteProvider.notifier)
              .set(PendingInviteLink(token: token, code: code));
        }
        return '/';
      }
      if (!isAuthenticated && goingToAuthenticatedRoute) {
        return '/';
      }
      if (needsRoleOnboarding && !onRoleOnboarding) {
        return '/onboarding/role';
      }
      if (isAuthenticated && onRoleOnboarding && profile?.role != null) {
        return '/home';
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
        path: '/onboarding/role',
        name: 'onboarding-role',
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
        builder: (context, state) =>
            const LocationPermissionGate(child: MainShell()),
      ),
      GoRoute(
        path: '/permission-priming',
        name: 'permission-priming',
        builder: (context, state) => const PermissionPrimingScreen(),
      ),
      GoRoute(
        path: '/battery-info',
        name: 'battery-info',
        builder: (context, state) => const BatteryTransparencyScreen(),
      ),
      GoRoute(
        path: '/privacy/policy',
        name: 'privacy-policy',
        builder: (context, state) => const PrivacyPolicyScreen(),
      ),
      GoRoute(
        path: '/profile',
        name: 'profile',
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/safe-zones',
        name: 'safe-zones',
        builder: (context, state) => const SafeZonesPage(),
      ),
      GoRoute(
        path: '/notifications',
        name: 'notifications',
        builder: (context, state) => const NotificationsPage(),
      ),
      GoRoute(
        path: '/notifications/quiet-hours',
        name: 'quiet-hours',
        builder: (context, state) => const QuietHoursPage(),
      ),
      GoRoute(
        path: '/zone-activity',
        name: 'zone-activity',
        builder: (context, state) =>
            RoutineActivityPage(zoneId: state.uri.queryParameters['zoneId']),
      ),
      GoRoute(
        path: '/safe-zones/add',
        name: 'safe-zones-add',
        builder: (context, state) => const SafeZoneEditorPage(),
      ),
      GoRoute(
        path: '/safe-zones/add/review',
        name: 'safe-zones-review',
        builder: (context, state) => const SafeZoneReviewPage(),
      ),
      GoRoute(
        path: '/safe-zones/:zoneId',
        name: 'safe-zones-detail',
        builder: (context, state) => SafeZoneDetailPage(
          zoneId: state.pathParameters['zoneId']!,
          zone: state.extra as SafeZone?,
        ),
      ),
      GoRoute(
        path: '/safe-zones/:zoneId/edit',
        name: 'safe-zones-edit',
        builder: (context, state) =>
            SafeZoneEditorPage(initialZone: state.extra as SafeZone?),
      ),
      GoRoute(
        path: '/sos/session',
        name: 'sos-session',
        builder: (context, state) => const SenderEmergencySessionScreen(),
      ),
      GoRoute(
        path: '/sos/responder/:sessionId',
        name: 'sos-responder',
        builder: (context, state) =>
            ResponderAlertScreen(sessionId: state.pathParameters['sessionId']!),
      ),
      GoRoute(
        path: '/settings/emergency-contacts',
        name: 'emergency-contacts',
        builder: (context, state) => const EmergencyContactsScreen(),
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

  // Routine pushes have their own service and normal-priority local channel.
  // Keeping this composition outside PushService prevents routine tap handling
  // from changing the existing SOS critical route or notification semantics.
  final routinePushService = RoutinePushService(
    messaging: FirebaseMessagingClient(),
    navigate: (zoneId) =>
        router.goNamed('zone-activity', queryParameters: {'zoneId': zoneId}),
    notifier: RoutineLocalNotificationPresenter(),
  );
  unawaited(
    routinePushService.initialize().catchError((
      Object error,
      StackTrace stack,
    ) {
      debugPrint(
        'RoutinePushService.initialize failed (Firebase not configured yet?): $error',
      );
    }),
  );
  ref.listen<AuthState>(authControllerProvider, (previous, next) {
    unawaited(
      routinePushService
          .onAuthStateChanged(next is AuthAuthenticated)
          .catchError((Object error, StackTrace stack) {
            debugPrint('RoutinePushService.onAuthStateChanged failed: $error');
          }),
    );
  }, fireImmediately: true);
  ref.onDispose(routinePushService.dispose);

  return router;
});
