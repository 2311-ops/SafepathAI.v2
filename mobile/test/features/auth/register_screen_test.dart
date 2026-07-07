// Behavior under test (01-03-PLAN.md Task 2):
// - Register screen renders the three field labels and the Continue CTA.
// - An invalid email keeps the CTA from navigating away.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:mobile/features/auth/presentation/register_screen.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  Widget buildTestApp() {
    final router = GoRouter(
      initialLocation: '/register',
      routes: [
        GoRoute(
          path: '/register',
          builder: (context, state) => const RegisterScreen(),
        ),
        GoRoute(
          path: '/register/role',
          builder: (context, state) =>
              const Scaffold(body: Text('role-select-reached')),
        ),
      ],
    );
    return ProviderScope(
      child: MaterialApp.router(routerConfig: router),
    );
  }

  testWidgets(
    'Register screen shows the three field labels and the Continue CTA',
    (WidgetTester tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      expect(find.text('FULL NAME'), findsOneWidget);
      expect(find.text('EMAIL'), findsOneWidget);
      expect(find.text('PASSWORD'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Continue'), findsOneWidget);
    },
  );

  testWidgets(
    'An invalid email keeps Continue from navigating to role select',
    (WidgetTester tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'Test User');
      await tester.enterText(fields.at(1), 'not-an-email');
      await tester.enterText(fields.at(2), 'password123');

      await tester.tap(find.widgetWithText(ElevatedButton, 'Continue'));
      await tester.pumpAndSettle();

      expect(find.text('role-select-reached'), findsNothing);
      expect(find.text('Enter a valid email'), findsOneWidget);
    },
  );
}
