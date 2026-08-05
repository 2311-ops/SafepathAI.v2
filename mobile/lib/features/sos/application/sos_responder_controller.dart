import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_controller.dart';
import '../../auth/application/auth_state.dart';
import '../../auth/data/auth_api.dart';
import '../../family/application/family_controller.dart';
import '../data/sos_api.dart';
import '../data/sos_hub_client.dart';
import '../data/sos_models.dart';

/// Callback the controller invokes to force-navigate to the full-screen
/// responder route the instant an incoming SOS arrives (D-20). Kept
/// router-agnostic — this feature layer never imports go_router directly;
/// whatever composes this controller with a live `BuildContext`/router wires
/// this once at app startup (mirrors `DeepLinkService.start(router)`).
typedef SosResponderNavigate = void Function(String sosSessionId);

/// State held by [SosResponderController]: the guardian's currently active
/// incoming emergency (if any this session) and, once acted on, when they
/// acknowledged it.
class SosResponderState {
  const SosResponderState({this.activeSession, this.acknowledgedAtUtc});

  final SosSession? activeSession;
  final DateTime? acknowledgedAtUtc;

  SosResponderState copyWith({
    SosSession? activeSession,
    DateTime? acknowledgedAtUtc,
  }) {
    return SosResponderState(
      activeSession: activeSession ?? this.activeSession,
      acknowledgedAtUtc: acknowledgedAtUtc ?? this.acknowledgedAtUtc,
    );
  }
}

/// Owns the guardian-side alert-hub connection and force-navigation on an
/// incoming SOS. Mirrors `LocationController`'s bootstrap/subscription
/// convention: connects once the caller is authenticated and has an active
/// family, holds a typed `StreamSubscription`, and tears down through
/// `ref.onDispose`. This is the one controller that owns
/// [sosHubClientProvider]'s connect/disconnect lifecycle — `SosController`
/// (sender-side) only ever listens to the already-connected client's
/// streams.
class SosResponderController extends AsyncNotifier<SosResponderState> {
  StreamSubscription<SosSession>? _sosTriggeredSubscription;
  SosHubClient? _hubClient;
  String? _connectedFamilyId;
  SosResponderNavigate? _navigate;
  int _generation = 0;
  final Set<String> _confirmedSessionIds = {};

  @override
  SosResponderState build() {
    ref.listen<AuthState>(authControllerProvider, (previous, next) {
      if (next is AuthAuthenticated) {
        _bootstrap();
      } else if (next is AuthUnauthenticated) {
        unawaited(_stop());
      }
    });
    ref.listen<AsyncValue<FamilyState>>(familyControllerProvider, (
      previous,
      next,
    ) {
      if (next.value?.family != null) {
        _bootstrap();
      } else if (!(next.value?.isLoading ?? false)) {
        unawaited(_stop());
      }
    });
    ref.onDispose(() {
      unawaited(_stop());
    });

    Future.microtask(_bootstrap);
    return const SosResponderState();
  }

  /// Wires the callback the controller invokes to push the responder route.
  /// Called once at app startup with a real router-backed implementation;
  /// tests supply a recording fake instead.
  void attachNavigator(SosResponderNavigate navigate) {
    _navigate = navigate;
  }

  /// Seeds the responder state from an authenticated fetch, used when the
  /// guardian opens an SOS notification before the SignalR event has hydrated
  /// this controller in memory.
  void showSession(SosSession session) {
    state = AsyncData(_current.copyWith(activeSession: session));
  }

  SosResponderState get _current => state.value ?? const SosResponderState();

  Future<void> _bootstrap() async {
    final authState = ref.read(authControllerProvider);
    if (authState is! AuthAuthenticated) {
      await _stop();
      return;
    }

    final familyId = ref.read(familyControllerProvider).value?.family?.id;
    if (familyId == null || familyId.isEmpty) {
      await _stop();
      return;
    }

    if (_connectedFamilyId == familyId) return;

    final generation = ++_generation;
    await _stop(disconnect: false, invalidateGeneration: false);
    if (generation != _generation) return;

    final hubClient = ref.read(sosHubClientProvider);
    _hubClient = hubClient;
    await hubClient.connect(familyId);
    if (generation != _generation) {
      await hubClient.disconnect();
      if (_hubClient == hubClient) _hubClient = null;
      return;
    }

    final subscription = hubClient.sosTriggered.listen(_onSosTriggered);
    if (generation != _generation) {
      await subscription.cancel();
      return;
    }

    _sosTriggeredSubscription = subscription;
    _connectedFamilyId = familyId;
  }

  Future<void> _stop({
    bool disconnect = true,
    bool invalidateGeneration = true,
  }) async {
    if (invalidateGeneration) _generation++;
    _connectedFamilyId = null;
    await _sosTriggeredSubscription?.cancel();
    _sosTriggeredSubscription = null;
    final hubClient = _hubClient;
    _hubClient = null;
    if (disconnect) {
      await hubClient?.disconnect();
    }
  }

  void _onSosTriggered(SosSession session) {
    final currentUserId = ref.read(authApiProvider).currentSession?.user.id;
    // A replayed self-event (e.g. reconnect gap-fill) must never loop the
    // sender into their own responder screen (threat T-03-18) — the sender
    // already has their own full-screen session open.
    if (session.triggeredByUserId == currentUserId) return;

    if (_confirmedSessionIds.add(session.sosSessionId)) {
      // Always read the shared singleton client (not the possibly-stale
      // `_hubClient` field) — one HubConnection per app session.
      unawaited(
        ref.read(sosHubClientProvider).confirmReceipt(session.sosSessionId),
      );
    }

    state = AsyncData(_current.copyWith(activeSession: session));

    // Force-navigation fires regardless of what the guardian is currently
    // doing in the app — SOS is never a dismissible card (D-20).
    _navigate?.call(session.sosSessionId);
  }

  /// Guardian confirms they have seen the alert (D-22). Strictly stronger
  /// than Delivered — only ever reached through this explicit action.
  Future<void> acknowledge() async {
    final session = _current.activeSession;
    if (session == null) return;
    final updated = await ref
        .read(sosApiProvider)
        .acknowledge(session.sosSessionId);
    state = AsyncData(
      _current.copyWith(
        activeSession: updated,
        acknowledgedAtUtc: DateTime.now().toUtc(),
      ),
    );
  }
}

final sosResponderControllerProvider =
    AsyncNotifierProvider<SosResponderController, SosResponderState>(
      SosResponderController.new,
    );
