import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// SafePath app router — a single themed placeholder route for now. Auth
/// routes (Welcome/Login/Register/etc.) are added in plan 03.
final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      name: 'placeholder',
      builder: (context, state) => const _PlaceholderHomeScreen(),
    ),
  ],
);

class _PlaceholderHomeScreen extends StatelessWidget {
  const _PlaceholderHomeScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('SafePath AI', style: AppTypography.display),
            const SizedBox(height: 8),
            Text(
              'Mobile foundation scaffold',
              style: AppTypography.bodySecondary,
            ),
            const SizedBox(height: 24),
            Icon(Icons.shield_rounded, color: AppColors.primaryTeal, size: 48),
          ],
        ),
      ),
    );
  }
}
