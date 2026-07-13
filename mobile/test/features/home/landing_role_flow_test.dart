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

  testWidgets('Guardian login routes to the Guardian family setup flow', (
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

    expect(find.text('Your circle'), findsOneWidget);
    expect(find.text('Create your family circle'), findsOneWidget);
    expect(find.text('Create a circle'), findsOneWidget);
    expect(find.text('Enter invite code'), findsNothing);
  });

  testWidgets('Member login routes to the Member join-family flow', (
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

    expect(find.text('Your circle'), findsOneWidget);
    expect(find.text('Join a family circle'), findsOneWidget);
    expect(find.text('Enter invite code'), findsOneWidget);
    expect(find.text('Create a circle'), findsNothing);
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
      expect(find.text('Your circle'), findsNothing);

      await tester.tap(find.text('Caregiver'));
      await tester.tap(find.widgetWithText(ElevatedButton, 'Continue'));
      await tester.pumpAndSettle();

      expect(profileApi.updateRoleCallCount, 1);
      expect(profileApi.lastUpdatedRole, Role.caregiver);
      expect(authApi.updateRoleMetadataCallCount, 1);
      expect(authApi.lastUpdatedMetadataRole, Role.caregiver);
      expect(find.text('Your circle'), findsOneWidget);
      expect(find.text('Set up your circle'), findsOneWidget);
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
      expect(find.text('Join a family circle'), findsNothing);

      await tester.tap(find.text('Guardian / Parent'));
      await tester.tap(find.widgetWithText(ElevatedButton, 'Continue'));
      await tester.pumpAndSettle();

      expect(profileApi.lastUpdatedRole, Role.guardian);
      expect(authApi.lastUpdatedMetadataRole, Role.guardian);
      expect(find.text('Your circle'), findsOneWidget);
      expect(find.text('Create your family circle'), findsOneWidget);
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
