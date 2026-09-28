import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';

/// SafePath surface card — 14-18px radius, white surface fill, per
/// `01-PATTERNS.md` ("Component shapes: 14-18px border radius on
/// buttons/cards/inputs").
///
/// [color]/[border] are optional per-instance overrides (both default to
/// null, reproducing today's plain white/no-border look) used by
/// color-coded tiles such as [StatTile].
class SafePathCard extends StatelessWidget {
  const SafePathCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.radius = 16,
    this.color,
    this.border,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? color;
  final BoxBorder? border;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? AppColors.surface,
        borderRadius: BorderRadius.circular(radius),
        border: border,
      ),
      child: child,
    );
  }
}
