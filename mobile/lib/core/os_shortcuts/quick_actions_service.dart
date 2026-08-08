// QuickActionsService's constructor deliberately assigns named parameters to
// underscore-prefixed fields by name (not via `this._field` initializing
// formals), so the public parameter names (client, arm, isSessionActive,
// navigate) stay the external named-argument labels at every call site
// rather than the private field names — mirrors push_service.dart's
// identical convention/rationale.
// ignore_for_file: prefer_initializing_formals
//
// The private field backing the injected `arm` callback below is
// deliberately named `_armCallback` (not `_arm`) purely so this file's own
// invocation of it does not itself read as a second, parallel arming call
// site next to the one real `SosController` call in
// `quickActionsServiceProvider` below — the shortcut must reuse that single
// entry point, never re-implement it.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quick_actions/quick_actions.dart';

import '../../features/auth/application/auth_controller.dart';
import '../../features/auth/application/auth_state.dart';
import '../../features/sos/application/sos_controller.dart';
import '../../features/sos/application/sos_session_state.dart';
import '../router/app_router.dart';

/// The `ShortcutItem.type` identifier for the Emergency SOS home-screen
/// action (Android App Shortcut / iOS Home Screen Quick Action) — SOS-06,
/// D-25.
const sosQuickActionType = 'sos';

/// Callback the service invokes to force-navigate into the full-screen
/// emergency session route (`sos-session`). Kept router-agnostic — mirrors
/// `SosResponderNavigate`/`PushResponderNavigate` so this class never
/// imports go_router directly; only `quickActionsServiceProvider` below
/// (the composition point, reusing the single shared `routerProvider`
/// instance) does.
typedef QuickActionsSessionNavigate = void Function();

/// Abstraction over the `quick_actions` plugin so
/// `quick_actions_service_test.dart` can drive [QuickActionsService] with a
/// fake and no platform channel — mirrors `PushMessagingClient`
/// (`push_service.dart`)'s identical seam over `firebase_messaging`.
abstract class QuickActionsClient {
  /// Registers the callback invoked whenever the user launches (or resumes)
  /// the app via a quick action — the plugin itself replays a cold-start
  /// launch action into this same callback once it is called, so there is
  /// no separate "initial action" query to make.
  Future<void> initialize(void Function(String type) handler);

  Future<void> setShortcutItems(List<ShortcutItem> items);

  Future<void> clearShortcutItems();
}

class RealQuickActionsClient implements QuickActionsClient {
  const RealQuickActionsClient([QuickActions? quickActions])
    : _quickActions = quickActions ?? const QuickActions();

  final QuickActions _quickActions;

  @override
  Future<void> initialize(void Function(String type) handler) =>
      _quickActions.initialize(handler);

  @override
  Future<void> setShortcutItems(List<ShortcutItem> items) =>
      _quickActions.setShortcutItems(items);

  @override
  Future<void> clearShortcutItems() => _quickActions.clearShortcutItems();
}

/// Owns the home-screen "Emergency SOS" quick-action shortcut's lifecycle:
/// registers it only while signed in, and on invocation fires the alert
/// immediately through the identical `SosController` entry point the
/// press-and-hold button calls — the injected `arm` callback below (SOS-06,
/// D-25/D-27).
///
/// There is deliberately no arming hold, countdown, confirmation or
/// intermediate screen on this path — the user already made a deliberate,
/// two-step choice by long-pressing the app icon and picking the action, so
/// requiring a second gesture here would defeat the point of a backup
/// trigger (D-27). This class never re-implements any part of that hold;
/// [arm] is the exact same callable the button uses.
class QuickActionsService {
  QuickActionsService({
    required QuickActionsClient client,
    required Future<void> Function() arm,
    required bool Function() isSessionActive,
    required QuickActionsSessionNavigate navigate,
  }) : _client = client,
       _armCallback = arm,
       _isSessionActive = isSessionActive,
       _navigate = navigate;

  final QuickActionsClient _client;
  final Future<void> Function() _armCallback;
  final bool Function() _isSessionActive;
  final QuickActionsSessionNavigate _navigate;

  bool _initialized = false;
  bool _isAuthenticated = false;

  /// A shortcut invocation that arrived before [onAuthStateChanged] first
  /// reported `true` — replayed exactly once the moment auth settles,
  /// mirroring `PushService`'s own `_pendingSessionId` cold-start replay.
  String? _pendingType;

  /// Registers the invocation handler. Safe to call once; a second call is
  /// a no-op (mirrors `PushService.initialize`).
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    await _client.initialize(_handleInvocation);
  }

  /// Registers the shortcut on sign-in, clears it on sign-out — advertising
  /// an emergency action on a signed-out device would fail silently at
  /// exactly the wrong moment. Also replays a deferred pre-auth invocation
  /// (see [_pendingType]).
  Future<void> onAuthStateChanged(bool isAuthenticated) async {
    _isAuthenticated = isAuthenticated;

    if (isAuthenticated) {
      await _client.setShortcutItems(const [
        ShortcutItem(type: sosQuickActionType, localizedTitle: 'Emergency SOS'),
      ]);

      final pending = _pendingType;
      if (pending != null) {
        _pendingType = null;
        _fire();
      }
    } else {
      await _client.clearShortcutItems();
    }
  }

  void _handleInvocation(String type) {
    if (type != sosQuickActionType) return;

    if (!_isAuthenticated) {
      _pendingType = type;
      return;
    }

    _fire();
  }

  void _fire() {
    if (_isSessionActive()) {
      // The server would treat a fresh session id as a genuinely new
      // emergency, so this client-side guard is what actually prevents a
      // duplicate — route to the session already in progress instead of
      // re-arming.
      _navigate();
      return;
    }

    // No confirmation, countdown or arming hold in between — do not await
    // before navigating, mirroring `main_shell.dart`'s own
    // `_onArmComplete` not awaiting the arm callback before pushing route.
    unawaited(_armCallback());
    _navigate();
  }
}

/// Composition point: constructs the real [QuickActionsService], registers
/// its invocation handler once, and forwards every `AuthController`
/// transition into [QuickActionsService.onAuthStateChanged] — mirrors
/// `pushServiceProvider`/`PushServiceController`'s identical wiring, folded
/// into one provider since this service needs no separate lifecycle beyond
/// what `ref.listen` already gives a plain `Provider` here.
final quickActionsServiceProvider = Provider<QuickActionsService>((ref) {
  final router = ref.watch(routerProvider);
  final service = QuickActionsService(
    client: const RealQuickActionsClient(),
    arm: () => ref.read(sosControllerProvider.notifier).arm(),
    isSessionActive: () {
      final state = ref.read(sosControllerProvider).value;
      return state != null && state is! SosIdle;
    },
    navigate: () => router.pushNamed('sos-session'),
  );

  unawaited(
    service.initialize().catchError((Object error, StackTrace stack) {
      debugPrint('QuickActionsService.initialize failed: $error');
    }),
  );

  ref.listen<AuthState>(authControllerProvider, (previous, next) {
    unawaited(
      service.onAuthStateChanged(next is AuthAuthenticated).catchError((
        Object error,
        StackTrace stack,
      ) {
        debugPrint('QuickActionsService.onAuthStateChanged failed: $error');
      }),
    );
  }, fireImmediately: true);

  return service;
});
