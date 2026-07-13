import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:mobile/features/auth/data/auth_models.dart';
import 'package:mobile/features/family/application/family_controller.dart';
import 'package:mobile/features/family/data/family_models.dart';
import 'package:mobile/features/family/presentation/accept_invite_screen.dart';
import 'package:mobile/features/family/presentation/create_circle_screen.dart';
import 'package:mobile/features/location/application/location_controller.dart';
import 'package:mobile/features/location/data/location_models.dart';
import 'package:mobile/features/location/presentation/live_map_screen.dart';
import 'package:mobile/features/profile/application/profile_controller.dart';
import 'package:mobile/features/profile/data/user_profile.dart';

/// No circle yet: family == null and not loading — the state a family-less
/// user's Map tab lands in.
class _NoFamilyController extends FamilyController {
  @override
  FamilyState build() => const FamilyState();
}

/// Empty, non-loading location state so `LiveMapScreen` reaches the
/// family-null branch instead of the loading spinner.
class _EmptyLocationController extends LocationController {
  @override
  LocationState build() => const LocationState();
}

/// A loaded family circle, non-null and not loading — the state needed to
/// reach the populated-map branch instead of the "No circle yet" branch.
class _PopulatedFamilyController extends FamilyController {
  @override
  FamilyState build() => const FamilyState(family: Family(id: 'family-1'));
}

/// A self position plus one other family member, so `LiveMapScreen` builds
/// its `FlutterMap` with a marker/accuracy-circle per location.
class _PopulatedLocationController extends LocationController {
  @override
  LocationState build() {
    final now = DateTime.now().toUtc();
    final self = LiveLocation(
      userId: 'self-user',
      lat: 30.0444,
      lng: 31.2357,
      accuracyMeters: 12,
      recordedAtUtc: now,
    );
    final other = LiveLocation(
      userId: 'other-user',
      displayName: 'Sam',
      lat: 30.0500,
      lng: 31.2400,
      accuracyMeters: 20,
      recordedAtUtc: now.subtract(const Duration(minutes: 1)),
    );
    return LocationState(
      selfPosition: self,
      members: {'self-user': self, 'other-user': other},
    );
  }
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

Widget _app(Role? role) {
  return ProviderScope(
    overrides: [
      familyControllerProvider.overrideWith(_NoFamilyController.new),
      locationControllerProvider.overrideWith(_EmptyLocationController.new),
      profileControllerProvider.overrideWith(
        () => _SeededProfileController(role),
      ),
    ],
    child: const MaterialApp(home: LiveMapScreen()),
  );
}

Widget _routerApp(Role? role) {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (context, state) => const LiveMapScreen()),
      GoRoute(
        path: '/circle/create',
        builder: (context, state) => const CreateCircleScreen(),
      ),
      GoRoute(
        path: '/invite/accept',
        builder: (context, state) => const AcceptInviteScreen(),
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      familyControllerProvider.overrideWith(_NoFamilyController.new),
      locationControllerProvider.overrideWith(_EmptyLocationController.new),
      profileControllerProvider.overrideWith(
        () => _SeededProfileController(role),
      ),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('family-less Guardian sees the create-circle CTA on the map', (
    tester,
  ) async {
    await tester.pumpWidget(_app(Role.guardian));
    await tester.pumpAndSettle();

    expect(find.text('No circle yet'), findsOneWidget);
    expect(find.byKey(const ValueKey('no-circle-create-cta')), findsOneWidget);
    expect(find.text('Create a circle'), findsOneWidget);
    expect(find.text('Enter invite code'), findsNothing);
  });

  testWidgets('family-less Member sees the join-circle CTA on the map', (
    tester,
  ) async {
    await tester.pumpWidget(_app(Role.member));
    await tester.pumpAndSettle();

    expect(find.text('No circle yet'), findsOneWidget);
    expect(find.byKey(const ValueKey('no-circle-join-cta')), findsOneWidget);
    expect(find.text('Enter invite code'), findsOneWidget);
    expect(find.text('Create a circle'), findsNothing);
  });

  testWidgets('other roles (Caregiver) get both entry points', (tester) async {
    await tester.pumpWidget(_app(Role.caregiver));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('no-circle-create-cta')), findsOneWidget);
    expect(find.byKey(const ValueKey('no-circle-join-cta')), findsOneWidget);
    expect(find.text('Create a circle'), findsOneWidget);
    expect(find.text('I have an invite code'), findsOneWidget);
  });

  testWidgets('Guardian create CTA navigates to CreateCircleScreen', (
    tester,
  ) async {
    await tester.pumpWidget(_routerApp(Role.guardian));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('no-circle-create-cta')));
    await tester.pumpAndSettle();

    // CreateCircleScreen's heading confirms navigation landed on the QR/invite
    // circle-creation flow.
    expect(find.text('Name your circle'), findsOneWidget);
  });

  testWidgets('Member join CTA navigates to AcceptInviteScreen', (
    tester,
  ) async {
    await tester.pumpWidget(_routerApp(Role.member));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('no-circle-join-cta')));
    await tester.pumpAndSettle();

    // AcceptInviteScreen's heading + accept action confirm the invite-entry
    // flow (the code field is where the Member types the invite code).
    expect(find.text("You've been invited"), findsOneWidget);
    expect(find.text('Accept & join'), findsOneWidget);
  });

  testWidgets('populated live locations render on a FlutterMap with OSM attribution', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          familyControllerProvider.overrideWith(_PopulatedFamilyController.new),
          locationControllerProvider.overrideWith(
            _PopulatedLocationController.new,
          ),
          profileControllerProvider.overrideWith(
            () => _SeededProfileController(Role.guardian),
          ),
        ],
        child: const MaterialApp(home: LiveMapScreen()),
      ),
    );
    // flutter_map issues real network tile requests that never resolve in the
    // test harness; pumpAndSettle would hang waiting on them, so build the
    // tree with a fixed-duration pump instead.
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(FlutterMap), findsOneWidget);
    expect(find.textContaining('OpenStreetMap'), findsWidgets);
  });
}
