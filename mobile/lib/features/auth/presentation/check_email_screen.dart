import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared_widgets/primary_button.dart';
import '../../../shared_widgets/safepath_logo.dart';

/// Shown right after a successful registration when Supabase requires the
/// user to verify their email before they can log in (AuthPendingVerification).
/// Supabase sends the verification email itself (native Auth flow via the
/// Custom SMTP configured in the Supabase Dashboard) — this screen only
/// informs the user and lets them return to Login once they've verified.
class CheckEmailScreen extends StatelessWidget {
  const CheckEmailScreen({super.key, this.email});

  final String? email;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.lg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: AppSpacing.xl),
              const SafePathLogo(size: 72),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Check your email',
                textAlign: TextAlign.center,
                style: AppTypography.heading,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                email == null
                    ? 'We sent you a verification link. Open it to activate your account, then log in.'
                    : 'We sent a verification link to $email. Open it to activate your account, then log in.',
                textAlign: TextAlign.center,
                style: AppTypography.bodySecondary,
              ),
              const SizedBox(height: AppSpacing.xl),
              PrimaryButton(
                label: 'Back to login',
                onPressed: () => context.go('/login'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
