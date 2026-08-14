import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../location/application/map_geometry.dart';
import '../../location/presentation/vector_map.dart';
import '../data/geofence_models.dart';

class SafeZoneDetailScreen extends StatelessWidget {
  const SafeZoneDetailScreen({
    super.key,
    required this.zone,
    required this.assignedMemberName,
    this.mapOverride,
    this.onEdit,
    this.onActivity,
    this.onOpenSettings,
    this.onDeleteConfirmed,
  });

  final SafeZone zone;
  final String assignedMemberName;
  final Widget? mapOverride;
  final VoidCallback? onEdit;
  final VoidCallback? onActivity;
  final VoidCallback? onOpenSettings;
  final ValueChanged<SafeZone>? onDeleteConfirmed;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.appBg,
    appBar: AppBar(title: Text(zone.name)),
    bottomNavigationBar: SafeArea(
      minimum: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Edit zone'),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: TextButton.icon(
              onPressed: () => _confirmDelete(context),
              icon: const Icon(Icons.delete_outline),
              label: const Text('Delete zone'),
            ),
          ),
        ],
      ),
    ),
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(height: 240, child: mapOverride ?? _map()),
            const SizedBox(height: 16),
            _InfoRow(title: 'Assigned member', value: assignedMemberName),
            _InfoRow(title: 'Type', value: zone.category.wireValue),
            _InfoRow(title: 'Radius', value: '${zone.radiusMeters} m'),
            _InfoRow(title: 'Sensitivity', value: zone.sensitivity.wireValue),
            _InfoRow(title: 'Status', value: _activationLabel(zone.activation)),
            if (zone.activation == SafeZoneActivation.needsLocationPermission)
              Card(
                color: AppColors.surface,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Location permission needed',
                        style: AppTypography.title,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Open Settings and allow background location so SafePath can activate this zone.',
                        style: AppTypography.bodySecondary,
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: onOpenSettings,
                        icon: const Icon(Icons.settings_outlined),
                        label: const Text('Open Settings'),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: AppSpacing.md),
            OutlinedButton.icon(
              onPressed: onActivity,
              icon: const Icon(Icons.timeline_outlined),
              label: const Text('View activity'),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _map() => VectorMap(
    initialTarget: MapPoint(zone.center.latitude, zone.center.longitude),
    initialZoom: 15,
    circles: [
      MapCircle(
        id: zone.id,
        center: MapPoint(zone.center.latitude, zone.center.longitude),
        radiusMeters: zone.radiusMeters.toDouble(),
        colorHex: '#2E7D7B',
        outlineOpacity: .8,
      ),
    ],
    markers: [
      OverlayMarker(
        id: '${zone.id}-center',
        lat: zone.center.latitude,
        lng: zone.center.longitude,
        width: 48,
        height: 48,
        child: const Icon(
          Icons.location_pin,
          color: AppColors.primaryTeal,
          size: 48,
        ),
      ),
    ],
  );

  Future<void> _confirmDelete(BuildContext context) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete ${zone.name}?'),
        content: const Text(
          'Alerts stop immediately, but past activity remains available until retention expires.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep safe zone'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete zone'),
          ),
        ],
      ),
    );
    if (shouldDelete == true) {
      onDeleteConfirmed?.call(zone);
    }
  }

  static String _activationLabel(SafeZoneActivation activation) =>
      switch (activation) {
        SafeZoneActivation.active => 'Active',
        SafeZoneActivation.inactive => 'Inactive',
        SafeZoneActivation.needsLocationPermission =>
          'Location permission needed',
      };
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.title, required this.value});
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(child: Text(title, style: AppTypography.caption)),
          const SizedBox(width: 16),
          Flexible(
            child: Text(
              value,
              style: AppTypography.body,
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    ),
  );
}
