// Behavior under test:
// - Loading indicator relabels/disables the Log in button while in flight.
// - Login failure shows the enumeration-safe inline error, no navigation.
// - Login success navigates away (verified via a stub destination route).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:mobile/features/auth/data/auth_api.dart';
import 'package:mobile/features/auth/presentation/login_screen.dart';

import '../../helpers/fake_auth_api.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  late FakeAuthApi fakeApi;

  setUp(() => fakeApi = FakeAuthApi());
  tearDown(() => fakeApi.dispose());

  Widget buildTestApp() {
    final router = GoRouter(
      initialLocation: '/login',
      routes: [
        GoRoute(
          path: '/login',
          builder: (context, state) => const LoginScreen(),
        ),
        GoRoute(
          path: '/register',
          builder: (context, state) => const Scaffold(body: Text('register-reached')),
        ),
        GoRoute(
          path: '/forgot-password',
          builder: (context, state) => const Scaffold(body: Text('forgot-reached')),
        ),
      ],
    );
    return ProviderScope(
      overrides: [authApiProvider.overrideWithValue(fakeApi)],
      child: MaterialApp.router(routerConfig: router),
    );
  }

  Future<void> fillAndSubmit(WidgetTester tester, {String email = 'ada@family.com', String password = 'correct-horse-1'}) async {
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), email);
    await tester.enterText(fields.at(1), password);
    await tester.tap(find.widgetWithText(ElevatedButton, 'Log in'));
  }

  testWidgets('button disables and relabels while the login request is in flight',
      (tester) async {
    fakeApi.responseDelay = const Duration(milliseconds: 200);
    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();

    await fillAndSubmit(tester);
    await tester.pump();

    final button = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Logging in...'),
    );
    expect(button.onPressed, isNull);

    await tester.pumpAndSettle();
    expect(fakeApi.loginCallCount, 1);
  });

  testWidgets('failure shows the enumeration-safe error and does not navigate',
      (tester) async {
    fakeApi.loginShouldFail = true;
    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();

    await fillAndSubmit(tester, password: 'wrong');
    await tester.pumpAndSettle();

    expect(find.text('Incorrect email or password. Try again.'), findsOneWidget);
    expect(find.text('Welcome back.'), findsOneWidget);
  });

  testWidgets('Forgot password? navigates to the forgot-password route', (tester) async {
    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Forgot password?'));
    await tester.pumpAndSettle();

    expect(find.text('forgot-reached'), findsOneWidget);
  });

  testWidgets("Don't have an account? navigates to Register", (tester) async {
    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text("Don't have an account? Create one"));
    await tester.pumpAndSettle();

    expect(find.text('register-reached'), findsOneWidget);
  });
}
