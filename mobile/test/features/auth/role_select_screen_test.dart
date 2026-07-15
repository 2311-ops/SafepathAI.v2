// Behavior under test:
// - Role select redirects to /register when registerDraftProvider is empty
//   (e.g. a direct deep link, or process death losing in-memory state) —
//   never silently renders a broken/incomplete confirm form.
// - Loading state disables the confirm button and relabels it.
// - Validation-safe: register() is called with the exact draft + selected role.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:mobile/features/auth/data/auth_api.dart';
import 'package:mobile/features/auth/data/auth_models.dart';
import 'package:mobile/features/auth/presentation/register_screen.dart';
import 'package:mobile/features/auth/presentation/role_select_screen.dart';

import '../../helpers/fake_auth_api.dart';

class _PresetDraftNotifier extends RegisterDraftNotifier {
  _PresetDraftNotifier(this._draft);

  final RegisterDraft _draft;

  @override
  RegisterDraft? build() => _draft;
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  late FakeAuthApi fakeApi;

  setUp(() => fakeApi = FakeAuthApi());
  tearDown(() => fakeApi.dispose());

  Widget buildTestApp({RegisterDraft? draft}) {
    final router = GoRouter(
      initialLocation: '/register/role',
      routes: [
        GoRoute(
          path: '/register',
          builder: (context, state) =>
              const Scaffold(body: Text('register-reached')),
        ),
        GoRoute(
          path: '/register/role',
          builder: (context, state) => const RoleSelectScreen(),
        ),
      ],
    );
    return ProviderScope(
      overrides: [
        authApiProvider.overrideWithValue(fakeApi),
        if (draft != null)
          registerDraftProvider.overrideWith(() => _PresetDraftNotifier(draft)),
      ],
      child: MaterialApp.router(
        theme: ThemeData(splashFactory: NoSplash.splashFactory),
        routerConfig: router,
      ),
    );
  }

  testWidgets('redirects to /register when there is no draft', (tester) async {
    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();

    expect(find.text('register-reached'), findsOneWidget);
  });

  testWidgets(
    'confirming with a draft calls register() with its values and the selected role',
    (tester) async {
      fakeApi.registerShouldRequireVerification = true;
      await tester.pumpWidget(
        buildTestApp(
          draft: const RegisterDraft(
            email: 'ada@family.com',
            password: 'correct-horse-1',
            fullName: 'Ada Guardian',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Who are you in this circle?'), findsOneWidget);

      await tester.tap(find.text('Caregiver'));
      final createButton = find.widgetWithText(
        ElevatedButton,
        'Create your circle',
      );
      await tester.ensureVisible(createButton);
      await tester.tap(createButton);
      await tester.pumpAndSettle();

      expect(fakeApi.registerCallCount, 1);
      expect(fakeApi.lastRegisterEmail, 'ada@family.com');
      expect(fakeApi.lastRegisterFullName, 'Ada Guardian');
      expect(fakeApi.lastRegisterRole, Role.caregiver);
    },
  );

  testWidgets(
    'confirm button disables and relabels while the request is in flight',
    (tester) async {
      fakeApi.responseDelay = const Duration(milliseconds: 200);
      await tester.pumpWidget(
        buildTestApp(
          draft: const RegisterDraft(
            email: 'ada@family.com',
            password: 'correct-horse-1',
            fullName: 'Ada Guardian',
          ),
        ),
      );
      await tester.pumpAndSettle();

      final createButton = find.widgetWithText(
        ElevatedButton,
        'Create your circle',
      );
      await tester.ensureVisible(createButton);
      await tester.tap(createButton);
      await tester.pump();

      final button = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Creating your circle...'),
      );
      expect(button.onPressed, isNull);

      await tester.pumpAndSettle();
    },
  );
}
