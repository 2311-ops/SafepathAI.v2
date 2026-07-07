import 'package:flutter/material.dart';

/// SafePath AI design-system color tokens.
///
/// Values are ported verbatim from `01-UI-SPEC.md` (Color section) and
/// `01-PATTERNS.md` (Mobile: Design tokens). Do NOT invent new colors here —
/// this is a locked, pre-existing design system (DESIGN-01).
///
/// [sosRed] / [sosRedDeep] are reserved exclusively for SOS/emergency states
/// (and the single flagged "Remove from circle" exception documented in
/// 01-UI-SPEC.md) — never use them for routine warnings.
abstract final class AppColors {
  /// Deep Teal — Welcome screen gradient hero background (start/end stop).
  static const Color deepTeal = Color(0xFF0C3A3F);

  /// Primary teal — CTA fills, focused-input borders, selected states.
  static const Color primaryTeal = Color(0xFF15807C);

  /// Safe green — positive/safe status indicators.
  static const Color safe = Color(0xFF2F9E6B);

  /// Caution amber — non-SOS attention/warning/validation-error states.
  static const Color caution = Color(0xFFC98A2B);

  /// SOS Red — reserved exclusively for SOS/emergency states.
  static const Color sosRed = Color(0xFFDE3B40);

  /// SOS Red (deep variant) — the single flagged exception: "Remove from
  /// circle" destructive action text/icon only (see 01-UI-SPEC.md).
  static const Color sosRedDeep = Color(0xFFC42A30);

  /// Default app background (dominant, 60%).
  static const Color appBg = Color(0xFFECF0EF);

  /// Ink — primary body/heading text color.
  static const Color ink = Color(0xFF15302E);

  /// Surface — cards, input fields, panels (secondary, 30%).
  static const Color surface = Color(0xFFFFFFFF);

  /// Accent Mint — Welcome screen's primary CTA fill only (on the deep-teal
  /// gradient hero, where mint has contrast and teal-on-teal would not).
  static const Color accentMint = Color(0xFF5FD0C5);

  /// Secondary body text color (subtitles, helper text).
  static const Color bodySecondary = Color(0xFF5E726F);

  // Form validation / error-state tokens (defined by extension, not in the
  // hifi mockup — see 01-UI-SPEC.md "Form validation / error states").
  static const Color cautionBg = Color(0xFFFBF3E3);
  static const Color cautionBorder = Color(0xFFEFDFBF);
  static const Color cautionText = Color(0xFF8A6118);
}
