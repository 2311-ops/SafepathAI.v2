// mobile/lib/features/geofencing/presentation/safe_zones_screen.dart
//
// `/safe-zones` list screen. Leads with a map header showing every zone as
// a category-colored circle, then one card per zone: a 42px category-tinted
// icon tile, a single "<radius> m · <member>" subtitle line, and a per-zone
// enable/disable switch (an amber caution row instead, for a zone that still
// needs location permission). Cards use the flat design-system surface
// treatment — white, hairline border, 16px radius, no Material elevation —
// and there is exactly one add affordance, the circular header control.
//
// Behavior/API preserved: same constructors (default/.empty/.error/.loading),
// same callbacks, plus `onToggle` for the switch and `mapOverride` as a test
// seam. Leaving `onToggle` null renders every switch disabled.

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../location/application/map_geometry.dart';
import '../../location/presentation/vector_map.dart';
import '../data/geofence_models.dart';

class SafeZonesScreen extends StatelessWidget {
  const SafeZonesScreen({
    super.key,
    required this.zones,
    this.memberNames = const {},
    this.onAdd,
    this.onOpen,
    this.onActivity,
    this.onToggle,
    this.onRetry,
    this.mapOverride,
  }) : isLoading = false,
       errorMessage = null;

  const SafeZonesScreen.empty({super.key, this.onAdd})
    : zones = const [],
      memberNames = const {},
      onOpen = null,
      onActivity = null,
      onToggle = null,
      onRetry = null,
      mapOverride = null,
      isLoading = false,
      errorMessage = null;

  const SafeZonesScreen.error({super.key, this.onRetry})
    : zones = const [],
      memberNames = const {},
      onAdd = null,
      onOpen = null,
      onActivity = null,
      onToggle = null,
      mapOverride = null,
      isLoading = false,
      errorMessage =
          "Couldn't load safe zones. Check your connection and try again.";

  const SafeZonesScreen.loading({super.key})
    : zones = const [],
      memberNames = const {},
      onAdd = null,
      onOpen = null,
      onActivity = null,
      onToggle = null,
      onRetry = null,
      mapOverride = null,
      isLoading = true,
      errorMessage = null;

  final List<SafeZone> zones;
  final Map<String, String> memberNames;
  final VoidCallback? onAdd;
  final ValueChanged<SafeZone>? onOpen;
  final ValueChanged<SafeZone>? onActivity;

  /// Enable/disable a zone from the list. Null renders the switches disabled.
  final void Function(SafeZone zone, bool enabled)? onToggle;
  final VoidCallback? onRetry;

  /// Test seam mirroring the other safe-zone screens — widget tests pass a
  /// stand-in because `VectorMap` mounts a native platform view.
  final Widget? mapOverride;

  final bool isLoading;
  final String? errorMessage;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.appBg,
    appBar: AppBar(
      title: const Text('Places & zones'),
      actions: [
        // Single add affordance (mockup): circular teal button in the header.
        Padding(
          padding: const EdgeInsets.only(right: AppSpacing.md),
          child: Semantics(
            label: 'Add safe zone',
            button: true,
            child: InkWell(
              onTap: onAdd,
              customBorder: const CircleBorder(),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: onAdd == null
                      ? AppColors.toggleOffTrack
                      : AppColors.primaryTeal,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.add, color: Colors.white, size: 22),
              ),
            ),
          ),
        ),
      ],
    ),
    body: SafeArea(child: _body(context)),
  );

  Widget _body(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (errorMessage != null) {
      return _StateMessage(
        icon: Icons.cloud_off_outlined,
        title: "Couldn't load safe zones",
        body: errorMessage!,
        action: OutlinedButton(
          onPressed: onRetry,
          child: const Text('Try again'),
        ),
      );
    }
    if (zones.isEmpty) {
      return _StateMessage(
        icon: Icons.add_location_alt_outlined,
        title: 'No safe zones yet',
        body:
            'Create a place alert for home, school, work, or anywhere your '
            'family cares about.',
        action: ElevatedButton(
          onPressed: onAdd,
          child: const Text('Add safe zone'),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.lg,
      ),
      children: [
        _ZonesOverviewMap(zones: zones, mapOverride: mapOverride),
        const SizedBox(height: AppSpacing.md),
        for (final zone in zones) ...[
          _SafeZoneCard(
            zone: zone,
            memberName: memberNames[zone.assignedMemberId] ?? 'Family member',
            onOpen: () => onOpen?.call(zone),
            onActivity: () => onActivity?.call(zone),
            onToggle: onToggle == null
                ? null
                : (enabled) => onToggle!(zone, enabled),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ],
    );
  }
}

/// Map header showing every zone as a translucent circle — the mockup's
/// leading element. Frames all zones at once so the list reads spatially.
class _ZonesOverviewMap extends StatelessWidget {
  const _ZonesOverviewMap({required this.zones, this.mapOverride});

  final List<SafeZone> zones;
  final Widget? mapOverride;

  @override
  Widget build(BuildContext context) {
    final content = mapOverride ?? _map();
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: SizedBox(
        height: 150,
        width: double.infinity,
        child: Semantics(
          label: 'Map showing ${zones.length} safe zones',
          image: true,
          child: ExcludeSemantics(child: content),
        ),
      ),
    );
  }

  Widget _map() {
    // Center on the mean of all zone centers so every circle is in frame at
    // a fixed overview zoom — cheaper and steadier than fitting exact bounds,
    // and this header is glanceable context, not an interactive map.
    final lat =
        zones.map((z) => z.center.latitude).reduce((a, b) => a + b) /
        zones.length;
    final lng =
        zones.map((z) => z.center.longitude).reduce((a, b) => a + b) /
        zones.length;

    return VectorMap(
      initialTarget: MapPoint(lat, lng),
      initialZoom: 12,
      circles: [
        for (final zone in zones)
          MapCircle(
            id: zone.id,
            center: MapPoint(zone.center.latitude, zone.center.longitude),
            radiusMeters: zone.radiusMeters.toDouble(),
            colorHex: _categoryHex(zone.category),
            outlineOpacity: .8,
          ),
      ],
    );
  }
}

class _SafeZoneCard extends StatelessWidget {
  const _SafeZoneCard({
    required this.zone,
    required this.memberName,
    this.onOpen,
    this.onActivity,
    this.onToggle,
  });

  final SafeZone zone;
  final String memberName;
  final VoidCallback? onOpen;
  final VoidCallback? onActivity;
  final ValueChanged<bool>? onToggle;

  @override
  Widget build(BuildContext context) {
    final needsPermission =
        zone.activation == SafeZoneActivation.needsLocationPermission;

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.hairline),
          ),
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _CategoryTile(category: zone.category),
                  const SizedBox(width: AppSpacing.xsMd),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(zone.name, style: AppTypography.title),
                        const SizedBox(height: 2),
                        Text(
                          '${zone.radiusMeters} m · $memberName',
                          style: AppTypography.bodySecondary,
                        ),
                      ],
                    ),
                  ),
                  if (!needsPermission)
                    Semantics(
                      label: '${zone.name} alerts',
                      child: Switch(
                        value: zone.isActive,
                        onChanged: onToggle,
                        activeTrackColor: AppColors.primaryTeal,
                        inactiveTrackColor: AppColors.toggleOffTrack,
                      ),
                    ),
                ],
              ),
              if (needsPermission) ...[
                const SizedBox(height: AppSpacing.xsMd),
                // Caution amber — a routine attention state, never SOS red.
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xsMd,
                    vertical: AppSpacing.sm,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.cautionBg,
                    border: Border.all(color: AppColors.cautionBorder),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.location_disabled_outlined,
                        size: 18,
                        color: AppColors.caution,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          'Location permission needed to activate',
                          style: AppTypography.bodySecondary.copyWith(
                            color: AppColors.cautionText,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              Align(
                alignment: Alignment.centerRight,
                child: Semantics(
                  label: 'View activity for ${zone.name}',
                  button: true,
                  child: TextButton.icon(
                    onPressed: onActivity,
                    icon: const Icon(Icons.timeline_outlined, size: 20),
                    label: const Text('View activity'),
                    style: TextButton.styleFrom(
                      minimumSize: const Size(48, 48),
                      foregroundColor: AppColors.primaryTeal,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 42px tinted rounded tile — the mockup's per-category color coding, so a
/// zone's type is readable at a glance without printing the enum.
class _CategoryTile extends StatelessWidget {
  const _CategoryTile({required this.category});
  final SafeZoneCategory category;

  @override
  Widget build(BuildContext context) {
    final color = _categoryColor(category);
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Icon(_categoryIcon(category), color: color, size: 24),
    );
  }
}

Color _categoryColor(SafeZoneCategory category) => switch (category) {
  SafeZoneCategory.home => AppColors.safe,
  SafeZoneCategory.school => AppColors.primaryTeal,
  SafeZoneCategory.university => AppColors.primaryTeal,
  SafeZoneCategory.workplace => AppColors.memberViolet,
  SafeZoneCategory.custom => AppColors.bodySecondary,
};

String _categoryHex(SafeZoneCategory category) => switch (category) {
  SafeZoneCategory.home => '#2F9E6B',
  SafeZoneCategory.school => '#2E7D7B',
  SafeZoneCategory.university => '#2E7D7B',
  SafeZoneCategory.workplace => '#6E66C9',
  SafeZoneCategory.custom => '#52697A',
};

IconData _categoryIcon(SafeZoneCategory category) => switch (category) {
  SafeZoneCategory.home => Icons.home_outlined,
  SafeZoneCategory.school => Icons.school_outlined,
  SafeZoneCategory.university => Icons.account_balance_outlined,
  SafeZoneCategory.workplace => Icons.work_outline,
  SafeZoneCategory.custom => Icons.place_outlined,
};

class _StateMessage extends StatelessWidget {
  const _StateMessage({
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
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: AppColors.primaryTeal),
          const SizedBox(height: AppSpacing.md),
          Text(title, style: AppTypography.title, textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.sm),
          Text(
            body,
            style: AppTypography.bodySecondary,
            textAlign: TextAlign.center,
          ),
          if (action != null) ...[
            const SizedBox(height: AppSpacing.md),
            action!,
          ],
        ],
      ),
    ),
  );
}
