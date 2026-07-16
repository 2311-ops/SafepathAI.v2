import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../data/location_models.dart';

class LowBatteryBanner extends StatelessWidget {
  const LowBatteryBanner({
    super.key,
    required this.alert,
    required this.onDismissed,
  });

  final LowBatteryAlert alert;
  final VoidCallback onDismissed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.cautionBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cautionBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x160C3A3F),
            blurRadius: 14,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.battery_alert, color: AppColors.cautionText),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Low battery',
                    style: AppTypography.body.copyWith(
                      color: AppColors.cautionText,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    "${alert.name}'s phone is at ${alert.batteryPercent}% — location updates may become less frequent.",
                    style: AppTypography.bodySecondary.copyWith(
                      color: AppColors.cautionText,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Dismiss low battery alert',
              visualDensity: VisualDensity.compact,
              onPressed: onDismissed,
              icon: const Icon(Icons.close, color: AppColors.cautionText),
            ),
          ],
        ),
      ),
    );
  }
}
