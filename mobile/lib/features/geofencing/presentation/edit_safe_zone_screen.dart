import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared_widgets/safepath_text_field.dart';
import '../../family/data/family_models.dart';
import '../../location/application/location_controller.dart';
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
  final _mapController = VectorMapController();
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
        final locationState = ref.read(locationControllerProvider).value;
        final defaultAssignedMemberId = _defaultAssignedMemberId;
        controller.startNewDraft(
          familyId: widget.familyId,
          activeGuardianIds: guardians,
          defaultAssignedMemberId: defaultAssignedMemberId,
          initialCenter: _initialCenterForNewDraft(
            locationState,
            defaultAssignedMemberId,
          ),
        );
      }
      _nameController.text = controller.draft.name;
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final editor = ref.watch(geofenceControllerProvider);
    final controller = ref.read(geofenceControllerProvider.notifier);
    final draft = editor.draft;
    final locationState = ref.watch(locationControllerProvider).value;
    final media = MediaQuery.of(context);
    if (!draft.hasExplicitCenter && widget.initialZone == null) {
      final nextCenter = _initialCenterForNewDraft(
        locationState,
        draft.assignedMemberId,
      );
      if (nextCenter != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          final latestDraft = ref.read(geofenceControllerProvider).draft;
          if (!latestDraft.hasExplicitCenter) {
            _setCenter(nextCenter, animate: true);
          }
        });
      }
    }

    return MediaQuery(
      data: media.copyWith(
        textScaler: MediaQuery.textScalerOf(
          context,
        ).clamp(maxScaleFactor: 1.15),
      ),
      child: Scaffold(
        backgroundColor: AppColors.appBg,
        appBar: AppBar(
          title: Text(
            widget.initialZone != null ? 'Edit safe zone' : 'Add safe zone',
          ),
        ),
        bottomNavigationBar: SafeArea(
          minimum: const EdgeInsets.all(16),
          child: SizedBox(
            height: 54,
            child: ElevatedButton(
              onPressed: editor.isSaving ? null : _handleReview,
              child: Text(editor.isSaving ? 'Saving...' : 'Review zone'),
            ),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 144),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.initialZone != null
                    ? 'Adjust the safe zone'
                    : 'Create a safe zone',
                style: AppTypography.heading.copyWith(fontSize: 26),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Pick the exact place on the map, set the radius, then choose who gets enter and leave alerts.',
                style: AppTypography.bodySecondary,
              ),
              const SizedBox(height: AppSpacing.lg),
              _LocationPickerPanel(
                draft: draft,
                map: draft.hasExplicitCenter
                    ? widget.mapOverride ?? _map(draft)
                    : null,
                hasLocation: draft.hasExplicitCenter,
                locationError: editor.validation.location,
                showNudges: _showNudges,
                onOpenMap: () => _openMapPicker(draft),
                onUseCurrentLocation: _useCurrentLocation,
                onToggleNudges: () =>
                    setState(() => _showNudges = !_showNudges),
                onNudge: (lat, lng) => _setCenter(
                  SafeZoneCenter(
                    latitude: draft.center.latitude + lat,
                    longitude: draft.center.longitude + lng,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              _CategoryAndNamePanel(
                selectedCategory: draft.category,
                nameController: _nameController,
                nameError: editor.validation.name,
                onCategorySelected: (category) {
                  controller.selectCategory(category);
                  _nameController.text = controller.draft.name;
                },
                onNameChanged: controller.setName,
              ),
              const SizedBox(height: 24),
              DropdownButtonFormField<String>(
                key: ValueKey('assigned-${draft.assignedMemberId ?? 'none'}'),
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
                    : (memberId) {
                        controller.setAssignedMember(memberId);
                        final center = _centerForMember(
                          ref.read(locationControllerProvider).value,
                          memberId,
                        );
                        final latestDraft = ref
                            .read(geofenceControllerProvider)
                            .draft;
                        if (center != null && !latestDraft.hasExplicitCenter) {
                          _setCenter(center, animate: true);
                        }
                      },
              ),
              const SizedBox(height: 24),
              Text('Radius', style: AppTypography.title),
              Wrap(
                spacing: 8,
                runSpacing: 8,
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
                  onChanged: (value) =>
                      controller.setRadiusMeters(value.round()),
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
                        title: Text(sensitivity.label),
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
      ),
    );
  }

  Future<void> _openMapPicker(SafeZoneDraft draft) async {
    final locationState = ref.read(locationControllerProvider).value;
    final suggestedCenter = draft.hasExplicitCenter
        ? draft.center
        : _initialCenterForNewDraft(locationState, draft.assignedMemberId);
    final selected = await Navigator.of(context).push<SafeZoneCenter>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => _SafeZoneMapPickerScreen(
          initialCenter: suggestedCenter ?? _fallbackMapCenter,
          hasInitialLocation: suggestedCenter != null,
          radiusMeters: draft.radiusMeters,
          mapOverride: widget.mapOverride,
        ),
      ),
    );

    if (!mounted || selected == null) return;
    _setCenter(selected, animate: true);
  }

  String? get _defaultAssignedMemberId =>
      widget.members
          .where((member) => member.role.name != 'guardian')
          .firstOrNull
          ?.userId ??
      widget.members.firstOrNull?.userId;

  SafeZoneCenter? _initialCenterForNewDraft(
    LocationState? state,
    String? assignedMemberId,
  ) => _centerForMember(state, assignedMemberId) ?? _centerForSelf(state);

  SafeZoneCenter? _centerForMember(LocationState? state, String? memberId) {
    if (state == null || memberId == null) return null;
    final location = state.members[memberId];
    if (location == null) return null;
    return SafeZoneCenter(latitude: location.lat, longitude: location.lng);
  }

  SafeZoneCenter? _centerForSelf(LocationState? state) {
    final self = state?.selfPosition;
    if (self == null) return null;
    return SafeZoneCenter(latitude: self.lat, longitude: self.lng);
  }

  void _handleReview() {
    final controller = ref.read(geofenceControllerProvider.notifier);
    if (controller.validateForReview()) {
      widget.onReview?.call();
      return;
    }

    final validation = ref.read(geofenceControllerProvider).validation;
    final message =
        validation.name ??
        validation.location ??
        validation.member ??
        validation.recipients ??
        validation.radius ??
        'Finish the highlighted fields.';
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _setCenter(SafeZoneCenter center, {bool animate = false}) {
    ref.read(geofenceControllerProvider.notifier).setCenter(center);
    if (animate) {
      _mapController.animateTo(
        lat: center.latitude,
        lng: center.longitude,
        zoom: 16,
      );
    }
  }

  void _useCurrentLocation() {
    final self = ref.read(locationControllerProvider).value?.selfPosition;
    if (self == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'Current location is not ready yet. Tap the map instead.',
            ),
          ),
        );
      return;
    }

    _setCenter(
      SafeZoneCenter(latitude: self.lat, longitude: self.lng),
      animate: true,
    );
  }

  Widget _map(SafeZoneDraft draft) => VectorMap(
    controller: _mapController,
    initialTarget: MapPoint(draft.center.latitude, draft.center.longitude),
    initialZoom: 15,
    onTap: (point) => _setCenter(
      SafeZoneCenter(latitude: point.lat, longitude: point.lng),
      animate: true,
    ),
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
          label:
              'Safe-zone center. Tap the map or fine tune to change location.',
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

const _fallbackMapCenter = SafeZoneCenter(latitude: 20, longitude: 0);

String _formatCenter(SafeZoneCenter center) =>
    '${center.latitude.toStringAsFixed(4)}, ${center.longitude.toStringAsFixed(4)}';

Color _categoryColor(SafeZoneCategory category) => switch (category) {
  SafeZoneCategory.home => AppColors.safe,
  SafeZoneCategory.school => AppColors.primaryTeal,
  SafeZoneCategory.university => AppColors.primaryTeal,
  SafeZoneCategory.workplace => AppColors.memberViolet,
  SafeZoneCategory.custom => AppColors.bodySecondary,
};

IconData _categoryIcon(SafeZoneCategory category) => switch (category) {
  SafeZoneCategory.home => Icons.home_outlined,
  SafeZoneCategory.school => Icons.school_outlined,
  SafeZoneCategory.university => Icons.account_balance_outlined,
  SafeZoneCategory.workplace => Icons.work_outline,
  SafeZoneCategory.custom => Icons.place_outlined,
};

class _CategoryAndNamePanel extends StatelessWidget {
  const _CategoryAndNamePanel({
    required this.selectedCategory,
    required this.nameController,
    required this.nameError,
    required this.onCategorySelected,
    required this.onNameChanged,
  });

  final SafeZoneCategory selectedCategory;
  final TextEditingController nameController;
  final String? nameError;
  final ValueChanged<SafeZoneCategory> onCategorySelected;
  final ValueChanged<String> onNameChanged;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.hairline),
        boxShadow: const [
          BoxShadow(
            color: Color(0x120C3A3F),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.category_outlined),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Zone type & name', style: AppTypography.title),
                      const SizedBox(height: 2),
                      Text(
                        'Choose what this place is, and give it a name your family will recognize.',
                        style: AppTypography.bodySecondary,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final category in SafeZoneCategory.values)
                  _CategoryOption(
                    key: ValueKey('category-option-${category.name}'),
                    category: category,
                    selected: selectedCategory == category,
                    onTap: () => onCategorySelected(category),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            SafePathTextField(
              label: 'Zone name',
              controller: nameController,
              errorText: nameError,
              onChanged: onNameChanged,
              prefixIcon: _categoryIcon(selectedCategory),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryOption extends StatelessWidget {
  const _CategoryOption({
    super.key,
    required this.category,
    required this.selected,
    required this.onTap,
  });

  final SafeZoneCategory category;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = _categoryColor(category);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeInOut,
          constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xsMd,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: selected ? color : color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
            border: selected ? null : Border.all(color: color),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _categoryIcon(category),
                size: 18,
                color: selected ? Colors.white : color,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                category.wireValue,
                style: AppTypography.body.copyWith(
                  color: selected ? Colors.white : color,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (selected) ...[
                const SizedBox(width: AppSpacing.xs),
                const Icon(Icons.check, size: 16, color: Colors.white),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _LocationPickerPanel extends StatelessWidget {
  const _LocationPickerPanel({
    required this.draft,
    required this.map,
    required this.hasLocation,
    required this.locationError,
    required this.showNudges,
    required this.onOpenMap,
    required this.onUseCurrentLocation,
    required this.onToggleNudges,
    required this.onNudge,
  });

  final SafeZoneDraft draft;
  final Widget? map;
  final bool hasLocation;
  final String? locationError;
  final bool showNudges;
  final VoidCallback onOpenMap;
  final VoidCallback onUseCurrentLocation;
  final VoidCallback onToggleNudges;
  final void Function(double lat, double lng) onNudge;

  @override
  Widget build(BuildContext context) {
    final viewHeight = MediaQuery.sizeOf(context).height;
    final mapHeight = (viewHeight * (viewHeight < 700 ? 0.24 : 0.28)).clamp(
      150.0,
      260.0,
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.hairline),
        boxShadow: const [
          BoxShadow(
            color: Color(0x120C3A3F),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.add_location_alt_outlined),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Zone location', style: AppTypography.title),
                      const SizedBox(height: 2),
                      Text(
                        'Open the map and tap the place to set the marker.',
                        style: AppTypography.bodySecondary,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                height: mapHeight,
                width: double.infinity,
                child: hasLocation && map != null
                    ? map!
                    : const _LocationPlaceholder(),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (hasLocation)
                  _MapInstructionChip(text: _formatCenter(draft.center))
                else
                  const _MapInstructionChip(text: 'No location selected'),
                SizedBox(
                  height: 48,
                  child: FilledButton.tonalIcon(
                    onPressed: onOpenMap,
                    icon: const Icon(Icons.map_outlined),
                    label: const Text('Choose on map'),
                  ),
                ),
              ],
            ),
            if (locationError != null) _ValidationText(locationError!),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onUseCurrentLocation,
                    icon: const Icon(Icons.my_location_outlined),
                    label: const Text('Current'),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onToggleNudges,
                    icon: const Icon(Icons.open_with),
                    label: Text(showNudges ? 'Hide tune' : 'Fine tune'),
                  ),
                ),
              ],
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: showNudges
                  ? Padding(
                      key: const ValueKey('nudge-controls'),
                      padding: const EdgeInsets.only(top: AppSpacing.sm),
                      child: _NudgeControls(onNudge: onNudge),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

class _SafeZoneMapPickerScreen extends StatefulWidget {
  const _SafeZoneMapPickerScreen({
    required this.initialCenter,
    required this.hasInitialLocation,
    required this.radiusMeters,
    this.mapOverride,
  });

  final SafeZoneCenter initialCenter;
  final bool hasInitialLocation;
  final int radiusMeters;
  final Widget? mapOverride;

  @override
  State<_SafeZoneMapPickerScreen> createState() =>
      _SafeZoneMapPickerScreenState();
}

class _SafeZoneMapPickerScreenState extends State<_SafeZoneMapPickerScreen> {
  late SafeZoneCenter _center = widget.initialCenter;
  late bool _hasCenter = widget.hasInitialLocation;
  final _controller = VectorMapController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.appBg,
      appBar: AppBar(
        title: const Text('Pick zone location'),
        actions: [
          TextButton(
            onPressed: _hasCenter
                ? () => Navigator.of(context).pop(_center)
                : null,
            child: const Text('Done'),
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(child: widget.mapOverride ?? _map()),
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.surface.withValues(alpha: 0.94),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.hairline),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x240C3A3F),
                        blurRadius: 20,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.touch_app_outlined),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Text(
                                'Tap the map to move the safe-zone marker.',
                                style: AppTypography.body,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          _hasCenter
                              ? _formatCenter(_center)
                              : 'Drag to your area, then tap the map.',
                          style: AppTypography.bodySecondary,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton.icon(
                            onPressed: _hasCenter
                                ? () => Navigator.of(context).pop(_center)
                                : null,
                            icon: const Icon(Icons.check),
                            label: const Text('Use this location'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _map() => VectorMap(
    controller: _controller,
    initialTarget: MapPoint(_center.latitude, _center.longitude),
    initialZoom: _hasCenter ? 16 : 1.5,
    onTap: (point) {
      final next = SafeZoneCenter(latitude: point.lat, longitude: point.lng);
      setState(() {
        _center = next;
        _hasCenter = true;
      });
      _controller.animateTo(lat: point.lat, lng: point.lng, zoom: 16);
    },
    circles: [
      if (_hasCenter)
        MapCircle(
          id: 'picker-safe-zone-radius',
          center: MapPoint(_center.latitude, _center.longitude),
          radiusMeters: widget.radiusMeters.toDouble(),
          colorHex: '#2E7D7B',
          outlineOpacity: .8,
        ),
    ],
    markers: [
      if (_hasCenter)
        OverlayMarker(
          id: 'picker-safe-zone-center',
          lat: _center.latitude,
          lng: _center.longitude,
          width: 56,
          height: 56,
          child: const Icon(
            Icons.location_pin,
            color: AppColors.primaryTeal,
            size: 56,
          ),
        ),
    ],
  );
}

class _LocationPlaceholder extends StatelessWidget {
  const _LocationPlaceholder();

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(color: AppColors.primaryTintBg),
    child: Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.location_searching_outlined,
              color: AppColors.primaryTeal,
              size: 34,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'No location selected',
              textAlign: TextAlign.center,
              style: AppTypography.title,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Use a member location, your current location, or choose on map.',
              textAlign: TextAlign.center,
              style: AppTypography.bodySecondary,
            ),
          ],
        ),
      ),
    ),
  );
}

class _NudgeControls extends StatelessWidget {
  const _NudgeControls({required this.onNudge});
  final void Function(double lat, double lng) onNudge;
  @override
  Widget build(BuildContext context) => Wrap(
    alignment: WrapAlignment.center,
    spacing: AppSpacing.sm,
    runSpacing: AppSpacing.sm,
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

class _MapInstructionChip extends StatelessWidget {
  const _MapInstructionChip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: AppColors.surface.withValues(alpha: 0.92),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.hairline),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.touch_app_outlined, size: 16),
          const SizedBox(width: AppSpacing.xs),
          Text(text, style: AppTypography.bodySecondary),
        ],
      ),
    ),
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
