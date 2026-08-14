---
phase: quick-260814-amy
plan: 01
subsystem: ui
tags: [flutter, theming, design-tokens, google_fonts, inter, wcag]

# Dependency graph
requires: []
provides:
  - Navy/safety-green/red color palette replacing the original 36-screen mockup palette, applied via AppColors token values only
  - Single Inter type family across all ten AppTypography roles (previously Manrope + JetBrains Mono)
  - Centralized AppRadius token scale (card=16, button=12, bottomSheet=24) driving app_theme.dart
  - Re-documented Design fidelity constraint in .claude/CLAUDE.md and .planning/PROJECT.md
affects: [ui, design-system, any future phase touching theme tokens]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - AppRadius token class alongside AppSpacing in app_spacing.dart as the single source of truth for corner radii
    - bottomSheetTheme added to buildSafePathTheme() (previously absent)

key-files:
  created: []
  modified:
    - mobile/lib/core/theme/app_colors.dart
    - mobile/lib/core/theme/app_typography.dart
    - mobile/lib/core/theme/app_spacing.dart
    - mobile/lib/core/theme/app_theme.dart
    - mobile/pubspec.yaml
    - mobile/test/theme_test.dart
    - .claude/CLAUDE.md
    - .planning/PROJECT.md

key-decisions:
  - "Darkened primaryTeal (the sole accent token) from the raw spec value #00C896 to #00875F, per the user's pre-resolved checkpoint decision, to clear WCAG AA 4.5:1 text/icon contrast on white; fill-only accent uses (map pins, active toggles, avatar backgrounds) read as unaffected by this since primaryTeal is the app's shared accent token for both roles."
  - "All 25 AppColors member names preserved verbatim; only hex values and doc comments changed (zero renames, zero deletions, matching the ~250 call-site dependency)."
  - "On-device visual verification (Task 5's checkpoint) deferred to the user for a real device/emulator session — this executor has no attached device."

patterns-established:
  - "AppRadius (card/button/bottomSheet) token class: future radius changes go here, not as inline BorderRadius.circular() literals in app_theme.dart."

requirements-completed: [DESIGN-01]

coverage:
  - id: D1
    description: "AppColors palette swapped to navy/safety-green/red tokens; all 25 member names preserved"
    requirement: "DESIGN-01"
    verification:
      - kind: unit
        ref: "mobile/test/theme_test.dart#buildSafePathTheme exposes the exact SafePath color tokens"
        status: pass
      - kind: other
        ref: "flutter analyze lib/core/theme/app_colors.dart"
        status: pass
    human_judgment: false
  - id: D2
    description: "Type scale moved to a single Inter family across all ten AppTypography roles, tabularFigures preserved on countdownLarge"
    requirement: "DESIGN-01"
    verification:
      - kind: unit
        ref: "mobile/test/theme_test.dart#buildSafePathTheme uses Inter for the whole type scale"
        status: pass
      - kind: other
        ref: "flutter analyze (full mobile package)"
        status: pass
    human_judgment: false
  - id: D3
    description: "AppRadius token scale (16/12/24) added and wired through app_theme.dart card/button/bottomSheet shapes"
    requirement: "DESIGN-01"
    verification:
      - kind: other
        ref: "grep AppRadius.button/bottomSheetTheme in mobile/lib/core/theme/app_theme.dart; flutter analyze clean"
        status: pass
    human_judgment: false
  - id: D4
    description: "Design fidelity constraint re-documented as locked in .claude/CLAUDE.md and .planning/PROJECT.md"
    requirement: "DESIGN-01"
    verification:
      - kind: other
        ref: "grep for 1B2A4A/E53935/Inter in both files; git diff confirms only the Design fidelity bullet changed"
        status: pass
    human_judgment: false
  - id: D5
    description: "On-device visual walkthrough of the rebranded theme (Welcome, Login, Live Map, Safe Zones, SOS, Profile, Privacy Center) and confirmation SOS red stays confined to emergency surfaces"
    verification: []
    human_judgment: true
    rationale: "Requires a real device/emulator session; this executor has no attached device and cannot literally walk the app on-screen."

duration: multi-session (~5h22m wall clock; edits themselves were a single short session)
completed: 2026-08-14
status: complete
---

# Quick Task 260814-amy: Replace locked design system with new navy/safety-green palette Summary

**Re-themed the whole app via token-value changes only: navy/safety-green/red palette in AppColors, single Inter type family in AppTypography, a new centralized AppRadius scale (16/12/24) wired through app_theme.dart, and the Design fidelity constraint re-documented as the now-locked system in both `.claude/CLAUDE.md` and `.planning/PROJECT.md`.**

## Performance

- **Duration:** multi-session, ~5h22m wall clock (actual edit work was a short, continuous burst)
- **Started:** 2026-08-14T04:58:16Z
- **Completed:** 2026-08-14T10:20:08Z
- **Tasks:** 4 of 5 (Task 5 is a human-verify checkpoint; its design-decision portion was pre-resolved by the user, its device-walkthrough portion is deferred — see below)
- **Files modified:** 8

## Accomplishments

- Swapped every `AppColors` member's hex value to the new navy/safety-green/red palette while preserving all 25 member names (zero renames, zero deletions) — every existing screen re-themes automatically since screens consume `AppColors.*` tokens, not literals.
- Moved all ten `AppTypography` roles (display, heading, title, body, bodySecondary, statValue, ctaLabel, caption, code, countdownLarge) from Manrope/JetBrains Mono to a single `GoogleFonts.inter(...)` family, preserving every size/weight/height/letterSpacing/fontFeature argument, including `tabularFigures()` on the SOS countdown.
- Added a new `AppRadius` token class (`card = 16`, `button = 12`, `bottomSheet = 24`) in `app_spacing.dart` and wired it through `app_theme.dart`: cards and input borders stay at 16px, buttons tighten from 16px to 12px (the real visual change), and a new `bottomSheetTheme` gives modal bottom sheets a 24px top radius (previously unset). Replaced two inline `Color(0xFFD7E0DE)` input-border literals with `AppColors.hairline`.
- Updated `theme_test.dart`'s hard-coded assertions (the only test file with literal design values) to the new hex values and to check for `Inter` on both `headlineMedium` and `labelSmall`.
- Re-documented the identical "Design fidelity" bullet in both `.claude/CLAUDE.md` and `.planning/PROJECT.md` (CLAUDE.md's Constraints section regenerates from PROJECT.md, so both needed the edit) to describe Material 3 + Inter + the new palette + the 16/12/24 radius scale as the now-locked system, retaining the SOS-red-reserved-for-emergency framing and the "fixed, not to be redesigned" close.
- `flutter analyze`: no issues. `flutter test`: all 433 tests pass (full mobile suite, including the 3 renamed/updated `theme_test.dart` cases).

## Full Old-to-New Token Mapping (as executed)

| Member | Old value | New value | Note |
|--------|-----------|-----------|------|
| `primaryNavy` | `0xFF1F3B57` | `0xFF1B2A4A` | |
| `ink` | `0xFF14283A` | `0xFF1B2A4A` | |
| `bodySecondary` | `0xFF52697A` | `0xFF6B7A99` | |
| `appBg` | `0xFFF4F8FA` | `0xFFF5F7FA` | |
| `surface` | `0xFFFFFFFF` | `0xFFFFFFFF` | unchanged |
| `primaryTeal` | `0xFF2E7D7B` | `0xFF00875F` | **Darkened from raw spec `#00C896`** per resolved checkpoint decision (WCAG AA text/icon contrast) |
| `sosRed` | `0xFFDE3B40` | `0xFFE53935` | |
| `sosRedDeep` | `0xFFC42A30` | `0xFFC62828` | |
| `safe` | `0xFF2F9E6B` | `0xFF00A47B` | |
| `safeBg` | `0xFFEAF5EF` | `0xFFE6F9F3` | |
| `safeBgBorder` | `0xFFCDE9DA` | `0xFFBFF0E2` | |
| `deepTeal` | `0xFF132B43` | `0xFF12203A` | |
| `heroGradientStart` | `0xFF2E7D7B` | `0xFF0B7F66` | |
| `accentMint` | `0xFF79D6C9` | `0xFF6FE3C0` | |
| `primaryTintBg` | `0xFFE8F2F2` | `0xFFE6F7F2` | |
| `navyTintBg` | `0xFFEAF0F5` | `0xFFE8ECF4` | |
| `hairline` | `0xFFDDE8EE` | `0xFFDCE3ED` | |
| `hairlineSoft` | `0xFFF1F6F8` | `0xFFEDF1F7` | |
| `toggleOffTrack` | `0xFFDCE8EC` | `0xFFD5DCE8` | |

**Deliberate no-change decisions** (per plan, verified as still correct):
- `caution` / `cautionBg` / `cautionBorder` / `cautionText` (amber warning family) — hue-independent of the brand swap; new spec names no warning color.
- `memberViolet` / `memberPink` — per-member identity hues, deliberately outside the brand ramp.
- Google brand hues in `shared_widgets/google_sign_in_button.dart` — mandated by Google's branding guidelines, must never be re-themed.
- `shared_widgets/safepath_logo.dart` — the brand mark's five hardcoded teal/mint hues were not touched; it will now visually diverge from the new palette (flagged as a candidate follow-up, per plan).
- The 13 pre-existing `BoxShadow` sites in feature/shared widgets — count verified unchanged at 13; no shadows added or removed.

## Task Commits

Each task was committed atomically:

1. **Task 1: Swap the color palette in app_colors.dart** - `4e658e2` (feat)
2. **Task 2: Move the type scale to Inter and centralize the radius scale** - `ef4bc50` (feat)
3. **Task 3: Update the design-token assertions and prove the full suite is green** - `6340a4e` (test)
4. **Task 4: Re-document the now-locked design system** - `46e5267` (docs)

Task 5 (human-verify checkpoint) has no code commit — see "Accent-Contrast Trade-off & Checkpoint Resolution" and "Deferred: On-Device Visual Verification" below.

## Files Created/Modified

- `mobile/lib/core/theme/app_colors.dart` - All 25 color tokens updated to the new navy/safety-green/red palette; doc comments rewritten to describe only the current system
- `mobile/lib/core/theme/app_typography.dart` - All ten type roles switched from `GoogleFonts.manrope`/`GoogleFonts.jetBrainsMono` to `GoogleFonts.inter`
- `mobile/lib/core/theme/app_spacing.dart` - New `AppRadius` class added (card/button/bottomSheet), `AppSpacing` untouched
- `mobile/lib/core/theme/app_theme.dart` - Imports `app_spacing.dart`; card/input radii use `AppRadius.card`, button radii use `AppRadius.button` (16→12), new `bottomSheetTheme` added, two raw input-border color literals replaced with `AppColors.hairline`
- `mobile/pubspec.yaml` - Comment above `google_fonts` updated to name Inter (dependency itself unchanged)
- `mobile/test/theme_test.dart` - Color/font assertions updated to new values; font test renamed and asserts `Inter` on both text roles
- `.claude/CLAUDE.md` - Design fidelity bullet rewritten to document the new locked system
- `.planning/PROJECT.md` - Same Design fidelity bullet rewritten (kept in sync with CLAUDE.md)

## Decisions Made

- **Accent-contrast trade-off (Task 5, step 5 — pre-resolved by the user before this execution):** `primaryTeal`, the sole accent token used for both fill and text/icon/CTA-label roles, was darkened from the spec's literal `#00C896` to `#00875F`. This clears WCAG AA 4.5:1 text contrast on white for accent-colored icons, text buttons, outlined-button labels/borders, and the selected bottom-nav item, while staying in the same green family. Because `primaryTeal` is the single shared token for both fill and foreground-text uses in this codebase, the darkened value applies everywhere the token is used — fill uses (map pins, active toggles, avatar backgrounds) get the same darker green rather than a separate lighter fill-only value, since no such second token exists. This was applied directly in Task 1; no separate fill-only accent token was introduced (out of scope — would be an architectural addition, not part of this task).
- Documented the actual implemented accent value (`#00875F`) rather than the raw spec value (`#00C896`) in `.claude/CLAUDE.md`/`.planning/PROJECT.md`, with an inline note on why it was darkened — keeping the design-system doc accurate to what actually ships rather than restating a superseded spec number.
- Task 1's automated verify script (`grep -cE '0xFF1B2A4A|0xFF00C896|...' >= 6`) assumed the literal `#00C896` would appear for `primaryTeal`; since the resolved checkpoint decision overrides that specific value to `#00875F`, that one grep-based check reads as failing by count even though the darkened value is the intended, correct implementation. See "Deviations from Plan" below.

## Deviations from Plan

### Auto-fixed Issues

None — no bugs, missing critical functionality, or blocking issues were found during Tasks 1-4; all four ran as planned.

### Plan-Instruction Override (per pre-resolved checkpoint decision, not a Rule 1-4 deviation)

**1. `primaryTeal` darkened to `#00875F` instead of the plan's literal `#00C896`**
- **Found during:** Task 1 (color palette swap)
- **Reason:** The orchestrator supplied an already-resolved checkpoint decision (normally Task 5, step 5) instructing this specific override before execution began, to fix a WCAG AA contrast regression (raw `#00C896` on white: ~2.17:1, fails both 4.5:1 text and 3:1 non-text thresholds; `#00875F` restores ~4.5:1+).
- **Effect on Task 1's automated verify script:** The script's hex-count check (`grep -cE '...0xFF00C896...' -ge 6`) now counts 5 instead of 6, since `primaryTeal` no longer contains the literal `0xFF00C896`. All other Task 1 checks (25 members present, no legacy hex, `flutter analyze` clean) pass. This is an expected, intentional divergence from the plan's stale-by-design verify script, not a bug.
- **Files modified:** `mobile/lib/core/theme/app_colors.dart`
- **Committed in:** `4e658e2` (Task 1 commit)

**Total deviations:** 0 auto-fixed; 1 pre-authorized plan-instruction override (accent-contrast darkening) applied per the checkpoint decision supplied ahead of execution.
**Impact on plan:** No scope creep — the override was scoped exactly to the single token/value the resolved decision named; every other token mapping executed exactly as the plan specified.

## Issues Encountered

- Two residual literal `Manrope` references were found outside the eight in-scope files, both in explicitly out-of-scope screen/widget files (per the plan's `<out_of_scope>` list: "Any screen/feature file"):
  - `mobile/lib/features/location/presentation/live_map_screen.dart:927` — a stale code **comment** only ("Manrope (not the mono `caption` role...)"); the actual style on that line already uses `AppTypography.title.copyWith(...)`, so it renders in Inter today. No functional effect.
  - `mobile/lib/shared_widgets/animated_safepath_mark.dart:76` — a hardcoded `TextStyle(fontFamily: 'Manrope', ...)` used only as the `wordmarkStyle` parameter's **default fallback** value. Both actual call sites (`SplashScreen` and `StartupSplashOverlay` in `app.dart`) explicitly pass `wordmarkStyle: AppTypography.display.copyWith(...)`, so this literal is unreachable dead code today — the splash wordmark already renders in Inter in practice.
  - Neither was fixed (plan explicitly marks screen/widget files out of scope for this task, deferred to a follow-up quick task per the plan's own instruction). Flagging here as required by that instruction, since it means the plan's own overall-verification claim #5 ("Legacy palette hex values and the superseded font names appear nowhere in mobile/lib...") is not literally 100% true — both hits are inert (comment / unreachable default), so no screen actually renders off-brand, but a future cleanup pass should either delete the stale comment and the dead default value, or make `animated_safepath_mark.dart` require its `wordmarkStyle` parameter.

## Accent-Contrast Trade-off & Checkpoint Resolution

Task 5 (human-verify checkpoint) asked the developer to judge the `primaryTeal` accent-contrast trade-off and choose one of: keep `#00C896` as-is, darken to a specific hex, or defer as a follow-up task. **This decision was already made by the user before this execution began** (relayed via the orchestrator, not re-asked): darken the accent to approximately `#00875F` for text/icon/CTA-label uses of the accent token. This was applied in Task 1 (see "Full Old-to-New Token Mapping" and "Decisions Made" above) — `primaryTeal` now carries `#00875F` throughout the codebase, including its fill uses, since it is the single shared accent token.

## Deferred: On-Device Visual Verification

The remainder of Task 5's checklist — walking Welcome → Login/Register → Live Map → Safe Zones → SOS → Profile → Privacy Center on a real device/emulator to confirm every surface picked up the new palette, that Inter renders everywhere, that button corners read tighter than card corners, that bottom sheets show a 24px top radius, and that SOS red appears only on emergency surfaces plus the one flagged destructive-action exception — **requires a physical device or emulator session and is deferred to the user**, consistent with how this project already handles physical-device verification elsewhere (see `.planning/STATE.md` "Blockers/Concerns" — e.g. the 04-05/04-17 physical geofencing acceptance evidence). This executor is a non-interactive background agent with no attached device.

All automatable portions of Task 5 are closed: the design decision is resolved and applied, `flutter analyze` is clean, and the full 433-test mobile suite passes.

## Next Phase Readiness

- The rebranded theme is source-complete and green on all automated gates (analyzer + full test suite). No screen file, SOS pipeline file, or geofencing file was touched — token value changes alone re-themed every screen.
- Follow-up candidates flagged but not actioned (per plan's out-of-scope list): `safepath_logo.dart` brand-mark redesign to match the new palette; cleanup of the two inert stale-Manrope residues noted above; the broader UI-spec structural work (bottom sheets content, hold-to-activate SOS animation, skeleton loaders, dark mode, floating bottom nav) already tracked separately.
- Recommend the user perform the deferred on-device visual walkthrough (Task 5) at their next device/emulator session and report back any off-brand or unreadable surfaces by screen name.

---
*Phase: quick-260814-amy*
*Completed: 2026-08-14*

## Self-Check: PASSED

All 8 modified files and the SUMMARY.md itself confirmed present on disk; all 4 task commit hashes (`4e658e2`, `ef4bc50`, `6340a4e`, `46e5267`) confirmed present in `git log --oneline --all`.
