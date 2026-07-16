import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared_widgets/primary_button.dart';
import '../../../shared_widgets/safepath_card.dart';

class BatteryTransparencyScreen extends StatelessWidget {
  const BatteryTransparencyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.appBg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            const SizedBox(height: AppSpacing.lg),
            SafePathCard(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 68,
                      height: 68,
                      decoration: BoxDecoration(
                        color: AppColors.cautionBg,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.cautionBorder),
                      ),
                      child: const Icon(
                        Icons.battery_full,
                        color: AppColors.caution,
                        size: 34,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'Battery use stays light',
                    textAlign: TextAlign.center,
                    style: AppTypography.heading,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'SafePath tracks location only while the app is open in this version. That keeps battery impact minimal while still helping your family see you are safe.',
                    style: AppTypography.bodySecondary,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  const _BatteryTip(
                    icon: Icons.phone_android,
                    label: 'Keep SafePath open when you want live sharing.',
                  ),
                  const _BatteryTip(
                    icon: Icons.wifi_tethering,
                    label: 'A stronger GPS and network signal uses less power.',
                  ),
                  const _BatteryTip(
                    icon: Icons.battery_saver,
                    label: 'Low power mode can make updates less frequent.',
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  PrimaryButton(
                    label: 'Got it',
                    onPressed: () => context.pop(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BatteryTip extends StatelessWidget {
  const _BatteryTip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          Icon(icon, color: AppColors.caution, size: 22),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(label, style: AppTypography.body)),
        ],
      ),
    );
  }
}
