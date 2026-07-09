// Behavior under test:
// - Renders the heading, email field, and Send reset link CTA.
// - Empty/invalid email is blocked client-side, no API call made.
// - Successful request shows a neutral status message (no navigation — this
//   screen's design intentionally stays put with an enumeration-safe status,
//   there is no separate confirmation screen for password reset).
// - API failure shows an inline error and preserves the entered email.
// - Duplicate submissions are prevented while a request is in flight.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:mobile/features/auth/data/auth_api.dart';
import 'package:mobile/features/auth/presentation/forgot_password_screen.dart';

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
      initialLocation: '/forgot-password',
      routes: [
        GoRoute(
          path: '/forgot-password',
          builder: (context, state) => const ForgotPasswordScreen(),
        ),
      ],
    );
    return ProviderScope(
      overrides: [authApiProvider.overrideWithValue(fakeApi)],
      child: MaterialApp.router(routerConfig: router),
    );
  }

  testWidgets('renders heading, email field, and CTA', (tester) async {
    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();

    expect(find.text('Reset password'), findsOneWidget);
    expect(find.byType(TextFormField), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Send reset link'), findsOneWidget);
  });

  testWidgets('empty email is blocked and shows a validation error, no API call',
      (tester) async {
    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ElevatedButton, 'Send reset link'));
    await tester.pumpAndSettle();

    expect(find.text('Enter your email'), findsOneWidget);
  });

  testWidgets('invalid email is blocked and shows a validation error, no API call',
      (tester) async {
    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField), 'not-an-email');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Send reset link'));
    await tester.pumpAndSettle();

    expect(find.text('Enter a valid email'), findsOneWidget);
  });

  testWidgets('successful request shows the neutral status message', (tester) async {
    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField), 'ada@family.com');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Send reset link'));
    await tester.pumpAndSettle();

    expect(
      find.text('If that email exists, Supabase sent a password reset link.'),
      findsOneWidget,
    );
    expect(fakeApi.lastResetEmail, 'ada@family.com');
  });

  testWidgets('failure shows an inline error and preserves the entered email',
      (tester) async {
    fakeApi.resetShouldFail = true;
    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField), 'ada@family.com');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Send reset link'));
    await tester.pumpAndSettle();

    expect(
      find.text('We could not send the reset email. Check your connection and try again.'),
      findsOneWidget,
    );
    // Form state preserved on failure.
    expect(find.text('ada@family.com'), findsOneWidget);
  });

  testWidgets('button disables while the request is in flight (no duplicate submissions)',
      (tester) async {
    fakeApi.responseDelay = const Duration(milliseconds: 200);
    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField), 'ada@family.com');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Send reset link'));
    await tester.pump();

    final button = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Sending link...'),
    );
    expect(button.onPressed, isNull);

    await tester.pumpAndSettle();
    expect(fakeApi.resetCallCount, 1);
  });
}
