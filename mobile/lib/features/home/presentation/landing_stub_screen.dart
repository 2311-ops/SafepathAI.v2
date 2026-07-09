import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/application/auth_controller.dart';
import '../../auth/data/auth_api.dart';
import '../../auth/data/auth_models.dart';
import '../../family/application/family_controller.dart';
import '../../family/data/family_models.dart';
import '../../profile/application/profile_controller.dart';

/// Deliberately-plain, default Material 3 authenticated landing stub
/// (UI-SPEC Scope Resolution #2). Intentionally NOT styled with the
/// SafePath design tokens (`AppColors`/`AppTypography`/etc.) and has NO
/// bottom navigation — this keeps it visually obviously-a-placeholder so
/// nobody mistakes it for the real Home/Live Map screen Phase 3 builds.
///
/// Upgraded in plan 01-07 to show the real family-circle member list (via
/// [familyControllerProvider]) and, for Guardians, entry points into the
/// Invite and Manage Permissions screens. Plan 01-10 added a bootstrap fetch
/// (`GET /families/mine`) so the circle survives logout/login and cold app
/// starts, not just the session that created/joined it — this screen shows
/// a loading spinner while that fetch is in flight (see
/// [FamilyState.isLoading]) rather than flashing the "create a circle"
/// empty state first.
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
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (familyState?.error != null) ...[
                  _InlineError(message: familyState!.error!),
                  const SizedBox(height: 12),
                ],
                if (members.isEmpty) ...[
                  const SizedBox(height: 48),
                  const Icon(Icons.group_off, size: 48),
                  const SizedBox(height: 16),
                  const Text(
                    'No members loaded yet',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Refresh your circle to load the roster.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () =>
                        ref.read(familyControllerProvider.notifier).refresh(),
                    child: const Text('Refresh'),
                  ),
                ],
                for (final member in members)
                  ListTile(
                    leading: const Icon(Icons.person),
                    title: Text(
                      member.userId == effectiveUserId ? 'You' : member.userId,
                    ),
                    trailing: Chip(label: Text(member.role.wireValue)),
                  ),
              ],
            ),
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
      padding: const EdgeInsets.all(16),
      children: [
        const SizedBox(height: 48),
        Icon(icon, size: 48),
        const SizedBox(height: 16),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(message, textAlign: TextAlign.center),
        const SizedBox(height: 24),
        ElevatedButton(onPressed: onPrimary, child: Text(primaryLabel)),
        if (secondaryLabel != null && onSecondary != null) ...[
          const SizedBox(height: 8),
          OutlinedButton(onPressed: onSecondary, child: Text(secondaryLabel!)),
        ],
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
      padding: const EdgeInsets.all(16),
      children: [
        const SizedBox(height: 48),
        const Icon(Icons.cloud_off, size: 48),
        const SizedBox(height: 16),
        const Text(
          "Couldn't load your circle",
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(message, textAlign: TextAlign.center),
        const SizedBox(height: 24),
        ElevatedButton(onPressed: onRetry, child: const Text('Try again')),
      ],
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.errorContainer,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(
          message,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onErrorContainer,
          ),
        ),
      ),
    );
  }
}
