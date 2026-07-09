import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_typography.dart';

/// SafePath text field — mono uppercase field label above a themed
/// [TextFormField] (relies on `ThemeData.inputDecorationTheme` for the
/// 16px-radius / 1.5px-border / teal-focus visual treatment).
///
/// On invalid input, the field's border/error copy render in the Caution
/// amber tokens (`#C98A2B` / `#FBF3E3` / `#EFDFBF`) per `01-UI-SPEC.md` —
/// SOS red is reserved exclusively for emergency states, never validation
/// errors.
class SafePathTextField extends StatelessWidget {
  const SafePathTextField({
    super.key,
    required this.label,
    this.controller,
    this.obscureText = false,
    this.keyboardType,
    this.errorText,
    this.onChanged,
    this.validator,
    this.autofillHints,
    this.textInputAction,
    this.onFieldSubmitted,
  });

  final String label;
  final TextEditingController? controller;
  final bool obscureText;
  final TextInputType? keyboardType;
  final String? errorText;
  final ValueChanged<String>? onChanged;
  final Iterable<String>? autofillHints;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onFieldSubmitted;

  /// Optional form-field validator (used when this field is wrapped in a
  /// [Form] — e.g. Register's client-side email/password checks).
  final FormFieldValidator<String>? validator;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: AppTypography.caption),
        const SizedBox(height: AppSpacing.sm),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          onChanged: onChanged,
          autofillHints: autofillHints,
          textInputAction: textInputAction,
          onFieldSubmitted: onFieldSubmitted,
          validator: validator,
          style: AppTypography.body,
          decoration: InputDecoration(
            errorText: errorText,
            errorStyle: const TextStyle(
              color: AppColors.cautionText,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
