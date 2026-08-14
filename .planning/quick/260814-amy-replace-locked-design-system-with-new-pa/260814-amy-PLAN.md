---
phase: quick-260814-amy
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - mobile/lib/core/theme/app_colors.dart
  - mobile/lib/core/theme/app_typography.dart
  - mobile/lib/core/theme/app_spacing.dart
  - mobile/lib/core/theme/app_theme.dart
  - mobile/pubspec.yaml
  - mobile/test/theme_test.dart
  - .claude/CLAUDE.md
  - .planning/PROJECT.md
autonomous: false
requirements: [DESIGN-01]

must_haves:
  truths:
    - Every existing screen renders in the new palette with zero per-screen edits, because only token values changed.
    - All app text renders in the Inter family; no second/mono family remains in the type scale.
    - Cards render at 16px radius, buttons at 12px, modal bottom sheets at 24px, sourced from named radius tokens.
    - SOS red is the new danger hex and still appears only on emergency/SOS surfaces (plus the one pre-existing flagged destructive-action exception).
    - "flutter analyze reports no issues and the full mobile test suite passes."
    - .claude/CLAUDE.md and .planning/PROJECT.md describe the new palette/type/radii as the now-locked design system.
  artifacts:
    - mobile/lib/core/theme/app_colors.dart with every existing member name preserved and new hex values.
    - mobile/lib/core/theme/app_typography.dart with all ten type roles on a single family.
    - mobile/lib/core/theme/app_spacing.dart exposing AppRadius.card / AppRadius.button / AppRadius.bottomSheet.
    - mobile/lib/core/theme/app_theme.dart consuming AppRadius and declaring a bottomSheetTheme shape.
    - mobile/test/theme_test.dart asserting the new hex values and the new font family.
  key_links:
    - AppColors member names -> ~250 call sites in mobile/lib (any rename breaks compilation).
    - AppTypography.textTheme -> buildSafePathTheme() -> MaterialApp -> every screen.
    - AppRadius -> app_theme.dart cardTheme / elevatedButtonTheme / outlinedButtonTheme / bottomSheetTheme.
    - test/theme_test.dart literal assertions -> app_colors.dart + app_typography.dart values.
---

<objective>
Replace the locked SafePath AI visual design system (color palette + type family) with the
user-specified navy/safety-green palette and a single Inter type family, centralize the new
border-radius scale, and re-document the result as the now-locked system in `.claude/CLAUDE.md`
and `.planning/PROJECT.md`.

Purpose: The user explicitly chose a full rebrand, superseding the previous "fixed, not to be
redesigned" design-fidelity constraint. Because every screen already reads `AppColors.*` /
`AppTypography.*` tokens, changing token *values* re-themes the whole app with no screen edits.

Output: Re-themed app, green analyzer + full mobile test suite, updated design-fidelity
constraint in both doc locations.
</objective>

<execution_context>
@$HOME/.claude/gsd-core/workflows/execute-plan.md
@$HOME/.claude/gsd-core/templates/summary.md
</execution_context>

<context>
@.planning/STATE.md
@mobile/lib/core/theme/app_colors.dart
@mobile/lib/core/theme/app_typography.dart
@mobile/lib/core/theme/app_theme.dart
@mobile/lib/core/theme/app_spacing.dart
@mobile/test/theme_test.dart
</context>

<discovery_findings>
Verified during planning — do not re-derive:

- **No orphaned tokens.** Every `AppColors` member has at least one reference in
  `mobile/lib` / `mobile/test` (lowest: `toggleOffTrack` = 1). Nothing may be deleted; every
  member name stays.
- **Fonts load via the `google_fonts` package** (`google_fonts: ^8.1.0`, resolved 8.1.0), not
  bundled assets — `mobile/pubspec.yaml` has no active `fonts:` block (only the commented Flutter
  template example). `GoogleFonts.inter(...)` exists in the resolved 8.1.0 package
  (`lib/src/google_fonts_parts/part_i.dart:4561`) with weights w100-w900 and returns a
  `fontFamily` string containing `Inter`. Same loading mechanism, zero dependency change.
- **No central radius/shadow/elevation constants exist.** `app_spacing.dart` is spacing-only. All
  radii are inline `BorderRadius.circular(16)` calls inside `app_theme.dart`. There is no
  `bottomSheetTheme` today.
- **Only one test file hard-codes design values:** `mobile/test/theme_test.dart` (7 ARGB literals
  at lines 84-92, font-family assertions at lines 95-103). No golden / `.png` files exist anywhere
  under `mobile/test`. No test asserts any border radius. 68 test files total; the other 67
  reference tokens symbolically and auto-follow.
- **`GoogleFonts.` appears in `mobile/lib` only inside `app_typography.dart`** — the type scale is
  the single font entry point for the whole app.
- **Non-token color literals in `mobile/lib`:** two inline input-border literals inside
  `app_theme.dart` (in scope — replaced by a token in Task 2); Google brand hues in
  `shared_widgets/google_sign_in_button.dart` and brand-mark hues in
  `shared_widgets/safepath_logo.dart` (both out of scope — see `<out_of_scope>`).
- **13 `BoxShadow` sites, all in feature/shared widget files** (none in `core/theme`). This task
  adds none, so "shadows stay subtle" is verified as an unchanged count.
- **The design-fidelity bullet exists in two places** and is worded identically in both:
  `.claude/CLAUDE.md:29-32` and `.planning/PROJECT.md:83-86`. CLAUDE.md's Constraints section is
  generated from PROJECT.md, so editing only CLAUDE.md would be reverted on the next
  regeneration — both must change.
</discovery_findings>

<!-- planner-discipline-allow: manrope -->
<!-- planner-discipline-allow: jetbrains -->

<tasks>

<task type="auto">
  <name>Task 1: Swap the color palette in app_colors.dart</name>
  <files>mobile/lib/core/theme/app_colors.dart</files>
  <action>
Change only the `Color(0x...)` value of each member listed below. Do not rename, delete, reorder
or add members — every name is referenced across roughly 250 call sites in `mobile/lib`.

| Member | New value | Role in the new system |
|--------|-----------|------------------------|
| `primaryNavy` | `0xFF1B2A4A` | Spec: primary / navy |
| `ink` | `0xFF1B2A4A` | Spec: text primary |
| `bodySecondary` | `0xFF6B7A99` | Spec: text secondary |
| `appBg` | `0xFFF5F7FA` | Spec: background |
| `surface` | `0xFFFFFFFF` | Spec: surface — value is already correct, leave it as is |
| `primaryTeal` | `0xFF00C896` | Spec: accent / safety green. This is the app's CTA-fill, selected-state, active-toggle and accent-icon token. |
| `sosRed` | `0xFFE53935` | Spec: danger / SOS red. The reservation rule is unchanged — emergency/SOS surfaces only. |
| `sosRedDeep` | `0xFFC62828` | Darker companion of the SOS red, for the single flagged destructive-action exception already documented in this file. |
| `safe` | `0xFF00A47B` | Positive / "online" status. It renders as small foreground text and icons on white, so it is a deeper accent-family green rather than the raw accent; this holds its on-white contrast at parity with the value it replaces. |
| `safeBg` | `0xFFE6F9F3` | Accent-tinted success fill |
| `safeBgBorder` | `0xFFBFF0E2` | Accent-tinted success border |
| `deepTeal` | `0xFF12203A` | Welcome-hero gradient END stop — deepest navy. The member name is a locked legacy label; only the value changes. |
| `heroGradientStart` | `0xFF0B7F66` | Welcome-hero gradient START stop — deep accent green, so the hero reads green to navy. |
| `accentMint` | `0xFF6FE3C0` | Light accent tint: the Welcome CTA fill on the dark hero and the splash-mark halo, where the full-strength accent has too little separation from the gradient. |
| `primaryTintBg` | `0xFFE6F7F2` | Accent-tinted panel background |
| `navyTintBg` | `0xFFE8ECF4` | Navy-tinted panel background |
| `hairline` | `0xFFDCE3ED` | Neutral navy-grey divider |
| `hairlineSoft` | `0xFFEDF1F7` | Softest divider |
| `toggleOffTrack` | `0xFFD5DCE8` | Neutral off-state switch track |

Leave these members at their current values, deliberately: `caution`, `cautionBg`,
`cautionBorder`, `cautionText` (the amber warning family is hue-independent of the brand swap and
stays harmonious with navy/green/red — the new spec names no warning color) and `memberViolet`,
`memberPink` (per-member identity hues, deliberately outside the brand ramp so two family members
never read as the same person).

Also rewrite the file's doc comments so they describe the current system only: the header block
should state that this is the locked SafePath palette and that the SOS tokens stay reserved
exclusively for emergency/SOS surfaces. Comments must not record superseded hex values or the
previous palette's color names anywhere in the file.
  </action>
  <verify>
    <automated>cd mobile; test "$(grep -vE '^\s*(///|//)' lib/core/theme/app_colors.dart | grep -cE '0xFF1F3B57|0xFF2E7D7B|0xFFDE3B40|0xFFC42A30|0xFFF4F8FA|0xFF14283A|0xFF52697A|0xFF132B43|0xFF79D6C9|0xFF2F9E6B')" = "0" &amp;&amp; test "$(grep -cE '0xFF1B2A4A|0xFF00C896|0xFFE53935|0xFFF5F7FA|0xFF6B7A99' lib/core/theme/app_colors.dart)" -ge 6 &amp;&amp; test "$(grep -cE '^\s+static const Color ' lib/core/theme/app_colors.dart)" = "25" &amp;&amp; flutter analyze lib/core/theme/app_colors.dart &amp;&amp; echo PASS-task1</automated>
  </verify>
  <done>All 25 `AppColors` members still exist with their original names; the listed members carry the new hex values; no legacy palette hex survives anywhere in the file, including its comments; `flutter analyze` is clean for the file.</done>
</task>

<task type="auto">
  <name>Task 2: Move the type scale to Inter and centralize the radius scale</name>
  <files>mobile/lib/core/theme/app_typography.dart, mobile/lib/core/theme/app_spacing.dart, mobile/lib/core/theme/app_theme.dart, mobile/pubspec.yaml</files>
  <action>
**app_typography.dart** — replace every `GoogleFonts.<family>(` factory call in the file with
`GoogleFonts.inter(` (there are 10 call sites: `display`, `heading`, `title`, `body`,
`bodySecondary`, `statValue`, `ctaLabel`, `caption`, `code`, `countdownLarge`). Change nothing
else about any role: preserve each `fontSize`, `fontWeight`, `height`, `letterSpacing`, `color`
and `fontFeatures` argument exactly as written, and keep `textTheme`'s role mapping identical.
Keep `FontFeature.tabularFigures()` on `countdownLarge` — Inter ships `tnum`, and the countdown's
non-shifting width is a correctness requirement during an emergency, not a refinement.

Rewrite the class-level doc comment and any per-member comment that names a font family so they
describe the single Inter family only; do not record the superseded family names anywhere in the
file. Call sites elsewhere in the app must not change — they consume `AppTypography.*` roles.

**app_spacing.dart** — append a second token class in the same file (keep `AppSpacing` untouched):

`abstract final class AppRadius` with `static const double card = 16;`,
`static const double button = 12;`, `static const double bottomSheet = 24;`, each with a one-line
doc comment naming its surface.

**app_theme.dart** — import `app_spacing.dart` and replace the inline radius literals:
`cardTheme` and all five `inputDecorationTheme` borders use `AppRadius.card` (value unchanged at
16); `elevatedButtonTheme` and `outlinedButtonTheme` shapes use `AppRadius.button` (this is the
real change: 16 to 12). Add a `bottomSheetTheme: BottomSheetThemeData(...)` carrying a
`RoundedRectangleBorder` with `BorderRadius.vertical(top: Radius.circular(AppRadius.bottomSheet))`
and no other properties — shape only, so the two existing `showModalBottomSheet` call sites keep
their current surface treatment. Replace the two inline `Color(0xFFD7E0DE)` input-border literals
with `AppColors.hairline` so no color outside the token file survives in the theme.

Do not add any `BoxShadow`, `elevation`, `shadowColor` or `surfaceTintColor` anywhere: the system
stays flat/subtle, and the 13 existing shadow sites in feature files are out of scope.

**pubspec.yaml** — update the one comment line above the `google_fonts` dependency so it names the
current single design-system font. The dependency itself does not change.
  </action>
  <verify>
    <automated>cd mobile; test "$(grep -c 'GoogleFonts.inter(' lib/core/theme/app_typography.dart)" = "10" &amp;&amp; test "$(grep -riE 'manrope|jetbrains' lib/core/theme pubspec.yaml | wc -l)" = "0" &amp;&amp; test "$(grep -c 'tabularFigures' lib/core/theme/app_typography.dart)" = "1" &amp;&amp; grep -q 'class AppRadius' lib/core/theme/app_spacing.dart &amp;&amp; grep -q 'AppRadius.button' lib/core/theme/app_theme.dart &amp;&amp; grep -q 'bottomSheetTheme' lib/core/theme/app_theme.dart &amp;&amp; test "$(grep -cE '0xFF[0-9A-Fa-f]{6}' lib/core/theme/app_theme.dart)" = "0" &amp;&amp; test "$(grep -rn 'BoxShadow' lib | wc -l)" = "13" &amp;&amp; flutter analyze &amp;&amp; echo PASS-task2</automated>
  </verify>
  <done>All ten type roles resolve through `GoogleFonts.inter`; the tabular-figures countdown feature survives; `AppRadius` exists and drives card/button/bottom-sheet shapes in the theme; no raw color literal remains in `app_theme.dart`; the app-wide `BoxShadow` count is still 13; `flutter analyze` reports no issues.</done>
</task>

<task type="auto">
  <name>Task 3: Update the design-token assertions and prove the full suite is green</name>
  <files>mobile/test/theme_test.dart</files>
  <action>
`theme_test.dart` is the only test in the package that hard-codes design values (verified during
planning: 7 ARGB literals, plus two font-family assertions; no goldens exist, no test asserts a
radius). Update it to assert the new system:

- The three `theme.*` assertions: `colorScheme.primary` and `colorScheme.secondary` and
  `scaffoldBackgroundColor` must expect the new navy, accent and background values from Task 1.
- The four `AppColors.*` assertions: `sosRed`, `primaryNavy`, `primaryTeal`, `appBg` must expect
  their new Task 1 values. Keep the comment that records why the SOS token is asserted here
  (reserved for emergency states).
- The font test: both `headlineMedium` and `labelSmall` now resolve to the same family, so update
  the `testWidgets` description and both `expect(...contains(...))` assertions to check for
  `Inter`. Do not delete the test — it is the regression guard proving the whole `textTheme` is on
  one family.
- Leave the third test (`SafePathApp builds and shows the themed placeholder route`) untouched.

Then run the analyzer and the FULL package test suite. If any other test fails on a color or font
expectation, fix that test's assertion to the new token value — never revert a token to make a
test pass. If a failure is unrelated to this change, confirm it is pre-existing by re-running that
single test against `git stash`ed changes, and record it in the summary with the evidence rather
than fixing it here.
  </action>
  <verify>
    <automated>cd mobile; flutter analyze &amp;&amp; flutter test &amp;&amp; test "$(grep -c 'Inter' test/theme_test.dart)" -ge 2 &amp;&amp; test "$(grep -cE '0xFF1F3B57|0xFF2E7D7B|0xFFF4F8FA|0xFFDE3B40' test/theme_test.dart)" = "0" &amp;&amp; echo PASS-task3</automated>
  </verify>
  <done>`flutter analyze` reports no issues; `flutter test` passes for all 68 test files with no skips introduced; `theme_test.dart` asserts the new hex values and the Inter family; no legacy palette hex remains in the test directory.</done>
</task>

<task type="auto">
  <name>Task 4: Re-document the now-locked design system</name>
  <files>.claude/CLAUDE.md, .planning/PROJECT.md</files>
  <action>
Both files carry an identical `- **Design fidelity**:` bullet under their Constraints heading
(`.claude/CLAUDE.md:29-32`, `.planning/PROJECT.md:83-86`). CLAUDE.md's Constraints section is
generated from PROJECT.md, so update BOTH or the change is reverted on the next regeneration.

Use `Edit` with a scoped replacement of just that bullet in each file — never `Write` either file.
Note the surrounding formatting differs: CLAUDE.md separates bullets with blank lines, PROJECT.md
does not. Preserve each file's existing bullet spacing and roughly 100-character wrap.

Replace the bullet with text that keeps the original framing (locked, "fixed, not to be
redesigned", SOS red reserved exclusively for emergency/SOS) while stating the new concrete
values:

- It must say the UI is implemented via Flutter widgets / `ThemeData` against the locked SafePath
  design system, and note that this system supersedes the original 36-screen mockup palette and
  type pairing (rebranded 2026-08-14).
- It must name Material 3 with the Inter type family as the single font.
- It must list the palette: navy `#1B2A4A` (primary and primary text), safety green `#00C896`
  (accent), `#E53935` (danger / SOS red, reserved exclusively for emergency/SOS surfaces),
  `#F5F7FA` (background), `#FFFFFF` (surface), `#6B7A99` (secondary text).
- It must list radii 16px cards / 12px buttons / 24px bottom sheets, and "subtle shadows only".
- It must close with the fixed / not-to-be-redesigned framing.

Do not touch any other bullet, and do not edit the historical `*-UI-SPEC.md` phase documents —
those are dated records of what was true at the time.
  </action>
  <verify>
    <automated>test "$(grep -ciE 'manrope|jetbrains' .claude/CLAUDE.md .planning/PROJECT.md | grep -c ':0$')" = "2" &amp;&amp; grep -q '1B2A4A' .claude/CLAUDE.md &amp;&amp; grep -q '1B2A4A' .planning/PROJECT.md &amp;&amp; grep -q 'E53935' .claude/CLAUDE.md &amp;&amp; grep -q 'E53935' .planning/PROJECT.md &amp;&amp; grep -q 'Inter' .claude/CLAUDE.md &amp;&amp; grep -q 'Inter' .planning/PROJECT.md &amp;&amp; test "$(grep -c 'Design fidelity' .claude/CLAUDE.md)" = "1" &amp;&amp; echo PASS-task4</automated>
  </verify>
  <done>Both files' Design fidelity bullets describe the new palette, Inter, and the radius scale as locked; the SOS-red reservation and "not to be redesigned" framing survive verbatim in intent; no legacy font name remains in either file; no other bullet changed.</done>
</task>

<task type="checkpoint:human-verify" gate="blocking">
  <name>Task 5: Human verification of the rebranded theme</name>
  <files>none (verification only)</files>
  <action>Pause execution and hand off to the developer using the checkpoint content below. Do not
  auto-approve and do not continue past this task without an explicit reply — step 5 asks for a
  design decision that only the developer can make.</action>
  <what-built>
The whole app re-themed from token values only: new navy/safety-green/red palette in
`app_colors.dart`, single Inter type scale in `app_typography.dart`, a new `AppRadius` scale
(16 card / 12 button / 24 bottom sheet) wired through `app_theme.dart`, and the design-fidelity
constraint re-documented in `.claude/CLAUDE.md` and `.planning/PROJECT.md`. No screen file, SOS
pipeline file, or geofencing file was touched. `flutter analyze` and the full 68-file test suite
are green.
  </what-built>
  <how-to-verify>
1. `cd mobile && flutter run` on your usual device/emulator.
2. Walk: Welcome (hero gradient + mint CTA) -> Login/Register -> Live Map (member pins, online
   status chips, bottom nav) -> Safe Zones list/add/review -> SOS arm button and countdown
   -> Profile -> Privacy Center. Confirm every surface picked up the new palette and that all
   text renders in Inter.
3. Confirm button corners now read tighter than card corners, and that any bottom sheet you can
   open has a 24px top radius.
4. Confirm SOS red appears ONLY on the SOS/emergency surfaces (arm button, responder screen,
   delivery-failure states) and on the one pre-existing "Remove from circle" destructive action —
   nowhere else.
5. **Judge one deliberate trade-off and decide.** The accent token `primaryTeal` now carries the
   spec's `#00C896` verbatim. That value was applied as specified rather than adjusted, but it is
   a measured legibility regression where the accent is used as foreground on white: contrast
   drops from about 4.85:1 (the value it replaces, WCAG AA pass) to about 2.17:1 (fails both the
   4.5:1 text and 3:1 non-text-graphic thresholds). Affected surfaces are accent-colored icons,
   text buttons, outlined-button labels/borders, and the selected bottom-nav item. Accent used as
   a FILL (map pins, active toggles, avatar backgrounds) is unaffected in the same way. Look at
   those surfaces and reply with one of: `keep #00C896 as-is`, or `darken the accent to <hex>`
   (about `#00875F` restores 4.5:1), or `follow-up task` to log it and ship as-is.
6. Flag anything that reads off-brand or unreadable, naming the screen.
  </how-to-verify>
  <resume-signal>Type "approved" plus your answer to step 5, or describe the issues.</resume-signal>
  <verify>
    <human-check>Developer confirms every walked screen picked up the new palette and Inter type,
    SOS red is confined to emergency surfaces, and records an explicit decision on the accent
    contrast trade-off.</human-check>
  </verify>
  <done>Developer replied "approved" with a step-5 decision, or listed issues to fix before the
  task can close.</done>
</task>

</tasks>

<out_of_scope>
Explicitly NOT part of this task — do not touch, but note in the summary as candidate follow-ups:

- **Any screen/feature file.** Token value changes re-theme every screen automatically. Per-screen
  structural work from the broader UI spec (bottom sheets, hold-to-activate SOS animation,
  skeleton loaders, dark mode, floating bottom nav) is deferred to separate quick tasks.
- **`mobile/lib/shared_widgets/safepath_logo.dart`** — the brand mark still paints its own five
  hardcoded teal/mint hues and will visually diverge from the new navy/green palette. The user did
  not ask for a logo redesign; flag it, do not change it.
- **`mobile/lib/shared_widgets/google_sign_in_button.dart`** — the four Google brand hues are
  mandated by Google's branding guidelines and must never be re-themed.
- **The 13 `BoxShadow` sites in feature/shared widgets** — verified subtle today; this task adds
  no shadows and changes no shadow.
- **Historical `.planning/phases/**/**-UI-SPEC.md` documents** — dated records, left as-is.
- **SOS pipeline, geofencing, and any non-visual code.**
</out_of_scope>

<verification>
1. `cd mobile && flutter analyze` — no issues.
2. `cd mobile && flutter test` — all 68 test files pass.
3. No `AppColors` or `AppTypography` member was renamed or removed:
   `cd mobile && test "$(grep -cE '^\s+static const Color ' lib/core/theme/app_colors.dart)" = "25"`
   and `git diff -- lib/core/theme/app_colors.dart lib/core/theme/app_typography.dart` shows only
   value/comment lines changed, no signature lines removed.
4. No screen file was modified: `git diff --name-only` lists only the eight files in
   `files_modified`.
5. Legacy palette hex values and the superseded font names appear nowhere in `mobile/lib`,
   `mobile/test`, `mobile/pubspec.yaml`, `.claude/CLAUDE.md`, or `.planning/PROJECT.md`.
</verification>

<success_criteria>
- Every listed `AppColors` member carries its new value; all 25 member names survive; no token was
  deleted (planning confirmed zero orphans, so nothing needed flagging for removal).
- All ten `AppTypography` roles render in Inter through the existing `google_fonts` mechanism, with
  every size/weight/height/letterSpacing/fontFeature preserved.
- `AppRadius.card` = 16, `AppRadius.button` = 12, `AppRadius.bottomSheet` = 24 exist and are the
  source of those radii in `app_theme.dart`; no shadow or elevation was added.
- `flutter analyze` clean and the full mobile test suite green, with `theme_test.dart` asserting
  the new values.
- The Design fidelity constraint in `.claude/CLAUDE.md` AND `.planning/PROJECT.md` documents the
  new palette/type/radii as locked, retaining the SOS-red reservation and the
  not-to-be-redesigned framing.
- The human-verify checkpoint is answered, including an explicit decision on the accent-contrast
  trade-off.
</success_criteria>

<output>
Create `.planning/quick/260814-amy-replace-locked-design-system-with-new-pa/260814-amy-SUMMARY.md` when done.

The summary must record: the full old-to-new token mapping table as executed, the deliberate
no-change decisions (amber warning family, member identity hues, Google brand hues, logo mark),
the accent-contrast trade-off and the user's checkpoint decision, and any pre-existing test
failure evidence.
</output>
