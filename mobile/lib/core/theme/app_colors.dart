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
  static const Color primaryNavy = Color(0xFF1F3B57);

  /// Deep Teal — Welcome screen gradient hero background (end stop).
  static const Color deepTeal = Color(0xFF132B43);

  /// Lighter teal — Welcome screen gradient hero background (start stop;
  /// [deepTeal] is the end stop). See 01-UI-SPEC.md Color section
  /// ("`#1FA89B` -> `#0C3A3F`").
  static const Color heroGradientStart = Color(0xFF2E7D7B);

  /// Primary teal — CTA fills, focused-input borders, selected states.
  static const Color primaryTeal = Color(0xFF2E7D7B);

  /// Safe green — positive/safe status indicators.
  static const Color safe = Color(0xFF2F9E6B);
  static const Color safeBg = Color(0xFFEAF5EF);
  static const Color safeBgBorder = Color(0xFFCDE9DA);

  /// Caution amber — non-SOS attention/warning/validation-error states.
  static const Color caution = Color(0xFFC98A2B);

  /// SOS Red — reserved exclusively for SOS/emergency states.
  static const Color sosRed = Color(0xFFDE3B40);

  /// SOS Red (deep variant) — the single flagged exception: "Remove from
  /// circle" destructive action text/icon only (see 01-UI-SPEC.md).
  static const Color sosRedDeep = Color(0xFFC42A30);

  /// Default app background (dominant, 60%).
  static const Color appBg = Color(0xFFF4F8FA);
  static const Color primaryTintBg = Color(0xFFE8F2F2);
  static const Color navyTintBg = Color(0xFFEAF0F5);
  static const Color hairline = Color(0xFFDDE8EE);
  static const Color hairlineSoft = Color(0xFFF1F6F8);

  /// Ink — primary body/heading text color.
  static const Color ink = Color(0xFF14283A);

  /// Surface — cards, input fields, panels (secondary, 30%).
  static const Color surface = Color(0xFFFFFFFF);

  /// Accent Mint — Welcome screen's primary CTA fill only (on the deep-teal
  /// gradient hero, where mint has contrast and teal-on-teal would not).
  static const Color accentMint = Color(0xFF79D6C9);

  /// Secondary body text color (subtitles, helper text).
  static const Color bodySecondary = Color(0xFF52697A);
  static const Color toggleOffTrack = Color(0xFFDCE8EC);
  static const Color memberViolet = Color(0xFF6E66C9);
  static const Color memberPink = Color(0xFFC95E8F);

  // Form validation / error-state tokens (defined by extension, not in the
  // hifi mockup — see 01-UI-SPEC.md "Form validation / error states").
  static const Color cautionBg = Color(0xFFFBF3E3);
  static const Color cautionBorder = Color(0xFFEFDFBF);
  static const Color cautionText = Color(0xFF8A6118);
}
