import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/application/auth_controller.dart';

/// Deliberately-plain, default Material 3 authenticated landing stub
/// (UI-SPEC Scope Resolution #2). Intentionally NOT styled with the
/// SafePath design tokens (`AppColors`/`AppTypography`/etc.) and has NO
/// bottom navigation — this keeps it visually obviously-a-placeholder so
/// nobody mistakes it for the real Home/Live Map screen Phase 3 builds.
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Your circle'),
        actions: [
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
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          SizedBox(height: 48),
          Icon(Icons.group, size: 48),
          SizedBox(height: 16),
          Text(
            'Just you so far',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text(
            'Invite a family member to start sharing safety with them.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
