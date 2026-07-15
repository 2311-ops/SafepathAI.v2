import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared_widgets/google_sign_in_button.dart';
import '../../../shared_widgets/primary_button.dart';
import '../../../shared_widgets/safepath_logo.dart';

/// Welcome — the entry point into every Phase 1 flow (`01-UI-SPEC.md`). The
/// one deliberate exception to the `#ECF0EF` app background: a full-bleed
/// deep-teal gradient hero (`#1FA89B` -> `#0C3A3F`).
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;

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
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: reduceMotion
                ? Duration.zero
                : const Duration(milliseconds: 320),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) {
              return Opacity(
                opacity: value,
                child: Transform.translate(
                  offset: Offset(0, 16 * (1 - value)),
                  child: child,
                ),
              );
            },
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xl,
                    vertical: AppSpacing.xl,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: Column(
                      children: [
                        const SizedBox(height: AppSpacing.xl),
                        const _AdaptiveWelcomeGap(multiplier: 3),
                        const Hero(
                          tag: 'safepath-logo',
                          child: SafePathLogo(size: 96, tile: false),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        Text(
                          'SafePath AI',
                          textAlign: TextAlign.center,
                          style: AppTypography.display.copyWith(
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          'Family safety, privacy, and calm coordination.',
                          textAlign: TextAlign.center,
                          style: AppTypography.body.copyWith(
                            color: Colors.white.withValues(alpha: 0.86),
                          ),
                        ),
                        const _AdaptiveWelcomeGap(multiplier: 4),
                        PrimaryButton(
                          label: 'Create your circle',
                          backgroundColor: AppColors.accentMint,
                          foregroundColor: AppColors.deepTeal,
                          onPressed: () => context.push('/register'),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        const GoogleSignInButton(
                          foregroundColor: Colors.white,
                          borderColor: Colors.white,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        TextButton(
                          onPressed: () => context.push('/login'),
                          child: Text(
                            'I already have an account',
                            style: AppTypography.bodySecondary.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _AdaptiveWelcomeGap extends StatelessWidget {
  const _AdaptiveWelcomeGap({required this.multiplier});

  final int multiplier;

  @override
  Widget build(BuildContext context) {
    final isLandscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    final unit = isLandscape ? AppSpacing.md : AppSpacing.lg;
    return SizedBox(height: unit * multiplier);
  }
}
