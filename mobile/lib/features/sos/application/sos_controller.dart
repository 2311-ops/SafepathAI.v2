import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/network/connectivity_service.dart';
import '../../family/application/family_controller.dart';
import '../../location/application/location_controller.dart';
import '../data/sos_api.dart';
import '../data/sos_hub_client.dart';
import '../data/sos_local_store.dart';
import '../data/sos_models.dart';
import 'sos_live_location_service.dart';
import 'sos_session_state.dart';

/// Schedules the offline-retry backoff timer for [SosController]. This is
/// the only seam the retry loop goes through — overridden in tests with a
/// fake that lets a test manually fire a scheduled retry instead of waiting
/// on real wall-clock time. Deliberately not a third-party backoff package
/// (03-RESEARCH.md "Don't Hand-Roll": the loop itself is simple; the part
/// that must not be improvised is idempotency, which lives server-side).
abstract class SosRetryScheduler {
  SosRetryHandle schedule(Duration delay, void Function() callback);
}

/// Cancels a single scheduled retry. Returned by [SosRetryScheduler.schedule].
abstract class SosRetryHandle {
  void cancel();
}

class TimerSosRetryScheduler implements SosRetryScheduler {
  const TimerSosRetryScheduler();

  @override
  SosRetryHandle schedule(Duration delay, void Function() callback) =>
      _TimerSosRetryHandle(Timer(delay, callback));
}

class _TimerSosRetryHandle implements SosRetryHandle {
  _TimerSosRetryHandle(this._timer);

  final Timer _timer;

  @override
  void cancel() => _timer.cancel();
}

final sosRetrySchedulerProvider = Provider<SosRetryScheduler>(
  (ref) => const TimerSosRetryScheduler(),
);

/// Owns the SOS sender-side state machine and trigger submission. `arm()` is
/// the single entry point the press-and-hold button (and, in plan 03-09, the
/// OS quick-actions shortcut) both call.
///
/// This controller never connects/disconnects [sosHubClientProvider] itself
/// — [SosResponderController] (03-04-PLAN.md Task 1) owns that connection's
/// lifecycle. This controller only listens to the already-connected
/// client's `deliveryStatusChanges`/`sosCanceled` streams so the sender's own
/// session reflects live delivery/acknowledgement/cancellation state.
///
/// Offline behaviour (03-07-PLAN.md, D-12..D-17): a trigger that cannot
/// reach the server persists its payload before the first network attempt,
/// enters [SosOfflineQueued], and retries on an escalating backoff driven
/// purely by the HTTP call's own outcome — [connectivityServiceProvider] is
/// consulted only to retry sooner when an interface reappears, never as
/// proof the server is reachable.
class SosController extends AsyncNotifier<SosSessionState> {
  String? _sessionId;
  SosTriggerRequest? _pendingRequest;
  SosRetryHandle? _retryHandle;
  late SosLiveLocationService _liveLocationService;
  bool _isLiveLocationActive = false;

  static const _initialRetryDelay = Duration(seconds: 4);
  static const _maxRetryDelay = Duration(seconds: 60);

  /// The device-generated session id for the current (or most recently
  /// persisted) emergency. Available immediately after [arm] completes,
  /// independent of whether the server has responded yet — the id is
  /// generated and persisted before any network call (D-13/D-14).
  String? get sosSessionId => _sessionId;

  @override
  SosSessionState build() {
    _liveLocationService = ref.read(sosLiveLocationServiceProvider);
    final hubClient = ref.read(sosHubClientProvider);
    final deliveryStatusSubscription = hubClient.deliveryStatusChanges.listen(
      _applyDeliveryStatusChange,
    );
    final sosCanceledSubscription = hubClient.sosCanceled.listen(
      _applySosCanceled,
    );
    final liveLocationUpdateSubscription = hubClient.liveLocationUpdates
        .listen(_applyLiveLocationUpdate);
    final connectivitySubscription = ref
        .read(connectivityServiceProvider)
        .onConnectivityChanged
        .listen(_onConnectivityChanged);
    ref.onDispose(() {
      unawaited(deliveryStatusSubscription.cancel());
      unawaited(sosCanceledSubscription.cancel());
      unawaited(liveLocationUpdateSubscription.cancel());
      unawaited(connectivitySubscription.cancel());
      _retryHandle?.cancel();
      _retryHandle = null;
      // Reads a plain field, never `state`/`ref` — Riverpod forbids touching
      // either from inside an onDispose callback.
      if (_isLiveLocationActive) {
        unawaited(_liveLocationService.stop());
      }
    });

    // Rehydrate a persisted session id (if any) so a restart lands on the
    // same emergency rather than losing it. Fire-and-forget: must run after
    // build() returns, matching FamilyController/LocationController's own
    // Future.microtask bootstrap convention.
    Future.microtask(_rehydrate);
    return const SosIdle();
  }

  /// [connectivityServiceProvider] is a hint, not ground truth (see class
  /// doc) — a `true` transition only shortens the wait for the *next*
  /// attempt of an already-queued trigger; it never itself decides success.
  void _onConnectivityChanged(bool isConnected) {
    if (!isConnected) return;
    final current = state.value;
    final request = _pendingRequest;
    if (current is! SosOfflineQueued || request == null) return;

    _retryHandle?.cancel();
    _retryHandle = null;
    unawaited(_attemptSubmit(request, retryCount: current.retryCount));
  }

  /// The [SosSession] embedded in the current sealed state, or `null` for
  /// states that carry no session ([SosIdle], [SosOfflineQueued]).
  SosSession? _sessionOf(SosSessionState value) {
    return switch (value) {
      SosSubmitted(:final session) => session,
      SosDelivering(:final session) => session,
      SosLiveActive(:final session) => session,
      SosCanceled(:final session) => session,
      SosIdle() || SosOfflineQueued() => null,
    };
  }

  void _applyDeliveryStatusChange(SosDeliveryStatusChange change) {
    final current = state.value;
    if (current == null) return;
    final session = _sessionOf(current);
    if (session == null || session.sosSessionId != change.sosSessionId) {
      return;
    }

    final updatedSession = _foldDeliveryStatusChange(session, change);
    _replaceState(
      AsyncData(
        switch (current) {
          SosSubmitted() || SosDelivering() => SosDelivering(updatedSession),
          SosLiveActive(:final windowEndsAtUtc) => SosLiveActive(
            updatedSession,
            windowEndsAtUtc,
          ),
          SosCanceled(:final canceledAtUtc) => SosCanceled(
            updatedSession,
            canceledAtUtc,
          ),
          SosIdle() || SosOfflineQueued() => current,
        },
      ),
    );
  }

  void _applySosCanceled(SosCancellation cancellation) {
    final current = state.value;
    if (current == null) return;
    final session = _sessionOf(current);
    if (session == null || session.sosSessionId != cancellation.sosSessionId) {
      return;
    }
    // Belt-and-suspenders alongside _replaceState's generic
    // leaving-live-active handling below: makes the "the session was
    // canceled" self-termination path explicit at the call site.
    if (current is SosLiveActive) {
      unawaited(_liveLocationService.handleSessionCanceled());
    }
    _replaceState(AsyncData(SosCanceled(session, cancellation.canceledAtUtc)));
  }

  /// Refreshes the live window's end time from the server's own broadcast —
  /// the client always defers to this over its own arithmetic (D-21). A
  /// session not yet known to be live-active (e.g. still `SosSubmitted`
  /// while the first update races the trigger response) is promoted to
  /// `SosLiveActive` here too, so a live update is never silently dropped.
  void _applyLiveLocationUpdate(SosLocationUpdate update) {
    final current = state.value;
    if (current == null) return;
    final session = _sessionOf(current);
    if (session == null || session.sosSessionId != update.sosSessionId) {
      return;
    }
    if (current is SosCanceled || current is SosOfflineQueued) return;

    _replaceState(
      AsyncData(SosLiveActive(session, update.windowEndsAtUtc)),
    );
  }

  SosSession _foldDeliveryStatusChange(
    SosSession session,
    SosDeliveryStatusChange change,
  ) {
    final updatedRecipients = [
      for (final recipient in session.recipients)
        _matchesRecipient(recipient, change)
            ? SosRecipientStatus(
                recipientUserId: recipient.recipientUserId,
                emergencyContactId: recipient.emergencyContactId,
                displayName: recipient.displayName,
                channels: [
                  for (final channelStatus in recipient.channels)
                    if (channelStatus.channel == change.channel)
                      SosChannelStatus(
                        channel: channelStatus.channel,
                        status: change.status,
                        queuedAtUtc: channelStatus.queuedAtUtc,
                        deliveredAtUtc:
                            change.status == SosDeliveryStatus.delivered
                            ? change.atUtc
                            : channelStatus.deliveredAtUtc,
                        acknowledgedAtUtc:
                            change.status == SosDeliveryStatus.acknowledged
                            ? change.atUtc
                            : channelStatus.acknowledgedAtUtc,
                      )
                    else
                      channelStatus,
                ],
              )
            : recipient,
    ];

    return SosSession(
      sosSessionId: session.sosSessionId,
      familyId: session.familyId,
      triggeredByUserId: session.triggeredByUserId,
      status: session.status,
      triggeredAtUtc: session.triggeredAtUtc,
      receivedAtUtc: session.receivedAtUtc,
      liveWindowEndsAtUtc: session.liveWindowEndsAtUtc,
      canceledAtUtc: session.canceledAtUtc,
      recipients: updatedRecipients,
    );
  }

  bool _matchesRecipient(
    SosRecipientStatus recipient,
    SosDeliveryStatusChange change,
  ) {
    if (change.recipientUserId != null) {
      return recipient.recipientUserId == change.recipientUserId;
    }
    if (change.emergencyContactId != null) {
      return recipient.emergencyContactId == change.emergencyContactId;
    }
    return false;
  }

  Future<void> _rehydrate() async {
    final localStore = ref.read(sosLocalStoreProvider);
    final persisted = await localStore.readSessionId();
    // A real arm() call may have already run (and generated its own fresh
    // session id) by the time this fire-and-forget bootstrap microtask gets
    // a turn — never clobber or duplicate that with a stale rehydrate.
    if (persisted == null || persisted.isEmpty || _sessionId != null) return;
    _sessionId = persisted;

    final pendingTrigger = await localStore.readPendingTrigger();
    if (pendingTrigger != null) {
      // A queued-but-unacknowledged trigger survived the process death —
      // resume as the same emergency immediately rather than losing it or
      // minting a new one (D-14). Land in SosOfflineQueued synchronously so
      // a cold-started sender screen reads "still in progress" the instant
      // it opens, then attempt a resubmit right away instead of waiting out
      // a fresh backoff.
      _pendingRequest = pendingTrigger;
      _replaceState(
        AsyncData(
          SosOfflineQueued(
            sessionId: persisted,
            lastRetryAtUtc: DateTime.now().toUtc(),
            retryCount: 0,
          ),
        ),
      );
      await _attemptSubmit(pendingTrigger);
      return;
    }

    try {
      final session = await ref.read(sosApiProvider).getSession(persisted);
      _replaceState(AsyncData(_deriveSessionState(session)));
    } catch (_) {
      // Best-effort resume only.
    }
  }

  /// Arm-complete entry point: generates the session id, persists it and the
  /// composed trigger payload, and only then attempts to send. Both the id
  /// and the payload exist on disk before any await on the network (D-13,
  /// D-14) — a process death between hold-complete and the first network
  /// attempt still leaves a resumable emergency behind.
  Future<void> arm() async {
    final id = const Uuid().v4();
    _sessionId = id;
    final localStore = ref.read(sosLocalStoreProvider);
    await localStore.writeSessionId(id);
    final request = _composeRequest(id);
    await localStore.writePendingTrigger(request);
    _replaceState(const AsyncLoading());
    await _attemptSubmit(request);
  }

  /// Re-submits the current session id to the server. Every call passes the
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

    final request = _composeRequest(sessionId);
    await ref.read(sosLocalStoreProvider).writePendingTrigger(request);
    _replaceState(const AsyncLoading());
    await _attemptSubmit(request);
  }

  /// Asks the server directly for the current status of a rehydrated
  /// session, for a client that cannot otherwise tell whether an earlier
  /// submission landed. A best-effort check, not a retry trigger — failure
  /// here leaves the current state untouched.
  Future<void> checkQueuedSessionStatus() async {
    final sessionId = _sessionId;
    if (sessionId == null || sessionId.isEmpty) return;
    try {
      final session = await ref.read(sosApiProvider).getSession(sessionId);
      await _handleSuccess(session);
    } catch (_) {
      // Best-effort only.
    }
  }

  SosTriggerRequest _composeRequest(String sessionId) {
    final familyId = ref.read(familyControllerProvider).value?.family?.id;
    // Read the last known fix already held by LocationController rather than
    // starting a fresh geolocator request — waiting on a cold GPS fix would
    // delay the alert, which the Core Value forbids. Null coordinates are
    // accepted by the backend when no fix is available (03-01).
    final position = ref.read(locationControllerProvider).value?.selfPosition;
    return SosTriggerRequest(
      sosSessionId: sessionId,
      familyId: familyId ?? '',
      latitude: position?.lat,
      longitude: position?.lng,
      accuracyMeters: position?.accuracyMeters,
      triggeredAtUtc: DateTime.now().toUtc(),
    );
  }

  /// The single place every submit/retry/resume path funnels through.
  /// [retryCount] is the number of attempts already made for this queued
  /// trigger (0 for the very first attempt) — used only to compute the next
  /// backoff delay if this attempt also fails on a network issue.
  Future<void> _attemptSubmit(
    SosTriggerRequest request, {
    int retryCount = 0,
  }) async {
    _pendingRequest = request;
    try {
      final session = await ref.read(sosApiProvider).trigger(request);
      // A replayed sosSessionId the server already held is the idempotent
      // success path working as designed (D-15) — not a conflict, so this
      // branch never distinguishes a "fresh" accept from a reconciled one.
      await _handleSuccess(session);
    } on SosApiException catch (error) {
      if (error.issue == SosApiIssue.network) {
        _enterOfflineQueued(request, retryCount: retryCount + 1);
      } else {
        // Any other issue (validation, forbidden) surfaces as an error
        // state — retrying a rejected payload forever helps nobody.
        _retryHandle?.cancel();
        _retryHandle = null;
        _replaceState(AsyncError<SosSessionState>(error, StackTrace.current));
      }
    } catch (error, stackTrace) {
      _retryHandle?.cancel();
      _retryHandle = null;
      _replaceState(AsyncError<SosSessionState>(error, stackTrace));
    }
  }

  void _enterOfflineQueued(SosTriggerRequest request, {required int retryCount}) {
    _pendingRequest = request;
    _replaceState(
      AsyncData(
        SosOfflineQueued(
          sessionId: request.sosSessionId,
          lastRetryAtUtc: DateTime.now().toUtc(),
          retryCount: retryCount,
        ),
      ),
    );
    _scheduleRetry(request, retryCount);
  }

  void _scheduleRetry(SosTriggerRequest request, int retryCount) {
    _retryHandle?.cancel();
    final delay = _delayForRetry(retryCount);
    _retryHandle = ref
        .read(sosRetrySchedulerProvider)
        .schedule(delay, () {
          unawaited(_attemptSubmit(request, retryCount: retryCount));
        });
  }

  /// Starts short (an emergency retry is worth more battery than a routine
  /// sync) and caps at roughly a minute — no external backoff package, this
  /// is simple enough to own directly (03-RESEARCH.md "Don't Hand-Roll").
  Duration _delayForRetry(int retryCount) {
    final exponent = (retryCount - 1).clamp(0, 8);
    final scaled = _initialRetryDelay * (1 << exponent);
    return scaled > _maxRetryDelay ? _maxRetryDelay : scaled;
  }

  Future<void> _handleSuccess(SosSession session) async {
    _retryHandle?.cancel();
    _retryHandle = null;
    _pendingRequest = null;
    await ref.read(sosLocalStoreProvider).clearPendingTrigger();
    _replaceState(AsyncData(_deriveSessionState(session)));
  }

  /// Self-cancel entry point for `SosHoldToCancelButton` (plan 03-09,
  /// SOS-05, D-05/D-24). Never touches, clears or rolls back any delivery
  /// state the session already accumulated — the guardians were alerted and
  /// that history stays; the server-returned session (still carrying its
  /// full recipient/delivery list) becomes [SosCanceled]'s payload verbatim.
  ///
  /// A network failure here is retried on the same backoff shape the
  /// offline-trigger queue uses (D-17's persistence philosophy applied to
  /// cancellation) rather than surfacing an error or silently dropping the
  /// request — the current (still-honest) session state is left on screen
  /// until the cancellation actually reaches the server. A non-network
  /// rejection (e.g. the session was already resolved) is not retried
  /// forever; it simply leaves the current state untouched.
  Future<void> cancel() async {
    final sessionId = _sessionId;
    if (sessionId == null || sessionId.isEmpty) return;
    await _attemptCancel(sessionId);
  }

  Future<void> _attemptCancel(String sessionId, {int retryCount = 0}) async {
    try {
      final session = await ref.read(sosApiProvider).cancel(sessionId);
      _retryHandle?.cancel();
      _retryHandle = null;
      await ref.read(sosLocalStoreProvider).clearPendingTrigger();
      // Unconditional (not gated on _isLiveLocationActive) — belt-and-
      // suspenders alongside _replaceState's generic leaving-live-active
      // handling below, mirroring _applySosCanceled's own comment. Both
      // SosLiveLocationService.stop() itself and the underlying foreground
      // host's stop() are idempotent, so a session that was never live-active
      // simply no-ops here rather than needing a state check first.
      unawaited(_liveLocationService.stop());
      _replaceState(
        AsyncData(
          SosCanceled(session, session.canceledAtUtc ?? DateTime.now().toUtc()),
        ),
      );
    } on SosApiException catch (error) {
      if (error.issue == SosApiIssue.network) {
        _scheduleCancelRetry(sessionId, retryCount);
      }
      // A non-network rejection (validation/forbidden) is not retried —
      // forcing a rejected cancel forever helps nobody, and the current
      // state (whatever it was) stays exactly as it was, which is the
      // honest thing to show.
    } catch (_) {
      // Best-effort only — never risk a false "canceled" transition on an
      // unexpected error.
    }
  }

  void _scheduleCancelRetry(String sessionId, int retryCount) {
    _retryHandle?.cancel();
    final delay = _delayForRetry(retryCount + 1);
    _retryHandle = ref
        .read(sosRetrySchedulerProvider)
        .schedule(delay, () {
          unawaited(_attemptCancel(sessionId, retryCount: retryCount + 1));
        });
  }

  /// Clears the persisted session id so the next arm starts a fresh
  /// emergency.
  Future<void> closeSession() async {
    _retryHandle?.cancel();
    _retryHandle = null;
    _pendingRequest = null;
    _sessionId = null;
    await ref.read(sosLocalStoreProvider).clear();
    _replaceState(const AsyncData(SosIdle()));
  }

  /// A session whose server-issued window is still open is `SosLiveActive`
  /// from the moment this client learns about it — whether that is the
  /// trigger response itself or a best-effort rehydrate fetch — never just
  /// `SosSubmitted`/`SosDelivering` first. The client always defers to the
  /// server's own `liveWindowEndsAtUtc`/`status` rather than deriving a
  /// window locally (D-21).
  SosSessionState _deriveSessionState(SosSession session) {
    final windowEndsAtUtc = session.liveWindowEndsAtUtc;
    if (session.status != SosSessionStatus.canceled &&
        windowEndsAtUtc != null &&
        windowEndsAtUtc.isAfter(DateTime.now().toUtc())) {
      return SosLiveActive(session, windowEndsAtUtc);
    }
    if (session.status == SosSessionStatus.canceled) {
      return SosCanceled(session, session.canceledAtUtc ?? DateTime.now().toUtc());
    }
    return SosSubmitted(session);
  }

  /// The single place every state mutation funnels through, so entering and
  /// leaving [SosLiveActive] reliably starts/stops
  /// [sosLiveLocationServiceProvider] exactly once per transition — never
  /// re-started on every live-location refresh, and never left running past
  /// the state that justified it.
  void _replaceState(AsyncValue<SosSessionState> next) {
    final previous = state.value;
    final wasLiveActive = previous is SosLiveActive;
    state = next;
    final nextValue = next.value;
    _isLiveLocationActive = nextValue is SosLiveActive;
    if (nextValue is SosLiveActive) {
      // start() is idempotent for an already-active same session id — it
      // only refreshes the expiry timer from the (possibly updated) window
      // end, never re-launches the foreground host on every live-location
      // refresh.
      unawaited(
        _liveLocationService.start(
          nextValue.session.sosSessionId,
          nextValue.windowEndsAtUtc,
        ),
      );
    } else if (wasLiveActive) {
      unawaited(_liveLocationService.stop());
    }
  }
}

final sosControllerProvider =
    AsyncNotifierProvider<SosController, SosSessionState>(SosController.new);
