import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/geofencing/application/geofence_controller.dart';
import 'package:mobile/features/geofencing/data/geofence_api.dart';
import 'package:mobile/features/geofencing/data/geofence_models.dart';

void main() {
  group('GeofenceController', () {
    test('uses accessible safe-zone defaults and preserves category names', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final controller = container.read(geofenceControllerProvider.notifier);

      expect(controller.draft.radiusMeters, 100);
      expect(controller.draft.sensitivity, SafeZoneSensitivity.reliable);
      expect(controller.draft.notifyAssignedMember, isFalse);
      controller.selectCategory(SafeZoneCategory.school);
      expect(controller.draft.name, 'School');
      controller.setName('Maya school');
      controller.selectCategory(SafeZoneCategory.home);
      expect(controller.draft.name, 'Maya school');
    });

    test('validates name, member, radius, and guardian recipients before review', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final controller = container.read(geofenceControllerProvider.notifier);

      controller.setName('');
      controller.setRadiusMeters(99);

      expect(controller.validateForReview(), isFalse);
      expect(controller.state.value!.validation.name, isNotNull);
      expect(controller.state.value!.validation.member, isNotNull);
      expect(controller.state.value!.validation.radius, isNotNull);
      expect(controller.state.value!.validation.recipients, isNotNull);
    });

    test('maps presets and fine slider values while rejecting invalid radii', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final controller = container.read(geofenceControllerProvider.notifier);

      controller.selectRadiusPreset(1000);
      expect(controller.draft.radiusMeters, 1000);
      controller.setRadiusMeters(1125);
      expect(controller.draft.radiusMeters, 1125);
      controller.setRadiusMeters(1111);
      expect(controller.draft.radiusMeters, 1125);
    });

    test('saves first, then retains a needs-permission inactive zone on denial', () async {
      final api = _FakeGeofenceApi();
      final permission = _FakeSavePermissionCoordinator(
        SafeZoneActivation.needsLocationPermission,
      );
      final container = ProviderContainer(
        overrides: [
          geofenceApiProvider.overrideWithValue(api),
          geofenceSavePermissionCoordinatorProvider.overrideWithValue(permission),
        ],
      );
      addTearDown(container.dispose);
      final controller = container.read(geofenceControllerProvider.notifier);
      _makeValid(controller);

      final result = await controller.save();

      expect(result, isTrue);
      expect(api.createCalls, 1);
      expect(permission.calls, 1);
      expect(controller.state.value!.savedZone!.activation,
          SafeZoneActivation.needsLocationPermission);
      expect(controller.state.value!.savedZone!.isActive, isFalse);
    });

    test('keeps the entered draft when the authoritative API rejects a save', () async {
      final api = _FakeGeofenceApi(throwsOnCreate: true);
      final container = ProviderContainer(
        overrides: [geofenceApiProvider.overrideWithValue(api)],
      );
      addTearDown(container.dispose);
      final controller = container.read(geofenceControllerProvider.notifier);
      _makeValid(controller);

      final result = await controller.save();

      expect(result, isFalse);
      expect(controller.draft.name, 'Home');
      expect(controller.state.value!.saveError, isNotNull);
    });
  });
}

void _makeValid(GeofenceController controller) {
  controller.setName('Home');
  controller.setCenter(
    const SafeZoneCenter(latitude: 30.0444, longitude: 31.2357),
  );
  controller.setAssignedMember('member-1');
  controller.setGuardianRecipients(const {'guardian-1'});
}

class _FakeGeofenceApi implements GeofenceApi {
  _FakeGeofenceApi({this.throwsOnCreate = false});

  final bool throwsOnCreate;
  int createCalls = 0;

  @override
  Future<SafeZone> create(SafeZoneDraft draft) async {
    createCalls++;
    if (throwsOnCreate) throw const GeofenceApiException('Save failed');
    return SafeZone(
      id: 'zone-1',
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
  Future<SafeZone> update(String zoneId, SafeZoneDraft draft) => create(draft);
}

class _FakeSavePermissionCoordinator implements GeofenceSavePermissionCoordinator {
  _FakeSavePermissionCoordinator(this.result);

  final SafeZoneActivation result;
  int calls = 0;

  @override
  Future<SafeZoneActivation> requestAfterSave() async {
    calls++;
    return result;
  }
}
