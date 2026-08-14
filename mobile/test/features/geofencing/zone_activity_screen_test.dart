import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/geofencing/application/geofence_activity_controller.dart';
import 'package:mobile/features/geofencing/data/geofence_api.dart';
import 'package:mobile/features/geofencing/data/geofence_models.dart';

void main() {
  final now = DateTime.utc(2026, 8, 14, 16);
  final pairedVisit = GeofenceActivity(
    memberId: 'member-1',
    memberName: 'Maya',
    zoneId: 'zone-1',
    zoneName: 'Home',
    transition: GeofenceActivityTransition.entered,
    occurredAtUtc: DateTime.utc(2026, 8, 14, 16, 5),
    enteredAtUtc: DateTime.utc(2026, 8, 14, 8, 20),
    exitedAtUtc: DateTime.utc(2026, 8, 14, 16, 5),
    completedVisitDurationSeconds: 27900,
  );

  test('filters clamp to the retained seven-day window', () {
    final filters = GeofenceActivityFilters(
      zoneId: 'zone-1',
      fromUtc: DateTime.utc(2026, 7, 1),
      toUtc: DateTime.utc(2026, 9, 1),
    ).clampToRetention(now);

    expect(filters.zoneId, 'zone-1');
    expect(filters.fromUtc, DateTime.utc(2026, 8, 7, 16));
    expect(filters.toUtc, now);
  });

  test('newer activity requests win when stale response finishes last', () async {
    final first = _CompleterActivityApi();
    final controller = GeofenceActivityController(first, () => now);

    final oldLoad = controller.load(
      const GeofenceActivityFilters(zoneId: 'old'),
      familyId: 'family-1',
    );
    final newLoad = controller.load(
      const GeofenceActivityFilters(zoneId: 'new'),
      familyId: 'family-1',
    );
    first.completeFor('new', [pairedVisit]);
    await newLoad;
    first.completeFor('old', const []);
    await oldLoad;

    expect(controller.state.filters.zoneId, 'new');
    expect(controller.state.activity, [pairedVisit]);
  });

}

class _CompleterActivityApi implements GeofenceApi {
  final _pending = <String, Completer<List<GeofenceActivity>>>{};

  @override
  Future<List<GeofenceActivity>> activity(
    String familyId,
    GeofenceActivityFilters filters,
    ) => (_pending[filters.zoneId!] ??= Completer<List<GeofenceActivity>>()).future;

  void completeFor(String zoneId, List<GeofenceActivity> activity) =>
      _pending[zoneId]!.complete(activity);

  @override
  Future<void> delete(String familyId, String zoneId) => throw UnimplementedError();
  @override
  Future<SafeZone> create(SafeZoneDraft draft) => throw UnimplementedError();
  @override
  Future<SafeZone> get(String familyId, String zoneId) => throw UnimplementedError();
  @override
  Future<List<SafeZone>> list(String familyId) => throw UnimplementedError();
  @override
  Future<SafeZone> update(String zoneId, SafeZoneDraft draft) => throw UnimplementedError();
}
