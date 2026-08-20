import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../family/data/family_models.dart';
import '../../location/application/map_geometry.dart';
import '../../location/presentation/vector_map.dart';
import '../application/geofence_controller.dart';
import '../data/geofence_models.dart';

class SafeZoneReviewScreen extends ConsumerStatefulWidget {
  const SafeZoneReviewScreen({
    super.key,
    required this.familyId,
    required this.members,
    this.mapOverride,
    this.onEditLocation,
    this.onEditDetails,
    this.onEditRadius,
    this.onEditSensitivity,
    this.onEditNotifications,
    this.onSaved,
  });
  final String familyId;
  final List<FamilyMemberView> members;
  final Widget? mapOverride;
  final VoidCallback? onEditLocation;
  final VoidCallback? onEditDetails;
  final VoidCallback? onEditRadius;
  final VoidCallback? onEditSensitivity;
  final VoidCallback? onEditNotifications;
  final ValueChanged<SafeZone>? onSaved;
  @override
  ConsumerState<SafeZoneReviewScreen> createState() =>
      _SafeZoneReviewScreenState();
}

class _SafeZoneReviewScreenState extends ConsumerState<SafeZoneReviewScreen> {
  @override
  void initState() {
    super.initState();
    final guardians = widget.members
        .where((m) => m.role.name == 'guardian')
        .map((m) => m.userId)
        .toSet();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref
            .read(geofenceControllerProvider.notifier)
            .loadFamily(
              familyId: widget.familyId,
              activeGuardianIds: guardians,
            );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(geofenceControllerProvider);
    final draft = state.draft;
    final controller = ref.read(geofenceControllerProvider.notifier);
    final assigned = widget.members
        .where((m) => m.userId == draft.assignedMemberId)
        .firstOrNull;
    return Scaffold(
      backgroundColor: AppColors.appBg,
      appBar: AppBar(title: const Text('Review safe zone')),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(16),
        child: SizedBox(
          height: 52,
          child: ElevatedButton(
            onPressed: state.isSaving
                ? null
                : () async {
                    if (await controller.save()) {
                      final zone = ref
                          .read(geofenceControllerProvider)
                          .savedZone;
                      if (zone != null) widget.onSaved?.call(zone);
                    }
                  },
            child: Text(state.isSaving ? 'Saving…' : 'Save safe zone'),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 96),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 280, child: widget.mapOverride ?? _map(draft)),
            const SizedBox(height: 16),
            _Group(
              title: 'Location',
              value:
                  '${draft.center.latitude.toStringAsFixed(5)}, ${draft.center.longitude.toStringAsFixed(5)}',
              action: 'Edit location',
              onPressed: widget.onEditLocation,
            ),
            _Group(
              title: 'Zone details',
              value: '${draft.name}\n${draft.category.wireValue}',
              action: 'Edit details',
              onPressed: widget.onEditDetails,
            ),
            _Group(
              title: 'Assigned member',
              value: assigned?.displayName ?? 'Choose a family member',
              action: 'Edit details',
              onPressed: widget.onEditDetails,
            ),
            _Group(
              title: 'Radius',
              value: '${draft.radiusMeters} m',
              action: 'Edit radius',
              onPressed: widget.onEditRadius,
            ),
            _Group(
              title: 'Sensitivity',
              value: draft.sensitivity.label,
              action: 'Edit sensitivity',
              onPressed: widget.onEditSensitivity,
            ),
            _Group(
              title: 'Guardian recipients',
              value: draft.guardianRecipientIds.isEmpty
                  ? 'None selected'
                  : '${draft.guardianRecipientIds.length} Guardian(s) selected',
              action: 'Edit notifications',
              onPressed: widget.onEditNotifications,
            ),
            _Group(
              title: 'Member notification',
              value: draft.notifyAssignedMember
                  ? 'Also notify assigned member'
                  : 'Assigned member is not notified',
              action: 'Edit notifications',
              onPressed: widget.onEditNotifications,
            ),
            if (state.saveError != null)
              Text(
                state.saveError!,
                style: AppTypography.bodySecondary.copyWith(
                  color: AppColors.caution,
                ),
              ),
            if (state.savedZone?.activation ==
                SafeZoneActivation.needsLocationPermission)
              const Padding(
                padding: EdgeInsets.only(top: 16),
                child: Text(
                  'Location permission needed — Allow location access in Settings to activate alerts for this zone.',
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _map(SafeZoneDraft draft) => VectorMap(
    initialTarget: MapPoint(draft.center.latitude, draft.center.longitude),
    initialZoom: 15,
    circles: [
      MapCircle(
        id: 'review-safe-zone',
        center: MapPoint(draft.center.latitude, draft.center.longitude),
        radiusMeters: draft.radiusMeters.toDouble(),
        colorHex: '#2E7D7B',
        outlineOpacity: .8,
      ),
    ],
    markers: [
      OverlayMarker(
        id: 'review-center',
        lat: draft.center.latitude,
        lng: draft.center.longitude,
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
}

class _Group extends StatelessWidget {
  const _Group({
    required this.title,
    required this.value,
    required this.action,
    this.onPressed,
  });
  final String title;
  final String value;
  final String action;
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTypography.caption),
          const SizedBox(height: 4),
          Text(value, style: AppTypography.body),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: onPressed,
              icon: const Icon(Icons.edit_outlined),
              label: Text(action),
            ),
          ),
        ],
      ),
    ),
  );
}
