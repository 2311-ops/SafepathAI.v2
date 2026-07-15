import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_typography.dart';

/// SafePath text field with a visible label, screen-reader label, touch-safe
/// password visibility toggle, and amber validation styling.
class SafePathTextField extends StatefulWidget {
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
    this.helperText,
    this.prefixIcon,
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
  final String? helperText;
  final IconData? prefixIcon;
  final FormFieldValidator<String>? validator;

  @override
  State<SafePathTextField> createState() => _SafePathTextFieldState();
}

class _SafePathTextFieldState extends State<SafePathTextField> {
  late bool _obscured = widget.obscureText;

  @override
  void didUpdateWidget(covariant SafePathTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.obscureText != widget.obscureText) {
      _obscured = widget.obscureText;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPassword = widget.obscureText;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label.toUpperCase(), style: AppTypography.caption),
        const SizedBox(height: AppSpacing.sm),
        Semantics(
          label: widget.label,
          textField: true,
          child: TextFormField(
            controller: widget.controller,
            obscureText: _obscured,
            keyboardType: widget.keyboardType,
            onChanged: widget.onChanged,
            autofillHints: widget.autofillHints,
            textInputAction: widget.textInputAction,
            onFieldSubmitted: widget.onFieldSubmitted,
            validator: widget.validator,
            autocorrect: !isPassword,
            enableSuggestions: !isPassword,
            style: AppTypography.body,
            decoration: InputDecoration(
              helperText: widget.helperText,
              helperStyle: AppTypography.bodySecondary.copyWith(fontSize: 12),
              prefixIcon: widget.prefixIcon == null
                  ? null
                  : Icon(widget.prefixIcon, size: 20),
              suffixIcon: isPassword
                  ? IconButton(
                      tooltip: _obscured ? 'Show password' : 'Hide password',
                      icon: Icon(
                        _obscured
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      onPressed: () => setState(() => _obscured = !_obscured),
                    )
                  : null,
              errorText: widget.errorText,
              errorStyle: const TextStyle(
                color: AppColors.cautionText,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
