/// Package-free phone-country model and E.164 composition rules.
///
/// This file must never import Flutter or the third-party country-list
/// package (see `country_picker_adapter.dart` for the single seam onto it) —
/// it is the piece the unit tests and the composition rules rest on, and it
/// must be directly testable with no widget harness.
library;

/// A single selectable country: its ISO alpha-2 code, its E.164 dial code
/// (digits only, no leading '+'), a human display name and a flag glyph.
class PhoneCountry {
  const PhoneCountry({
    required this.isoCode,
    required this.dialCode,
    required this.displayName,
    required this.flagEmoji,
  });

  /// ISO 3166-1 alpha-2 country code, e.g. `EG`.
  final String isoCode;

  /// E.164 dial code, digits only, e.g. `20` (not `+20`).
  final String dialCode;

  /// Human-readable country name for the picker button/list.
  final String displayName;

  /// Flag emoji glyph.
  final String flagEmoji;

  @override
  bool operator ==(Object other) =>
      other is PhoneCountry &&
      other.isoCode == isoCode &&
      other.dialCode == dialCode;

  @override
  int get hashCode => Object.hash(isoCode, dialCode);

  @override
  String toString() => 'PhoneCountry($isoCode, +$dialCode)';
}

/// The result of splitting a stored E.164 value: the country whose dial code
/// matched, and the national-number remainder after that dial code.
typedef PhoneNumberParts = ({PhoneCountry country, String national});

/// Composes [dialCode] and [nationalInput] into a full E.164 string.
///
/// - Separators (`spaces`, `-`, `(`, `)`) are dropped.
/// - A single leading trunk `0` on the national part is stripped, so an
///   Egyptian user typing `01001234567` with Egypt (dial `20`) selected
///   yields `+201001234567`.
/// - If [nationalInput] already carries a leading `+` (a pasted complete
///   international number), it is passed straight through — digits kept,
///   separators dropped — instead of being prefixed with [dialCode] again,
///   so pasting a complete number can never be double-prefixed.
/// - Blank input, or input whose only digit was the stripped trunk zero,
///   composes to an empty string — this is how the "clear my number" path
///   (quick task 260807-rk2) survives regardless of the selected country.
String composeE164(String dialCode, String nationalInput) {
  final trimmed = nationalInput.trim();
  if (trimmed.isEmpty) return '';

  if (trimmed.startsWith('+')) {
    final digits = trimmed.replaceAll(RegExp(r'[^0-9]'), '');
    return digits.isEmpty ? '' : '+$digits';
  }

  var digits = trimmed.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.isEmpty) return '';
  if (digits.startsWith('0')) {
    digits = digits.substring(1);
  }
  if (digits.isEmpty) return '';

  return '+$dialCode$digits';
}

/// Preference map for the rare case where several countries share a dial
/// code (the whole NANP shares `1`; `7` covers Russia and Kazakhstan; `44`
/// covers the UK and the Crown dependencies). This tie-break is cosmetic
/// only: every tied country contributes identical digits to the composed
/// value, so an imperfect flag can never change what is actually stored —
/// which is exactly the invariant the round-trip test below pins down.
const Map<String, String> _dialCodeTiePreference = {
  '1': 'US',
  '7': 'RU',
  '44': 'GB',
};

/// Splits a stored E.164 [value] against the longest matching dial code in
/// [countries]. Returns `null` when [value] has no leading `+`, no matching
/// dial code in [countries], or a non-digit body — the caller should fall
/// back to the default country and an empty field rather than throwing.
PhoneNumberParts? splitE164(String value, List<PhoneCountry> countries) {
  final trimmed = value.trim();
  if (!trimmed.startsWith('+')) return null;

  final body = trimmed.substring(1);
  if (body.isEmpty || !RegExp(r'^[0-9]+$').hasMatch(body)) return null;

  var bestLength = 0;
  final candidates = <PhoneCountry>[];
  for (final country in countries) {
    final dialCode = country.dialCode;
    if (dialCode.isEmpty || !body.startsWith(dialCode)) continue;
    if (dialCode.length > bestLength) {
      bestLength = dialCode.length;
      candidates
        ..clear()
        ..add(country);
    } else if (dialCode.length == bestLength) {
      candidates.add(country);
    }
  }

  if (candidates.isEmpty) return null;

  final country = _resolveTie(candidates);
  final national = body.substring(bestLength);
  return (country: country, national: national);
}

PhoneCountry _resolveTie(List<PhoneCountry> candidates) {
  if (candidates.length == 1) return candidates.first;

  final preferredIso = _dialCodeTiePreference[candidates.first.dialCode];
  if (preferredIso != null) {
    for (final candidate in candidates) {
      if (candidate.isoCode == preferredIso) return candidate;
    }
  }

  return candidates.first;
}

/// Returns the first country in [countries] whose ISO code matches
/// [isoCode] (case-insensitive), or `null` if none match.
PhoneCountry? resolvePhoneCountry(String isoCode, List<PhoneCountry> countries) {
  final upper = isoCode.toUpperCase();
  for (final country in countries) {
    if (country.isoCode.toUpperCase() == upper) return country;
  }
  return null;
}

/// Resolves the default country: [localeCountryCode] when it matches a
/// country in [countries], otherwise `US` — matching the backend's own
/// `PhoneNumberNormalizer.DefaultRegionFallback` so client and server agree
/// on the unset case. Falls back to the first entry in [countries] as a last
/// resort if `US` itself is not present in the supplied list.
PhoneCountry defaultPhoneCountry(
  List<PhoneCountry> countries, {
  String? localeCountryCode,
}) {
  if (localeCountryCode != null) {
    final match = resolvePhoneCountry(localeCountryCode, countries);
    if (match != null) return match;
  }

  return resolvePhoneCountry('US', countries) ?? countries.first;
}
