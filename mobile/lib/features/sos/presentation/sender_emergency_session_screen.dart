import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared_widgets/primary_button.dart';
import '../application/sos_controller.dart';
import '../application/sos_session_state.dart';
import '../data/sos_models.dart';
import 'delivery_status_chip.dart';

/// Full-screen sender emergency session (03-UI-SPEC.md "Full-Screen Sender
/// Emergency Session — State Machine"). This is the one screen in the app
/// where SOS red is the dominant surface — the screen literally *is* the
/// emergency, not a dilution of the reservation rule.
///
/// This plan renders [SosSubmitted] and [SosDelivering] in full; the
/// remaining sealed states ([SosOfflineQueued], [SosLiveActive],
/// [SosCanceled]) render a non-empty placeholder body so the switch below
/// stays exhaustive today — each is named at its call site with the plan
/// that owns its locked treatment.
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
      body = const _SendingBody(
        key: ValueKey('sos-error'),
        headline: 'Not sent yet',
        message:
            "We couldn't confirm delivery to anyone yet. Keep trying — this "
            'screen will keep retrying automatically.',
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
          // Owned by plan 03-07: offline/retrying chrome ("Not sent yet,
          // retrying… Last retry: {relative time}") plus local fallback
          // actions ("Call {emergency contact}", "Copy my location") that
          // work with zero network.
          SosOfflineQueued() => const _SendingBody(
            headline: 'Your emergency is in progress',
            message: 'Not sent yet — still trying to reach your guardians.',
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
