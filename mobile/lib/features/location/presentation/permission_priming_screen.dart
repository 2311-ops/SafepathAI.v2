import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared_widgets/primary_button.dart';
import '../../../shared_widgets/safepath_card.dart';
import '../application/permission_controller.dart';

class PermissionPrimingScreen extends ConsumerWidget {
  const PermissionPrimingScreen({super.key});

  Future<void> _request(BuildContext context, WidgetRef ref) async {
    final status = await ref
        .read(permissionControllerProvider.notifier)
        .requestPermission();
    if (!context.mounted) return;
    if (status == LocationPermissionStatus.granted) {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final permission = ref.watch(permissionControllerProvider);
    final deniedForever = permission.isDeniedForever;

    return Scaffold(
      backgroundColor: AppColors.appBg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            const SizedBox(height: AppSpacing.xl),
            SafePathCard(
              padding: const EdgeInsets.all(22),
              child: Column(
                children: [
                  Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      color: AppColors.primaryTintBg,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(
                      Icons.location_on,
                      color: AppColors.primaryTeal,
                      size: 34,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'Let your family see you are safe',
                    textAlign: TextAlign.center,
                    style: AppTypography.heading,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'SafePath uses your location while the app is open so your family can see where you are and so SOS can send your live location immediately.',
                    textAlign: TextAlign.center,
                    style: AppTypography.bodySecondary,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  PrimaryButton(
                    label: deniedForever
                        ? 'Open Settings'
                        : 'Turn on location sharing',
                    onPressed: permission.isRequesting
                        ? null
                        : () => _request(context, ref),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextButton(
                    onPressed: () => context.go('/home'),
                    child: const Text('Not now'),
                  ),
                  TextButton.icon(
                    onPressed: () => context.push('/battery-info'),
                    icon: const Icon(Icons.battery_full),
                    label: const Text('How battery use works'),
                  ),
                ],
              ),
            ),
            if (permission.status == LocationPermissionStatus.denied) ...[
              const SizedBox(height: AppSpacing.md),
              const _InlineNotice(
                message:
                    'Location access is off. Turn it on so your family can see you are safe.',
              ),
            ],
            if (deniedForever) ...[
              const SizedBox(height: AppSpacing.md),
              const _InlineNotice(
                message:
                    'Location access is off. Turn it on in Settings so your family can see you are safe.',
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InlineNotice extends StatelessWidget {
  const _InlineNotice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.cautionBg,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(
          message,
          style: const TextStyle(color: AppColors.cautionText),
        ),
      ),
    );
  }
}
