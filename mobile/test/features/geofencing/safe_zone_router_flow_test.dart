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
import 'package:mobile/features/location/application/location_controller.dart';
import 'package:mobile/features/location/application/permission_controller.dart';
import 'package:mobile/features/location/data/location_models.dart';
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

/// Reproduces a failed circle bootstrap (e.g. the API is unreachable):
/// `FamilyController` records the error but leaves `family` null.
class _FailedFamilyController extends FamilyController {
  @override
  FamilyState build() =>
      const FamilyState(error: 'Network error. Check your connection.');
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

/// The create journey needs a known member location: since commit `2bb8b30`
/// a new draft only carries an explicit center when one can be derived
/// (assigned member's live location, else the caller's own), and
/// `validateForReview()` refuses to advance to review without it — the guard
/// that stops a zone being saved at 0,0. Seeding this mirrors
/// `safe_zone_editor_test.dart`'s `_SeededMemberLocationController`.
class _SeededMemberLocationController extends LocationController {
  @override
  LocationState build() => LocationState(
    members: {
      'member-1': LiveLocation(
        userId: 'member-1',
        lat: 29.9765,
        lng: 31.1325,
        accuracyMeters: 18,
        recordedAtUtc: DateTime.utc(2026, 8, 14, 12),
      ),
    },
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
ProviderContainer _buildContainer(
  FakeGeofenceApi geofenceApi, {
  FakeLocationPermissionService? locationPermissionService,
  bool seedMemberLocation = false,
  bool failFamilyLoad = false,
}) {
  final authApi = FakeAuthApi(initialSession: _fakeSession());
  final container = ProviderContainer(
    overrides: [
      familyControllerProvider.overrideWith(
        failFamilyLoad
            ? _FailedFamilyController.new
            : _SeededFamilyController.new,
      ),
      profileControllerProvider.overrideWith(_SeededProfileController.new),
      authApiProvider.overrideWithValue(authApi),
      locationPermissionServiceProvider.overrideWithValue(
        locationPermissionService ?? FakeLocationPermissionService(),
      ),
      geofenceApiProvider.overrideWithValue(geofenceApi),
      geofenceSavePermissionCoordinatorProvider.overrideWithValue(
        _FakeSavePermissionCoordinator(),
      ),
      safeZoneMapOverrideProvider.overrideWithValue(const SizedBox.expand()),
      if (seedMemberLocation)
        locationControllerProvider.overrideWith(
          _SeededMemberLocationController.new,
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
      expect(find.text('100 m · Distinctive Maya'), findsOneWidget);
      expect(find.textContaining('Family member'), findsNothing);
    },
  );

  testWidgets('/safe-zones switch toggles the zone active state', (
    tester,
  ) async {
    final geofenceApi = FakeGeofenceApi()..zonesToReturn = [_seededZone()];
    final container = _buildContainer(geofenceApi);
    addTearDown(container.dispose);
    final router = container.read(routerProvider);

    router.go('/safe-zones');
    await tester.pumpWidget(_app(container, router));
    await tester.pumpAndSettle();

    expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(geofenceApi.setActiveCalls, 1);
    expect(geofenceApi.lastSetActiveZoneId, 'zone-1');
    expect(geofenceApi.lastSetActiveValue, isFalse);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
  });

  testWidgets(
    'create journey: list -> add -> review -> save calls create once',
    (tester) async {
      final geofenceApi = FakeGeofenceApi()..zonesToReturn = [_seededZone()];
      final container = _buildContainer(geofenceApi, seedMemberLocation: true);
      addTearDown(container.dispose);
      final router = container.read(routerProvider);

      router.go('/safe-zones');
      await tester.pumpWidget(_app(container, router));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      expect(find.text('Add safe zone'), findsWidgets); // AppBar title + CTA
      expect(find.text('Review zone'), findsOneWidget);

      // Add opens as a fresh, usable draft: standard name, first non-guardian
      // member selected, guardian notifications seeded, and an explicit
      // center derived from that member's live location (without which
      // `validateForReview()` blocks the Review-zone tap).
      final draft = container.read(geofenceControllerProvider).draft;
      expect(draft.name, 'Home');
      expect(draft.assignedMemberId, 'member-1');
      expect(draft.guardianRecipientIds, {'guardian-1'});
      expect(draft.hasExplicitCenter, isTrue);

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
    'a failed circle load surfaces an error with a working retry instead of '
    'a silent empty state with a dead add button',
    (tester) async {
      final geofenceApi = FakeGeofenceApi();
      final container = _buildContainer(geofenceApi, failFamilyLoad: true);
      addTearDown(container.dispose);
      final router = container.read(routerProvider);

      router.go('/safe-zones');
      await tester.pumpWidget(_app(container, router));
      await tester.pumpAndSettle();

      // The regression: this used to render "No safe zones yet" with both add
      // affordances null, so tapping '+' did nothing at all — no navigation,
      // no snackbar, no error.
      expect(find.text('No safe zones yet'), findsNothing);
      expect(find.text("Couldn't load safe zones"), findsOneWidget);

      final retry = find.widgetWithText(OutlinedButton, 'Try again');
      expect(tester.widget<OutlinedButton>(retry).onPressed, isNotNull);
    },
  );

  testWidgets(
    'a failed zone-list load still lets the guardian add a zone',
    (tester) async {
      // The user's reported symptom, reproduced: the circle loads fine and the
      // guardian reaches "Places & zones", but the LIST fetch fails (on the
      // real device, a `Conservative` sensitivity the client could not parse).
      // `SafeZonesScreen.error` hardcoded `onAdd = null`, so the header '+'
      // was drawn gray and its onTap was null — tapping it did nothing at all:
      // no navigation, no snackbar, no error.
      final geofenceApi = FakeGeofenceApi()..throwsOnList = true;
      final container = _buildContainer(geofenceApi, seedMemberLocation: true);
      addTearDown(container.dispose);
      final router = container.read(routerProvider);

      router.go('/safe-zones');
      await tester.pumpWidget(_app(container, router));
      await tester.pumpAndSettle();

      expect(find.text("Couldn't load safe zones"), findsOneWidget);

      final addButton = find.ancestor(
        of: find.byIcon(Icons.add),
        matching: find.byType(InkWell),
      );
      expect(
        tester.widget<InkWell>(addButton).onTap,
        isNotNull,
        reason: 'failing to READ zones must not disable CREATING one',
      );

      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      // Asserted on the rendered editor rather than a route string: go_router
      // does not reflect imperative pushes in
      // `currentConfiguration.uri` (verified — the passing happy-path create
      // journey above also reports '/safe-zones' there). `SafeZoneEditorScreen`
      // only ever mounts at /safe-zones/add, so this IS the navigation proof.
      expect(find.text('Add safe zone'), findsWidgets); // AppBar title + CTA
      expect(find.text('Review zone'), findsOneWidget);
      expect(find.text("Couldn't load safe zones"), findsNothing);
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

  testWidgets(
    'confirming delete removes the zone through the fake API and returns '
    'to /safe-zones',
    (tester) async {
      final zone = _seededZone();
      final geofenceApi = FakeGeofenceApi()..zonesToReturn = [zone];
      final container = _buildContainer(geofenceApi);
      addTearDown(container.dispose);
      final router = container.read(routerProvider);

      router.go('/safe-zones');
      await tester.pumpWidget(_app(container, router));
      await tester.pumpAndSettle();

      router.push('/safe-zones/${zone.id}', extra: zone);
      await tester.pumpAndSettle();

      expect(find.text('Assigned member'), findsOneWidget);

      // Disambiguate: the bottom-bar trigger is a TextButton, the dialog's
      // confirm action is a FilledButton — both carry the same label.
      await tester.tap(find.widgetWithText(TextButton, 'Delete zone'));
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Delete zone'));
      await tester.pumpAndSettle();

      expect(geofenceApi.deleteCalls, 1);
      expect(find.text('No safe zones yet'), findsOneWidget);
      expect(find.text('Assigned member'), findsNothing);
    },
  );

  testWidgets(
    'cancelling the delete confirmation deletes nothing and stays on the '
    'detail screen',
    (tester) async {
      final zone = _seededZone();
      final geofenceApi = FakeGeofenceApi()..zonesToReturn = [zone];
      final container = _buildContainer(geofenceApi);
      addTearDown(container.dispose);
      final router = container.read(routerProvider);

      router.go('/safe-zones');
      await tester.pumpWidget(_app(container, router));
      await tester.pumpAndSettle();

      router.push('/safe-zones/${zone.id}', extra: zone);
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(TextButton, 'Delete zone'));
      await tester.pump();
      await tester.tap(find.text('Keep safe zone'));
      await tester.pumpAndSettle();

      expect(geofenceApi.deleteCalls, 0);
      expect(find.text('Assigned member'), findsOneWidget);
    },
  );

  testWidgets(
    'Open Settings on the permission card reaches the location permission '
    'seam',
    (tester) async {
      final zone = _seededZone().copyWith(
        activation: SafeZoneActivation.needsLocationPermission,
      );
      final geofenceApi = FakeGeofenceApi()..zonesToReturn = [zone];
      final locationPermissionService = FakeLocationPermissionService();
      final container = _buildContainer(
        geofenceApi,
        locationPermissionService: locationPermissionService,
      );
      addTearDown(container.dispose);
      final router = container.read(routerProvider);

      router.go('/safe-zones');
      await tester.pumpWidget(_app(container, router));
      await tester.pumpAndSettle();

      router.push('/safe-zones/${zone.id}', extra: zone);
      await tester.pumpAndSettle();

      final openSettingsFinder = find.widgetWithText(
        OutlinedButton,
        'Open Settings',
      );
      await tester.ensureVisible(openSettingsFinder);
      await tester.pumpAndSettle();
      await tester.tap(openSettingsFinder);
      await tester.pumpAndSettle();

      expect(locationPermissionService.openAppSettingsCalls, 1);
    },
  );
}
