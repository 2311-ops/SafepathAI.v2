import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared_widgets/onboarding_scaffold.dart';
import '../../../shared_widgets/primary_button.dart';
import '../../profile/application/profile_controller.dart';
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
  _RoleOption(Role.caregiver, 'Caregiver', 'Help look after a family member.'),
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
      if (ref.read(authControllerProvider) is! AuthAuthenticated) {
        context.go('/register');
        return;
      }

      await ref.read(profileControllerProvider.notifier).updateRole(_selected);
      if (!mounted) return;

      final profileState = ref.read(profileControllerProvider).value;
      if (profileState?.profile?.role != null) {
        context.go('/home');
      }
      return;
    }

    await ref
        .read(authControllerProvider.notifier)
        .register(
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
    final profileState = ref.watch(profileControllerProvider).value;
    final draft = ref.watch(registerDraftProvider);
    final isOnboarding = draft == null && authState is AuthAuthenticated;
    final isLoading =
        authState is AuthLoading || (profileState?.isLoading ?? false);
    final noticeMessage = authState is AuthError
        ? authState.message
        : isOnboarding
        ? profileState?.error
        : null;

    if (draft == null && !isOnboarding) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/register');
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(),
      body: OnboardingScaffold(
        stepLabel: isOnboarding ? 'STEP 1 / 1' : 'STEP 2 / 2',
        title: 'Who are you in this circle?',
        subtitle:
            'Choose the role that best matches how you will use SafePath AI.',
        showLogo: !isOnboarding,
        children: [
          for (final option in _roleOptions) ...[
            _RoleCard(
              option: option,
              selected: _selected == option.role,
              onTap: () => setState(() => _selected = option.role),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          if (noticeMessage != null) ...[
            AuthMessageBanner(message: noticeMessage),
            const SizedBox(height: AppSpacing.md),
          ],
          PrimaryButton(
            label: isLoading
                ? (isOnboarding
                      ? 'Saving your role...'
                      : 'Creating your circle...')
                : (isOnboarding ? 'Continue' : 'Create your circle'),
            onPressed: isLoading ? null : _onConfirm,
          ),
        ],
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
    return Semantics(
      button: true,
      selected: selected,
      label: '${option.title}. ${option.description}',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          constraints: const BoxConstraints(minHeight: 72),
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: selected ? AppColors.navyTintBg : AppColors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? AppColors.primaryNavy : AppColors.hairline,
              width: selected ? 2 : 1,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: AppColors.primaryNavy.withValues(alpha: 0.12),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : const [
                    BoxShadow(
                      color: Color(0x12000000),
                      blurRadius: 8,
                      offset: Offset(0, 3),
                    ),
                  ],
          ),
          child: Row(
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color: selected
                    ? AppColors.primaryNavy
                    : AppColors.bodySecondary,
              ),
              const SizedBox(width: AppSpacing.xsMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(option.title, style: AppTypography.title),
                    const SizedBox(height: 2),
                    Text(
                      option.description,
                      style: AppTypography.bodySecondary,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
