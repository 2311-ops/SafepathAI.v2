import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';

class PermissionPrimingScreen extends StatelessWidget {
  const PermissionPrimingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.appBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.location_on,
                size: 48,
                color: AppColors.primaryTeal,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Share location when you choose',
                textAlign: TextAlign.center,
                style: AppTypography.heading,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Location sharing lets your family see that you are safe.',
                textAlign: TextAlign.center,
                style: AppTypography.bodySecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
