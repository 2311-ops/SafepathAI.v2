import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/application/auth_controller.dart';
import '../../auth/data/auth_api.dart';
import '../../auth/data/auth_models.dart';
import '../../family/application/family_controller.dart';

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
    final familyState = ref.watch(familyControllerProvider).value;
    final currentUserId = ref.watch(authApiProvider).currentSession?.user.id;
    final isBootstrapping = familyState?.isLoading ?? false;
    final hasFamily = familyState?.family != null;
    final members = familyState?.members ?? const [];
    final isGuardian = members.any(
      (member) => member.userId == currentUserId && member.role == Role.guardian,
    );

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
          : !hasFamily
          ? ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const SizedBox(height: 48),
                const Icon(Icons.group, size: 48),
                const SizedBox(height: 16),
                const Text(
                  'Just you so far',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Invite a family member to start sharing safety with them.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => context.push('/circle/create'),
                  child: const Text('Create a circle'),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () => context.push('/invite/accept'),
                  child: const Text('I have an invite code'),
                ),
              ],
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                for (final member in members)
                  ListTile(
                    leading: const Icon(Icons.person),
                    title: Text(member.userId == currentUserId ? 'You' : member.userId),
                    trailing: Chip(label: Text(member.role.wireValue)),
                  ),
              ],
            ),
    );
  }
}
