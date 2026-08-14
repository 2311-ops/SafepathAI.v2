import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../family/data/family_models.dart';
import '../../location/application/map_geometry.dart';
import '../../location/presentation/vector_map.dart';
import '../application/geofence_controller.dart';
import '../data/geofence_models.dart';

class SafeZoneEditorScreen extends ConsumerStatefulWidget {
  const SafeZoneEditorScreen({
    super.key,
    required this.familyId,
    required this.members,
    this.mapOverride,
    this.onReview,
    this.initialZone,
  });
  final String familyId;
  final List<FamilyMemberView> members;
  final Widget? mapOverride;
  final VoidCallback? onReview;

  /// When supplied, this screen is in edit mode: the draft is hydrated from
  /// this existing zone (carrying its id) instead of a fresh
  /// `loadFamily(...)` call, so saving issues an update rather than a
  /// create.
  final SafeZone? initialZone;
  @override
  ConsumerState<SafeZoneEditorScreen> createState() =>
      _SafeZoneEditorScreenState();
}

class _SafeZoneEditorScreenState extends ConsumerState<SafeZoneEditorScreen> {
  final _nameController = TextEditingController();
  bool _showNudges = false;

  @override
  void initState() {
    super.initState();
    final guardians = widget.members
        .where((member) => member.role.name == 'guardian')
        .map((member) => member.userId)
        .toSet();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final controller = ref.read(geofenceControllerProvider.notifier);
      final initialZone = widget.initialZone;
      if (initialZone != null) {
        controller.loadDraftForEdit(
          SafeZoneDraft.fromZone(initialZone, familyId: widget.familyId),
        );
      } else {
        controller.loadFamily(
          familyId: widget.familyId,
          activeGuardianIds: guardians,
        );
      }
      _nameController.text = controller.draft.name;
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final editor = ref.watch(geofenceControllerProvider);
    final controller = ref.read(geofenceControllerProvider.notifier);
    final draft = editor.draft;
    return Scaffold(
      backgroundColor: AppColors.appBg,
      appBar: AppBar(
        title: Text(
          widget.initialZone != null ? 'Edit safe zone' : 'Add safe zone',
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(16),
        child: SizedBox(
          height: 52,
          child: ElevatedButton(
            onPressed: editor.isSaving || !controller.isReadyForReview
                ? null
                : widget.onReview,
            child: Text(editor.isSaving ? 'Saving…' : 'Review zone'),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 96),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Position on map', style: AppTypography.title),
            const SizedBox(height: 8),
            SizedBox(
              height: 280,
              child: Stack(
                children: [
                  Positioned.fill(child: widget.mapOverride ?? _map(draft)),
                  Align(
                    alignment: Alignment.bottomRight,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: FilledButton.icon(
                        onPressed: () =>
                            setState(() => _showNudges = !_showNudges),
                        icon: const Icon(Icons.open_with),
                        label: const Text('Move pin'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (_showNudges)
              _NudgeControls(
                onNudge: (lat, lng) => controller.setCenter(
                  SafeZoneCenter(
                    latitude: draft.center.latitude + lat,
                    longitude: draft.center.longitude + lng,
                  ),
                ),
              ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.my_location_outlined),
              label: const Text('Use current location'),
            ),
            const SizedBox(height: 24),
            Text('ZONE TYPE AND NAME', style: AppTypography.caption),
            Wrap(
              spacing: 8,
              children: [
                for (final category in SafeZoneCategory.values)
                  ChoiceChip(
                    label: Text(category.wireValue),
                    selected: draft.category == category,
                    onSelected: (_) {
                      controller.selectCategory(category);
                      _nameController.text = controller.draft.name;
                    },
                  ),
              ],
            ),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'ZONE NAME',
                errorText: editor.validation.name,
              ),
              onChanged: controller.setName,
            ),
            const SizedBox(height: 24),
            DropdownButtonFormField<String>(
              initialValue: draft.assignedMemberId,
              decoration: InputDecoration(
                labelText: 'Family member',
                errorText: editor.validation.member,
              ),
              items: widget.members
                  .map(
                    (member) => DropdownMenuItem(
                      value: member.userId,
                      child: Text(member.displayName ?? 'Family member'),
                    ),
                  )
                  .toList(growable: false),
              onChanged: widget.members.isEmpty
                  ? null
                  : controller.setAssignedMember,
            ),
            const SizedBox(height: 24),
            Text('Radius', style: AppTypography.title),
            Wrap(
              spacing: 8,
              children: [
                for (final preset in SafeZoneDraft.radiusPresets)
                  ChoiceChip(
                    label: Text(preset == 1000 ? '1 km' : '$preset m'),
                    selected: draft.radiusMeters == preset,
                    onSelected: (_) => controller.selectRadiusPreset(preset),
                  ),
              ],
            ),
            Semantics(
              label: 'Safe-zone radius ${draft.radiusMeters} metres',
              child: Slider(
                value: draft.radiusMeters.toDouble(),
                min: 100,
                max: 2000,
                divisions: 76,
                label: '${draft.radiusMeters} m',
                onChanged: (value) => controller.setRadiusMeters(value.round()),
              ),
            ),
            Text('${draft.radiusMeters} m', style: AppTypography.body),
            if (editor.validation.radius != null)
              _ValidationText(editor.validation.radius!),
            const SizedBox(height: 24),
            Text('Sensitivity', style: AppTypography.title),
            RadioGroup<SafeZoneSensitivity>(
              groupValue: draft.sensitivity,
              onChanged: (value) => controller.setSensitivity(value!),
              child: Column(
                children: [
                  for (final sensitivity in SafeZoneSensitivity.values)
                    RadioListTile<SafeZoneSensitivity>(
                      value: sensitivity,
                      title: Text(sensitivity.wireValue),
                      subtitle: Text(sensitivity.description),
                    ),
                ],
              ),
            ),
            Text('Notifications', style: AppTypography.title),
            for (final guardian in widget.members.where(
              (m) => m.role.name == 'guardian',
            ))
              CheckboxListTile(
                value: draft.guardianRecipientIds.contains(guardian.userId),
                onChanged: (selected) {
                  final recipients = {...draft.guardianRecipientIds};
                  selected == true
                      ? recipients.add(guardian.userId)
                      : recipients.remove(guardian.userId);
                  controller.setGuardianRecipients(recipients);
                },
                title: Text(guardian.displayName ?? 'Guardian'),
              ),
            if (editor.validation.recipients != null)
              _ValidationText(editor.validation.recipients!),
            SwitchListTile(
              value: draft.notifyAssignedMember,
              onChanged: controller.setNotifyAssignedMember,
              title: const Text('Also notify assigned member'),
              subtitle: const Text(
                'Let them know when they enter or leave this zone.',
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
        id: 'safe-zone-radius',
        center: MapPoint(draft.center.latitude, draft.center.longitude),
        radiusMeters: draft.radiusMeters.toDouble(),
        colorHex: '#2E7D7B',
        outlineOpacity: .8,
      ),
    ],
    markers: [
      OverlayMarker(
        id: 'safe-zone-center',
        lat: draft.center.latitude,
        lng: draft.center.longitude,
        width: 48,
        height: 48,
        child: Semantics(
          label: 'Safe-zone center. Drag to change location.',
          child: Icon(
            Icons.location_pin,
            color: AppColors.primaryTeal,
            size: 48,
          ),
        ),
      ),
    ],
  );
}

class _NudgeControls extends StatelessWidget {
  const _NudgeControls({required this.onNudge});
  final void Function(double lat, double lng) onNudge;
  @override
  Widget build(BuildContext context) => Wrap(
    alignment: WrapAlignment.center,
    children: [
      IconButton(
        onPressed: () => onNudge(.0001, 0),
        icon: const Icon(Icons.keyboard_arrow_up),
        tooltip: 'Move pin north',
      ),
      IconButton(
        onPressed: () => onNudge(0, -.0001),
        icon: const Icon(Icons.keyboard_arrow_left),
        tooltip: 'Move pin west',
      ),
      IconButton(
        onPressed: () => onNudge(0, .0001),
        icon: const Icon(Icons.keyboard_arrow_right),
        tooltip: 'Move pin east',
      ),
      IconButton(
        onPressed: () => onNudge(-.0001, 0),
        icon: const Icon(Icons.keyboard_arrow_down),
        tooltip: 'Move pin south',
      ),
    ],
  );
}

class _ValidationText extends StatelessWidget {
  const _ValidationText(this.message);
  final String message;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 4),
    child: Text(
      message,
      style: AppTypography.bodySecondary.copyWith(color: AppColors.caution),
    ),
  );
}
