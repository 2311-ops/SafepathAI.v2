import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared_widgets/primary_button.dart';
import '../../../shared_widgets/safepath_card.dart';
import '../../../shared_widgets/secondary_button.dart';
import '../application/family_controller.dart';
import '../data/family_models.dart';

/// Invite member (F1-5) — QR + short mono share code + "Copy link" + native
/// "Share" (`share_plus`). Locked decision D3: there is deliberately **no
/// email-address input field** — the native share sheet's own Mail option is
/// how FAM-02 ("invite by email") is satisfied at the transport layer.
class InviteMemberScreen extends ConsumerStatefulWidget {
  const InviteMemberScreen({super.key});

  @override
  ConsumerState<InviteMemberScreen> createState() => _InviteMemberScreenState();
}

class _InviteMemberScreenState extends ConsumerState<InviteMemberScreen> {
  String? _requestedInviteForFamilyId;

  void _maybeGenerateInvite(FamilyState? familyState) {
    final familyId = familyState?.family?.id;
    if (familyId == null ||
        familyState?.latestInvite != null ||
        _requestedInviteForFamilyId == familyId) {
      return;
    }

    _requestedInviteForFamilyId = familyId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(familyControllerProvider.notifier).generateInvite(familyId);
    });
  }

  void _retryGenerateInvite() {
    final familyId = ref.read(familyControllerProvider).value?.family?.id;
    if (familyId == null) return;
    _requestedInviteForFamilyId = familyId;
    ref.read(familyControllerProvider.notifier).generateInvite(familyId);
  }

  /// The QR payload / "Copy link" target. There is no universal-link route
  /// registered for this scheme in this phase (accept is via manual code
  /// entry on `/invite/accept` — see 01-07-SUMMARY.md deviations); the QR
  /// still carries the full opaque link token so a future deep-link handler
  /// can be wired up without changing the invite payload shape.
  String _inviteLink(Invitation invite) =>
      'safepathai://invite?token=${invite.linkToken}';

  Future<void> _onCopyLink(Invitation invite) async {
    await Clipboard.setData(ClipboardData(text: _inviteLink(invite)));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Invite link copied')));
  }

  Future<void> _onShare(Invitation invite) async {
    await SharePlus.instance.share(
      ShareParams(
        text:
            'Join our SafePath AI family circle: ${_inviteLink(invite)}\n'
            'Code: ${invite.code} (expires in 24h)',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final familyState = ref.watch(familyControllerProvider).value;
    _maybeGenerateInvite(familyState);
    final family = familyState?.family;
    final invite = familyState?.latestInvite;
    // Exclude the invite currently on display above — "Pending" lists
    // previously-generated, still-unredeemed invites, not a duplicate of
    // the card just shown (matches the mockup's F1-5 "Pending" section,
    // which is keyed by invitee label + relative time for *other* invites).
    final pending = (familyState?.pendingInvites ?? const [])
        .where(
          (pendingInvite) => pendingInvite.invitationId != invite?.invitationId,
        )
        .toList();
    final error = familyState?.error;

    return Scaffold(
      appBar: AppBar(title: const Text('Invite')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.lg,
          ),
          children: [
            if (familyState == null || familyState.isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (family == null)
              SafePathCard(
                padding: const EdgeInsets.all(22),
                child: Column(
                  children: [
                    const Icon(Icons.diversity_3, size: 48),
                    const SizedBox(height: AppSpacing.md),
                    Text('Create a circle first', style: AppTypography.title),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Guardian invites are generated from an active family circle.',
                      textAlign: TextAlign.center,
                      style: AppTypography.bodySecondary,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    PrimaryButton(
                      label: 'Create circle',
                      onPressed: () => context.go('/circle/create'),
                    ),
                  ],
                ),
              )
            else if (invite == null && error != null)
              SafePathCard(
                padding: const EdgeInsets.all(22),
                child: Column(
                  children: [
                    const Icon(Icons.cloud_off, size: 48),
                    const SizedBox(height: AppSpacing.md),
                    Text('Invite not generated', style: AppTypography.title),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      error,
                      textAlign: TextAlign.center,
                      style: AppTypography.bodySecondary,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    PrimaryButton(
                      label: 'Try again',
                      onPressed: _retryGenerateInvite,
                    ),
                  ],
                ),
              )
            else if (invite == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
                child: Center(child: CircularProgressIndicator()),
              )
            else
              SafePathCard(
                padding: const EdgeInsets.all(22),
                child: Column(
                  children: [
                    QrImageView(
                      data: _inviteLink(invite),
                      size: 180,
                      semanticsLabel: 'Invite QR code',
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(invite.code, style: AppTypography.code),
                    const SizedBox(height: AppSpacing.xs),
                    Text('Expires in 24h', style: AppTypography.caption),
                    const SizedBox(height: AppSpacing.lg),
                    PrimaryButton(
                      label: 'Copy link',
                      onPressed: () => _onCopyLink(invite),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    SecondaryButton(
                      label: 'Share',
                      onPressed: () => _onShare(invite),
                    ),
                  ],
                ),
              ),
            if (invite != null && error != null) ...[
              const SizedBox(height: AppSpacing.md),
              Text(error, style: AppTypography.bodySecondary),
            ],
            const SizedBox(height: AppSpacing.xl),
            Text('Pending', style: AppTypography.title),
            const SizedBox(height: AppSpacing.md),
            if (pending.isEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('No pending invites yet', style: AppTypography.title),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Share your code or link above to add someone to your circle.',
                    style: AppTypography.bodySecondary,
                  ),
                ],
              )
            else
              for (final pendingInvite in pending)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: SafePathCard(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            pendingInvite.inviteeLabel ?? pendingInvite.code,
                            style: AppTypography.body,
                          ),
                        ),
                        Text(
                          _relativeInviteTime(pendingInvite),
                          style: AppTypography.bodySecondary,
                        ),
                      ],
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

String _relativeInviteTime(Invitation invite) {
  final createdAt = invite.expiresAt.subtract(const Duration(hours: 24));
  final diff = DateTime.now().difference(createdAt);
  if (diff.inMinutes < 1) return 'Invited just now';
  if (diff.inHours < 1) return 'Invited ${diff.inMinutes}m ago';
  if (diff.inDays < 1) return 'Invited ${diff.inHours}h ago';
  return 'Invited ${diff.inDays}d ago';
}
