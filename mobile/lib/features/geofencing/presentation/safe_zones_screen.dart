import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../data/geofence_models.dart';

class SafeZonesScreen extends StatelessWidget {
  const SafeZonesScreen({
    super.key,
    required this.zones,
    this.memberNames = const {},
    this.onAdd,
    this.onOpen,
    this.onActivity,
    this.onRetry,
  }) : isLoading = false,
       errorMessage = null;

  const SafeZonesScreen.empty({
    super.key,
    this.onAdd,
  }) : zones = const [],
       memberNames = const {},
       onOpen = null,
       onActivity = null,
       onRetry = null,
       isLoading = false,
       errorMessage = null;

  const SafeZonesScreen.error({
    super.key,
    this.onRetry,
  }) : zones = const [],
       memberNames = const {},
       onAdd = null,
       onOpen = null,
       onActivity = null,
       isLoading = false,
       errorMessage = "Couldn't load safe zones. Check your connection and try again.";

  const SafeZonesScreen.loading({super.key})
    : zones = const [],
      memberNames = const {},
      onAdd = null,
      onOpen = null,
      onActivity = null,
      onRetry = null,
      isLoading = true,
      errorMessage = null;

  final List<SafeZone> zones;
  final Map<String, String> memberNames;
  final VoidCallback? onAdd;
  final ValueChanged<SafeZone>? onOpen;
  final ValueChanged<SafeZone>? onActivity;
  final VoidCallback? onRetry;
  final bool isLoading;
  final String? errorMessage;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.appBg,
    appBar: AppBar(
      title: const Text('Safe zones'),
      actions: [
        IconButton(
          tooltip: 'Add safe zone',
          onPressed: onAdd,
          icon: const Icon(Icons.add_location_alt_outlined),
        ),
      ],
    ),
    body: SafeArea(child: _body(context)),
    floatingActionButton: zones.isEmpty || isLoading || errorMessage != null
        ? null
        : FloatingActionButton.extended(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: const Text('Add safe zone'),
          ),
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
        body: 'Create a place alert for home, school, work, or anywhere your family cares about.',
        action: ElevatedButton(
          onPressed: onAdd,
          child: const Text('Add safe zone'),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      itemCount: zones.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) {
        final zone = zones[index];
        return _SafeZoneCard(
          zone: zone,
          memberName: memberNames[zone.assignedMemberId] ?? 'Family member',
          onOpen: () => onOpen?.call(zone),
          onActivity: () => onActivity?.call(zone),
        );
      },
    );
  }
}

class _SafeZoneCard extends StatelessWidget {
  const _SafeZoneCard({
    required this.zone,
    required this.memberName,
    this.onOpen,
    this.onActivity,
  });

  final SafeZone zone;
  final String memberName;
  final VoidCallback? onOpen;
  final VoidCallback? onActivity;

  @override
  Widget build(BuildContext context) => Card(
    child: InkWell(
      onTap: onOpen,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.location_on_outlined, color: AppColors.primaryTeal),
                const SizedBox(width: 12),
                Expanded(child: Text(zone.name, style: AppTypography.title)),
                _ActivationChip(activation: zone.activation),
              ],
            ),
            const SizedBox(height: 8),
            Text(memberName, style: AppTypography.body),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              children: [
                Text('Type: ${zone.category.wireValue}', style: AppTypography.bodySecondary),
                Text('${zone.radiusMeters} m', style: AppTypography.bodySecondary),
              ],
            ),
            Align(
              alignment: Alignment.centerRight,
              child: Semantics(
                label: 'View activity for ${zone.name}',
                button: true,
                child: TextButton.icon(
                  onPressed: onActivity,
                  icon: const Icon(Icons.timeline_outlined),
                  label: const Text('View activity'),
                  style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _ActivationChip extends StatelessWidget {
  const _ActivationChip({required this.activation});
  final SafeZoneActivation activation;

  @override
  Widget build(BuildContext context) {
    final label = switch (activation) {
      SafeZoneActivation.active => 'Active',
      SafeZoneActivation.inactive => 'Inactive',
      SafeZoneActivation.needsLocationPermission => 'Location permission needed',
    };
    return Chip(label: Text(label));
  }
}

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
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: AppColors.primaryTeal),
          const SizedBox(height: 16),
          Text(title, style: AppTypography.title, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(body, style: AppTypography.bodySecondary, textAlign: TextAlign.center),
          if (action != null) ...[
            const SizedBox(height: 16),
            action!,
          ],
        ],
      ),
    ),
  );
}
