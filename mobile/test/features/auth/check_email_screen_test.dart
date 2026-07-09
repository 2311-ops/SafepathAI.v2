// Behavior under test:
// - Shows the address the verification email was sent to when provided.
// - Falls back to a generic message when no address is available.
// - Back to login navigates to /login.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:mobile/features/auth/presentation/check_email_screen.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  GoRouter buildRouter({String? email}) {
    return GoRouter(
      initialLocation: '/verify-email',
      routes: [
        GoRoute(
          path: '/verify-email',
          builder: (context, state) => CheckEmailScreen(email: email),
        ),
        GoRoute(
          path: '/login',
          builder: (context, state) => const Scaffold(body: Text('login-reached')),
        ),
      ],
    );
  }

  testWidgets('shows the email address when provided', (tester) async {
    await tester.pumpWidget(
      MaterialApp.router(
        theme: ThemeData(splashFactory: NoSplash.splashFactory),
        routerConfig: buildRouter(email: 'ada@family.com'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('ada@family.com'), findsOneWidget);
  });

  testWidgets('falls back to a generic message with no email', (tester) async {
    await tester.pumpWidget(
      MaterialApp.router(
        theme: ThemeData(splashFactory: NoSplash.splashFactory),
        routerConfig: buildRouter(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Check your email'), findsOneWidget);
    expect(find.textContaining('We sent you a verification link'), findsOneWidget);
  });

  testWidgets('Back to login navigates to /login', (tester) async {
    await tester.pumpWidget(
      MaterialApp.router(
        theme: ThemeData(splashFactory: NoSplash.splashFactory),
        routerConfig: buildRouter(email: 'ada@family.com'),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ElevatedButton, 'Back to login'));
    await tester.pumpAndSettle();

    expect(find.text('login-reached'), findsOneWidget);
  });
}
