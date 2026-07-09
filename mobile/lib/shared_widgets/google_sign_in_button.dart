import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_typography.dart';
import '../features/auth/application/auth_controller.dart';
import '../features/auth/application/auth_state.dart';

/// "Continue with Google" — an outlined button (matches [SecondaryButton]'s
/// `OutlinedButton` base for hierarchy consistency; it is a secondary action
/// relative to each screen's primary CTA), used on Welcome and Login only
/// (D-08-5 — deliberately excluded from Register).
///
/// Watches [authControllerProvider] directly rather than taking an
/// `isLoading` prop, so it disables itself and shows a spinner the instant
/// [AuthController.signInWithGoogle] sets [AuthLoading] — a button-level
/// duplicate-tap guard on top of the controller-level re-entrancy guard
/// (D-08-6).
///
/// [foregroundColor]/[borderColor] are optional overrides for the same
/// documented exception [PrimaryButton] has: Welcome's deep-teal gradient
/// hero needs a light outline/label instead of the default teal-on-white,
/// or the button would be nearly invisible against the background — leave
/// both null on Login, where the default theme styling already has
/// sufficient contrast on the app's light background.
class GoogleSignInButton extends ConsumerWidget {
  const GoogleSignInButton({
    super.key,
    this.foregroundColor,
    this.borderColor,
  });

  final Color? foregroundColor;
  final Color? borderColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = ref.watch(authControllerProvider) is AuthLoading;
    final hasOverride = foregroundColor != null || borderColor != null;

    return Semantics(
      label: 'Continue with Google',
      button: true,
      child: SizedBox(
        width: double.infinity,
        height: 48,
        child: OutlinedButton(
          onPressed: isLoading
              ? null
              : () => ref.read(authControllerProvider.notifier).signInWithGoogle(),
          style: hasOverride
              ? OutlinedButton.styleFrom(
                  foregroundColor: foregroundColor,
                  side: borderColor != null
                      ? BorderSide(color: borderColor!, width: 1.5)
                      : null,
                )
              : null,
          child: isLoading
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: foregroundColor,
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const _GoogleGlyph(),
                    const SizedBox(width: 10),
                    Text(
                      'Continue with Google',
                      style: AppTypography.body.copyWith(color: foregroundColor),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

/// Minimal, image-asset-free "G" glyph per Google's minimal branding
/// guidance — a small circle with a bold "G", not an official logo asset.
class _GoogleGlyph extends StatelessWidget {
  const _GoogleGlyph();

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 9,
      backgroundColor: AppColors.appBg,
      child: Text(
        'G',
        style: AppTypography.caption.copyWith(
          color: AppColors.ink,
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
        ),
      ),
    );
  }
}
