import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// SafePath AI type scale — Manrope (primary UI) + JetBrains Mono (labels,
/// codes, captions). Ported verbatim from `01-UI-SPEC.md` (Typography
/// section). This system deliberately uses more than the generic "2 weight"
/// default (500/600/700/800 Manrope + 600/800 mono) — required by DESIGN-01
/// exact-recreation fidelity, not a gap to "fix."
abstract final class AppTypography {
  /// 38px/800 — Welcome screen wordmark only.
  static TextStyle get display => GoogleFonts.manrope(
        fontSize: 38,
        fontWeight: FontWeight.w800,
        height: 1.05,
        letterSpacing: -0.025 * 38,
        color: AppColors.ink,
      );

  /// 28px/800 — screen-level headlines.
  static TextStyle get heading => GoogleFonts.manrope(
        fontSize: 28,
        fontWeight: FontWeight.w800,
        height: 1.2,
        letterSpacing: -0.02 * 28,
        color: AppColors.ink,
      );

  /// 17px/700 — header bar titles, role-card titles, member-row names.
  static TextStyle get title => GoogleFonts.manrope(
        fontSize: 17,
        fontWeight: FontWeight.w700,
        height: 1.2,
        color: AppColors.ink,
      );

  /// 15px/600 — button labels (base weight; primary CTA uses 700 via
  /// [ctaLabel]), input field text, permission-row labels.
  static TextStyle get body => GoogleFonts.manrope(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        height: 1.4,
        color: AppColors.ink,
      );

  /// 13px/500 — subtitles, helper/reassurance text, role-card descriptions.
  static TextStyle get bodySecondary => GoogleFonts.manrope(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        height: 1.4,
        color: AppColors.bodySecondary,
      );

  /// Primary CTA button label — 700 weight/16px per UI-SPEC ("Primary CTA
  /// buttons specifically render at 700 weight, 16px").
  static TextStyle get ctaLabel => GoogleFonts.manrope(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        height: 1.2,
      );

  /// 12px/600 JetBrains Mono, uppercase, letter-spaced — field labels, step
  /// indicators, status badges.
  static TextStyle get caption => GoogleFonts.jetBrainsMono(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        height: 1.3,
        letterSpacing: 0.06 * 12,
        color: const Color(0xFF8A9893),
      );

  /// 24px/800 JetBrains Mono — the invite share code display only.
  static TextStyle get code => GoogleFonts.jetBrainsMono(
        fontSize: 24,
        fontWeight: FontWeight.w800,
        height: 1.0,
        letterSpacing: 0.18 * 24,
        color: AppColors.ink,
      );

  /// Full [TextTheme] assembled from the roles above, for [ThemeData].
  static TextTheme get textTheme => TextTheme(
        displayLarge: display,
        headlineMedium: heading,
        titleMedium: title,
        bodyLarge: body,
        bodyMedium: bodySecondary,
        labelSmall: caption,
      );
}
