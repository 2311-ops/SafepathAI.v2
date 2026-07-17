import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';

/// Neutral, always-on battery readout (LOC-04).
///
/// This is intentionally NOT the low-battery alert (`LowBatteryBanner`) —
/// it renders whenever a member's `batteryPercent` is known, regardless of
/// any low-battery threshold, and must never adopt `AppColors.caution*` or
/// `AppColors.sosRed*` styling (that palette is reserved for the threshold
/// alert / SOS states respectively).
class BatteryIndicator extends StatelessWidget {
  const BatteryIndicator({super.key, required this.percent});

  final int? percent;

  @override
  Widget build(BuildContext context) {
    final value = percent;
    if (value == null) {
      // Graceful null path: no figure, no placeholder, no garbage box.
      return const SizedBox.shrink();
    }

    return Semantics(
      label: 'Battery $value percent',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.battery_full,
            size: 14,
            color: AppColors.bodySecondary,
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(
            '$value%',
            style: AppTypography.bodySecondary.copyWith(
              color: AppColors.bodySecondary,
            ),
          ),
        ],
      ),
    );
  }
}
