// Behavior under test — the real `routerProvider` driving the Phase 04
// Safe Zones journey end-to-end (the regression this suite exists to catch):
//
//   /safe-zones renders the caller's real zones (fetch actually issued,
//   member card labelled with a real display name, not the fallback string).
//   list -> add -> review -> save reaches SafeZoneReviewScreen with a
//   Review-zone button that becomes tappable once the draft is valid
//   (previously permanently disabled), and saving calls the fake API's
//   `create` exactly once.
//   /safe-zones/{id}/edit prefills the existing zone and saves as an
//   `update`, not a `create`, proving the draft carried `zoneId` through.
//
// A locally-declared GoRouter would not catch the original gap (the real
// route table had an empty familyId/members editor and a missing review
// route) — this suite drives the actual `routerProvider`.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import 'package:mobile/core/router/app_router.dart';
import 'package:mobile/features/auth/data/auth_api.dart';
import 'package:mobile/features/auth/data/auth_models.dart';
import 'package:mobile/features/family/application/family_controller.dart';
import 'package:mobile/features/family/data/family_models.dart';
import 'package:mobile/features/geofencing/application/geofence_controller.dart';
import 'package:mobile/features/geofencing/data/geofence_api.dart';
import 'package:mobile/features/geofencing/data/geofence_models.dart';
import 'package:mobile/features/geofencing/presentation/safe_zones_page.dart';
import 'package:mobile/features/location/application/permission_controller.dart';
import 'package:mobile/features/profile/application/profile_controller.dart';
import 'package:mobile/features/profile/data/user_profile.dart';

import '../../helpers/fake_auth_api.dart';
import '../../helpers/fake_geofence_api.dart';
import '../../helpers/fake_location_permission_service.dart';

final _guardian = FamilyMemberView(
  memberId: 'membership-guardian-1',
  userId: 'guardian-1',
  displayName: 'Alex Guardian',
  role: Role.guardian,
  permission: PermissionLevel.fullLocation,
  joinedAt: DateTime.utc(2026),
);

final _member = FamilyMemberView(
  memberId: 'membership-member-1',
  userId: 'member-1',
  displayName: 'Distinctive Maya',
  role: Role.member,
  permission: PermissionLevel.fullLocation,
  joinedAt: DateTime.utc(2026),
);

SafeZone _seededZone() => const SafeZone(
  id: 'zone-1',
  name: 'Home',
  category: SafeZoneCategory.home,
  center: SafeZoneCenter(latitude: 30.0444, longitude: 31.2357),
  radiusMeters: 100,
  assignedMemberId: 'member-1',
  sensitivity: SafeZoneSensitivity.reliable,
  guardianRecipientIds: {'guardian-1'},
  notifyAssignedMember: false,
);

class _SeededFamilyController extends FamilyController {
  @override
  FamilyState build() => FamilyState(
    family: const Family(id: 'family-1', name: 'Test Family'),
    members: [_guardian, _member],
  );
}

class _SeededProfileController extends ProfileController {
  @override
  ProfileState build() => const ProfileState(
    profile: UserProfile(
      userId: 'guardian-1',
      email: null,
      fullName: null,
      role: Role.guardian,
    ),
  );
}

class _FakeSavePermissionCoordinator
    implements GeofenceSavePermissionCoordinator {
  @override
  Future<SafeZoneActivation> requestAfterSave() async =>
      SafeZoneActivation.active;
}

sb.Session _fakeSession() => sb.Session(
  accessToken: 'fake-access-token',
  tokenType: 'bearer',
  user: sb.User(
    id: 'guardian-1',
    appMetadata: const {},
    userMetadata: const {},
    aud: 'authenticated',
    createdAt: DateTime.now().toIso8601String(),
  ),
);

/// Builds a real `routerProvider` behind a `ProviderContainer` with every
/// seam this journey touches overridden, mirroring the established
/// subclass-override convention (`live_map_screen_test.dart`) and fake-api
/// convention (`auth_flow_navigation_test.dart`).
ProviderContainer _buildContainer(FakeGeofenceApi geofenceApi) {
  final authApi = FakeAuthApi(initialSession: _fakeSession());
  final container = ProviderContainer(
    overrides: [
      familyControllerProvider.overrideWith(_SeededFamilyController.new),
      profileControllerProvider.overrideWith(_SeededProfileController.new),
      authApiProvider.overrideWithValue(authApi),
      locationPermissionServiceProvider.overrideWithValue(
        FakeLocationPermissionService(),
      ),
      geofenceApiProvider.overrideWithValue(geofenceApi),
      geofenceSavePermissionCoordinatorProvider.overrideWithValue(
        _FakeSavePermissionCoordinator(),
      ),
      safeZoneMapOverrideProvider.overrideWithValue(
        const SizedBox.expand(),
      ),
    ],
  );
  return container;
}

Widget _app(ProviderContainer container, GoRouter router) =>
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        theme: ThemeData(splashFactory: NoSplash.splashFactory),
        routerConfig: router,
      ),
    );

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets(
    '/safe-zones renders the family\'s zones with a real member name',
    (tester) async {
      final geofenceApi = FakeGeofenceApi()..zonesToReturn = [_seededZone()];
      final container = _buildContainer(geofenceApi);
      addTearDown(container.dispose);
      final router = container.read(routerProvider);

      // Pre-mount navigation: the first resolved location is the safe-zones
      // list, so `/home` (and its VectorMap-bearing LiveMapScreen) is never
      // built.
      router.go('/safe-zones');

      await tester.pumpWidget(_app(container, router));
      await tester.pumpAndSettle();

      expect(geofenceApi.listCalls, 1);
      expect(find.text('Distinctive Maya'), findsOneWidget);
      expect(find.text('Family member'), findsNothing);
    },
  );

  testWidgets(
    'create journey: list -> add -> review -> save calls create once',
    (tester) async {
      final geofenceApi = FakeGeofenceApi()..zonesToReturn = [_seededZone()];
      final container = _buildContainer(geofenceApi);
      addTearDown(container.dispose);
      final router = container.read(routerProvider);

      router.go('/safe-zones');
      await tester.pumpWidget(_app(container, router));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Add safe zone'));
      await tester.pumpAndSettle();

      expect(find.text('Add safe zone'), findsWidgets); // AppBar title + CTA
      expect(find.text('Review zone'), findsOneWidget);

      // Initially disabled: no assigned member yet, exactly the regression
      // this task fixes (the add route used to construct the editor with an
      // empty member list, leaving this button permanently disabled).
      final disabledReview = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Review zone'),
      );
      expect(disabledReview.onPressed, isNull);

      container
          .read(geofenceControllerProvider.notifier)
          .setAssignedMember('member-1');
      await tester.pump();

      final enabledReview = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Review zone'),
      );
      expect(enabledReview.onPressed, isNotNull);

      await tester.tap(find.widgetWithText(ElevatedButton, 'Review zone'));
      await tester.pumpAndSettle();

      expect(find.text('Review safe zone'), findsOneWidget);

      await tester.tap(find.widgetWithText(ElevatedButton, 'Save safe zone'));
      await tester.pumpAndSettle();

      expect(geofenceApi.createCalls, 1);
      expect(find.text('Review safe zone'), findsNothing);
    },
  );

  testWidgets(
    'edit journey: pushing /safe-zones/{id}/edit prefills the zone and '
    'saves as an update',
    (tester) async {
      final zone = _seededZone();
      final geofenceApi = FakeGeofenceApi()..zonesToReturn = [zone];
      final container = _buildContainer(geofenceApi);
      addTearDown(container.dispose);
      final router = container.read(routerProvider);

      router.go('/safe-zones/${zone.id}/edit', extra: zone);
      await tester.pumpWidget(_app(container, router));
      await tester.pumpAndSettle();

      expect(find.text('Edit safe zone'), findsOneWidget);
      final nameField = tester.widget<TextField>(find.byType(TextField));
      expect(nameField.controller?.text, zone.name);

      final reviewButton = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Review zone'),
      );
      expect(reviewButton.onPressed, isNotNull);

      await tester.tap(find.widgetWithText(ElevatedButton, 'Review zone'));
      await tester.pumpAndSettle();

      expect(find.text('Review safe zone'), findsOneWidget);

      await tester.tap(find.widgetWithText(ElevatedButton, 'Save safe zone'));
      await tester.pumpAndSettle();

      expect(geofenceApi.updateCalls, 1);
      expect(geofenceApi.createCalls, 0);
    },
  );
}
