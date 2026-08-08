import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/phone/country_picker_adapter.dart';
import '../core/phone/phone_country.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_typography.dart';

/// A country button beside a national-number [TextField]. The parent holds
/// the selected [country] (this widget owns no state of its own), which
/// keeps it trivially testable and lets callers seed both halves of a
/// restored E.164 number together.
///
/// Tapping the country button awaits the injected [phoneCountryPickerProvider]
/// and, on a non-null result, calls [onCountryChanged]. Both providers this
/// widget reads (`phoneCountriesProvider` is read by callers to seed
/// [country]; `phoneCountryPickerProvider` is read here) are overridable in
/// widget tests so no real third-party picker UI is ever exercised.
class PhoneNumberField extends ConsumerWidget {
  const PhoneNumberField({
    super.key,
    required this.country,
    required this.controller,
    required this.onCountryChanged,
    this.onSubmitted,
  });

  final PhoneCountry country;
  final TextEditingController controller;
  final ValueChanged<PhoneCountry> onCountryChanged;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pickCountry = ref.watch(phoneCountryPickerProvider);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _CountryButton(
          country: country,
          onTap: () async {
            final selected = await pickCountry(context);
            if (selected != null) {
              onCountryChanged(selected);
            }
          },
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: TextField(
            key: const ValueKey('phone-number-field'),
            controller: controller,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(labelText: 'Phone number'),
            onSubmitted: onSubmitted,
          ),
        ),
      ],
    );
  }
}

class _CountryButton extends StatelessWidget {
  const _CountryButton({required this.country, required this.onTap});

  final PhoneCountry country;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final semanticsLabel = '${country.displayName}, dial code +${country.dialCode}';

    return Semantics(
      container: true,
      excludeSemantics: true,
      label: semanticsLabel,
      child: Material(
        key: const ValueKey('phone-country-button'),
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.hairline),
              borderRadius: BorderRadius.circular(12),
              color: AppColors.surface,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(country.flagEmoji, style: const TextStyle(fontSize: 20)),
                const SizedBox(width: AppSpacing.xs),
                Text('+${country.dialCode}', style: AppTypography.body),
                const SizedBox(width: AppSpacing.xs),
                const Icon(
                  Icons.arrow_drop_down,
                  color: AppColors.bodySecondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
