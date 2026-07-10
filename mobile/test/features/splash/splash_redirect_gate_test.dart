// Deterministic tests proving the /splash redirect gate works through the
// REAL routerProvider/SafePathApp (not a hand-written test router): the app
// holds on /splash for the full minimum duration, then routes authenticated
// users to Home, unauthenticated users to Welcome, and recovery sessions to
// /reset-password — and existing routing rules keep working once /splash is
// left. Mirrors `01.1-UI-SPEC.md`'s Testing Contract.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import 'package:mobile/app.dart';
import 'package:mobile/features/auth/data/auth_api.dart';
import 'package:mobile/features/family/data/family_api.dart';
import 'package:mobile/features/profile/data/profile_api.dart';
import 'package:mobile/features/splash/presentation/splash_screen.dart';

import '../../helpers/fake_auth_api.dart';
import '../../helpers/fake_family_api.dart';
import '../../helpers/fake_profile_api.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  late FakeAuthApi fakeApi;
  late FakeFamilyApi fakeFamilyApi;
  late FakeProfileApi fakeProfileApi;

  setUp(() {
    fakeApi = FakeAuthApi();
    fakeFamilyApi = FakeFamilyApi();
    fakeProfileApi = FakeProfileApi();
  });

  tearDown(() {
    fakeApi.dispose();
  });

  Widget buildApp() {
    return ProviderScope(
      overrides: [
        authApiProvider.overrideWithValue(fakeApi),
        familyApiProvider.overrideWithValue(fakeFamilyApi),
        profileApiProvider.overrideWithValue(fakeProfileApi),
      ],
      child: const SafePathApp(),
    );
  }

  testWidgets(
    'holds on /splash for the minimum duration then routes unauthenticated '
    'to Welcome',
    (tester) async {
      fakeApi.initialSession = null;

      await tester.pumpWidget(buildApp());
      await tester.pump();

      expect(find.byType(SplashScreen), findsOneWidget);
      expect(find.text('Create your circle'), findsNothing);

      // Gate holds for the full minimum duration — still on splash mid-way.
      await tester.pump(const Duration(milliseconds: 700));
      expect(find.byType(SplashScreen), findsOneWidget);

      await tester.pumpAndSettle();

      expect(find.byType(SplashScreen), findsNothing);
      expect(find.text('Create your circle'), findsOneWidget);
    },
  );

  testWidgets('routes authenticated to Home', (tester) async {
    fakeApi.initialSession = _fakeSession();

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    expect(find.byType(SplashScreen), findsNothing);
    expect(find.text('Your circle'), findsOneWidget);
  });

  testWidgets('recovery routes to reset-password', (tester) async {
    fakeApi.initialSession = null;

    await tester.pumpWidget(buildApp());
    await tester.pump();

    fakeApi.emitPasswordRecovery();
    await tester.pumpAndSettle();

    expect(find.byType(SplashScreen), findsNothing);
    expect(find.text('Set a new password'), findsOneWidget);
  });

  testWidgets(
    'existing routing unchanged after splash: unauthenticated -> Welcome -> '
    'Login still works',
    (tester) async {
      fakeApi.initialSession = null;

      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      expect(find.text('Create your circle'), findsOneWidget);

      await tester.tap(find.text('I already have an account'));
      await tester.pumpAndSettle();

      expect(find.text('Welcome back.'), findsOneWidget);
    },
  );
}

// A real (but locally-constructed, never sent over the network) Supabase
// Session — mirrors auth_flow_navigation_test.dart's `_fakeSession()`.
sb.Session _fakeSession() => sb.Session(
  accessToken: 'fake-access-token',
  tokenType: 'bearer',
  user: sb.User(
    id: 'fake-user-id',
    appMetadata: const {},
    userMetadata: const {},
    aud: 'authenticated',
    createdAt: DateTime.now().toIso8601String(),
  ),
);
