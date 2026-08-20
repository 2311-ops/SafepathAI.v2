import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_typography.dart';

/// Duration-badge text color — the one hex value in this design system not
/// drawn from `AppColors`. Deliberately kept local (not added to the locked
/// token file): `AppColors.safe` on `safeBg` is only ~2.6:1 contrast at
/// small badge sizes, while this value reaches ~4.4:1. Sourced from the
/// user-approved mockup; flagged for explicit user acceptance in the
/// executing plan's summary.
const Color _durationBadgeTextColor = Color(0xFF1E7A50);

class TimelineNode extends StatelessWidget {
  const TimelineNode({
    super.key,
    required this.title,
    required this.subtitle,
    this.isTransit = false,
    this.showConnector = true,
    this.durationLabel,
  });

  final String title;
  final String subtitle;
  final bool isTransit;
  final bool showConnector;
  final String? durationLabel;

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
                    color: isTransit ? AppColors.safeBg : AppColors.surface,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isTransit
                          ? AppColors.safeBgBorder
                          : AppColors.hairline,
                    ),
                  ),
                  child: Icon(
                    icon,
                    size: 16,
                    color: isTransit ? AppColors.safe : AppColors.bodySecondary,
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
          if (durationLabel != null)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.lg),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 4,
                  horizontal: 10,
                ),
                decoration: BoxDecoration(
                  color: AppColors.safeBg,
                  border: Border.all(color: AppColors.safeBgBorder),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  durationLabel!,
                  style: AppTypography.caption.copyWith(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: _durationBadgeTextColor,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
