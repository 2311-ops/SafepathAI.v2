import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/geofencing/data/geofence_models.dart';
import 'package:mobile/features/geofencing/presentation/safe_zone_detail_screen.dart';
import 'package:mobile/features/geofencing/presentation/safe_zones_screen.dart';
import 'package:mobile/features/location/presentation/live_map_screen.dart';

void main() {
  const activeZone = SafeZone(
    id: 'zone-1',
    name: 'Home',
    category: SafeZoneCategory.home,
    center: SafeZoneCenter(latitude: 30.0444, longitude: 31.2357),
    radiusMeters: 250,
    assignedMemberId: 'member-1',
    sensitivity: SafeZoneSensitivity.reliable,
    guardianRecipientIds: {'guardian-1'},
    notifyAssignedMember: false,
  );

  Widget app(Widget child) => MaterialApp(home: child);

  testWidgets('safe zones list renders empty, error, and truthful cards', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: SafeZonesScreen.empty()));
    expect(find.text('No safe zones yet'), findsOneWidget);
    expect(find.text('Add safe zone'), findsOneWidget);

    await tester.pumpWidget(const MaterialApp(home: SafeZonesScreen.error()));
    expect(
      find.text(
        "Couldn't load safe zones. Check your connection and try again.",
      ),
      findsOneWidget,
    );
    expect(find.text('Try again'), findsOneWidget);

    await tester.pumpWidget(
      app(
        SafeZonesScreen(
          zones: [
            activeZone,
            activeZone.copyWith(
              activation: SafeZoneActivation.needsLocationPermission,
            ),
          ],
          memberNames: const {'member-1': 'Maya'},
          mapOverride: const SizedBox.expand(),
        ),
      ),
    );
    expect(find.text('Home'), findsNWidgets(2));
    expect(find.text('250 m · Maya'), findsNWidgets(2));
    final switchFinder = find.byType(Switch);
    expect(switchFinder, findsOneWidget);
    final switchWidget = tester.widget<Switch>(switchFinder);
    expect(switchWidget.value, isTrue);
    expect(switchWidget.onChanged, isNull);
    expect(find.text('Location permission needed to activate'), findsOneWidget);
    expect(find.text('View activity'), findsNWidgets(2));
  });

  testWidgets('safe zones list map header renders through mapOverride', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(
        SafeZonesScreen(
          zones: [activeZone],
          memberNames: const {'member-1': 'Maya'},
          mapOverride: const SizedBox.expand(key: Key('zones-map')),
        ),
      ),
    );
    expect(find.byKey(const Key('zones-map')), findsOneWidget);
  });

  testWidgets('safe zones list shows a category-specific icon tile per zone', (
    tester,
  ) async {
    const schoolZone = SafeZone(
      id: 'zone-2',
      name: 'School',
      category: SafeZoneCategory.school,
      center: SafeZoneCenter(latitude: 30.0444, longitude: 31.2357),
      radiusMeters: 250,
      assignedMemberId: 'member-1',
      sensitivity: SafeZoneSensitivity.reliable,
      guardianRecipientIds: {'guardian-1'},
      notifyAssignedMember: false,
    );
    const workplaceZone = SafeZone(
      id: 'zone-3',
      name: 'Workplace',
      category: SafeZoneCategory.workplace,
      center: SafeZoneCenter(latitude: 30.0444, longitude: 31.2357),
      radiusMeters: 250,
      assignedMemberId: 'member-1',
      sensitivity: SafeZoneSensitivity.reliable,
      guardianRecipientIds: {'guardian-1'},
      notifyAssignedMember: false,
    );
    await tester.pumpWidget(
      app(
        SafeZonesScreen(
          zones: [activeZone, schoolZone, workplaceZone],
          memberNames: const {'member-1': 'Maya'},
          mapOverride: const SizedBox.expand(),
        ),
      ),
    );
    expect(find.byIcon(Icons.home_outlined), findsOneWidget);
    expect(find.byIcon(Icons.school_outlined), findsOneWidget);
    expect(find.byIcon(Icons.work_outline), findsOneWidget);
  });

  testWidgets('safe zones list wires onToggle to the tapped zone', (
    tester,
  ) async {
    SafeZone? toggledZone;
    bool? toggledValue;
    await tester.pumpWidget(
      app(
        SafeZonesScreen(
          zones: [activeZone],
          memberNames: const {'member-1': 'Maya'},
          mapOverride: const SizedBox.expand(),
          onToggle: (zone, enabled) {
            toggledZone = zone;
            toggledValue = enabled;
          },
        ),
      ),
    );
    await tester.tap(find.byType(Switch));
    await tester.pump();
    expect(toggledZone?.id, activeZone.id);
    expect(toggledValue, isFalse);
  });

  testWidgets('safe zones list shows exactly one add affordance', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(
        SafeZonesScreen(
          zones: [activeZone],
          memberNames: const {'member-1': 'Maya'},
          mapOverride: const SizedBox.expand(),
        ),
      ),
    );
    expect(find.byType(FloatingActionButton), findsNothing);
    expect(find.byIcon(Icons.add), findsOneWidget);
  });

  testWidgets('detail exposes permission settings and confirmed delete', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(
        SafeZoneDetailScreen(
          zone: activeZone.copyWith(
            activation: SafeZoneActivation.needsLocationPermission,
          ),
          assignedMemberName: 'Maya',
        ),
      ),
    );

    expect(find.text('Edit zone'), findsOneWidget);
    expect(find.text('View activity'), findsOneWidget);
    expect(find.text('Open Settings'), findsOneWidget);
    await tester.tap(find.text('Delete zone'));
    await tester.pumpAndSettle();
    expect(find.text('Delete Home?'), findsOneWidget);
    expect(find.text('Keep safe zone'), findsOneWidget);
  });

  testWidgets('live map safe-zone entry keeps a 48px guardian action', (
    tester,
  ) async {
    var opened = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ManageSafeZonesButton(onPressed: () => opened = true),
        ),
      ),
    );

    expect(find.text('Manage zones'), findsOneWidget);
    expect(find.bySemanticsLabel('Manage safe zones'), findsOneWidget);
    final size = tester.getSize(find.byType(ManageSafeZonesButton));
    expect(size.height, greaterThanOrEqualTo(48));
    await tester.tap(find.text('Manage zones'));
    expect(opened, isTrue);
  });
}
