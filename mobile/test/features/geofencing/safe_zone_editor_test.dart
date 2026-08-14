import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/auth/data/auth_models.dart';
import 'package:mobile/features/family/data/family_models.dart';
import 'package:mobile/features/geofencing/presentation/edit_safe_zone_screen.dart';
import 'package:mobile/features/geofencing/presentation/review_safe_zone_screen.dart';

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

    expect(find.text('Position on map'), findsOneWidget);
    expect(find.text('Use current location'), findsOneWidget);
    expect(find.text('100 m'), findsWidgets);
    expect(find.text('1 km'), findsOneWidget);
    expect(find.bySemanticsLabel('Move pin'), findsOneWidget);
    expect(find.text('Review zone'), findsOneWidget);
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
