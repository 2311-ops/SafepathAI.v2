import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/geofencing/application/geofence_activity_controller.dart';
import 'package:mobile/features/geofencing/data/geofence_api.dart';
import 'package:mobile/features/geofencing/data/geofence_models.dart';
import 'package:mobile/features/geofencing/presentation/zone_activity_screen.dart';

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

  test(
    'newer activity requests win when stale response finishes last',
    () async {
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
    },
  );

  testWidgets('renders paired visits, unmatched activity, and filter summary', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ZoneActivityScreen(
          state: GeofenceActivityState(
            filters: const GeofenceActivityFilters(zoneId: 'zone-1'),
            activity: [
              pairedVisit,
              GeofenceActivity(
                memberId: 'member-2',
                memberName: 'Long name that is still fully exposed to readers',
                zoneId: 'zone-1',
                zoneName: 'Home',
                transition: GeofenceActivityTransition.entered,
                occurredAtUtc: DateTime.utc(2026, 8, 13, 10),
                enteredAtUtc: DateTime.utc(2026, 8, 13, 10),
                isInProgress: true,
              ),
            ],
          ),
          now: now,
        ),
      ),
    );

    expect(find.text('Zone activity'), findsOneWidget);
    expect(find.textContaining('Home'), findsWidgets);
    expect(find.text('Visit duration 7h 45m'), findsOneWidget);
    expect(find.text('Visit in progress'), findsOneWidget);
    expect(
      find.bySemanticsLabel(RegExp('Long name that is still fully exposed')),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('Filter activity'), findsOneWidget);
  });

  testWidgets('renders deliberate empty and error states', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: ZoneActivityScreen.empty()),
    );
    expect(find.text('No zone activity yet'), findsOneWidget);

    await tester.pumpWidget(
      const MaterialApp(home: ZoneActivityScreen.error(onRetry: _noop)),
    );
    expect(find.text('Try again'), findsOneWidget);
  });
}

void _noop() {}

class _CompleterActivityApi implements GeofenceApi {
  final _pending = <String, Completer<List<GeofenceActivity>>>{};

  @override
  Future<List<GeofenceActivity>> activity(
    String familyId,
    GeofenceActivityFilters filters,
  ) => (_pending[filters.zoneId!] ??= Completer<List<GeofenceActivity>>())
      .future;

  void completeFor(String zoneId, List<GeofenceActivity> activity) =>
      _pending[zoneId]!.complete(activity);

  @override
  Future<void> delete(String familyId, String zoneId) =>
      throw UnimplementedError();
  @override
  Future<SafeZone> create(SafeZoneDraft draft) => throw UnimplementedError();
  @override
  Future<SafeZone> get(String familyId, String zoneId) =>
      throw UnimplementedError();
  @override
  Future<List<SafeZone>> list(String familyId) => throw UnimplementedError();
  @override
  Future<SafeZoneActivation> setActive(
    String familyId,
    String zoneId,
    bool active,
  ) => throw UnimplementedError();
  @override
  Future<SafeZone> update(String zoneId, SafeZoneDraft draft) =>
      throw UnimplementedError();
}
