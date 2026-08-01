import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../family/application/family_controller.dart';
import '../../location/application/location_controller.dart';
import '../data/sos_api.dart';
import '../data/sos_local_store.dart';
import '../data/sos_models.dart';
import 'sos_session_state.dart';

/// Owns the SOS sender-side state machine and trigger submission. `arm()` is
/// the single entry point the press-and-hold button (and, in plan 03-09, the
/// OS quick-actions shortcut) both call.
class SosController extends AsyncNotifier<SosSessionState> {
  String? _sessionId;

  /// The device-generated session id for the current (or most recently
  /// persisted) emergency. Available immediately after [arm] completes,
  /// independent of whether the server has responded yet — the id is
  /// generated and persisted before any network call (D-13/D-14).
  String? get sosSessionId => _sessionId;

  @override
  SosSessionState build() {
    // Rehydrate a persisted session id (if any) so a restart lands on the
    // same emergency rather than losing it. Fire-and-forget: must run after
    // build() returns, matching FamilyController/LocationController's own
    // Future.microtask bootstrap convention.
    Future.microtask(_rehydrate);
    return const SosIdle();
  }

  Future<void> _rehydrate() async {
    final persisted = await ref.read(sosLocalStoreProvider).readSessionId();
    // A real arm() call may have already run (and generated its own fresh
    // session id) by the time this fire-and-forget bootstrap microtask gets
    // a turn — never clobber or duplicate that with a stale rehydrate.
    if (persisted == null || persisted.isEmpty || _sessionId != null) return;
    _sessionId = persisted;
    try {
      final session = await ref.read(sosApiProvider).getSession(persisted);
      state = AsyncData(SosSubmitted(session));
    } catch (_) {
      // Best-effort resume only — plan 03-07 owns full offline/resume
      // handling; leaving state as SosIdle here is a safe fallback.
    }
  }

  /// Arm-complete entry point: generates the session id, persists it, and
  /// only then calls [submit]. The id exists and is persisted before any
  /// await on the network (D-13, D-14).
  Future<void> arm() async {
    final id = const Uuid().v4();
    _sessionId = id;
    await ref.read(sosLocalStoreProvider).writeSessionId(id);
    state = const AsyncLoading();
    await submit();
  }

  /// Submits the current session id to the server. Every call passes the
  /// same persisted [sosSessionId], so a server-side replay is a status
  /// check rather than a second emergency (D-15).
  Future<void> submit() async {
    final sessionId =
        _sessionId ?? await ref.read(sosLocalStoreProvider).readSessionId();
    if (sessionId == null || sessionId.isEmpty) {
      // arm() was never called — nothing to submit.
      return;
    }
    _sessionId = sessionId;

    final familyId = ref.read(familyControllerProvider).value?.family?.id;
    // Read the last known fix already held by LocationController rather than
    // starting a fresh geolocator request — waiting on a cold GPS fix would
    // delay the alert, which the Core Value forbids. Null coordinates are
    // accepted by the backend when no fix is available (03-01).
    final position = ref.read(locationControllerProvider).value?.selfPosition;
    final request = SosTriggerRequest(
      sosSessionId: sessionId,
      familyId: familyId ?? '',
      latitude: position?.lat,
      longitude: position?.lng,
      accuracyMeters: position?.accuracyMeters,
      triggeredAtUtc: DateTime.now().toUtc(),
    );

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final session = await ref.read(sosApiProvider).trigger(request);
      return SosSubmitted(session);
    });
  }

  /// Clears the persisted session id so the next arm starts a fresh
  /// emergency.
  Future<void> closeSession() async {
    _sessionId = null;
    await ref.read(sosLocalStoreProvider).clear();
    state = const AsyncData(SosIdle());
  }
}

final sosControllerProvider =
    AsyncNotifierProvider<SosController, SosSessionState>(SosController.new);
