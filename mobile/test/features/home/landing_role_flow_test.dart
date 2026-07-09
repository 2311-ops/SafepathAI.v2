import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import 'package:mobile/app.dart';
import 'package:mobile/features/auth/data/auth_api.dart';
import 'package:mobile/features/auth/data/auth_models.dart';
import 'package:mobile/features/family/data/family_api.dart';
import 'package:mobile/features/profile/data/profile_api.dart';

import '../../helpers/fake_auth_api.dart';
import '../../helpers/fake_family_api.dart';
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
        ],
        child: const SafePathApp(),
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
    final authApi = FakeAuthApi(initialSession: _fakeSession('member-user'));
    final profileApi = FakeProfileApi(userId: 'member-user', role: Role.member);
    final familyApi = FakeFamilyApi();
    addTearDown(authApi.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authApiProvider.overrideWithValue(authApi),
          familyApiProvider.overrideWithValue(familyApi),
          profileApiProvider.overrideWithValue(profileApi),
        ],
        child: const SafePathApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Your circle'), findsOneWidget);
    expect(find.text('Join a family circle'), findsOneWidget);
    expect(find.text('Enter invite code'), findsOneWidget);
    expect(find.text('Create a circle'), findsNothing);
  });
}

sb.Session _fakeSession(String userId) => sb.Session(
  accessToken: 'fake-access-token',
  tokenType: 'bearer',
  user: sb.User(
    id: userId,
    appMetadata: const {},
    userMetadata: const {},
    aud: 'authenticated',
    createdAt: DateTime.now().toIso8601String(),
  ),
);
