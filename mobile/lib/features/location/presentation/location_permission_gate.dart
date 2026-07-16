import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../application/permission_controller.dart';

class LocationPermissionGate extends ConsumerWidget {
  const LocationPermissionGate({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final permission = ref.watch(permissionControllerProvider);

    if (permission.isGranted) {
      return child;
    }

    if (!permission.isChecking) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (context.mounted &&
            GoRouterState.of(context).matchedLocation !=
                '/permission-priming') {
          context.go('/permission-priming');
        }
      });
    }

    return const Scaffold(
      backgroundColor: AppColors.appBg,
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
