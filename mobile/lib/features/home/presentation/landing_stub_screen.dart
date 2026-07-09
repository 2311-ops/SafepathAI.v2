import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared_widgets/primary_button.dart';
import '../../../shared_widgets/safepath_card.dart';
import '../../../shared_widgets/secondary_button.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/data/auth_api.dart';
import '../../auth/data/auth_models.dart';
import '../../family/application/family_controller.dart';
import '../../family/data/family_models.dart';
import '../../profile/application/profile_controller.dart';

/// Phase 1 authenticated landing for family-circle setup. It intentionally
/// avoids the later map/bottom-nav shell, while still using the SafePath
/// tokens so Guardian/Member setup is visually production-ready.
class LandingStubScreen extends ConsumerWidget {
  const LandingStubScreen({super.key});

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log out of SafePath AI?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Log out'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await ref.read(authControllerProvider.notifier).logout();

    if (context.mounted) {
      context.go('/');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final familyAsync = ref.watch(familyControllerProvider);
    final profileAsync = ref.watch(profileControllerProvider);
    final familyState = familyAsync.value;
    final profileState = profileAsync.value;
    final currentUserId = ref.watch(authApiProvider).currentSession?.user.id;
    final profileUserId = profileState?.profile?.userId;
    final effectiveUserId = currentUserId ?? profileUserId;
    final isBootstrapping =
        (familyState?.isLoading ?? familyAsync.isLoading) ||
        (profileState?.isLoading ?? profileAsync.isLoading);
    final hasFamily = familyState?.family != null;
    final members = familyState?.members ?? const [];
    FamilyMemberView? currentMember;
    for (final member in members) {
      if (member.userId == effectiveUserId) {
        currentMember = member;
        break;
      }
    }
    final effectiveRole = currentMember?.role ?? profileState?.profile?.role;
    final isGuardian = effectiveRole == Role.guardian;
    final blockingError = !isBootstrapping && !hasFamily
        ? (profileState?.error ?? familyState?.error)
        : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Your circle'),
        actions: [
          if (hasFamily && isGuardian)
            IconButton(
              icon: const Icon(Icons.person_add_alt_1),
              tooltip: 'Invite',
              onPressed: () => context.push('/circle/invite'),
            ),
          if (hasFamily && isGuardian)
            IconButton(
              icon: const Icon(Icons.tune),
              tooltip: 'Permissions',
              onPressed: () => context.push('/circle/permissions'),
            ),
          PopupMenuButton<String>(
            tooltip: 'Account menu',
            onSelected: (value) {
              if (value == 'logout') {
                _confirmLogout(context, ref);
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'logout', child: Text('Logout')),
            ],
          ),
        ],
      ),
      body: isBootstrapping
          ? const Center(child: CircularProgressIndicator())
          : blockingError != null
          ? _ConnectionFailure(
              message: blockingError,
              onRetry: () {
                ref.read(profileControllerProvider.notifier).refresh();
                ref.read(familyControllerProvider.notifier).refresh();
              },
            )
          : !hasFamily
          ? _RoleEmptyState(role: effectiveRole)
          : _FamilyDashboard(
              familyState: familyState,
              members: members,
              effectiveUserId: effectiveUserId,
              onRefresh: () =>
                  ref.read(familyControllerProvider.notifier).refresh(),
            ),
    );
  }
}

class _FamilyDashboard extends StatelessWidget {
  const _FamilyDashboard({
    required this.familyState,
    required this.members,
    required this.effectiveUserId,
    required this.onRefresh,
  });

  final FamilyState? familyState;
  final List<FamilyMemberView> members;
  final String? effectiveUserId;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        if (familyState?.error != null) ...[
          _InlineError(message: familyState!.error!),
          const SizedBox(height: AppSpacing.md),
        ],
        if (members.isEmpty)
          _DashboardEmptyState(onRefresh: onRefresh)
        else ...[
          Text(
            familyState?.family?.name ?? 'Family circle',
            style: AppTypography.heading,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '${members.length} active member${members.length == 1 ? '' : 's'}',
            style: AppTypography.bodySecondary,
          ),
          const SizedBox(height: AppSpacing.lg),
          for (final member in members)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: SafePathCard(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: AppColors.primaryTeal.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.person,
                        color: AppColors.primaryTeal,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text(
                        member.userId == effectiveUserId
                            ? 'You'
                            : member.userId,
                        style: AppTypography.title,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Chip(
                      label: Text(member.role.wireValue),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ],
    );
  }
}

class _RoleEmptyState extends StatelessWidget {
  const _RoleEmptyState({required this.role});

  final Role? role;

  @override
  Widget build(BuildContext context) {
    if (role == Role.member) {
      return _EmptyState(
        icon: Icons.qr_code_scanner,
        title: 'Join a family circle',
        message: 'Enter the invite code your Guardian shared with you.',
        primaryLabel: 'Enter invite code',
        onPrimary: () => context.push('/invite/accept'),
      );
    }

    if (role == Role.guardian) {
      return _EmptyState(
        icon: Icons.diversity_3,
        title: 'Create your family circle',
        message: 'Start a circle, then generate an invite code or QR.',
        primaryLabel: 'Create a circle',
        onPrimary: () => context.push('/circle/create'),
      );
    }

    return _EmptyState(
      icon: Icons.group,
      title: 'Set up your circle',
      message: 'Create a circle or join one with an invite code.',
      primaryLabel: 'Create a circle',
      onPrimary: () => context.push('/circle/create'),
      secondaryLabel: 'I have an invite code',
      onSecondary: () => context.push('/invite/accept'),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
    required this.primaryLabel,
    required this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
  });

  final IconData icon;
  final String title;
  final String message;
  final String primaryLabel;
  final VoidCallback onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        const SizedBox(height: AppSpacing.xl),
        SafePathCard(
          padding: const EdgeInsets.all(22),
          child: Column(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.primaryTeal,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(icon, size: 32, color: Colors.white),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                title,
                textAlign: TextAlign.center,
                style: AppTypography.title,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                message,
                textAlign: TextAlign.center,
                style: AppTypography.bodySecondary,
              ),
              const SizedBox(height: AppSpacing.lg),
              PrimaryButton(label: primaryLabel, onPressed: onPrimary),
              if (secondaryLabel != null && onSecondary != null) ...[
                const SizedBox(height: AppSpacing.sm),
                SecondaryButton(label: secondaryLabel!, onPressed: onSecondary),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ConnectionFailure extends StatelessWidget {
  const _ConnectionFailure({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        const SizedBox(height: AppSpacing.xl),
        SafePathCard(
          padding: const EdgeInsets.all(22),
          child: Column(
            children: [
              const Icon(
                Icons.cloud_off,
                size: 48,
                color: AppColors.bodySecondary,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                "Couldn't load your circle",
                textAlign: TextAlign.center,
                style: AppTypography.title,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                message,
                textAlign: TextAlign.center,
                style: AppTypography.bodySecondary,
              ),
              const SizedBox(height: AppSpacing.lg),
              PrimaryButton(label: 'Try again', onPressed: onRetry),
            ],
          ),
        ),
      ],
    );
  }
}

class _DashboardEmptyState extends StatelessWidget {
  const _DashboardEmptyState({required this.onRefresh});

  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return SafePathCard(
      padding: const EdgeInsets.all(22),
      child: Column(
        children: [
          const Icon(Icons.group_off, size: 48, color: AppColors.bodySecondary),
          const SizedBox(height: AppSpacing.md),
          Text(
            'No members loaded yet',
            textAlign: TextAlign.center,
            style: AppTypography.title,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Refresh your circle to load the roster.',
            textAlign: TextAlign.center,
            style: AppTypography.bodySecondary,
          ),
          const SizedBox(height: AppSpacing.lg),
          PrimaryButton(label: 'Refresh', onPressed: onRefresh),
        ],
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.cautionBg,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(
          message,
          style: const TextStyle(color: AppColors.cautionText),
        ),
      ),
    );
  }
}
