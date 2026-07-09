import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
      excludeSemantics: true,
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

/// The official Google "G" logomark, hand-drawn via [CustomPainter] from
/// Google's published multi-color path data — no image asset dependency
/// (per D-08-2's original constraint), but the real four-color mark instead
/// of a plain text "G" (which read as a generic/broken icon, not Google's).
class _GoogleGlyph extends StatelessWidget {
  const _GoogleGlyph();

  static const double _size = 18;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _size,
      height: _size,
      child: CustomPaint(painter: _GoogleGlyphPainter()),
    );
  }
}

/// Paints Google's "G" logomark at a 48x48 reference size, scaled to fit
/// the widget's bounds. Path/colors match Google's published brand asset
/// (blue #4285F4, green #34A853, yellow #FBBC05, red #EA4335).
class _GoogleGlyphPainter extends CustomPainter {
  static const _blue = Color(0xFF4285F4);
  static const _green = Color(0xFF34A853);
  static const _yellow = Color(0xFFFBBC05);
  static const _red = Color(0xFFEA4335);

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 48;
    canvas.save();
    canvas.scale(scale);

    final paint = Paint()..style = PaintingStyle.fill;

    // Blue: right-side arc + horizontal bar.
    paint.color = _blue;
    canvas.drawPath(
      Path()
        ..moveTo(46.98, 24.55)
        ..cubicTo(46.98, 22.98, 46.83, 21.46, 46.56, 20.0)
        ..lineTo(24.0, 20.0)
        ..lineTo(24.0, 28.62)
        ..lineTo(36.94, 28.62)
        ..cubicTo(36.36, 31.63, 34.61, 34.19, 32.0, 35.9)
        ..lineTo(32.0, 41.66)
        ..lineTo(39.75, 41.66)
        ..cubicTo(44.26, 37.53, 46.98, 31.59, 46.98, 24.55)
        ..close(),
      paint,
    );

    // Green: bottom-left arc.
    paint.color = _green;
    canvas.drawPath(
      Path()
        ..moveTo(24.0, 48.0)
        ..cubicTo(30.48, 48.0, 35.93, 45.87, 39.75, 41.66)
        ..lineTo(32.0, 35.9)
        ..cubicTo(29.94, 37.27, 27.24, 38.07, 24.0, 38.07)
        ..cubicTo(17.74, 38.07, 12.44, 33.9, 10.53, 28.29)
        ..lineTo(2.51, 28.29)
        ..lineTo(2.51, 34.24)
        ..cubicTo(6.32, 42.05, 14.53, 48.0, 24.0, 48.0)
        ..close(),
      paint,
    );

    // Yellow: bottom-left short arc.
    paint.color = _yellow;
    canvas.drawPath(
      Path()
        ..moveTo(10.53, 28.29)
        ..cubicTo(10.0, 26.92, 9.71, 25.49, 9.71, 24.0)
        ..cubicTo(9.71, 22.51, 10.0, 21.08, 10.53, 19.71)
        ..lineTo(10.53, 13.76)
        ..lineTo(2.51, 13.76)
        ..cubicTo(0.9, 16.99, 0.0, 20.39, 0.0, 24.0)
        ..cubicTo(0.0, 27.61, 0.9, 31.01, 2.51, 34.24)
        ..lineTo(10.53, 28.29)
        ..close(),
      paint,
    );

    // Red: top-left arc.
    paint.color = _red;
    canvas.drawPath(
      Path()
        ..moveTo(24.0, 9.93)
        ..cubicTo(27.55, 9.93, 30.74, 11.16, 33.26, 13.56)
        ..lineTo(39.92, 6.9)
        ..cubicTo(35.9, 3.17, 30.48, 0.0, 24.0, 0.0)
        ..cubicTo(14.53, 0.0, 6.32, 5.95, 2.51, 13.76)
        ..lineTo(10.53, 19.71)
        ..cubicTo(12.44, 14.1, 17.74, 9.93, 24.0, 9.93)
        ..close(),
      paint,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
