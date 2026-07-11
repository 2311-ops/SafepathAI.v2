import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/deep_link/deep_link_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared_widgets/primary_button.dart';
import '../../../shared_widgets/safepath_text_field.dart';
import '../application/family_controller.dart';

/// Accept/reject invite (F1-6). The plan-05 backend has no "preview invite"
/// endpoint (`POST /invites/redeem` performs the accept/decline directly),
/// so this screen cannot show the mockup's personalized "{Guardian} invited
/// you to {circle}" copy without a real round trip first — see
/// 01-07-SUMMARY.md deviations. The invitee enters (or arrives with, via
/// [initialCode]/[initialLinkToken]) the invite, then Accept & join or Decline.
class AcceptInviteScreen extends ConsumerStatefulWidget {
  const AcceptInviteScreen({
    super.key,
    this.initialCode,
    this.initialLinkToken,
  });

  /// Pre-fills the code field when reached with `?code=...` (e.g. a future
  /// deep-link handler for the QR's `safepathai://invite` payload).
  final String? initialCode;
  final String? initialLinkToken;

  @override
  ConsumerState<AcceptInviteScreen> createState() => _AcceptInviteScreenState();
}

class _AcceptInviteScreenState extends ConsumerState<AcceptInviteScreen> {
  late final TextEditingController _codeController;
  bool _isSubmitting = false;
  String? _localError;

  @override
  void initState() {
    super.initState();
    _codeController = TextEditingController(text: widget.initialCode ?? '');
    if ((widget.initialCode?.isNotEmpty ?? false) ||
        (widget.initialLinkToken?.isNotEmpty ?? false)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref.read(pendingInviteProvider.notifier).set(null);
        }
      });
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _redeem({required bool accept}) async {
    final code = _codeController.text.trim();
    final linkToken = widget.initialLinkToken?.trim();
    final hasLinkToken = linkToken != null && linkToken.isNotEmpty;
    if (!hasLinkToken && code.isEmpty) {
      setState(() => _localError = 'Enter an invite code.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _localError = null;
    });
    await ref
        .read(familyControllerProvider.notifier)
        .redeemInvite(
          code: hasLinkToken ? null : code,
          linkToken: hasLinkToken ? linkToken : null,
          accept: accept,
        );
    if (!mounted) return;
    setState(() => _isSubmitting = false);

    final familyState = ref.read(familyControllerProvider).value;
    if (familyState?.error == null) {
      if (accept) {
        context.go('/home');
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Invitation declined')));
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/home');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final familyState = ref.watch(familyControllerProvider).value;
    final error = _localError ?? familyState?.error;

    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.lg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("You've been invited", style: AppTypography.heading),
              const SizedBox(height: AppSpacing.sm),
              Text(
                widget.initialLinkToken?.isNotEmpty ?? false
                    ? 'Review the invitation before joining this SafePath family circle.'
                    : 'Enter the invite code you were sent to join a SafePath family circle.',
                style: AppTypography.bodySecondary,
              ),
              const SizedBox(height: AppSpacing.xl),
              if (widget.initialLinkToken?.isNotEmpty ?? false)
                const _LinkInviteNotice()
              else
                SafePathTextField(
                  label: 'Invite code',
                  controller: _codeController,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) {
                    if (!_isSubmitting) _redeem(accept: true);
                  },
                ),
              if (error != null) ...[
                const SizedBox(height: AppSpacing.md),
                _ErrorBanner(message: error),
              ],
              const SizedBox(height: AppSpacing.xl),
              PrimaryButton(
                label: _isSubmitting ? 'Joining...' : 'Accept & join',
                onPressed: _isSubmitting ? null : () => _redeem(accept: true),
              ),
              const SizedBox(height: AppSpacing.md),
              Center(
                child: TextButton(
                  onPressed: _isSubmitting
                      ? null
                      : () => _redeem(accept: false),
                  child: Text('Decline', style: AppTypography.bodySecondary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.cautionBg,
        border: Border.all(color: AppColors.cautionBorder),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        message,
        style: const TextStyle(
          color: AppColors.cautionText,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _LinkInviteNotice extends StatelessWidget {
  const _LinkInviteNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.cautionBg,
        border: Border.all(color: AppColors.cautionBorder),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Text(
        'Invite link ready. Tap Accept & join to continue.',
        style: TextStyle(
          color: AppColors.cautionText,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
