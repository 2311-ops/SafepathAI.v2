import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared_widgets/primary_button.dart';
import '../application/auth_controller.dart';
import '../application/auth_state.dart';
import '../data/auth_models.dart';
import 'register_screen.dart';

class _RoleOption {
  const _RoleOption(this.role, this.title, this.description);

  final Role role;
  final String title;
  final String description;
}

const _roleOptions = [
  _RoleOption(
    Role.guardian,
    'Guardian / Parent',
    'Full visibility and control over the circle.',
  ),
  _RoleOption(
    Role.member,
    'Member',
    'Share your location and get alerts from your circle.',
  ),
  _RoleOption(
    Role.caregiver,
    'Caregiver',
    'Help look after a family member.',
  ),
  _RoleOption(
    Role.orgAdmin,
    'School Admin',
    'Manage a group circle on behalf of an organization.',
  ),
];

/// Role selection - "Who are you in this circle?" (AUTH-05). Confirming
/// calls [AuthController.register] with the draft read from
/// [registerDraftProvider] plus the chosen role.
///
/// The draft is read from a provider (not a constructor argument fed by
/// `GoRouterState.extra`) so it survives the router's `refreshListenable`
/// re-evaluating this route while `register()` is in flight — see the note
/// on [registerDraftProvider] in register_screen.dart.
class RoleSelectScreen extends ConsumerStatefulWidget {
  const RoleSelectScreen({super.key});

  @override
  ConsumerState<RoleSelectScreen> createState() => _RoleSelectScreenState();
}

class _RoleSelectScreenState extends ConsumerState<RoleSelectScreen> {
  Role _selected = Role.guardian;

  Future<void> _onConfirm() async {
    final draft = ref.read(registerDraftProvider);
    if (draft == null) {
      context.go('/register');
      return;
    }

    await ref.read(authControllerProvider.notifier).register(
          email: draft.email,
          password: draft.password,
          fullName: draft.fullName,
          role: _selected,
        );

    if (!mounted) return;
    final authState = ref.read(authControllerProvider);
    if (authState is AuthAuthenticated) {
      context.go('/home');
    } else if (authState is AuthPendingVerification) {
      context.go('/verify-email', extra: draft.email);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final draft = ref.watch(registerDraftProvider);
    final isLoading = authState is AuthLoading;
    final noticeMessage = authState is AuthError ? authState.message : null;

    if (draft == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/register');
      });
      return const Scaffold(body: SizedBox.shrink());
    }

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
              Text('Who are you in this circle?', style: AppTypography.heading),
              const SizedBox(height: AppSpacing.lg),
              for (final option in _roleOptions) ...[
                _RoleCard(
                  option: option,
                  selected: _selected == option.role,
                  onTap: () => setState(() => _selected = option.role),
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              if (noticeMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.cautionBg,
                    border: Border.all(color: AppColors.cautionBorder),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    noticeMessage,
                    style: const TextStyle(
                      color: AppColors.cautionText,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              PrimaryButton(
                label: isLoading ? 'Creating your circle...' : 'Create your circle',
                onPressed: isLoading ? null : _onConfirm,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final _RoleOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppColors.primaryTeal : const Color(0xFFD7E0DE),
            width: selected ? 2 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AppColors.primaryTeal.withValues(alpha: 0.15),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: selected ? AppColors.primaryTeal : AppColors.bodySecondary,
            ),
            const SizedBox(width: AppSpacing.xsMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(option.title, style: AppTypography.title),
                  Text(option.description, style: AppTypography.bodySecondary),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
