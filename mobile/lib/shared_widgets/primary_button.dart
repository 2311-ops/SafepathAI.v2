import 'package:flutter/material.dart';

/// SafePath primary CTA button — full-width, 17px vertical padding, 16px
/// radius, teal fill, white 700/16 label (per `01-UI-SPEC.md` Copywriting
/// Contract: "Primary CTA buttons specifically render at 700 weight, 16px").
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        child: Text(label),
      ),
    );
  }
}
