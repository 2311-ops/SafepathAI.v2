// Behavior under test (quick 260807-vqc, superseding 260807-rk2's bare
// text-field version):
// - the profile screen splits a saved E.164 number into a country button
//   (phone-country-button) and a national-number field (phone-number-field)
//   seeded from the loaded profile, and re-saving it untouched sends back the
//   identical E.164 string
// - picking a different country recomposes the saved value with the new
//   dial code — the previously selected country never leaks into the result
// - an unset number falls back to the default country and an empty field
// - saving an empty field still clears the number regardless of selected
//   country, and the screen reports removal rather than an error
// - ProfileController.updatePhoneNumber still surfaces a ProfileApiException
//   message into state.error (unchanged controller-level behavior)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mobile/core/phone/country_picker_adapter.dart';
import 'package:mobile/core/phone/phone_country.dart';
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

const _egypt = PhoneCountry(
  isoCode: 'EG',
  dialCode: '20',
  displayName: 'Egypt',
  flagEmoji: '🇪🇬',
);
const _unitedStates = PhoneCountry(
  isoCode: 'US',
  dialCode: '1',
  displayName: 'United States',
  flagEmoji: '🇺🇸',
);
const _unitedKingdom = PhoneCountry(
  isoCode: 'GB',
  dialCode: '44',
  displayName: 'United Kingdom',
  flagEmoji: '🇬🇧',
);

final _fixtureCountries = [_egypt, _unitedStates, _unitedKingdom];

/// A scripted picker that always resolves with [nextSelection] (or `null` if
/// unset), so no real `country_picker` bottom-sheet UI is ever exercised.
class _ScriptedCountryPicker {
  PhoneCountry? nextSelection;

  Future<PhoneCountry?> call(BuildContext context) async => nextSelection;
}

Widget _wrap(FakeProfileApi api, {_ScriptedCountryPicker? picker}) {
  return ProviderScope(
    overrides: [
      profileApiProvider.overrideWithValue(api),
      authControllerProvider.overrideWith(_FixedAuthController.new),
      phoneCountriesProvider.overrideWithValue(_fixtureCountries),
      if (picker != null)
        phoneCountryPickerProvider.overrideWithValue(picker.call),
    ],
    child: const MaterialApp(home: ProfileScreen()),
  );
}

/// A tall test surface keeps every card (display name, phone number, photo)
/// within the hit-testable viewport without needing manual scroll
/// gymnastics per test — mirrors `emergency_contacts_screen_test.dart`'s own
/// `_pumpScreen` convention.
Future<void> _pumpScreen(
  WidgetTester tester,
  FakeProfileApi api, {
  _ScriptedCountryPicker? picker,
}) async {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(_wrap(api, picker: picker));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('restores the saved country and national number', (
    tester,
  ) async {
    final api = FakeProfileApi(phoneNumberE164: '+201001234567');

    await _pumpScreen(tester, api);

    expect(find.textContaining('+20'), findsOneWidget);
    final phoneField = tester.widget<TextField>(
      find.byKey(const ValueKey('phone-number-field')),
    );
    expect(phoneField.controller?.text, '1001234567');
  });

  testWidgets(
    're-saving a restored number without editing sends the identical E.164 string',
    (tester) async {
      final api = FakeProfileApi(phoneNumberE164: '+201001234567');

      await _pumpScreen(tester, api);
      await tester.tap(find.text('Save phone number'));
      await tester.pumpAndSettle();

      expect(api.updatePhoneNumberCallCount, 1);
      expect(api.lastPhoneNumber, '+201001234567');
    },
  );

  testWidgets('picking a different country recomposes the saved value', (
    tester,
  ) async {
    final api = FakeProfileApi(phoneNumberE164: '+201001234567');
    final picker = _ScriptedCountryPicker()..nextSelection = _unitedKingdom;

    await _pumpScreen(tester, api, picker: picker);

    await tester.tap(find.byKey(const ValueKey('phone-country-button')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('phone-number-field')),
      '7700900123',
    );
    await tester.tap(find.text('Save phone number'));
    await tester.pumpAndSettle();

    expect(api.updatePhoneNumberCallCount, 1);
    expect(api.lastPhoneNumber, '+447700900123');
  });

  testWidgets(
    'an unset number falls back to the default country and an empty field',
    (tester) async {
      final api = FakeProfileApi();

      await _pumpScreen(tester, api);

      final phoneField = tester.widget<TextField>(
        find.byKey(const ValueKey('phone-number-field')),
      );
      expect(phoneField.controller?.text, '');
      expect(find.byKey(const ValueKey('phone-country-button')), findsOneWidget);
    },
  );

  testWidgets(
    'saving an empty field still clears the number regardless of selected country',
    (tester) async {
      final api = FakeProfileApi(phoneNumberE164: '+201001234567');

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
