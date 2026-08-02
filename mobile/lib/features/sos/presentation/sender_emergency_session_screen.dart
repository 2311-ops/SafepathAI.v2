import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared_widgets/primary_button.dart';
import '../../location/application/location_controller.dart';
import '../../location/data/location_models.dart';
import '../application/emergency_contacts_controller.dart';
import '../application/sos_controller.dart';
import '../application/sos_session_state.dart';
import '../data/sos_api.dart';
import '../data/sos_models.dart';
import 'delivery_status_chip.dart';

/// Full-screen sender emergency session (03-UI-SPEC.md "Full-Screen Sender
/// Emergency Session — State Machine"). This is the one screen in the app
/// where SOS red is the dominant surface — the screen literally *is* the
/// emergency, not a dilution of the reservation rule.
///
/// This plan renders [SosSubmitted], [SosDelivering] and [SosOfflineQueued]
/// in full; the remaining sealed states ([SosLiveActive], [SosCanceled])
/// render a non-empty placeholder body so the switch below stays exhaustive
/// today — each is named at its call site with the plan that owns its
/// locked treatment.
class SenderEmergencySessionScreen extends ConsumerStatefulWidget {
  const SenderEmergencySessionScreen({super.key});

  @override
  ConsumerState<SenderEmergencySessionScreen> createState() =>
      _SenderEmergencySessionScreenState();
}

class _SenderEmergencySessionScreenState
    extends ConsumerState<SenderEmergencySessionScreen> {
  Timer? _elapsedTicker;

  @override
  void initState() {
    super.initState();
    // Drives the delivering headline's mm:ss elapsed timer. A local UI
    // tick, not a network poll — the underlying session data is unaffected.
    _elapsedTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _elapsedTicker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final asyncState = ref.watch(sosControllerProvider);
    final sessionState = asyncState.value;

    final Widget body;
    if (asyncState.hasError && !asyncState.isLoading) {
      // Reached only for a non-network rejection (validation/forbidden) —
      // Task 1's offline queue routes every network failure through
      // SosOfflineQueued instead, which owns the "still retrying" copy
      // below. A genuine rejection is not retried automatically, so this
      // copy must never imply that it is.
      final error = asyncState.error;
      final serverMessage = error is SosApiException ? error.message : null;
      body = _SendingBody(
        key: const ValueKey('sos-error'),
        headline: 'Not sent yet',
        message: (serverMessage?.isNotEmpty ?? false)
            ? serverMessage!
            : "We couldn't send this alert. Please try again.",
      );
    } else if (sessionState == null) {
      // arm() has generated and persisted the session id, but the network
      // request hasn't resolved yet — this is the moment right after the
      // hold completes, before the server has acknowledged anything.
      body = const _SendingBody(
        key: ValueKey('sos-pending'),
        headline: 'Sending alert…',
        message: "Please hold on — we're reaching your guardians.",
      );
    } else {
      body = KeyedSubtree(
        key: ValueKey(sessionState.runtimeType),
        child: switch (sessionState) {
          SosIdle() => const _SendingBody(
            headline: 'Sending alert…',
            message: "Please hold on — we're reaching your guardians.",
          ),
          SosSubmitted() => const _SendingBody(
            headline: 'Sending alert…',
            message:
                "We've received your alert and are notifying your "
                'guardians.',
          ),
          SosDelivering(:final session) => _DeliveringWithRecipientsBody(
            session: session,
          ),
          SosOfflineQueued(:final lastRetryAtUtc, :final retryCount) =>
            _OfflineQueuedBody(
              lastRetryAtUtc: lastRetryAtUtc,
              retryCount: retryCount,
              reduceMotion: reduceMotion,
            ),
          // Owned by plan 03-08: live-location streaming window + countdown
          // ("Live until {end time} · {mm:ss} remaining").
          SosLiveActive(:final session) => _DeliveringBody(session: session),
          // Owned by plan 03-09: hold-to-cancel gesture + the de-escalated
          // Deep Teal canceled-state chrome (self-cancel is never red).
          SosCanceled(:final session) => _DeliveringBody(session: session),
        },
      );
    }

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            colors: [AppColors.sosRed, AppColors.sosRedDeep],
            radius: 1.1,
          ),
        ),
        child: SafeArea(
          child: reduceMotion
              ? body
              : AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  switchInCurve: Curves.easeOut,
                  switchOutCurve: Curves.easeOut,
                  transitionBuilder: (child, animation) =>
                      FadeTransition(opacity: animation, child: child),
                  child: body,
                ),
        ),
      ),
    );
  }
}

/// Headline + frosted-card body copy, centered — used for every state that
/// has no per-recipient delivery list to show yet.
class _SendingBody extends StatelessWidget {
  const _SendingBody({
    super.key,
    required this.headline,
    required this.message,
  });

  final String headline;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              headline,
              textAlign: TextAlign.center,
              style: AppTypography.heading.copyWith(color: Colors.white),
            ),
            const SizedBox(height: AppSpacing.md),
            _FrostedCard(
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: AppTypography.body.copyWith(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The delivering headline shows elapsed time since trigger: per-channel
/// delivery is in progress and "Call 911" is the one non-red CTA on the
/// screen — deliberate so the highest-urgency escalation never blends into
/// the red chrome.
class _DeliveringBody extends StatelessWidget {
  const _DeliveringBody({required this.session});

  final SosSession session;

  @override
  Widget build(BuildContext context) {
    final elapsed = DateTime.now().toUtc().difference(session.triggeredAtUtc);
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _FrostedCard(
            child: Text(
              'Alert active · ${_formatElapsed(elapsed)} elapsed',
              textAlign: TextAlign.center,
              style: AppTypography.caption.copyWith(
                color: Colors.white,
                letterSpacing: 0,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          PrimaryButton(
            label: 'Call 911',
            backgroundColor: AppColors.ink,
            foregroundColor: Colors.white,
            onPressed: () => _call911(),
          ),
        ],
      ),
    );
  }

  Future<void> _call911() async {
    final uri = Uri(scheme: 'tel', path: '911');
    await launchUrl(uri);
  }
}

/// The Delivering state's real body (03-UI-SPEC.md "Delivery Status
/// Vocabulary", D-09/D-10): the elapsed header plus a scrollable list of one
/// [RecipientDeliveryRow] per recipient — never a single aggregate
/// checkmark. Shows the locked empty-state copy (see [_NoRecipientsEmptyState])
/// when the server resolved zero recipients, so a nowhere-to-send SOS never
/// silently looks like it is working.
class _DeliveringWithRecipientsBody extends StatelessWidget {
  const _DeliveringWithRecipientsBody({required this.session});

  final SosSession session;

  @override
  Widget build(BuildContext context) {
    final elapsed = DateTime.now().toUtc().difference(session.triggeredAtUtc);
    final recipients = session.recipients;

    return Column(
      children: [
        const SizedBox(height: AppSpacing.md),
        _FrostedCard(
          child: Text(
            'Alert active · ${_formatElapsed(elapsed)} elapsed',
            textAlign: TextAlign.center,
            style: AppTypography.caption.copyWith(
              color: Colors.white,
              letterSpacing: 0,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Expanded(
          child: recipients.isEmpty
              ? const _NoRecipientsEmptyState()
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                  ),
                  itemCount: recipients.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, index) =>
                      RecipientDeliveryRow(recipient: recipients[index]),
                ),
        ),
        const SizedBox(height: AppSpacing.xl),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: PrimaryButton(
            label: 'Call 911',
            backgroundColor: AppColors.ink,
            foregroundColor: Colors.white,
            onPressed: () => _call911(),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
      ],
    );
  }

  Future<void> _call911() async {
    final uri = Uri(scheme: 'tel', path: '911');
    await launchUrl(uri);
  }
}

/// D-11's server-side recipient resolution can legitimately return zero
/// recipients (no Guardians/emergency contacts configured yet) — this must
/// never silently look like the alert is working when it has nowhere to go.
class _NoRecipientsEmptyState extends StatelessWidget {
  const _NoRecipientsEmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'No one to alert yet.',
              textAlign: TextAlign.center,
              style: AppTypography.heading.copyWith(color: Colors.white),
            ),
            const SizedBox(height: AppSpacing.md),
            _FrostedCard(
              child: Text(
                'Add a guardian or emergency contact in your Family Circle '
                'so SOS has somewhere to send help.',
                textAlign: TextAlign.center,
                style: AppTypography.body.copyWith(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Offline/queued state (D-12, D-17): reached the instant the hold completes
/// with no connectivity, or resumed at cold start over a still-pending
/// trigger (D-14). Chrome is the same red gradient as every other active
/// state, deliberately with **no pulse ring and no blinking live dot** — a
/// calm, static background says "this is still an emergency" without
/// implying progress that is not happening yet. Only the retry timestamp
/// below animates, and only a 150ms cross-fade, never the whole screen.
class _OfflineQueuedBody extends StatelessWidget {
  const _OfflineQueuedBody({
    required this.lastRetryAtUtc,
    required this.retryCount,
    required this.reduceMotion,
  });

  final DateTime lastRetryAtUtc;
  final int retryCount;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    // No retry has actually happened yet (the very first cold-start moment
    // before the first resubmit resolves) — render without a placeholder
    // timestamp rather than implying a retry that hasn't occurred.
    final retrySuffix = retryCount > 0
        ? ' Last retry: ${_relativeTime(lastRetryAtUtc)}'
        : '';
    final bodyText = 'Not sent yet, retrying…$retrySuffix';

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Not sent yet',
            textAlign: TextAlign.center,
            style: AppTypography.heading.copyWith(color: Colors.white),
          ),
          const SizedBox(height: AppSpacing.md),
          _FrostedCard(
            child: reduceMotion
                ? Text(
                    bodyText,
                    textAlign: TextAlign.center,
                    style: AppTypography.body.copyWith(color: Colors.white),
                  )
                : AnimatedSwitcher(
                    duration: const Duration(milliseconds: 150),
                    transitionBuilder: (child, animation) =>
                        FadeTransition(opacity: animation, child: child),
                    child: Text(
                      bodyText,
                      key: ValueKey(bodyText),
                      textAlign: TextAlign.center,
                      style: AppTypography.body.copyWith(color: Colors.white),
                    ),
                  ),
          ),
          const SizedBox(height: AppSpacing.xl),
          const _CallContactAction(),
          const SizedBox(height: AppSpacing.md),
          const _CopyLocationAction(),
          const SizedBox(height: AppSpacing.xl),
          _FrostedCard(
            child: Text(
              "We couldn't confirm delivery to anyone yet. Keep trying — "
              'this screen will keep retrying automatically.',
              textAlign: TextAlign.center,
              style: AppTypography.body.copyWith(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

/// "Call {emergency contact name}" — works with zero network via a native
/// `tel:` intent (D-17). With no contact configured, this renders as a link
/// to the emergency-contacts screen (plan 03-07 Task 2) instead of a dead
/// button, so the offline session never shows a control that does nothing.
class _CallContactAction extends ConsumerWidget {
  const _CallContactAction();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contacts =
        ref.watch(emergencyContactsControllerProvider).value?.contacts ??
        const [];

    if (contacts.isEmpty) {
      return _OfflineActionButton(
        icon: Icons.call,
        label: 'Add an emergency contact to call',
        onPressed: () => context.push('/settings/emergency-contacts'),
      );
    }

    final contact = contacts.first;
    return _OfflineActionButton(
      icon: Icons.call,
      label: 'Call ${contact.displayName}',
      onPressed: () => _call(contact.phoneNumberE164),
    );
  }

  Future<void> _call(String phoneNumberE164) async {
    final uri = Uri(scheme: 'tel', path: phoneNumberE164);
    await launchUrl(uri);
  }
}

/// The local copy-location fallback action — writes the last known fix to
/// the system clipboard as a human-pasteable string plus a maps link, so it
/// can be pasted into any messaging app when the network path has failed
/// (D-17, T-03-25: a user-initiated, never-automatic clipboard write).
/// Disabled (never a silent no-op copying an empty string) when no fix is
/// available yet.
class _CopyLocationAction extends ConsumerWidget {
  const _CopyLocationAction();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final position = ref.watch(locationControllerProvider).value?.selfPosition;

    return Column(
      children: [
        _OfflineActionButton(
          icon: Icons.copy_all,
          label: 'Copy my location',
          onPressed: position == null
              ? null
              : () => _copy(context, position),
        ),
        if (position == null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            'No location fix yet — try again once one is available.',
            textAlign: TextAlign.center,
            style: AppTypography.caption.copyWith(
              color: Colors.white.withValues(alpha: 0.85),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _copy(BuildContext context, LiveLocation position) async {
    final mapsUrl =
        'https://maps.google.com/?q=${position.lat},${position.lng}';
    await Clipboard.setData(
      ClipboardData(
        text: 'My location: ${position.lat}, ${position.lng}\n$mapsUrl',
      ),
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Location copied')));
  }
}

/// Shared styling for the two offline local-fallback actions — a frosted,
/// icon-labelled button so both read as available-but-secondary next to the
/// dominant red chrome, never blending into it (contrast rule).
class _OfflineActionButton extends StatelessWidget {
  const _OfflineActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          backgroundColor: Colors.white.withValues(alpha: 0.12),
          disabledBackgroundColor: Colors.white.withValues(alpha: 0.08),
          foregroundColor: Colors.white,
          disabledForegroundColor: Colors.white.withValues(alpha: 0.5),
          textStyle: AppTypography.ctaLabel,
          padding: const EdgeInsets.symmetric(vertical: 17),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}

/// Short, human relative-time phrasing for the "Last retry" clause — no
/// third-party date-formatting package needed for a handful of buckets.
String _relativeTime(DateTime atUtc) {
  final elapsed = DateTime.now().toUtc().difference(atUtc);
  if (elapsed.inSeconds < 5) return 'just now';
  if (elapsed.inSeconds < 60) return '${elapsed.inSeconds}s ago';
  if (elapsed.inMinutes < 60) return '${elapsed.inMinutes}m ago';
  return '${elapsed.inHours}h ago';
}

/// Contrast rule (03-UI-SPEC.md): any text below 20px/700+ must sit on this
/// frosted card (or the gradient's darker end) rather than directly on the
/// lighter red — white-on-`#DE3B40` at full opacity only clears the large-
/// text contrast floor, not the small-text one.
class _FrostedCard extends StatelessWidget {
  const _FrostedCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: child,
      ),
    );
  }
}

String _formatElapsed(Duration elapsed) {
  final totalSeconds = elapsed.inSeconds < 0 ? 0 : elapsed.inSeconds;
  final minutes = totalSeconds ~/ 60;
  final seconds = totalSeconds % 60;
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}
