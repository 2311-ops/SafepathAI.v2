import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/geofence_api.dart';
import '../data/geofence_models.dart';
import 'geofence_registration_controller.dart';

abstract class GeofenceSavePermissionCoordinator {
  Future<SafeZoneActivation> requestAfterSave();
}

class RegistrationSavePermissionCoordinator
    implements GeofenceSavePermissionCoordinator {
  RegistrationSavePermissionCoordinator(this._ref);
  final Ref _ref;

  @override
  Future<SafeZoneActivation> requestAfterSave() async {
    await _ref
        .read(geofenceRegistrationControllerProvider.notifier)
        .requestBackgroundPermissionForSave();
    return switch (_ref.read(geofenceRegistrationControllerProvider)) {
      GeofenceRegistrationReady() => SafeZoneActivation.active,
      GeofenceRegistrationNeedsLocationPermission() =>
        SafeZoneActivation.needsLocationPermission,
      _ => SafeZoneActivation.inactive,
    };
  }
}

final geofenceSavePermissionCoordinatorProvider =
    Provider<GeofenceSavePermissionCoordinator>(
      (ref) => RegistrationSavePermissionCoordinator(ref),
    );

class GeofenceEditorState {
  const GeofenceEditorState({
    this.draft = const SafeZoneDraft(),
    this.validation = const SafeZoneValidation(),
    this.isSaving = false,
    this.saveError,
    this.savedZone,
  });

  final SafeZoneDraft draft;
  final SafeZoneValidation validation;
  final bool isSaving;
  final String? saveError;
  final SafeZone? savedZone;

  GeofenceEditorState copyWith({
    SafeZoneDraft? draft,
    SafeZoneValidation? validation,
    bool? isSaving,
    String? saveError,
    bool clearSaveError = false,
    SafeZone? savedZone,
  }) => GeofenceEditorState(
    draft: draft ?? this.draft,
    validation: validation ?? this.validation,
    isSaving: isSaving ?? this.isSaving,
    saveError: clearSaveError ? null : (saveError ?? this.saveError),
    savedZone: savedZone ?? this.savedZone,
  );
}

class GeofenceController extends Notifier<GeofenceEditorState> {
  @override
  GeofenceEditorState build() => const GeofenceEditorState();

  SafeZoneDraft get draft => state.draft;

  bool get isReadyForReview =>
      draft.name.trim().isNotEmpty &&
      draft.hasExplicitCenter &&
      draft.assignedMemberId != null &&
      draft.hasValidRadius &&
      draft.guardianRecipientIds.isNotEmpty;

  /// Used by the edit route to hydrate an existing draft. Validation remains
  /// authoritative here because a stale server payload must never make an
  /// invalid review/save appear valid.
  void loadDraftForEdit(SafeZoneDraft value) => _replace(value);

  /// Starts a clean create flow. The editor provider intentionally outlives
  /// routes so review/edit can share one draft, but a new add route must not
  /// inherit an abandoned custom name or member selection from an older try.
  void startNewDraft({
    required String familyId,
    required Set<String> activeGuardianIds,
    String? defaultAssignedMemberId,
    SafeZoneCenter? initialCenter,
  }) {
    _replace(
      SafeZoneDraft(
        familyId: familyId,
        center:
            initialCenter ?? const SafeZoneCenter(latitude: 0, longitude: 0),
        hasExplicitCenter: initialCenter != null,
        assignedMemberId: defaultAssignedMemberId,
        guardianRecipientIds: activeGuardianIds,
      ),
    );
  }

  /// Sets [familyId] unconditionally, but only seeds [guardianRecipientIds]
  /// from [activeGuardianIds] when the current draft has no recipients yet.
  /// Both the editor and the review screen call this on mount, so without
  /// this guard reaching review after deliberately narrowing the recipient
  /// set would silently reset it back to every active guardian — for a
  /// safety product that means notifying people the guardian just
  /// deselected.
  void loadFamily({
    required String familyId,
    required Set<String> activeGuardianIds,
  }) {
    _replace(
      draft.copyWith(
        familyId: familyId,
        guardianRecipientIds: draft.guardianRecipientIds.isEmpty
            ? activeGuardianIds
            : draft.guardianRecipientIds,
      ),
    );
  }

  void selectCategory(SafeZoneCategory category) {
    final defaultName = category.defaultName;
    _replace(
      draft.copyWith(
        category: category,
        name: draft.name.isEmpty || draft.name == draft.category.defaultName
            ? defaultName
            : draft.name,
      ),
    );
  }

  void setName(String name) => _replace(draft.copyWith(name: name));
  void setCenter(SafeZoneCenter center) =>
      _replace(draft.copyWith(center: center, hasExplicitCenter: true));
  void setAssignedMember(String? memberId) => _replace(
    memberId == null
        ? draft.copyWith(clearAssignedMember: true)
        : draft.copyWith(assignedMemberId: memberId),
  );
  void setGuardianRecipients(Set<String> recipients) =>
      _replace(draft.copyWith(guardianRecipientIds: recipients));
  void setSensitivity(SafeZoneSensitivity sensitivity) =>
      _replace(draft.copyWith(sensitivity: sensitivity));
  void setNotifyAssignedMember(bool value) =>
      _replace(draft.copyWith(notifyAssignedMember: value));
  void selectRadiusPreset(int radiusMeters) {
    if (SafeZoneDraft.radiusPresets.contains(radiusMeters)) {
      setRadiusMeters(radiusMeters);
    }
  }

  void setRadiusMeters(int radiusMeters) {
    if (radiusMeters >= SafeZoneDraft.minRadiusMeters &&
        radiusMeters <= SafeZoneDraft.maxRadiusMeters &&
        radiusMeters % SafeZoneDraft.radiusStepMeters == 0) {
      _replace(draft.copyWith(radiusMeters: radiusMeters));
    }
  }

  bool validateForReview() {
    final validation = SafeZoneValidation(
      name: draft.name.trim().isEmpty ? 'Enter a zone name.' : null,
      location: draft.hasExplicitCenter
          ? null
          : 'Choose a zone location before review.',
      member: draft.assignedMemberId == null ? 'Choose a family member.' : null,
      radius: draft.hasValidRadius
          ? null
          : 'Choose a radius from 100 m to 2 km.',
      recipients: draft.guardianRecipientIds.isEmpty
          ? 'Select at least one Guardian to receive alerts.'
          : null,
    );
    state = state.copyWith(validation: validation, clearSaveError: true);
    return validation.isValid;
  }

  Future<bool> save() async {
    if (!validateForReview()) return false;
    state = state.copyWith(isSaving: true, clearSaveError: true);
    try {
      final api = ref.read(geofenceApiProvider);
      final zone = draft.zoneId == null
          ? await api.create(draft)
          : await api.update(draft.zoneId!, draft);
      // This is intentionally post-API: opening a form or using the map must
      // never prompt for location; only the explicit save gesture may do so.
      final activation = await ref
          .read(geofenceSavePermissionCoordinatorProvider)
          .requestAfterSave();
      state = state.copyWith(
        isSaving: false,
        savedZone: zone.copyWith(activation: activation),
        clearSaveError: true,
      );
      return true;
    } on GeofenceApiException catch (error) {
      state = state.copyWith(isSaving: false, saveError: error.message);
      return false;
    } catch (_) {
      state = state.copyWith(
        isSaving: false,
        saveError:
            "We couldn't save this safe zone. Your changes are still here — try again.",
      );
      return false;
    }
  }

  void _replace(SafeZoneDraft next) {
    state = state.copyWith(
      draft: next,
      validation: const SafeZoneValidation(),
      clearSaveError: true,
    );
  }
}

final geofenceControllerProvider =
    NotifierProvider<GeofenceController, GeofenceEditorState>(
      GeofenceController.new,
    );

class GeofenceListState {
  const GeofenceListState({
    this.familyId,
    this.zones = const [],
    this.isLoading = false,
    this.error,
  });

  final String? familyId;
  final List<SafeZone> zones;
  final bool isLoading;
  final String? error;

  GeofenceListState copyWith({
    String? familyId,
    List<SafeZone>? zones,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) => GeofenceListState(
    familyId: familyId ?? this.familyId,
    zones: zones ?? this.zones,
    isLoading: isLoading ?? this.isLoading,
    error: clearError ? null : (error ?? this.error),
  );
}

class GeofenceListController extends Notifier<GeofenceListState> {
  @override
  GeofenceListState build() => const GeofenceListState();

  Future<void> load(String familyId) async {
    state = state.copyWith(
      familyId: familyId,
      isLoading: true,
      clearError: true,
    );
    try {
      final zones = await ref.read(geofenceApiProvider).list(familyId);
      state = GeofenceListState(familyId: familyId, zones: zones);
    } on GeofenceApiException catch (error) {
      state = state.copyWith(isLoading: false, error: error.message);
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        error: "Couldn't load safe zones. Check your connection and try again.",
      );
    }
  }

  Future<void> deleteZone(SafeZone zone) async {
    final familyId = state.familyId;
    if (familyId == null) return;
    try {
      await ref.read(geofenceApiProvider).delete(familyId, zone.id);
      state = state.copyWith(
        zones: state.zones.where((item) => item.id != zone.id).toList(),
        clearError: true,
      );
    } on GeofenceApiException catch (error) {
      state = state.copyWith(error: error.message);
    }
  }

  Future<void> toggleZone(SafeZone zone, bool enabled) async {
    final familyId = state.familyId;
    if (familyId == null) return;
    final previousZones = state.zones;
    final optimisticActivation = enabled
        ? SafeZoneActivation.active
        : SafeZoneActivation.inactive;
    state = state.copyWith(
      zones: _replaceZone(
        previousZones,
        zone.copyWith(activation: optimisticActivation),
      ),
      clearError: true,
    );
    try {
      final activation = await ref
          .read(geofenceApiProvider)
          .setActive(familyId, zone.id, enabled);
      state = state.copyWith(
        zones: _replaceZone(state.zones, zone.copyWith(activation: activation)),
        clearError: true,
      );
    } on GeofenceApiException catch (error) {
      state = state.copyWith(zones: previousZones, error: error.message);
    } catch (_) {
      state = state.copyWith(
        zones: previousZones,
        error:
            "Couldn't update this safe zone. Check your connection and try again.",
      );
    }
  }

  List<SafeZone> _replaceZone(List<SafeZone> zones, SafeZone next) => zones
      .map((item) => item.id == next.id ? next : item)
      .toList(growable: false);
}

final geofenceListControllerProvider =
    NotifierProvider<GeofenceListController, GeofenceListState>(
      GeofenceListController.new,
    );
