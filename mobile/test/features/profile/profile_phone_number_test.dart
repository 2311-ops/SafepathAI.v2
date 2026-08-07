// Behavior under test (quick 260807-rk2):
// - the profile screen renders a phone-number field seeded from the loaded
//   profile, and saving it calls the api once with the typed value
// - saving an empty phone-number field calls the api with a value the
//   backend treats as a clear, and the screen reports removal rather than
//   an error
// - ProfileController.updatePhoneNumber surfaces a ProfileApiException's
//   message into state.error instead of throwing

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mobile/features/auth/application/auth_controller.dart';
import 'package:mobile/features/auth/application/auth_state.dart';
import 'package:mobile/features/profile/application/profile_controller.dart';
import 'package:mobile/features/profile/data/profile_api.dart';
import 'package:mobile/features/profile/presentation/profile_screen.dart';

import '../../helpers/fake_profile_api.dart';

/// A fixed, always-authenticated `AuthController` — mirrors
/// `responder_alert_screen_test.dart`'s own `_FixedAuthController` so
/// `ProfileController.build()` triggers its auto-refresh without needing a
/// real Supabase session.
class _FixedAuthController extends AuthController {
  @override
  AuthState build() => const AuthAuthenticated();
}

Widget _wrap(FakeProfileApi api) {
  return ProviderScope(
    overrides: [
      profileApiProvider.overrideWithValue(api),
      authControllerProvider.overrideWith(_FixedAuthController.new),
    ],
    child: const MaterialApp(home: ProfileScreen()),
  );
}

/// A tall test surface keeps every card (display name, phone number, photo)
/// within the hit-testable viewport without needing manual scroll
/// gymnastics per test — mirrors `emergency_contacts_screen_test.dart`'s own
/// `_pumpScreen` convention.
Future<void> _pumpScreen(WidgetTester tester, FakeProfileApi api) async {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(_wrap(api));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'renders a phone-number field seeded from the loaded profile and saves the typed value',
    (tester) async {
      final api = FakeProfileApi(phoneNumberE164: '+12025550173');

      await _pumpScreen(tester, api);

      final phoneField = tester.widget<TextField>(
        find.byKey(const ValueKey('phone-number-field')),
      );
      expect(phoneField.controller?.text, '+12025550173');

      await tester.enterText(
        find.byKey(const ValueKey('phone-number-field')),
        '+15551234567',
      );
      await tester.tap(find.text('Save phone number'));
      await tester.pumpAndSettle();

      expect(api.updatePhoneNumberCallCount, 1);
      expect(api.lastPhoneNumber, '+15551234567');
    },
  );

  testWidgets(
    'saving an empty phone-number field calls the api with a clearing value and reports removal',
    (tester) async {
      final api = FakeProfileApi(phoneNumberE164: '+12025550173');

      await _pumpScreen(tester, api);

      await tester.enterText(
        find.byKey(const ValueKey('phone-number-field')),
        '',
      );
      await tester.tap(find.text('Save phone number'));
      await tester.pumpAndSettle();

      expect(api.updatePhoneNumberCallCount, 1);
      expect(api.lastPhoneNumber, '');
      expect(find.text('Phone number removed.'), findsOneWidget);
      expect(find.textContaining('Enter a'), findsNothing);
    },
  );

  test(
    "ProfileController.updatePhoneNumber surfaces a ProfileApiException's message into state.error",
    () async {
      final api = FakeProfileApi()..shouldThrowNetwork = true;
      final container = ProviderContainer(
        overrides: [
          profileApiProvider.overrideWithValue(api),
          authControllerProvider.overrideWith(_FixedAuthController.new),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(profileControllerProvider.notifier)
          .updatePhoneNumber('+12025550173');

      final state = container.read(profileControllerProvider).value!;
      expect(
        state.error,
        "Couldn't connect. Check your connection and try again.",
      );
    },
  );
}
