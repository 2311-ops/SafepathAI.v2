import 'dart:math';

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// Paints the SOS arm control's press-and-hold progress ring.
///
/// Two rendering modes, both driven by the same [progress] (0..1, the
/// fraction of the locked 3000ms hold completed so far):
///
/// - Normal motion: a translucent base track plus a mint-to-red progress arc
///   that interpolates color past 60% progress (03-UI-SPEC.md "Press-and-hold
///   arm ring").
/// - [reduceMotion]: three discrete tick marks that fill solid
///   [AppColors.sosRedDeep] one at a time as progress crosses one third, two
///   thirds and one — no gradient, no easing (the 3000ms timing itself is
///   never shortened; only the decorative interpolation is removed).
class SosArmRingPainter extends CustomPainter {
  const SosArmRingPainter({required this.progress, required this.reduceMotion});

  /// Fraction of the 3000ms hold completed, clamped to 0..1.
  final double progress;

  /// Whether `MediaQuery.disableAnimations` is set — swaps the smooth arc for
  /// discrete, non-animated tick marks.
  final bool reduceMotion;

  static const double _ringRadius = 34;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final clampedProgress = progress.clamp(0.0, 1.0);

    if (reduceMotion) {
      _paintTicks(canvas, center, clampedProgress);
      return;
    }

    _paintTrack(canvas, center);
    _paintArc(canvas, center, clampedProgress);
  }

  void _paintTrack(Canvas canvas, Offset center) {
    final trackPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawCircle(center, _ringRadius, trackPaint);
  }

  void _paintArc(Canvas canvas, Offset center, double progress) {
    final color = progress < 0.6
        ? AppColors.accentMint
        : Color.lerp(
            AppColors.accentMint,
            AppColors.sosRedDeep,
            ((progress - 0.6) / 0.4).clamp(0.0, 1.0),
          )!;
    final arcPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    final rect = Rect.fromCircle(center: center, radius: _ringRadius);
    canvas.drawArc(rect, -pi / 2, 2 * pi * progress, false, arcPaint);
  }

  void _paintTicks(Canvas canvas, Offset center, double progress) {
    const tickCount = 3;
    const tickLength = 8.0;
    final tickPaint = Paint()
      ..color = AppColors.sosRedDeep
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    for (var i = 0; i < tickCount; i++) {
      final threshold = (i + 1) / tickCount;
      if (progress < threshold) continue;

      final angle = -pi / 2 + (2 * pi * (i + 1) / tickCount);
      final outer = center + Offset(cos(angle), sin(angle)) * _ringRadius;
      final inner =
          center + Offset(cos(angle), sin(angle)) * (_ringRadius - tickLength);
      canvas.drawLine(inner, outer, tickPaint);
    }
  }

  @override
  bool shouldRepaint(covariant SosArmRingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.reduceMotion != reduceMotion;
  }
}
