// Behavior under test:
// - Submit is disabled unless AuthState is AuthRecovery (deep-link required).
// - Password validation (min length, confirm-match).
// - Successful reset navigates to /login.
// - Failure shows an inline error and does not navigate.
// - Loading state disables the submit button (no duplicate submissions).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:mobile/features/auth/data/auth_api.dart';
import 'package:mobile/features/auth/presentation/reset_password_screen.dart';

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
      initialLocation: '/reset-password',
      routes: [
        GoRoute(
          path: '/reset-password',
          builder: (context, state) => const ResetPasswordScreen(),
        ),
        GoRoute(
          path: '/login',
          builder: (context, state) => const Scaffold(body: Text('login-reached')),
        ),
      ],
    );
    return ProviderScope(
      overrides: [authApiProvider.overrideWithValue(fakeApi)],
      child: MaterialApp.router(routerConfig: router),
    );
  }

  testWidgets('without an active recovery session, submit is disabled', (tester) async {
    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();

    expect(
      find.text('Open the reset link from your email on this device to unlock this screen.'),
      findsOneWidget,
    );
    final button = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Update password'),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('password too short is blocked client-side', (tester) async {
    await tester.pumpWidget(buildTestApp());
    fakeApi.emitPasswordRecovery();
    await tester.pumpAndSettle();

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'short');
    await tester.enterText(fields.at(1), 'short');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Update password'));
    await tester.pumpAndSettle();

    expect(find.text('Use at least 8 characters'), findsOneWidget);
    expect(fakeApi.updatePasswordCallCount, 0);
  });

  testWidgets('mismatched confirm password is blocked client-side', (tester) async {
    await tester.pumpWidget(buildTestApp());
    fakeApi.emitPasswordRecovery();
    await tester.pumpAndSettle();

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'correct-horse-1');
    await tester.enterText(fields.at(1), 'different-password');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Update password'));
    await tester.pumpAndSettle();

    expect(find.text('Passwords do not match'), findsOneWidget);
    expect(fakeApi.updatePasswordCallCount, 0);
  });

  testWidgets('successful reset navigates to Login', (tester) async {
    await tester.pumpWidget(buildTestApp());
    fakeApi.emitPasswordRecovery();
    await tester.pumpAndSettle();

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'correct-horse-1');
    await tester.enterText(fields.at(1), 'correct-horse-1');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Update password'));
    await tester.pumpAndSettle();

    expect(find.text('login-reached'), findsOneWidget);
    expect(fakeApi.updatePasswordCallCount, 1);
    expect(fakeApi.lastUpdatedPassword, 'correct-horse-1');
  });

  testWidgets('failure shows an inline error and does not navigate', (tester) async {
    fakeApi.updatePasswordShouldFail = true;
    await tester.pumpWidget(buildTestApp());
    fakeApi.emitPasswordRecovery();
    await tester.pumpAndSettle();

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'correct-horse-1');
    await tester.enterText(fields.at(1), 'correct-horse-1');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Update password'));
    await tester.pumpAndSettle();

    expect(
      find.text("Couldn't connect. Check your connection and try again."),
      findsOneWidget,
    );
    expect(find.text('login-reached'), findsNothing);
  });

  testWidgets('button disables while the request is in flight', (tester) async {
    fakeApi.responseDelay = const Duration(milliseconds: 200);
    await tester.pumpWidget(buildTestApp());
    fakeApi.emitPasswordRecovery();
    await tester.pumpAndSettle();

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'correct-horse-1');
    await tester.enterText(fields.at(1), 'correct-horse-1');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Update password'));
    await tester.pump();

    final button = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Updating...'),
    );
    expect(button.onPressed, isNull);

    await tester.pumpAndSettle();
    expect(fakeApi.updatePasswordCallCount, 1);
  });
}
