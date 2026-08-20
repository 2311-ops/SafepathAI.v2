// Behavior under test — the safe-zone JSON wire contract against the real
// ASP.NET Core backend enums.
//
// The regression this suite exists to catch: `SafeZoneSensitivity` used a
// single `wireValue` field for BOTH the API contract and the on-screen label.
// 04-UI-SPEC.md §59 mandates the user-facing word "Reliable", so the enum was
// declared `reliable('Reliable')` — but the backend
// (backend/src/SafePath.Domain/Enums/SafeZoneSensitivity.cs) spells that same
// member `Conservative`.
//
// Consequence: every persisted zone came back as `"sensitivity":"Conservative"`,
// `_enumFromWire` matched nothing and threw `ArgumentError`. Because that is
// not a `DioException` it escaped `DioGeofenceApi.list`'s handler and was
// swallowed by `GeofenceListController.load`'s bare `catch (_)`, failing the
// ENTIRE zone-list load. `SafeZonesPage` then rendered the error state, whose
// `onAdd` was null — so the header '+' was inert and "add zone" silently did
// nothing.
//
// The payload below is copied verbatim from a live capture of the device's own
// HTTP traffic (GET /families/{id}/geofences -> 200) during the investigation.

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/geofencing/data/geofence_models.dart';

/// The backend's `SafeZoneSensitivity` enum members, verbatim. Mirrored here
/// so a rename on either side fails loudly in CI instead of silently bricking
/// the zone list on a real device.
const _backendSensitivityWireValues = {
  'Conservative',
  'Balanced',
  'Responsive',
};

/// The backend's `SafeZoneCategory` enum members, verbatim.
const _backendCategoryWireValues = {
  'Home',
  'School',
  'University',
  'Workplace',
  'Custom',
};

void main() {
  group('sensitivity wire contract', () {
    test('every wireValue is a member of the backend enum', () {
      for (final sensitivity in SafeZoneSensitivity.values) {
        expect(
          _backendSensitivityWireValues,
          contains(sensitivity.wireValue),
          reason:
              '${sensitivity.name} sends "${sensitivity.wireValue}", which the '
              'backend SafeZoneSensitivity enum cannot parse.',
        );
      }
    });

    test('the least-sensitive option is "Conservative" on the wire', () {
      expect(SafeZoneSensitivity.reliable.wireValue, 'Conservative');
    });

    test('but is still labelled "Reliable" on screen (04-UI-SPEC.md)', () {
      expect(SafeZoneSensitivity.reliable.label, 'Reliable');
      expect(SafeZoneSensitivity.balanced.label, 'Balanced');
      expect(SafeZoneSensitivity.responsive.label, 'Responsive');
    });
  });

  group('category wire contract', () {
    test('every wireValue is a member of the backend enum', () {
      for (final category in SafeZoneCategory.values) {
        expect(
          _backendCategoryWireValues,
          contains(category.wireValue),
          reason:
              '${category.name} sends "${category.wireValue}", which the '
              'backend SafeZoneCategory enum cannot parse.',
        );
      }
    });
  });

  group('SafeZone.fromJson', () {
    // Captured verbatim from the device's live GET
    // /families/a16955a1-.../geofences 200 response.
    final realBackendPayload = <String, dynamic>{
      'zoneId': 'a51cd0a6-a6ca-4104-80d8-f1e5cf74ee6e',
      'category': 'Custom',
      'customName': '04-05 Guardian Device Verification 012517',
      'latitude': 30.0469085,
      'longitude': 31.5262786,
      'radiusMeters': 100,
      'assignedMemberUserId': '24a51971-0b4b-4245-a671-13ca001af7f2',
      'sensitivity': 'Conservative',
      'recipientUserIds': ['24a51971-0b4b-4245-a671-13ca001af7f2'],
      'notifyAssignedMember': false,
      'registrationGeneration': 1,
      'active': true,
      'needsLocationPermission': false,
      'needsSync': false,
    };

    test('parses a real backend zone carrying "Conservative"', () {
      final zone = SafeZone.fromJson(realBackendPayload);

      expect(zone.sensitivity, SafeZoneSensitivity.reliable);
      expect(zone.id, 'a51cd0a6-a6ca-4104-80d8-f1e5cf74ee6e');
      expect(zone.category, SafeZoneCategory.custom);
      expect(zone.radiusMeters, 100);
      expect(zone.activation, SafeZoneActivation.active);
    });

    test('parses every sensitivity the backend can emit', () {
      for (final wireValue in _backendSensitivityWireValues) {
        expect(
          () => SafeZone.fromJson({
            ...realBackendPayload,
            'sensitivity': wireValue,
          }),
          returnsNormally,
          reason: 'the backend can persist "$wireValue"',
        );
      }
    });
  });

  group('SafeZoneDraft.toRequest', () {
    test('sends the backend spelling, not the UI label', () {
      const draft = SafeZoneDraft(
        familyId: 'family-1',
        assignedMemberId: 'member-1',
        sensitivity: SafeZoneSensitivity.reliable,
      );

      expect(draft.toRequest()['sensitivity'], 'Conservative');
    });

    test('round-trips through the wire without changing meaning', () {
      for (final sensitivity in SafeZoneSensitivity.values) {
        final request = SafeZoneDraft(
          familyId: 'family-1',
          assignedMemberId: 'member-1',
          sensitivity: sensitivity,
        ).toRequest();

        final parsed = SafeZone.fromJson({
          'zoneId': 'zone-1',
          'category': 'Home',
          'latitude': 0.0,
          'longitude': 0.0,
          'radiusMeters': 100,
          'assignedMemberUserId': 'member-1',
          'sensitivity': request['sensitivity'],
        });

        expect(parsed.sensitivity, sensitivity);
      }
    });
  });
}
