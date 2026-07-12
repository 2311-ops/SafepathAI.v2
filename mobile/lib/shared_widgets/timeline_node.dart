import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_typography.dart';

class TimelineNode extends StatelessWidget {
  const TimelineNode({
    super.key,
    required this.title,
    required this.subtitle,
    this.isTransit = false,
    this.showConnector = true,
  });

  final String title;
  final String subtitle;
  final bool isTransit;
  final bool showConnector;

  @override
  Widget build(BuildContext context) {
    final icon = isTransit ? Icons.directions_walk : Icons.location_on;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 32,
            child: Column(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isTransit
                        ? AppColors.primaryTintBg
                        : AppColors.surface,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.hairline),
                  ),
                  child: Icon(
                    icon,
                    size: 16,
                    color: isTransit
                        ? AppColors.primaryTeal
                        : AppColors.bodySecondary,
                  ),
                ),
                if (showConnector)
                  const Expanded(
                    child: VerticalDivider(
                      width: 1,
                      thickness: 1,
                      color: AppColors.hairline,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.title,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodySecondary,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
