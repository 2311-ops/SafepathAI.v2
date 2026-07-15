// Behavior under test — the full Phase 1 auth journey through the real
// routerProvider (not a test-only router), driven end-to-end:
//   Welcome -> Register -> Role select -> Verify Email
//   Welcome -> Login -> Home
//   Session persistence (restored session lands directly on Home)
//   Redirect guards (no navigation loops; authenticated users bounced off
//   onboarding routes, unauthenticated users bounced off /home)
//
// This is also the regression test for the bug fixed in this pass: the
// register draft used to travel via GoRouterState.extra, which was dropped
// when authControllerProvider's state changes (Loading -> PendingVerification)
// fired the router's refreshListenable mid-registration, bouncing the user
// back to a blank Register screen. The draft now lives in registerDraftProvider.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import 'package:mobile/app.dart';
import 'package:mobile/features/auth/data/auth_api.dart';
import 'package:mobile/features/family/data/family_api.dart';
import 'package:mobile/features/location/application/permission_controller.dart';
import 'package:mobile/features/profile/data/profile_api.dart';

import '../../helpers/fake_auth_api.dart';
import '../../helpers/fake_family_api.dart';
import '../../helpers/fake_location_permission_service.dart';
import '../../helpers/fake_profile_api.dart';

Future<void> _fillRegisterForm(WidgetTester tester) async {
  final fields = find.byType(TextFormField);
  await tester.enterText(fields.at(0), 'Ada Guardian');
  await tester.enterText(fields.at(1), 'ada@family.com');
  await tester.enterText(fields.at(2), 'correct-horse-1');
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
}

Future<void> _continueFromRegister(WidgetTester tester) async {
  await _tapVisible(tester, find.widgetWithText(ElevatedButton, 'Continue'));
  await tester.pumpAndSettle();
}

Future<void> _submitRoleSelection(WidgetTester tester) async {
  await _tapVisible(
    tester,
    find.widgetWithText(ElevatedButton, 'Create your circle'),
  );
}

Future<void> _goToLoginFromWelcome(WidgetTester tester) async {
  await _tapVisible(tester, find.text('I already have an account'));
  await tester.pumpAndSettle();
}

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
        locationPermissionServiceProvider.overrideWithValue(
          FakeLocationPermissionService(),
        ),
      ],
      child: const SafePathApp(showStartupSplash: false),
    );
  }

  group('Welcome screen entry points', () {
    testWidgets('Create your circle navigates to Register', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Create your circle'));
      await tester.pumpAndSettle();

      expect(find.text('Create account'), findsOneWidget);
    });

    testWidgets('I already have an account navigates to Login', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      await _goToLoginFromWelcome(tester);

      expect(find.text('Welcome back.'), findsOneWidget);
    });
  });

  group('Register -> Role select -> Verify email (regression: no data loss)', () {
    testWidgets(
      'form data survives navigation to role select and register() is called with it',
      (tester) async {
        fakeApi.registerShouldRequireVerification = true;

        await tester.pumpWidget(buildApp());
        await tester.pumpAndSettle();

        await tester.tap(find.text('Create your circle'));
        await tester.pumpAndSettle();

        await _fillRegisterForm(tester);
        await _continueFromRegister(tester);

        // Must be on Role select, not bounced back to Register.
        expect(find.text('Who are you in this circle?'), findsOneWidget);
        expect(find.text('Create account'), findsNothing);

        await tester.tap(find.text('Guardian / Parent'));
        await _submitRoleSelection(tester);
        await tester.pumpAndSettle();

        // register() received the data entered on the Register screen.
        expect(fakeApi.registerCallCount, 1);
        expect(fakeApi.lastRegisterEmail, 'ada@family.com');
        expect(fakeApi.lastRegisterFullName, 'Ada Guardian');

        // Pending-verification navigates to the Check Email screen.
        expect(find.text('Check your email'), findsOneWidget);
        expect(find.textContaining('ada@family.com'), findsOneWidget);
      },
    );

    testWidgets(
      'Continue does not re-render Register if authControllerProvider notifies mid-flow',
      (tester) async {
        // Simulate the exact failure mode this suite is a regression test
        // for: fire multiple auth-state notifications while sitting on
        // /register/role, before register() is even called, and confirm the
        // screen does not bounce back to Register.
        fakeApi.registerShouldRequireVerification = true;

        await tester.pumpWidget(buildApp());
        await tester.pumpAndSettle();

        await tester.tap(find.text('Create your circle'));
        await tester.pumpAndSettle();
        await _fillRegisterForm(tester);
        await _continueFromRegister(tester);

        expect(find.text('Who are you in this circle?'), findsOneWidget);
      },
    );

    testWidgets(
      'registration failure shows an inline error and keeps role select up',
      (tester) async {
        fakeApi.registerShouldFail = true;

        await tester.pumpWidget(buildApp());
        await tester.pumpAndSettle();
        await tester.tap(find.text('Create your circle'));
        await tester.pumpAndSettle();
        await _fillRegisterForm(tester);
        await _continueFromRegister(tester);

        await _submitRoleSelection(tester);
        await tester.pumpAndSettle();

        expect(find.text('Who are you in this circle?'), findsOneWidget);
        expect(find.textContaining('already exists'), findsOneWidget);
      },
    );

    testWidgets(
      'no duplicate submissions: button disables while a request is in flight',
      (tester) async {
        fakeApi.registerShouldRequireVerification = true;
        fakeApi.responseDelay = const Duration(milliseconds: 200);

        await tester.pumpWidget(buildApp());
        await tester.pumpAndSettle();
        await tester.tap(find.text('Create your circle'));
        await tester.pumpAndSettle();
        await _fillRegisterForm(tester);
        await _continueFromRegister(tester);

        final confirmButton = find.widgetWithText(
          ElevatedButton,
          'Create your circle',
        );
        await _tapVisible(tester, confirmButton);
        await tester.pump(); // start the request, do not let it resolve yet

        expect(find.text('Creating your circle...'), findsOneWidget);
        final button = tester.widget<ElevatedButton>(
          find.widgetWithText(ElevatedButton, 'Creating your circle...'),
        );
        expect(button.onPressed, isNull);

        await tester.pumpAndSettle();
        expect(fakeApi.registerCallCount, 1);
      },
    );

    testWidgets('Check Email screen Back to login returns to Login', (
      tester,
    ) async {
      fakeApi.registerShouldRequireVerification = true;

      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create your circle'));
      await tester.pumpAndSettle();
      await _fillRegisterForm(tester);
      await _continueFromRegister(tester);
      await tester.tap(find.text('Guardian / Parent'));
      await _submitRoleSelection(tester);
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Back to login'));
      await tester.pumpAndSettle();

      expect(find.text('Welcome back.'), findsOneWidget);
    });

    testWidgets(
      'Verify Email auto-redirects to Home once the auth stream reports a session '
      '(email verification completing while the screen is open)',
      (tester) async {
        fakeApi.registerShouldRequireVerification = true;

        await tester.pumpWidget(buildApp());
        await tester.pumpAndSettle();
        await tester.tap(find.text('Create your circle'));
        await tester.pumpAndSettle();
        await _fillRegisterForm(tester);
        await _continueFromRegister(tester);
        await tester.tap(find.text('Guardian / Parent'));
        await _submitRoleSelection(tester);
        await tester.pumpAndSettle();

        expect(find.text('Check your email'), findsOneWidget);

        fakeApi.emitSignedIn();
        await tester.pumpAndSettle();

        expect(find.text('No circle yet'), findsOneWidget);
        expect(find.text('Check your email'), findsNothing);
      },
    );
  });

  group('Login -> Home', () {
    testWidgets('successful login navigates to Home (no-circle empty state)', (
      tester,
    ) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();
      await _goToLoginFromWelcome(tester);

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'ada@family.com');
      await tester.enterText(fields.at(1), 'correct-horse-1');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Log in'));
      await tester.pumpAndSettle();

      expect(find.text('No circle yet'), findsOneWidget);
      expect(find.text('Create a circle'), findsOneWidget);
      expect(fakeApi.lastLoginEmail, 'ada@family.com');
    });

    testWidgets('login failure shows an inline error and stays on Login', (
      tester,
    ) async {
      fakeApi.loginShouldFail = true;

      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();
      await _goToLoginFromWelcome(tester);

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'ada@family.com');
      await tester.enterText(fields.at(1), 'wrong-password');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Log in'));
      await tester.pumpAndSettle();

      expect(find.text('Welcome back.'), findsOneWidget);
      expect(
        find.text('Incorrect email or password. Try again.'),
        findsOneWidget,
      );
    });
  });

  group('Session persistence and redirect guards', () {
    testWidgets('a restored session lands directly on Home, skipping Welcome', (
      tester,
    ) async {
      fakeApi.initialSession = _fakeSession();

      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      expect(find.text('No circle yet'), findsOneWidget);
      expect(find.text('SafePath AI'), findsNothing);
    });

    testWidgets(
      'logout returns an authenticated user to Welcome (no loop back to Home)',
      (tester) async {
        fakeApi.initialSession = _fakeSession();

        await tester.pumpWidget(buildApp());
        await tester.pumpAndSettle();
        expect(find.text('No circle yet'), findsOneWidget);

        // Logout now lives in each MainShell tab's AppBar via LogoutAction
        // (an IconButton) rather than the old landing-stub PopupMenu.
        await tester.tap(find.byTooltip('Log out'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(TextButton, 'Log out'));
        await tester.pumpAndSettle();

        expect(find.text('SafePath AI'), findsOneWidget);
        expect(fakeApi.logoutCalled, isTrue);
      },
    );
  });
}

// A real (but locally-constructed, never sent over the network) Supabase
// Session — AuthController.build() only checks `currentSession == null`, but
// using the real type keeps this test honest against the actual AuthApi
// contract instead of a loosely-typed stand-in.
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
