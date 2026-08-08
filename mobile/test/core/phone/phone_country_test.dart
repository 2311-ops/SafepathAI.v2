// Package-free coverage for phone_country.dart's composition rules, driven
// against a fixture country list — no package import, no WidgetTester.
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/phone/phone_country.dart';

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
const _canada = PhoneCountry(
  isoCode: 'CA',
  dialCode: '1',
  displayName: 'Canada',
  flagEmoji: '🇨🇦',
);
const _unitedKingdom = PhoneCountry(
  isoCode: 'GB',
  dialCode: '44',
  displayName: 'United Kingdom',
  flagEmoji: '🇬🇧',
);
const _japan = PhoneCountry(
  isoCode: 'JP',
  dialCode: '81',
  displayName: 'Japan',
  flagEmoji: '🇯🇵',
);

final _fixtureCountries = [_egypt, _unitedStates, _canada, _unitedKingdom, _japan];

void main() {
  group('composeE164', () {
    test('joins the dial code and typed national digits, dropping separators', () {
      expect(composeE164('20', '(100) 123-4567'), '+201001234567');
    });

    test('strips a single leading trunk zero from the national part', () {
      expect(composeE164('20', '01001234567'), '+201001234567');
    });

    test('passes a +-prefixed input straight through without double-prefixing', () {
      expect(composeE164('20', '+15551234567'), '+15551234567');
    });

    test('drops separators from a +-prefixed input too', () {
      expect(composeE164('20', '+1 (555) 123-4567'), '+15551234567');
    });

    test('returns an empty string for blank input', () {
      expect(composeE164('20', ''), '');
      expect(composeE164('20', '   '), '');
    });

    test(
      'returns an empty string when the only digit was the stripped trunk zero',
      () {
        expect(composeE164('20', '0'), '');
      },
    );
  });

  group('splitE164', () {
    test('splits on the longest matching dial code (Egypt)', () {
      final result = splitE164('+201001234567', _fixtureCountries);
      expect(result, isNotNull);
      expect(result!.country, _egypt);
      expect(result.national, '1001234567');
    });

    test('splits on the longest matching dial code (United Kingdom)', () {
      final result = splitE164('+447700900123', _fixtureCountries);
      expect(result, isNotNull);
      expect(result!.country, _unitedKingdom);
      expect(result.national, '7700900123');
    });

    test('resolves a shared dial code tie via the preference map (NANP -> US)', () {
      final result = splitE164('+12025550173', _fixtureCountries);
      expect(result, isNotNull);
      expect(result!.country, _unitedStates);
      expect(result.national, '2025550173');
    });

    test('returns null for a value with no leading +', () {
      expect(splitE164('201001234567', _fixtureCountries), isNull);
    });

    test('returns null for a value with no matching dial code', () {
      expect(splitE164('+999123456', _fixtureCountries), isNull);
    });

    test('returns null for a non-digit body', () {
      expect(splitE164('+20abc123', _fixtureCountries), isNull);
    });
  });

  group('round trip', () {
    for (final value in [
      '+201001234567',
      '+12025550173',
      '+447700900123',
      '+819012345678',
    ]) {
      test('composeE164(splitE164($value)) reproduces the original string', () {
        final split = splitE164(value, _fixtureCountries);
        expect(split, isNotNull);
        expect(composeE164(split!.country.dialCode, split.national), value);
      });
    }
  });

  group('defaultPhoneCountry', () {
    test('resolves the device locale country code when it is in the list', () {
      final result = defaultPhoneCountry(
        _fixtureCountries,
        localeCountryCode: 'EG',
      );
      expect(result, _egypt);
    });

    test('falls back to US when the locale country code is absent', () {
      final result = defaultPhoneCountry(
        _fixtureCountries,
        localeCountryCode: 'FR',
      );
      expect(result, _unitedStates);
    });

    test('falls back to US when no locale country code is supplied', () {
      final result = defaultPhoneCountry(_fixtureCountries);
      expect(result, _unitedStates);
    });
  });
}
