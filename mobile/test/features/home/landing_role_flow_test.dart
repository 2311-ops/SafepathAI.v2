import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import 'package:mobile/app.dart';
import 'package:mobile/features/auth/data/auth_api.dart';
import 'package:mobile/features/auth/data/auth_models.dart';
import 'package:mobile/features/family/data/family_api.dart';
import 'package:mobile/features/location/application/permission_controller.dart';
import 'package:mobile/features/profile/data/profile_api.dart';

import '../../helpers/fake_auth_api.dart';
import '../../helpers/fake_family_api.dart';
import '../../helpers/fake_location_permission_service.dart';
import '../../helpers/fake_profile_api.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('Guardian login lands on Home with a reachable create-circle CTA', (
    tester,
  ) async {
    final authApi = FakeAuthApi(initialSession: _fakeSession('guardian-user'));
    final profileApi = FakeProfileApi(
      userId: 'guardian-user',
      role: Role.guardian,
    );
    final familyApi = FakeFamilyApi();
    addTearDown(authApi.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authApiProvider.overrideWithValue(authApi),
          familyApiProvider.overrideWithValue(familyApi),
          profileApiProvider.overrideWithValue(profileApi),
          locationPermissionServiceProvider.overrideWithValue(
            FakeLocationPermissionService(),
          ),
        ],
        child: const SafePathApp(showStartupSplash: false),
      ),
    );
    await tester.pumpAndSettle();

    // A family-less Guardian now lands on MainShell's Map tab, which surfaces
    // the role-aware "Create a circle" entry point (previously orphaned in the
    // unrouted landing_stub_screen).
    expect(find.text('No circle yet'), findsOneWidget);
    expect(find.text('Create a circle'), findsOneWidget);
    expect(find.text('Enter invite code'), findsNothing);

    // End-to-end through the real router: the CTA opens CreateCircleScreen.
    await tester.tap(find.byKey(const ValueKey('no-circle-create-cta')));
    await tester.pumpAndSettle();
    expect(find.text('Name your circle'), findsOneWidget);
  });

  testWidgets('Member login lands on Home with a reachable enter-code CTA', (
    tester,
  ) async {
    final authApi = FakeAuthApi(
      initialSession: _fakeSession('member-user', role: Role.member),
    );
    final profileApi = FakeProfileApi(userId: 'member-user', role: Role.member);
    final familyApi = FakeFamilyApi();
    addTearDown(authApi.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authApiProvider.overrideWithValue(authApi),
          familyApiProvider.overrideWithValue(familyApi),
          profileApiProvider.overrideWithValue(profileApi),
          locationPermissionServiceProvider.overrideWithValue(
            FakeLocationPermissionService(),
          ),
        ],
        child: const SafePathApp(showStartupSplash: false),
      ),
    );
    await tester.pumpAndSettle();

    // A family-less Member lands on MainShell's Map tab with the "Enter invite
    // code" entry point.
    expect(find.text('No circle yet'), findsOneWidget);
    expect(find.text('Enter invite code'), findsOneWidget);
    expect(find.text('Create a circle'), findsNothing);

    // End-to-end through the real router: the CTA opens AcceptInviteScreen.
    await tester.tap(find.byKey(const ValueKey('no-circle-join-cta')));
    await tester.pumpAndSettle();
    expect(find.text("You've been invited"), findsOneWidget);
  });

  testWidgets(
    'OAuth user without a role must choose one before reaching Home',
    (tester) async {
      final authApi = FakeAuthApi(initialSession: _fakeSession('oauth-user'));
      final profileApi = FakeProfileApi(userId: 'oauth-user', role: null);
      final familyApi = FakeFamilyApi();
      addTearDown(authApi.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authApiProvider.overrideWithValue(authApi),
            familyApiProvider.overrideWithValue(familyApi),
            profileApiProvider.overrideWithValue(profileApi),
            locationPermissionServiceProvider.overrideWithValue(
              FakeLocationPermissionService(),
            ),
          ],
          child: const SafePathApp(showStartupSplash: false),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Who are you in this circle?'), findsOneWidget);
      expect(find.text('No circle yet'), findsNothing);

      await tester.tap(find.text('Caregiver'));
      await tester.tap(find.widgetWithText(ElevatedButton, 'Continue'));
      await tester.pumpAndSettle();

      expect(profileApi.updateRoleCallCount, 1);
      expect(profileApi.lastUpdatedRole, Role.caregiver);
      expect(authApi.updateRoleMetadataCallCount, 1);
      expect(authApi.lastUpdatedMetadataRole, Role.caregiver);
      // A Caregiver (neither Guardian nor Member) lands on Home and is offered
      // both entry points so no role is stranded without a way in.
      expect(find.text('No circle yet'), findsOneWidget);
      expect(find.text('Create a circle'), findsOneWidget);
      expect(find.text('I have an invite code'), findsOneWidget);
    },
  );

  testWidgets(
    'Google user defaulted to Member by old backend trigger must still choose a role',
    (tester) async {
      final authApi = FakeAuthApi(
        initialSession: _fakeSession('legacy-google'),
      );
      final profileApi = FakeProfileApi(
        userId: 'legacy-google',
        role: Role.member,
      );
      final familyApi = FakeFamilyApi();
      addTearDown(authApi.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authApiProvider.overrideWithValue(authApi),
            familyApiProvider.overrideWithValue(familyApi),
            profileApiProvider.overrideWithValue(profileApi),
            locationPermissionServiceProvider.overrideWithValue(
              FakeLocationPermissionService(),
            ),
          ],
          child: const SafePathApp(showStartupSplash: false),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Who are you in this circle?'), findsOneWidget);
      expect(find.text('No circle yet'), findsNothing);

      await tester.tap(find.text('Guardian / Parent'));
      await tester.tap(find.widgetWithText(ElevatedButton, 'Continue'));
      await tester.pumpAndSettle();

      expect(profileApi.lastUpdatedRole, Role.guardian);
      expect(authApi.lastUpdatedMetadataRole, Role.guardian);
      // Having chosen Guardian, they land on Home with the create-circle CTA.
      expect(find.text('No circle yet'), findsOneWidget);
      expect(find.text('Create a circle'), findsOneWidget);
      expect(find.text('Enter invite code'), findsNothing);
    },
  );
}

sb.Session _fakeSession(String userId, {Role? role}) => sb.Session(
  accessToken: 'fake-access-token',
  tokenType: 'bearer',
  user: sb.User(
    id: userId,
    appMetadata: const {},
    userMetadata: role == null ? const {} : {'role': role.wireValue},
    aud: 'authenticated',
    createdAt: DateTime.now().toIso8601String(),
  ),
);
