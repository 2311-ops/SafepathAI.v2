import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared_widgets/member_map_pin.dart';
import '../../../shared_widgets/primary_button.dart';
import '../application/location_controller.dart';
import '../application/staleness.dart';
import '../data/location_models.dart';
import 'member_detail_sheet.dart';

class LiveMapScreen extends ConsumerWidget {
  const LiveMapScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncState = ref.watch(locationControllerProvider);
    final state = asyncState.value;

    if (asyncState.isLoading || (state?.isLoading ?? false)) {
      return const Scaffold(
        backgroundColor: AppColors.appBg,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (state?.error != null) {
      return _MapMessage(
        icon: Icons.cloud_off,
        title: "Couldn't load live locations",
        body: state!.error!,
        action: PrimaryButton(
          label: 'Try again',
          onPressed: () => ref.invalidate(locationControllerProvider),
        ),
      );
    }

    final locations = state?.members.values.toList() ?? const [];
    if (locations.isEmpty) {
      return const _MapMessage(
        icon: Icons.location_off,
        title: 'No one to show yet',
        body:
            "Once a family member turns on location sharing, they'll appear here.",
      );
    }

    final self = state?.selfPosition ?? locations.first;
    final cameraTarget = LatLng(self.lat, self.lng);
    final markers = {
      for (final location in locations)
        Marker(
          markerId: MarkerId(location.userId),
          position: LatLng(location.lat, location.lng),
          alpha: stalenessFor(
            DateTime.now().toUtc().difference(location.recordedAtUtc),
          ).opacity,
          icon: BitmapDescriptor.defaultMarkerWithHue(
            location.userId == state?.selfPosition?.userId
                ? BitmapDescriptor.hueCyan
                : _memberHue(location.userId),
          ),
          onTap: () => showMemberDetailSheet(
            context,
            member: MemberDetail(
              name: _memberName(location, state),
              isOnline: state?.isMemberOnline(location.userId) ?? false,
              recordedAtUtc: location.recordedAtUtc,
            ),
          ),
        ),
    };
    final circles = {
      for (final location in locations)
        Circle(
          circleId: CircleId('accuracy-${location.userId}'),
          center: LatLng(location.lat, location.lng),
          radius: accuracyCircleRadius(location.accuracyMeters),
          fillColor: _memberColor(location.userId).withValues(alpha: 0.15),
          strokeColor: _memberColor(location.userId).withValues(alpha: 0.40),
          strokeWidth: 2,
        ),
    };

    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: cameraTarget,
              zoom: 15,
            ),
            markers: markers,
            circles: circles,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x180C3A3F),
                      blurRadius: 16,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Row(
                    children: [
                      const MemberMapPin(
                        label: 'You',
                        identityColor: AppColors.primaryTeal,
                        isSelf: true,
                        size: 36,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Your family, live',
                              style: AppTypography.title,
                            ),
                            Text(
                              '${locations.length} visible location${locations.length == 1 ? '' : 's'}',
                              style: AppTypography.bodySecondary,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static double _memberHue(String userId) {
    return userId.hashCode.isEven
        ? BitmapDescriptor.hueViolet
        : BitmapDescriptor.hueRose;
  }

  static Color _memberColor(String userId) {
    return userId.hashCode.isEven
        ? AppColors.memberViolet
        : AppColors.memberPink;
  }

  static String _memberName(LiveLocation location, LocationState? state) {
    if (location.userId == state?.selfPosition?.userId) return 'You';
    final displayName = location.displayName?.trim();
    if (displayName != null && displayName.isNotEmpty) return displayName;
    return 'Family member';
  }
}

class _MapMessage extends StatelessWidget {
  const _MapMessage({
    required this.icon,
    required this.title,
    required this.body,
    this.action,
  });

  final IconData icon;
  final String title;
  final String body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.appBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 44, color: AppColors.bodySecondary),
                const SizedBox(height: AppSpacing.md),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: AppTypography.heading,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  body,
                  textAlign: TextAlign.center,
                  style: AppTypography.bodySecondary,
                ),
                if (action != null) ...[
                  const SizedBox(height: AppSpacing.lg),
                  action!,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
