import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
          // Widened from the 44x44 tap-target-only box so the always-visible
          // name label (PROFILE-06) has room beneath the avatar — flutter_map
          // has no overflow anchor, so the declared box must contain the
          // whole Column[avatar, label] (research §5).
          width: 88,
          height: 72,
          alignment: Alignment.center,
          child: LiveMemberMarker(
            location: location,
            name: _memberName(location, state),
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
                          IconButton(
                            tooltip: 'Profile',
                            icon: const Icon(Icons.person_outline),
                            color: AppColors.ink,
                            onPressed: () => context.push('/profile'),
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

/// A single family member's OSM map marker: an avatar (or colored-initial
/// fallback, D-18) plus an always-visible name label (PROFILE-06), faded by
/// [stalenessFor] the way the pre-migration `google_maps_flutter` marker
/// alpha did, with a tap target opening the member detail sheet. flutter_map
/// `Marker`s carry no `alpha`/`onTap` of their own, so both live here.
///
/// Kept a self-contained `StatelessWidget` over a plain `List<Marker>` (no
/// per-marker global state) so a future `flutter_map_marker_cluster` layer
/// could wrap these without a rewrite (D-19 — compatibility only, the
/// clustering dependency itself is not added this phase). Public (not
/// underscore-private) so it can be exercised directly by widget tests.
class LiveMemberMarker extends StatelessWidget {
  const LiveMemberMarker({
    super.key,
    required this.location,
    required this.name,
    required this.isSelf,
    required this.color,
    required this.onTap,
  });

  final LiveLocation location;
  final String name;
  final bool isSelf;
  final Color color;
  final VoidCallback onTap;

  bool get _hasAvatar => (location.profileImageUrl?.trim().isNotEmpty ?? false);

  @override
  Widget build(BuildContext context) {
    final opacity = stalenessFor(
      DateTime.now().toUtc().difference(location.recordedAtUtc),
    ).opacity;

    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: opacity,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
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
              child: _hasAvatar
                  ? ClipOval(
                      child: CachedNetworkImage(
                        imageUrl: location.profileImageUrl!,
                        cacheKey:
                            '${location.userId}-${location.profileUpdatedAt?.toIso8601String()}',
                        width: 36,
                        height: 36,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => _initials(),
                        errorWidget: (context, url, error) => _initials(),
                      ),
                    )
                  : _initials(),
            ),
            const SizedBox(height: 2),
            _MarkerNameLabel(name: name),
          ],
        ),
      ),
    );
  }

  Widget _initials() {
    return Text(
      name.isEmpty ? '?' : name.substring(0, 1).toUpperCase(),
      style: AppTypography.body.copyWith(
        color: Colors.white,
        fontWeight: FontWeight.w800,
        letterSpacing: 0,
      ),
    );
  }
}

/// Always-visible name pill under a [LiveMemberMarker] (PROFILE-06 — the
/// name previously only appeared inside the tap-triggered member detail
/// sheet). Never uses SOS red per this phase's UI-SPEC scope rule.
class _MarkerNameLabel extends StatelessWidget {
  const _MarkerNameLabel({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.hairline),
        boxShadow: const [
          BoxShadow(
            color: Color(0x180C3A3F),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          // Manrope (not the mono `caption` role — that's reserved for
          // uppercase status badges, not a person's name) at a compact size
          // so the pill stays small on the map.
          style: AppTypography.title.copyWith(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppColors.ink,
            height: 1.2,
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
        actions: [
          IconButton(
            tooltip: 'Profile',
            icon: const Icon(Icons.person_outline),
            onPressed: () => context.push('/profile'),
          ),
          const LogoutAction(),
        ],
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
