import 'package:flutter/material.dart';

/// SafePath primary CTA button — full-width, 17px vertical padding, 16px
/// radius, teal fill, white 700/16 label (per `01-UI-SPEC.md` Copywriting
/// Contract: "Primary CTA buttons specifically render at 700 weight, 16px").
///
/// [backgroundColor]/[foregroundColor] are optional overrides for the single
/// documented exception in the design system: the Welcome screen's CTA uses
/// the accent-mint fill instead of the default teal (see `01-UI-SPEC.md`
/// Color section) — leave both null everywhere else to use the theme
/// default.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.backgroundColor,
    this.foregroundColor,
  });

  final String label;
  final VoidCallback? onPressed;
  final Color? backgroundColor;
  final Color? foregroundColor;

  @override
  Widget build(BuildContext context) {
    final hasOverride = backgroundColor != null || foregroundColor != null;
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: hasOverride
            ? ElevatedButton.styleFrom(
                backgroundColor: backgroundColor,
                foregroundColor: foregroundColor,
              )
            : null,
        child: Text(label),
      ),
    );
  }
}
