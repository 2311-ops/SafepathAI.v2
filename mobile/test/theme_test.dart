// Asserts that `buildSafePathTheme()` exposes the exact SafePath design
// tokens (DESIGN-01 fidelity) — see 01-UI-SPEC.md Color/Typography sections.
//
// Uses `testWidgets` (not a plain `test`) throughout: `google_fonts` fires a
// fire-and-forget background Future to fetch/cache the real font file on
// every `GoogleFonts.<family>()` call, which is disabled here via
// `allowRuntimeFetching = false` for deterministic, offline-safe runs (the
// returned TextStyle's `fontFamily` — what we assert on — is already set
// synchronously before that background attempt even starts). The resulting
// harmless "font not found" error only surfaces reliably inside the
// `testWidgets`/pump lifecycle rather than a bare synchronous `test` body.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import 'package:mobile/app.dart';
import 'package:mobile/core/theme/app_colors.dart';
import 'package:mobile/core/theme/app_theme.dart';
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

  testWidgets('buildSafePathTheme exposes the exact SafePath color tokens', (
    WidgetTester tester,
  ) async {
    final theme = buildSafePathTheme();

    expect(theme.colorScheme.primary, const Color(0xFF15807C));
    expect(theme.scaffoldBackgroundColor, const Color(0xFFECF0EF));

    // SOS red must be reachable via AppColors, reserved for emergency states.
    expect(AppColors.sosRed, const Color(0xFFDE3B40));
    expect(AppColors.primaryTeal, const Color(0xFF15807C));
    expect(AppColors.appBg, const Color(0xFFECF0EF));
  });

  testWidgets(
    'buildSafePathTheme uses Manrope for headings and JetBrains Mono '
    'for the mono style',
    (WidgetTester tester) async {
      final theme = buildSafePathTheme();

      final headingFamily = theme.textTheme.headlineMedium?.fontFamily ?? '';
      final captionFamily = theme.textTheme.labelSmall?.fontFamily ?? '';

      expect(headingFamily.contains('Manrope'), isTrue);
      expect(captionFamily.contains('JetBrainsMono'), isTrue);
    },
  );

  testWidgets('SafePathApp builds and shows the themed placeholder route', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authApiProvider.overrideWithValue(_FakeAuthApi()),
        ],
        child: const SafePathApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('SafePath AI'), findsOneWidget);

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
    // Scaffold background falls back to the theme's scaffoldBackgroundColor
    // when not explicitly set on the widget itself.
    expect(scaffold.backgroundColor, isNull);
  });
}
