// Behavior under test (01-08-PLAN.md Task 2):
// - Renders "Continue with Google" and is enabled while AuthState is not Loading.
// - Tapping it calls AuthController.signInWithGoogle().
// - Disables and shows a spinner while AuthState is AuthLoading; tapping while
//   disabled is a no-op (button-level duplicate-tap guard, D-08-6).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:mobile/features/auth/application/auth_controller.dart';
import 'package:mobile/features/auth/application/auth_state.dart';
import 'package:mobile/shared_widgets/google_sign_in_button.dart';

/// Overrides both [build] and [signInWithGoogle] so the widget test never
/// touches the real `authApiProvider`/Supabase client — this test only
/// exercises the button's own disabled/spinner/tap-guard behavior, which is
/// already covered against a real `AuthApi` fake in auth_controller_test.dart.
class _FakeAuthController extends AuthController {
  _FakeAuthController(this._initialState);

  final AuthState _initialState;
  int signInWithGoogleCallCount = 0;

  @override
  AuthState build() => _initialState;

  @override
  Future<void> signInWithGoogle() async {
    signInWithGoogleCallCount++;
  }
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  Widget buildTestApp(_FakeAuthController controller) {
    return ProviderScope(
      overrides: [
        authControllerProvider.overrideWith(() => controller),
      ],
      child: MaterialApp(
        theme: ThemeData(splashFactory: NoSplash.splashFactory),
        home: const Scaffold(body: GoogleSignInButton()),
      ),
    );
  }

  testWidgets(
    'renders "Continue with Google", enabled, and tapping calls signInWithGoogle',
    (tester) async {
      final controller = _FakeAuthController(const AuthUnauthenticated());
      await tester.pumpWidget(buildTestApp(controller));

      expect(find.text('Continue with Google'), findsOneWidget);
      final button = tester.widget<OutlinedButton>(find.byType(OutlinedButton));
      expect(button.onPressed, isNotNull);

      await tester.tap(find.byType(OutlinedButton));
      await tester.pump();

      expect(controller.signInWithGoogleCallCount, 1);
    },
  );

  testWidgets(
    'disables and shows a spinner while AuthLoading; tapping while disabled is a no-op',
    (tester) async {
      final controller = _FakeAuthController(const AuthLoading());
      await tester.pumpWidget(buildTestApp(controller));

      expect(find.text('Continue with Google'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      final button = tester.widget<OutlinedButton>(find.byType(OutlinedButton));
      expect(button.onPressed, isNull);

      await tester.tap(find.byType(OutlinedButton), warnIfMissed: false);
      await tester.pump();

      expect(controller.signInWithGoogleCallCount, 0);
    },
  );

  testWidgets('exposes a "Continue with Google" semantics label', (tester) async {
    final controller = _FakeAuthController(const AuthUnauthenticated());
    await tester.pumpWidget(buildTestApp(controller));

    expect(
      find.bySemanticsLabel('Continue with Google'),
      findsOneWidget,
    );
  });
}
