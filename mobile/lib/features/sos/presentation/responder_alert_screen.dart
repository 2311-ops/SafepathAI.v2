import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared_widgets/primary_button.dart';
import '../../family/application/family_controller.dart';
import '../../family/data/family_models.dart';
import '../application/sos_responder_controller.dart';
import '../data/sos_api.dart';
import '../data/sos_models.dart';

/// Guardian-side full-screen responder experience
/// (03-UI-SPEC.md "Full-Screen Responder Alert Screen"). Force-navigated to
/// on an incoming SOS regardless of what the guardian is doing in the app
/// (D-20). Phase 3's only two responder actions are Acknowledge and Call
/// sender (D-22) — there is no "mark resolved" or dismiss control anywhere
/// on this screen (D-23).
class ResponderAlertScreen extends ConsumerStatefulWidget {
  const ResponderAlertScreen({super.key, required this.sessionId});

  /// The `sosSessionId` route path parameter. The screen's content is
  /// driven by [sosResponderControllerProvider]'s live state (already
  /// populated by the same event that triggered navigation here), not a
  /// separate fetch-by-id — a cold-start fetch-by-id path is plan 03-06's
  /// FCM deep-link scope.
  final String sessionId;

  @override
  ConsumerState<ResponderAlertScreen> createState() =>
      _ResponderAlertScreenState();
}

class _ResponderAlertScreenState extends ConsumerState<ResponderAlertScreen> {
  bool _acknowledging = false;
  String? _loadingSessionId;
  Object? _loadError;

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadSessionIfMissing);
  }

  @override
  void didUpdateWidget(covariant ResponderAlertScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sessionId != widget.sessionId) {
      _loadError = null;
      Future.microtask(_loadSessionIfMissing);
    }
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

    return Scaffold(
      body: SafeArea(
        child: session.status == SosSessionStatus.canceled
            ? _CanceledPlaceholderBody(session: session)
            : _IncomingBody(
                session: session,
                acknowledgedAtUtc: acknowledgedAtUtc,
                acknowledging: _acknowledging,
                onAcknowledge: _acknowledge,
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
  });

  final SosSession session;
  final DateTime? acknowledgedAtUtc;
  final bool acknowledging;
  final Future<void> Function() onAcknowledge;

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
                  // Owned by plan 03-08: live-location map/pin card with an
                  // explicit end-time/countdown (D-21).
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
    // No phone number is ever present on SosSession (threat T-03-03) — the
    // OS dialler receives it without this screen ever displaying it. A real
    // number requires a phone field on the wire contract that does not yet
    // exist for family members (only EmergencyContact carries one, a
    // separate sender-side fallback); this opens the bare dialler until
    // that field lands. See 03-04-SUMMARY.md Known Stubs.
    final uri = Uri(scheme: 'tel', path: '');
    await launchUrl(uri);
  }
}

/// Owned by plan 03-09: deep-teal chrome, the "Canceled by {sender name} at
/// {time}" copy, and a "Close" action. This plan renders a minimal,
/// non-empty placeholder so the switch above stays exhaustive today.
class _CanceledPlaceholderBody extends StatelessWidget {
  const _CanceledPlaceholderBody({required this.session});

  final SosSession session;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Text(
          'This alert was canceled.',
          textAlign: TextAlign.center,
          style: AppTypography.heading,
        ),
      ),
    );
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
