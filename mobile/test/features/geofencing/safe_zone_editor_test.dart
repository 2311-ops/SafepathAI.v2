import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/auth/data/auth_models.dart';
import 'package:mobile/features/family/data/family_models.dart';
import 'package:mobile/features/geofencing/presentation/edit_safe_zone_screen.dart';
import 'package:mobile/features/geofencing/presentation/review_safe_zone_screen.dart';
import 'package:mobile/features/location/application/location_controller.dart';
import 'package:mobile/features/location/data/location_models.dart';

void main() {
  final member = FamilyMemberView(
    memberId: 'membership-1',
    userId: 'member-1',
    displayName: 'Maya Longname',
    role: Role.member,
    permission: PermissionLevel.fullLocation,
    joinedAt: DateTime.utc(2026),
  );
  final guardian = FamilyMemberView(
    memberId: 'membership-2',
    userId: 'guardian-1',
    displayName: 'Alex Guardian',
    role: Role.guardian,
    permission: PermissionLevel.fullLocation,
    joinedAt: DateTime.utc(2026),
  );

  Widget app(Widget child) => ProviderScope(child: MaterialApp(home: child));

  Widget appWithSeededLocation(Widget child) => ProviderScope(
    overrides: [
      locationControllerProvider.overrideWith(_SeededLocationController.new),
    ],
    child: MaterialApp(home: child),
  );

  testWidgets('editor lets users choose from the map or current location', (
    tester,
  ) async {
    await tester.pumpWidget(
      appWithSeededLocation(
        SafeZoneEditorScreen(
          familyId: 'family-1',
          members: [member, guardian],
          mapOverride: const ColoredBox(color: Colors.white),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Create a safe zone'), findsOneWidget);
    expect(
      find.text(
        'Pick the exact place on the map, set the radius, then choose who gets enter and leave alerts.',
      ),
      findsOneWidget,
    );
    expect(find.text('Zone location'), findsOneWidget);
    expect(find.textContaining('30.0444, 31.2357'), findsOneWidget);
    expect(find.text('Current'), findsOneWidget);
    expect(find.text('Choose on map'), findsOneWidget);

    await tester.tap(find.text('Current'));
    await tester.pump();

    expect(find.textContaining('30.0444, 31.2357'), findsOneWidget);
  });

  testWidgets('editor is map-first with accessible radius controls', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(
        SafeZoneEditorScreen(
          familyId: 'family-1',
          members: [member, guardian],
          mapOverride: const ColoredBox(color: Colors.white),
        ),
      ),
    );

    expect(find.text('Create a safe zone'), findsOneWidget);
    expect(find.text('Choose on map'), findsOneWidget);
    expect(find.text('Current'), findsOneWidget);
    expect(find.text('100 m'), findsWidgets);
    expect(find.text('1 km'), findsOneWidget);
    expect(find.text('Fine tune'), findsOneWidget);
    expect(find.byIcon(Icons.open_with), findsOneWidget);
    expect(find.text('Review zone'), findsOneWidget);
  });

  testWidgets('choose on map opens a full-screen picker', (tester) async {
    await tester.pumpWidget(
      app(
        SafeZoneEditorScreen(
          familyId: 'family-1',
          members: [member, guardian],
          mapOverride: const ColoredBox(color: Colors.white),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Choose on map'));
    await tester.pumpAndSettle();

    expect(find.text('Pick zone location'), findsOneWidget);
    expect(
      find.text('Tap the map to move the safe-zone marker.'),
      findsOneWidget,
    );
    expect(find.text('Use this location'), findsOneWidget);
  });

  testWidgets(
    'editor starts with usable defaults and validates bad review taps',
    (tester) async {
      var reviewed = false;
      await tester.pumpWidget(
        app(
          SafeZoneEditorScreen(
            familyId: 'family-1',
            members: [member, guardian],
            mapOverride: const ColoredBox(color: Colors.white),
            onReview: () => reviewed = true,
          ),
        ),
      );
      await tester.pump();

      final reviewButton = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Review zone'),
      );
      expect(reviewButton.onPressed, isNotNull);

      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -160),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Custom'));
      await tester.pump();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Review zone'));
      await tester.pump();

      expect(reviewed, isFalse);
      expect(find.text('Enter a zone name.'), findsWidgets);
    },
  );

  testWidgets('review presents all saved decision fields and edit targets', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(
        SafeZoneReviewScreen(
          familyId: 'family-1',
          members: [member, guardian],
          mapOverride: const SizedBox.expand(),
        ),
      ),
    );

    expect(find.text('Review safe zone'), findsOneWidget);
    expect(find.text('Assigned member'), findsOneWidget);
    expect(find.text('Sensitivity'), findsOneWidget);
    expect(find.text('Guardian recipients'), findsOneWidget);
    expect(find.text('Edit location'), findsOneWidget);
    expect(find.text('Save safe zone'), findsOneWidget);
  });
}

class _SeededLocationController extends LocationController {
  @override
  LocationState build() => LocationState(
    selfPosition: LiveLocation(
      userId: 'self-user',
      lat: 30.0444,
      lng: 31.2357,
      accuracyMeters: 12,
      recordedAtUtc: DateTime.utc(2026, 8, 14, 12),
    ),
  );
}
