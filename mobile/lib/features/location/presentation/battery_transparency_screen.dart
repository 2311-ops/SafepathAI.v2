import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';

class BatteryTransparencyScreen extends StatelessWidget {
  const BatteryTransparencyScreen({super.key});

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
                Icons.battery_full,
                size: 48,
                color: AppColors.caution,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Battery use stays light',
                textAlign: TextAlign.center,
                style: AppTypography.heading,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'SafePath uses foreground-only tracking for this version.',
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
