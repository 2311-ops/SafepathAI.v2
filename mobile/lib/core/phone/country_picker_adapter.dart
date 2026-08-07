// The one and only file in the mobile app that imports the third-party
// `country_picker` package. `phone_country.dart`'s model and composition
// rules stay package-free; this file is the single seam onto the picker's
// country list and its bottom-sheet UI, exposed as two overridable Riverpod
// `Provider`s so widget tests can substitute a fixture list and a scripted
// picker without exercising any real package UI.
import 'dart:async';

import 'package:country_picker/country_picker.dart' as country_picker;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'phone_country.dart';

/// Awaits the user's country selection from the picker UI, or `null` if they
/// dismiss it without picking one.
typedef PhoneCountryPicker = Future<PhoneCountry?> Function(BuildContext context);

PhoneCountry _mapCountry(country_picker.Country country) {
  return PhoneCountry(
    isoCode: country.countryCode,
    dialCode: country.phoneCode,
    displayName: country.name,
    flagEmoji: country.flagEmoji,
  );
}

/// The full list of selectable countries, mapped from the package's own
/// `CountryService` into the package-free [PhoneCountry] model.
final phoneCountriesProvider = Provider<List<PhoneCountry>>((ref) {
  return country_picker.CountryService().getAll().map(_mapCountry).toList();
});

Future<PhoneCountry?> _showPhoneCountryPicker(BuildContext context) {
  final completer = Completer<PhoneCountry?>();
  country_picker.showCountryPicker(
    context: context,
    showPhoneCode: true,
    showSearch: true,
    onSelect: (country) {
      if (!completer.isCompleted) completer.complete(_mapCountry(country));
    },
    onClosed: () {
      if (!completer.isCompleted) completer.complete(null);
    },
  );
  return completer.future;
}

/// The real picker implementation: opens the package's bottom-sheet country
/// list (phone-code column + search box enabled) and resolves with the
/// selected [PhoneCountry], or `null` if dismissed. Overridable in widget
/// tests with a scripted picker that never touches the real package UI.
final phoneCountryPickerProvider = Provider<PhoneCountryPicker>(
  (ref) => _showPhoneCountryPicker,
);
