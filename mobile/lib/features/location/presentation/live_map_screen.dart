import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared_widgets/logout_action.dart';
import '../../../shared_widgets/member_map_pin.dart';
import '../../../shared_widgets/no_circle_cta.dart';
import '../../../shared_widgets/primary_button.dart';
import '../../family/application/family_controller.dart';
import '../application/location_controller.dart';
import '../application/staleness.dart';
import '../data/location_models.dart';
import 'low_battery_banner.dart';
import 'member_detail_sheet.dart';

class LiveMapScreen extends ConsumerWidget {
  const LiveMapScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncState = ref.watch(locationControllerProvider);
    final state = asyncState.value;
    final familyState = ref.watch(familyControllerProvider).value;

    if (asyncState.isLoading ||
        (state?.isLoading ?? false) ||
        (familyState?.isLoading ?? false)) {
      return const Scaffold(
        backgroundColor: AppColors.appBg,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // No family yet: the map has nothing to show and, more importantly, the
    // user needs a way to create or join a circle. This branch must precede
    // the location-based empty state so a family-less user always gets the
    // role-aware CTA rather than the generic "No one to show yet" copy.
    if (familyState?.family == null) {
      return const _MapMessage(
        icon: Icons.group_off,
        title: 'No circle yet',
        body: 'Create or join a family circle to see everyone on the map.',
        action: NoCircleCta(),
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
    final circleMarkers = [
      for (final location in locations)
        CircleMarker(
          point: LatLng(location.lat, location.lng),
          radius: accuracyCircleRadius(location.accuracyMeters),
          useRadiusInMeter: true,
          color: _memberColor(location.userId).withValues(alpha: 0.15),
          borderColor: _memberColor(location.userId).withValues(alpha: 0.40),
          borderStrokeWidth: 2,
        ),
    ];
    final markers = [
      for (final location in locations)
        Marker(
          point: LatLng(location.lat, location.lng),
          width: 44,
          height: 44,
          child: _LiveMemberMarker(
            location: location,
            isSelf: location.userId == state?.selfPosition?.userId,
            color: _memberColor(location.userId),
            onTap: () => showMemberDetailSheet(
              context,
              member: MemberDetail(
                name: _memberName(location, state),
                isOnline: state?.isMemberOnline(location.userId) ?? false,
                recordedAtUtc: location.recordedAtUtc,
              ),
            ),
          ),
        ),
    ];

    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            options: MapOptions(initialCenter: cameraTarget, initialZoom: 15),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.safepath.mobile',
              ),
              CircleLayer(circles: circleMarkers),
              MarkerLayer(markers: markers),
              const SimpleAttributionWidget(
                source: Text('OpenStreetMap contributors'),
              ),
            ],
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DecoratedBox(
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
                          const LogoutAction(),
                        ],
                      ),
                    ),
                  ),
                  if (state?.lowBatteryAlert != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    LowBatteryBanner(
                      alert: state!.lowBatteryAlert!,
                      onDismissed: () => ref
                          .read(locationControllerProvider.notifier)
                          .dismissLowBatteryAlert(),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
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

/// A single family member's OSM map pin: identity color, faded by
/// [stalenessFor] the way the pre-migration `google_maps_flutter` marker
/// alpha did, with a tap target opening the member detail sheet. flutter_map
/// `Marker`s carry no `alpha`/`onTap` of their own, so both live here.
class _LiveMemberMarker extends StatelessWidget {
  const _LiveMemberMarker({
    required this.location,
    required this.isSelf,
    required this.color,
    required this.onTap,
  });

  final LiveLocation location;
  final bool isSelf;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final opacity = stalenessFor(
      DateTime.now().toUtc().difference(location.recordedAtUtc),
    ).opacity;

    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: opacity,
        child: Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelf ? AppColors.primaryTeal : color,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.surface, width: 3),
            boxShadow: const [
              BoxShadow(
                color: Color(0x220C3A3F),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
        ),
      ),
    );
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
      appBar: AppBar(
        title: const Text('Live Map'),
        actions: const [LogoutAction()],
      ),
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
