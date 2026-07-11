// Basic smoke test: the SafePath app boots without throwing and shows the
// themed placeholder home. Theme-token assertions live in theme_test.dart.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import 'package:mobile/app.dart';
import 'package:mobile/features/auth/data/auth_api.dart';
import 'package:mobile/features/auth/data/auth_models.dart';

class _FakeAuthApi implements AuthApi {
  @override
  sb.Session? get currentSession => null;

  @override
  Stream<dynamic> get authStateChanges => const Stream<dynamic>.empty();

  @override
  Future<AuthSessionResult> register({
    required String email,
    required String password,
    required String fullName,
    required Role role,
  }) async {
    return const AuthSessionResult(signedIn: false, requiresEmailVerification: true);
  }

  @override
  Future<AuthSessionResult> login({
    required String email,
    required String password,
  }) async {
    return const AuthSessionResult(signedIn: false);
  }

  @override
  Future<void> logout() async {}

  @override
  Future<AuthSessionResult> refreshSession() async {
    return const AuthSessionResult(signedIn: false);
  }

  @override
  Future<void> sendPasswordResetEmail({required String email}) async {}

  @override
  Future<void> updatePassword({required String password}) async {}

  @override
  Future<bool> signInWithGoogle() async => true;
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('SafePathApp pumps without exceptions', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authApiProvider.overrideWithValue(_FakeAuthApi()),
        ],
        child: const SafePathApp(showStartupSplash: false),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('SafePath AI'), findsWidgets);
  });
}
