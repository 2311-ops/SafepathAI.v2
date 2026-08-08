import '../data/sos_models.dart';

/// The sender-side SOS emergency-session state machine (03-UI-SPEC.md "Full-
/// Screen Sender Emergency Session — State Machine"). A Dart 3 sealed union
/// rather than a single `copyWith` class (the `LocationState` shape) because
/// these states carry genuinely different payloads, not variations of one
/// shape.
///
/// [SosOfflineQueued], [SosLiveActive] and [SosCanceled] are constructed by
/// plans 03-07, 03-08 and 03-09 respectively — declared now so those plans
/// add rendering, not new state types. This plan only ever constructs
/// [SosIdle] and [SosSubmitted]; the "sending in progress" moment between
/// `arm()` generating a session id and `submit()` resolving is represented
/// by the surrounding `AsyncNotifier`'s own `AsyncLoading` state, not a
/// dedicated sealed subclass.
sealed class SosSessionState {
  const SosSessionState();
}

/// No emergency in progress.
class SosIdle extends SosSessionState {
  const SosIdle();
}

/// Armed while offline: the trigger has not yet reached the server. Owned by
/// plan 03-07.
class SosOfflineQueued extends SosSessionState {
  const SosOfflineQueued({
    required this.sessionId,
    required this.lastRetryAtUtc,
    required this.retryCount,
  });

  final String sessionId;
  final DateTime lastRetryAtUtc;
  final int retryCount;
}

/// The server has accepted the trigger but no delivery channel has
/// confirmed yet. Headline copy here must never claim "Sent" (D-10).
class SosSubmitted extends SosSessionState {
  const SosSubmitted(this.session);

  final SosSession session;
}

/// At least one channel dispatch has been attempted; per-recipient/per-
/// channel status is available on [session].
class SosDelivering extends SosSessionState {
  const SosDelivering(this.session);

  final SosSession session;
}

/// The live-location streaming window is open. Owned by plan 03-08.
class SosLiveActive extends SosSessionState {
  const SosLiveActive(this.session, this.windowEndsAtUtc);

  final SosSession session;
  final DateTime windowEndsAtUtc;
}

/// The sender canceled the alert via the hold-to-cancel gesture. Owned by
/// plan 03-09.
class SosCanceled extends SosSessionState {
  const SosCanceled(this.session, this.canceledAtUtc);

  final SosSession session;
  final DateTime canceledAtUtc;
}
