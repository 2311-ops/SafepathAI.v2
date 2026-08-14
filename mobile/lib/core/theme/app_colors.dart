import 'package:flutter/material.dart';

/// SafePath AI design-system color tokens.
///
/// This is the locked SafePath navy/safety-green design system (DESIGN-01,
/// rebranded 2026-08-14). Do NOT invent new colors here.
///
/// [sosRed] / [sosRedDeep] are reserved exclusively for SOS/emergency states
/// (and the single flagged "Remove from circle" exception documented below)
/// — never use them for routine warnings.
abstract final class AppColors {
  static const Color primaryNavy = Color(0xFF1B2A4A);

  /// Deep Teal — Welcome screen gradient hero background (end stop, deepest
  /// navy). The member name is a locked legacy label; only the value changed.
  static const Color deepTeal = Color(0xFF12203A);

  /// Welcome screen gradient hero background (start stop; [deepTeal] is the
  /// end stop) — deep accent green, so the hero reads green to navy.
  static const Color heroGradientStart = Color(0xFF0B7F66);

  /// Accent / safety green — CTA fills, focused-input borders, selected
  /// states, active-toggle and accent-icon token. Darkened from the raw spec
  /// value (`#00C896`) to `#00875F` for text/icon/CTA-label roles to clear
  /// WCAG AA 4.5:1 contrast on white while staying in the same green family.
  static const Color primaryTeal = Color(0xFF00875F);

  /// Safe green — positive/safe status indicators. Renders as small
  /// foreground text/icons on white, so it is a deeper accent-family green
  /// rather than the raw accent, holding on-white contrast parity.
  static const Color safe = Color(0xFF00A47B);
  static const Color safeBg = Color(0xFFE6F9F3);
  static const Color safeBgBorder = Color(0xFFBFF0E2);

  /// Caution amber — non-SOS attention/warning/validation-error states.
  static const Color caution = Color(0xFFC98A2B);

  /// SOS Red — reserved exclusively for SOS/emergency states.
  static const Color sosRed = Color(0xFFE53935);

  /// SOS Red (deep variant) — the single flagged exception: "Remove from
  /// circle" destructive action text/icon only.
  static const Color sosRedDeep = Color(0xFFC62828);

  /// Default app background (dominant, 60%).
  static const Color appBg = Color(0xFFF5F7FA);
  static const Color primaryTintBg = Color(0xFFE6F7F2);
  static const Color navyTintBg = Color(0xFFE8ECF4);
  static const Color hairline = Color(0xFFDCE3ED);
  static const Color hairlineSoft = Color(0xFFEDF1F7);

  /// Ink — primary body/heading text color.
  static const Color ink = Color(0xFF1B2A4A);

  /// Surface — cards, input fields, panels (secondary, 30%).
  static const Color surface = Color(0xFFFFFFFF);

  /// Accent Mint — light accent tint: the Welcome CTA fill on the dark hero
  /// gradient, and the splash-mark halo, where the full-strength accent has
  /// too little separation from the gradient.
  static const Color accentMint = Color(0xFF6FE3C0);

  /// Secondary body text color (subtitles, helper text).
  static const Color bodySecondary = Color(0xFF6B7A99);
  static const Color toggleOffTrack = Color(0xFFD5DCE8);
  static const Color memberViolet = Color(0xFF6E66C9);
  static const Color memberPink = Color(0xFFC95E8F);

  // Form validation / error-state tokens (defined by extension, not in the
  // hifi mockup — see 01-UI-SPEC.md "Form validation / error states").
  static const Color cautionBg = Color(0xFFFBF3E3);
  static const Color cautionBorder = Color(0xFFEFDFBF);
  static const Color cautionText = Color(0xFF8A6118);
}
