import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:mobile/features/auth/data/auth_models.dart';
import 'package:mobile/features/family/application/family_controller.dart';
import 'package:mobile/features/family/data/family_models.dart';
import 'package:mobile/features/location/application/history_controller.dart';
import 'package:mobile/features/location/data/location_models.dart';
import 'package:mobile/features/location/presentation/history_timeline_screen.dart';
import 'package:mobile/features/profile/application/profile_controller.dart';
import 'package:mobile/features/profile/data/user_profile.dart';

class _SeededFamilyController extends FamilyController {
  @override
  FamilyState build() => FamilyState(
    family: const Family(id: 'fam-1', name: 'Safe circle'),
    members: [
      FamilyMemberView(
        memberId: 'member-row-1',
        userId: 'member-1',
        displayName: 'Maya Rivera',
        role: Role.member,
        permission: PermissionLevel.fullLocation,
        joinedAt: DateTime.utc(2026, 7, 12),
      ),
    ],
  );
}

/// No circle yet (family == null, not loading).
class _NoFamilyController extends FamilyController {
  @override
  FamilyState build() => const FamilyState();
}

class _SeededProfileController extends ProfileController {
  _SeededProfileController(this.role);

  final Role? role;

  @override
  ProfileState build() => ProfileState(
    profile: UserProfile(
      userId: 'self-user',
      email: null,
      fullName: null,
      role: role,
    ),
  );
}

class _SeededHistoryController extends HistoryController {
  _SeededHistoryController(this.seed);

  final HistoryState seed;

  @override
  HistoryState build() => seed;
}

Widget _app(HistoryState historyState) {
  return ProviderScope(
    overrides: [
      familyControllerProvider.overrideWith(_SeededFamilyController.new),
      historyControllerProvider.overrideWith(
        () => _SeededHistoryController(historyState),
      ),
    ],
    child: const MaterialApp(home: HistoryTimelineScreen()),
  );
}

Widget _noCircleApp(Role? role) {
  return ProviderScope(
    overrides: [
      familyControllerProvider.overrideWith(_NoFamilyController.new),
      historyControllerProvider.overrideWith(
        () => _SeededHistoryController(const HistoryState()),
      ),
      profileControllerProvider.overrideWith(
        () => _SeededProfileController(role),
      ),
    ],
    child: const MaterialApp(home: HistoryTimelineScreen()),
  );
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('renders stat tiles and timeline nodes from seeded history', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        HistoryState(
          selectedTargetUserId: 'member-1',
          fromUtc: DateTime.utc(2026, 7, 12),
          toUtc: DateTime.utc(2026, 7, 13),
          history: LocationHistory(
            polylinePoints: [
              RoutePoint(
                lat: 30.0444,
                lng: 31.2357,
                recordedAtUtc: DateTime.utc(2026, 7, 12, 8),
              ),
              RoutePoint(
                lat: 30.05,
                lng: 31.24,
                recordedAtUtc: DateTime.utc(2026, 7, 12, 9),
              ),
            ],
            stops: [
              HistoryStop(
                startUtc: DateTime.utc(2026, 7, 12, 8),
                endUtc: DateTime.utc(2026, 7, 12, 8, 12),
                lat: 30.0444,
                lng: 31.2357,
              ),
              HistoryStop(
                startUtc: DateTime.utc(2026, 7, 12, 9),
                endUtc: DateTime.utc(2026, 7, 12, 9, 20),
                lat: 30.05,
                lng: 31.24,
              ),
            ],
          ),
          stats: const TravelStats(
            distanceMeters: 3218,
            timeAway: Duration(hours: 1, minutes: 15),
            stopCount: 2,
          ),
        ),
      ),
    );

    expect(find.text('2.0 mi'), findsOneWidget);
    expect(find.text('DISTANCE'), findsOneWidget);
    expect(find.text('1h 15m'), findsOneWidget);
    expect(find.text('TIME AWAY'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('STOPS'), findsOneWidget);
    expect(find.text('Maya Rivera'), findsOneWidget);
    expect(find.text('Stop 1'), findsOneWidget);
    expect(find.text('On the move'), findsOneWidget);
    expect(find.text('Stop 2'), findsOneWidget);
  });

  testWidgets('no-circle empty state shows the Guardian create-circle CTA', (
    tester,
  ) async {
    await tester.pumpWidget(_noCircleApp(Role.guardian));
    await tester.pumpAndSettle();

    expect(find.text('No circle yet'), findsOneWidget);
    expect(find.byKey(const ValueKey('no-circle-create-cta')), findsOneWidget);
    expect(find.text('Create a circle'), findsOneWidget);
    expect(find.text('Enter invite code'), findsNothing);
  });

  testWidgets('no-circle empty state shows the Member join-circle CTA', (
    tester,
  ) async {
    await tester.pumpWidget(_noCircleApp(Role.member));
    await tester.pumpAndSettle();

    expect(find.text('No circle yet'), findsOneWidget);
    expect(find.byKey(const ValueKey('no-circle-join-cta')), findsOneWidget);
    expect(find.text('Enter invite code'), findsOneWidget);
    expect(find.text('Create a circle'), findsNothing);
  });

  testWidgets('renders the locked empty history copy', (tester) async {
    await tester.pumpWidget(
      _app(
        HistoryState(
          selectedTargetUserId: 'member-1',
          fromUtc: DateTime.utc(2026, 7, 12),
          toUtc: DateTime.utc(2026, 7, 13),
        ),
      ),
    );

    expect(find.text('No history yet'), findsOneWidget);
    expect(
      find.text(
        "Once location tracking starts, Maya Rivera's stays and trips will show up here.",
      ),
      findsOneWidget,
    );
  });
}
