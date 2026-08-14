// Configurable fake for [GeofenceApi], following the existing test/helpers/
// convention (see fake_family_api.dart). Deliberately separate from the
// private `_FakeGeofenceApi` inside geofence_controller_test.dart — that
// file is left untouched.

import 'package:mobile/features/geofencing/data/geofence_api.dart';
import 'package:mobile/features/geofencing/data/geofence_models.dart';

class FakeGeofenceApi implements GeofenceApi {
  List<SafeZone> zonesToReturn = const [];
  bool throwsOnCreate = false;
  bool throwsOnUpdate = false;

  int listCalls = 0;
  int createCalls = 0;
  int updateCalls = 0;
  int deleteCalls = 0;

  SafeZoneDraft? lastCreateDraft;
  SafeZoneDraft? lastUpdateDraft;
  String? lastUpdateZoneId;

  @override
  Future<List<SafeZone>> list(String familyId) async {
    listCalls++;
    return zonesToReturn;
  }

  @override
  Future<SafeZone> get(String familyId, String zoneId) async =>
      zonesToReturn.firstWhere((zone) => zone.id == zoneId);

  @override
  Future<List<GeofenceActivity>> activity(
    String familyId,
    GeofenceActivityFilters filters,
  ) async => const [];

  @override
  Future<SafeZone> create(SafeZoneDraft draft) async {
    createCalls++;
    lastCreateDraft = draft;
    if (throwsOnCreate) {
      throw const GeofenceApiException('That safe zone could not be saved.');
    }
    return SafeZone(
      id: 'zone-new',
      name: draft.name,
      category: draft.category,
      center: draft.center,
      radiusMeters: draft.radiusMeters,
      assignedMemberId: draft.assignedMemberId!,
      sensitivity: draft.sensitivity,
      guardianRecipientIds: draft.guardianRecipientIds,
      notifyAssignedMember: draft.notifyAssignedMember,
    );
  }

  @override
  Future<SafeZone> update(String zoneId, SafeZoneDraft draft) async {
    updateCalls++;
    lastUpdateZoneId = zoneId;
    lastUpdateDraft = draft;
    if (throwsOnUpdate) {
      throw const GeofenceApiException('That safe zone could not be saved.');
    }
    return SafeZone(
      id: zoneId,
      name: draft.name,
      category: draft.category,
      center: draft.center,
      radiusMeters: draft.radiusMeters,
      assignedMemberId: draft.assignedMemberId!,
      sensitivity: draft.sensitivity,
      guardianRecipientIds: draft.guardianRecipientIds,
      notifyAssignedMember: draft.notifyAssignedMember,
    );
  }

  @override
  Future<void> delete(String familyId, String zoneId) async {
    deleteCalls++;
  }
}
