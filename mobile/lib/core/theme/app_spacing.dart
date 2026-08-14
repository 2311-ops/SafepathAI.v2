/// SafePath AI 4pt spacing scale, ported verbatim from `01-UI-SPEC.md`
/// (Spacing Scale section). Base unit is 4px.
abstract final class AppSpacing {
  /// 4px — icon-to-label gaps, tightest inline spacing.
  static const double xs = 4;

  /// 8px — compact element spacing (trust-chip icon gap, toggle row gaps).
  static const double sm = 8;

  /// 12px — card internal row gaps (e.g. permission-row icon-to-text gap).
  static const double xsMd = 12;

  /// 16px — default element spacing, field-to-field gaps, button padding.
  static const double md = 16;

  /// 24px — section padding, gap between heading and first control group.
  static const double lg = 24;

  /// 32px — larger layout gaps (used sparingly).
  static const double xl = 32;

  /// Default screen horizontal gutter (24px per UI-SPEC phase default).
  static const double screenGutter = 24;
}
