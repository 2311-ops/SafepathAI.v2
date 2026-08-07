import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared_widgets/primary_button.dart';
import '../../family/application/family_controller.dart';
import '../../family/data/family_models.dart';
import '../../location/application/map_geometry.dart';
import '../../location/presentation/vector_map.dart';
import '../application/sos_responder_controller.dart';
import '../data/sos_api.dart';
import '../data/sos_hub_client.dart';
import '../data/sos_models.dart';
import 'sos_countdown.dart';

/// Guardian-side full-screen responder experience
/// (03-UI-SPEC.md "Full-Screen Responder Alert Screen"). Force-navigated to
/// on an incoming SOS regardless of what the guardian is doing in the app
/// (D-20). Phase 3's only two responder actions are Acknowledge and Call
/// sender (D-22) — there is no "mark resolved" or dismiss control anywhere
/// on this screen (D-23).
class ResponderAlertScreen extends ConsumerStatefulWidget {
  const ResponderAlertScreen({
    super.key,
    required this.sessionId,
    @visibleForTesting this.mapPlatformViewBuilder,
  });

  /// The `sosSessionId` route path parameter. The screen's content is
  /// driven by [sosResponderControllerProvider]'s live state (already
  /// populated by the same event that triggered navigation here), not a
  /// separate fetch-by-id — a cold-start fetch-by-id path is plan 03-06's
  /// FCM deep-link scope.
  final String sessionId;

  /// Test seam threaded straight through to [VectorMap]'s identically-
  /// scoped seam (`live_map_screen.dart`'s own convention) so a widget test
  /// never mounts a real platform view. Production callers leave this null.
  @visibleForTesting
  final WidgetBuilder? mapPlatformViewBuilder;

  @override
  ConsumerState<ResponderAlertScreen> createState() =>
      _ResponderAlertScreenState();
}

class _ResponderAlertScreenState extends ConsumerState<ResponderAlertScreen> {
  bool _acknowledging = false;
  String? _loadingSessionId;
  Object? _loadError;
  StreamSubscription<SosLocationUpdate>? _liveLocationSubscription;
  SosLocationUpdate? _liveLocationUpdate;
  Timer? _liveWindowExpiryTimer;
  bool _liveWindowExpired = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadSessionIfMissing);
    // Read once (not watch): this subscription's own lifetime is owned by
    // this State, not rebuilt on every provider change — mirrors
    // SosResponderController's own one-subscription-per-connection
    // convention, just scoped to this screen instead of that controller.
    _liveLocationSubscription = ref
        .read(sosHubClientProvider)
        .liveLocationUpdates
        .listen(_applyLiveLocationUpdate);
  }

  @override
  void didUpdateWidget(covariant ResponderAlertScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sessionId != widget.sessionId) {
      _loadError = null;
      _liveLocationUpdate = null;
      _liveWindowExpired = false;
      _liveWindowExpiryTimer?.cancel();
      Future.microtask(_loadSessionIfMissing);
    }
  }

  @override
  void dispose() {
    unawaited(_liveLocationSubscription?.cancel());
    _liveWindowExpiryTimer?.cancel();
    super.dispose();
  }

  /// Updates stop applying the moment the window is known to have closed —
  /// the last known position and countdown-at-zero stay on screen rather
  /// than being blanked, since that is the most useful state to leave a
  /// guardian with (the sender is presumably still wherever they last
  /// reported, not "nowhere").
  void _applyLiveLocationUpdate(SosLocationUpdate update) {
    if (update.sosSessionId != widget.sessionId) return;
    if (_liveWindowExpired) return;
    if (!mounted) return;
    setState(() => _liveLocationUpdate = update);
    _scheduleLiveWindowExpiry(update.windowEndsAtUtc);
  }

  void _scheduleLiveWindowExpiry(DateTime windowEndsAtUtc) {
    _liveWindowExpiryTimer?.cancel();
    final delay = windowEndsAtUtc.difference(DateTime.now().toUtc());
    _liveWindowExpiryTimer = Timer(delay.isNegative ? Duration.zero : delay, () {
      if (!mounted) return;
      setState(() => _liveWindowExpired = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final responderState = ref.watch(sosResponderControllerProvider).value;
    final activeSession = responderState?.activeSession;
    final session = activeSession?.sosSessionId == widget.sessionId
        ? activeSession
        : null;
    final acknowledgedAtUtc = responderState?.acknowledgedAtUtc;

    if (session == null) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: _loadError == null
                ? const CircularProgressIndicator()
                : Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "Couldn't load this SOS.",
                          textAlign: TextAlign.center,
                          style: AppTypography.heading,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        PrimaryButton(
                          label: 'Retry',
                          onPressed: _loadSessionIfMissing,
                        ),
                      ],
                    ),
                  ),
          ),
        ),
      );
    }

    // The window end this screen defers to: the most recent live update's
    // own value once one arrives, falling back to the session's own
    // server-issued liveWindowEndsAtUtc so the countdown renders
    // immediately rather than waiting on the first hub push (D-21).
    final windowEndsAtUtc =
        _liveLocationUpdate?.windowEndsAtUtc ?? session.liveWindowEndsAtUtc;

    return Scaffold(
      body: SafeArea(
        child: session.status == SosSessionStatus.canceled
            ? _CanceledBody(
                session: session,
                liveWindowEndsAtUtc: windowEndsAtUtc,
                liveLocationUpdate: _liveLocationUpdate,
                mapPlatformViewBuilder: widget.mapPlatformViewBuilder,
              )
            : _IncomingBody(
                session: session,
                acknowledgedAtUtc: acknowledgedAtUtc,
                acknowledging: _acknowledging,
                onAcknowledge: _acknowledge,
                liveWindowEndsAtUtc: windowEndsAtUtc,
                liveLocationUpdate: _liveLocationUpdate,
                mapPlatformViewBuilder: widget.mapPlatformViewBuilder,
              ),
      ),
    );
  }

  Future<void> _acknowledge() async {
    if (_acknowledging) return;
    setState(() => _acknowledging = true);
    try {
      await ref.read(sosResponderControllerProvider.notifier).acknowledge();
    } finally {
      if (mounted) setState(() => _acknowledging = false);
    }
  }

  Future<void> _loadSessionIfMissing() async {
    final current = ref
        .read(sosResponderControllerProvider)
        .value
        ?.activeSession;
    if (current?.sosSessionId == widget.sessionId) return;
    if (_loadingSessionId == widget.sessionId) return;

    setState(() {
      _loadingSessionId = widget.sessionId;
      _loadError = null;
    });

    try {
      final session = await ref
          .read(sosApiProvider)
          .getSession(widget.sessionId);
      if (!mounted || _loadingSessionId != widget.sessionId) return;
      ref.read(sosResponderControllerProvider.notifier).showSession(session);
      setState(() {
        _loadingSessionId = null;
        _loadError = null;
      });
    } catch (error) {
      if (!mounted || _loadingSessionId != widget.sessionId) return;
      setState(() {
        _loadingSessionId = null;
        _loadError = error;
      });
    }
  }
}

class _IncomingBody extends ConsumerWidget {
  const _IncomingBody({
    required this.session,
    required this.acknowledgedAtUtc,
    required this.acknowledging,
    required this.onAcknowledge,
    required this.liveWindowEndsAtUtc,
    required this.liveLocationUpdate,
    required this.mapPlatformViewBuilder,
  });

  final SosSession session;
  final DateTime? acknowledgedAtUtc;
  final bool acknowledging;
  final Future<void> Function() onAcknowledge;

  /// The window end this screen defers to (D-21) — null only when this
  /// session predates 03-08 or the server never opened a live window for
  /// it, in which case the live-location card is omitted entirely.
  final DateTime? liveWindowEndsAtUtc;

  /// The sender's most recently reported live position, or null before the
  /// first `LiveLocationWindowUpdate` arrives.
  final SosLocationUpdate? liveLocationUpdate;

  final WidgetBuilder? mapPlatformViewBuilder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final members =
        ref.watch(familyControllerProvider).value?.members ?? const [];
    final senderName = _senderDisplayName(members, session.triggeredByUserId);
    final isAcknowledged = acknowledgedAtUtc != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DecoratedBox(
          key: const ValueKey('responder-header-strip'),
          decoration: const BoxDecoration(color: AppColors.sosRed),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Text(
                '$senderName triggered SOS',
                textAlign: TextAlign.center,
                style: AppTypography.heading.copyWith(color: Colors.white),
              ),
            ),
          ),
        ),
        Expanded(
          child: DecoratedBox(
            decoration: const BoxDecoration(color: AppColors.appBg),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (liveWindowEndsAtUtc != null)
                    _LiveLocationCard(
                      windowEndsAtUtc: liveWindowEndsAtUtc!,
                      update: liveLocationUpdate,
                      mapPlatformViewBuilder: mapPlatformViewBuilder,
                    )
                  else
                    const Spacer(),
                  if (isAcknowledged)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: Text(
                        'You acknowledged this alert at '
                        '${_formatTime(acknowledgedAtUtc!)}',
                        textAlign: TextAlign.center,
                        style: AppTypography.caption,
                      ),
                    ),
                  PrimaryButton(
                    label: isAcknowledged ? 'Acknowledged' : 'Acknowledge',
                    backgroundColor: AppColors.primaryTeal,
                    foregroundColor: Colors.white,
                    onPressed: isAcknowledged || acknowledging
                        ? null
                        : () => onAcknowledge(),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  PrimaryButton(label: 'Call sender', onPressed: _callSender),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _callSender() async {
    // The server only populates this field for this session's actual
    // delivery recipients (SosSessionProjection, quick 260807-rk2) — this
    // screen hands it straight to the OS dialler without ever rendering it
    // anywhere on screen. A null value (a non-recipient, the sender's own
    // screen, or a sender who never stored a number) keeps exactly today's
    // bare-dialler fallback — no error, no crash.
    final uri = sosDialUri(session.triggeredByPhoneNumberE164);
    await launchUrl(uri);
  }
}

/// Builds the tel-scheme URI `_callSender` hands to the OS dialler. A
/// null/blank [phoneNumberE164] produces an empty-path `tel:` URI —
/// reproducing today's bare-dialler behaviour exactly rather than crashing
/// or silently doing nothing. Exposed at top level (rather than kept
/// private) so `sos_call_sender_test.dart` can assert the URI construction
/// directly instead of going through `launchUrl`, which has no platform
/// channel handler in a widget test.
@visibleForTesting
Uri sosDialUri(String? phoneNumberE164) {
  final trimmed = phoneNumberE164?.trim();
  return Uri(scheme: 'tel', path: trimmed == null || trimmed.isEmpty ? '' : trimmed);
}

/// The live-location streaming window card (03-08-PLAN.md, D-21): the same
/// labelled live indicator and "Live until {end time} · {mm:ss} remaining"
/// countdown vocabulary as the sender's own Live-active state, above a map
/// showing the sender's latest reported position. Renders an explanatory
/// placeholder instead of an empty map before the first position arrives,
/// and keeps showing the last known position (rather than blanking) once
/// [ResponderAlertScreen] stops applying further updates at window expiry —
/// that is the most useful thing left on screen, not "nowhere".
class _LiveLocationCard extends StatelessWidget {
  const _LiveLocationCard({
    required this.windowEndsAtUtc,
    required this.update,
    required this.mapPlatformViewBuilder,
  });

  final DateTime windowEndsAtUtc;
  final SosLocationUpdate? update;
  final WidgetBuilder? mapPlatformViewBuilder;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        children: [
          const SosLiveIndicator(color: AppColors.ink),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'Live until ${_formatTime(windowEndsAtUtc)} · ',
                style: AppTypography.body,
              ),
              SosCountdown(endsAtUtc: windowEndsAtUtc),
              Text(' remaining', style: AppTypography.body),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              height: 200,
              child: update == null
                  ? const _AwaitingLivePositionPlaceholder()
                  : VectorMap(
                      initialTarget: MapPoint(update!.latitude, update!.longitude),
                      initialZoom: 16,
                      markers: [
                        OverlayMarker(
                          id: 'sender-live-location',
                          lat: update!.latitude,
                          lng: update!.longitude,
                          width: 32,
                          height: 32,
                          child: const _SenderLiveMarker(),
                        ),
                      ],
                      // Both fields are test-only seams, mirroring
                      // live_map_screen.dart's identical pass-through.
                      // ignore: invalid_use_of_visible_for_testing_member
                      platformViewBuilder: mapPlatformViewBuilder,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Sender's live-position pin on the responder's map — SOS red, since this
/// marker only ever exists during an active emergency.
class _SenderLiveMarker extends StatelessWidget {
  const _SenderLiveMarker();

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.sosRed,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.surface, width: 3),
        boxShadow: const [
          BoxShadow(
            color: Color(0x330C3A3F),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: const Icon(Icons.person_pin_circle, color: Colors.white, size: 18),
    );
  }
}

/// Shown in place of the map before the first `LiveLocationWindowUpdate`
/// arrives — an empty map with no explanation would read as broken, not as
/// "still waiting for a fix" (mirrors the sender screen's own
/// never-silently-empty rule for the offline session state).
class _AwaitingLivePositionPlaceholder extends StatelessWidget {
  const _AwaitingLivePositionPlaceholder();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.hairlineSoft,
      child: Center(
        child: Text(
          'Waiting for a live position…',
          textAlign: TextAlign.center,
          style: AppTypography.caption,
        ),
      ),
    );
  }
}

/// The sender-canceled state's real body (03-UI-SPEC.md "Sender-canceled"
/// row, D-05/D-24): the header shifts from red to the same Deep Teal used
/// on the sender's own Self-canceled screen, the locked copy names who
/// canceled and when (see the `Text` below), Acknowledge is replaced by a
/// single "Close" action, and the last known live-location card stays
/// visible rather than being cleared — a guardian who glances at this
/// screen after the fact still needs to see where the sender last reported
/// from. This screen never auto-navigates away on its own; only the
/// guardian's own tap on Close leaves it (D-23/D-24 — no auto-dismiss, no
/// "mark resolved").
class _CanceledBody extends ConsumerWidget {
  const _CanceledBody({
    required this.session,
    required this.liveWindowEndsAtUtc,
    required this.liveLocationUpdate,
    required this.mapPlatformViewBuilder,
  });

  final SosSession session;
  final DateTime? liveWindowEndsAtUtc;
  final SosLocationUpdate? liveLocationUpdate;
  final WidgetBuilder? mapPlatformViewBuilder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final members =
        ref.watch(familyControllerProvider).value?.members ?? const [];
    final senderName = _senderDisplayName(members, session.triggeredByUserId);
    final canceledAt = session.canceledAtUtc;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DecoratedBox(
          key: const ValueKey('responder-header-strip'),
          decoration: const BoxDecoration(color: AppColors.deepTeal),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Text(
                'Canceled by $senderName'
                '${canceledAt != null ? ' at ${_formatTime(canceledAt)}' : ''}',
                textAlign: TextAlign.center,
                style: AppTypography.heading.copyWith(color: Colors.white),
              ),
            ),
          ),
        ),
        Expanded(
          child: DecoratedBox(
            decoration: const BoxDecoration(color: AppColors.appBg),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (liveWindowEndsAtUtc != null)
                    _LiveLocationCard(
                      windowEndsAtUtc: liveWindowEndsAtUtc!,
                      update: liveLocationUpdate,
                      mapPlatformViewBuilder: mapPlatformViewBuilder,
                    )
                  else
                    const Spacer(),
                  PrimaryButton(
                    label: 'Close',
                    onPressed: () => _handleClose(context),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _handleClose(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/home');
    }
  }
}

String _senderDisplayName(
  List<FamilyMemberView> members,
  String triggeredByUserId,
) {
  for (final member in members) {
    if (member.userId == triggeredByUserId) {
      return member.displayName ?? 'A family member';
    }
  }
  return 'A family member';
}

String _formatTime(DateTime time) {
  final local = time.toLocal();
  final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final minute = local.minute.toString().padLeft(2, '0');
  final suffix = local.hour >= 12 ? 'PM' : 'AM';
  return '$hour:$minute $suffix';
}
