import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared_widgets/primary_button.dart';
import '../../../shared_widgets/safepath_logo.dart';

/// Welcome — the entry point into every Phase 1 flow (`01-UI-SPEC.md`). The
/// one deliberate exception to the `#ECF0EF` app background: a full-bleed
/// deep-teal gradient hero (`#1FA89B` -> `#0C3A3F`).
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.heroGradientStart, AppColors.deepTeal],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xl,
              vertical: AppSpacing.xl,
            ),
            child: Column(
              children: [
                const Spacer(flex: 3),
                const SafePathLogo(size: 96, tile: false),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'SafePath AI',
                  textAlign: TextAlign.center,
                  style: AppTypography.display.copyWith(color: Colors.white),
                ),
                const Spacer(flex: 4),
                PrimaryButton(
                  label: 'Create your circle',
                  backgroundColor: AppColors.accentMint,
                  foregroundColor: AppColors.deepTeal,
                  onPressed: () => context.push('/register'),
                ),
                const SizedBox(height: AppSpacing.md),
                TextButton(
                  onPressed: () => context.push('/login'),
                  child: Text(
                    'I already have an account',
                    style: AppTypography.bodySecondary.copyWith(
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
