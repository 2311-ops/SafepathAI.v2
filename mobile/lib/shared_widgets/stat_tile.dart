import 'package:flutter/material.dart';

import '../core/theme/app_spacing.dart';
import '../core/theme/app_typography.dart';
import 'safepath_card.dart';

class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.value,
    required this.label,
    this.icon,
    this.backgroundColor,
    this.borderColor,
    this.valueColor,
    this.labelColor,
  });

  final String value;
  final String label;
  final Widget? icon;
  final Color? backgroundColor;
  final Color? borderColor;
  final Color? valueColor;
  final Color? labelColor;

  @override
  Widget build(BuildContext context) {
    final hasIcon = icon != null;
    final valueStyle = valueColor == null
        ? AppTypography.statValue
        : AppTypography.statValue.copyWith(color: valueColor);
    final labelStyle = labelColor == null
        ? AppTypography.caption
        : AppTypography.caption.copyWith(color: labelColor);
    return SafePathCard(
      radius: 14,
      color: backgroundColor,
      border: borderColor == null ? null : Border.all(color: borderColor!),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xsMd,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: hasIcon
            ? CrossAxisAlignment.center
            : CrossAxisAlignment.start,
        children: [
          if (hasIcon) ...[
            icon!,
            const SizedBox(height: AppSpacing.xs),
          ],
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: hasIcon ? Alignment.center : Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: valueStyle,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            label.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: labelStyle,
          ),
        ],
      ),
    );
  }
}
