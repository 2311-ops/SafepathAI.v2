---
phase: quick-260820-3tj
plan: 01
subsystem: ui
tags: [flutter, flutter_svg, illustrations, welcome-screen, family-circle, geofencing]

requires: []
provides:
  - flutter_svg 2.3.0 as the app's SVG-rendering dependency
  - Three bundled decorative illustrations (hero-safety, family-connect, safe-zone-empty)
  - Illustration wiring on WelcomeScreen, CreateCircleScreen, InviteMemberScreen (empty state), SafeZonesScreen (empty state)
affects: [ui-polish, geofencing]

tech-stack:
  added: [flutter_svg ^2.3.0]
  patterns:
    - "Decorative-only SvgPicture.asset usage (no semanticsLabel, stays out of a11y tree)"
    - "_StateMessage widened with an optional illustration slot alongside an now-optional icon (assert(icon != null || illustration != null))"

key-files:
  created:
    - mobile/assets/illustrations/hero-safety.svg
    - mobile/assets/illustrations/family-connect.svg
    - mobile/assets/illustrations/safe-zone-empty.svg
  modified:
    - mobile/pubspec.yaml
    - mobile/lib/features/auth/presentation/welcome_screen.dart
    - mobile/lib/features/family/presentation/create_circle_screen.dart
    - mobile/lib/features/family/presentation/invite_member_screen.dart
    - mobile/lib/features/geofencing/presentation/safe_zones_screen.dart

key-decisions:
  - "No pre-supplied SVG markup existed anywhere in the repo or plan file despite the plan calling them 'already-approved, already-designed' — authored three original flat-vector illustrations myself, using only the app's locked AppColors tokens (DESIGN-01), matching the exact viewBox dimensions the plan's must_haves.artifacts required"
  - "SafeZonesScreen's Task 4 commit also carries one pre-existing, unrelated uncommitted hunk (SafeZonesScreen.error's onAdd parameter) from a separate in-progress debug session, because sibling uncommitted files (safe_zones_page.dart) already depend on it and isolating it broke compilation"

patterns-established:
  - "Illustration assets live under mobile/assets/illustrations/, registered as a directory in pubspec.yaml flutter:assets:"

requirements-completed: [QUICK-SVG-ILLUSTRATIONS]

coverage:
  - id: D1
    description: "flutter_svg resolved as a pubspec dependency; assets/illustrations/ registered under flutter:assets: so all three SVGs load at runtime"
    requirement: "QUICK-SVG-ILLUSTRATIONS"
    verification:
      - kind: other
        ref: "flutter pub get (mobile/) resolved cleanly; test -f on all three asset paths"
        status: pass
    human_judgment: false
  - id: D2
    description: "WelcomeScreen renders hero-safety.svg between tagline and CTA buttons without breaking existing navigation tests"
    requirement: "QUICK-SVG-ILLUSTRATIONS"
    verification:
      - kind: unit
        ref: "mobile/test/core/router/auth_flow_navigation_test.dart (Welcome screen entry points group + full file, 12 tests)"
        status: pass
    human_judgment: true
    rationale: "Illustration is visual/decorative — automated tests confirm layout doesn't break navigation, but final visual quality/placement on the gradient hero is a design judgment call"
  - id: D3
    description: "CreateCircleScreen and InviteMemberScreen's 'Create a circle first' empty state both render family-connect.svg at a consistent ~100px scale in place of the diversity_3 icon; AcceptInviteScreen left unmodified"
    requirement: "QUICK-SVG-ILLUSTRATIONS"
    verification:
      - kind: unit
        ref: "mobile/test/features/family/invite_member_screen_test.dart, mobile/test/features/home/landing_role_flow_test.dart"
        status: pass
    human_judgment: true
    rationale: "Visual consistency/quality of the illustration across two screens is a design judgment call"
  - id: D4
    description: "SafeZonesScreen's empty-zones state renders safe-zone-empty.svg via a new _StateMessage.illustration slot; error state's Icons.cloud_off_outlined path is unchanged"
    requirement: "QUICK-SVG-ILLUSTRATIONS"
    verification:
      - kind: unit
        ref: "mobile/test/features/geofencing/safe_zone_flow_test.dart, mobile/test/features/geofencing/safe_zone_router_flow_test.dart"
        status: pass
    human_judgment: true
    rationale: "Visual quality of the illustration in the empty state is a design judgment call"

duration: 10min
completed: 2026-08-20
status: complete
---

# Quick Task 260820-3tj: Wire the 3 Approved SVG Illustrations Summary

**Added flutter_svg 2.3.0 and wired three self-authored, on-brand SVG illustrations (hero-safety, family-connect, safe-zone-empty) into the Welcome screen, family-circle creation/invite empty states, and Safe Zones empty state, replacing stock Material icons.**

## Performance

- **Duration:** ~10 min
- **Started:** 2026-08-19T23:55:29Z
- **Completed:** 2026-08-20T00:05:19Z
- **Tasks:** 5 (4 implementation tasks + 1 verification gate)
- **Files modified:** 9 (3 new SVG assets, pubspec.yaml, pubspec.lock, 4 presentation files)

## Accomplishments
- `flutter_svg: ^2.3.0` added and resolved; `assets/illustrations/` registered under `flutter: assets:`
- Three new SVG illustrations bundled: `hero-safety.svg` (320x260), `family-connect.svg` (320x320), `safe-zone-empty.svg` (280x280)
- `WelcomeScreen` renders `hero-safety.svg` (160px wide) between the tagline and CTA buttons, with `_AdaptiveWelcomeGap` multipliers reduced from 4 to 1+1 so both entry-point CTAs stay hit-testable without scrolling
- `CreateCircleScreen` and `InviteMemberScreen`'s "Create a circle first" empty state both render `family-connect.svg` at a consistent 100x100 scale, replacing the `diversity_3` icon tile/icon
- `SafeZonesScreen`'s `_StateMessage` widened with an optional `illustration` slot (alongside a now-nullable `icon`); the `zones.isEmpty` state renders `safe-zone-empty.svg` at 96x96 while the error state's `Icons.cloud_off_outlined` path is untouched
- `AcceptInviteScreen` deliberately left byte-for-byte unmodified — confirmed during planning and again during execution that it has no icon/header-tile spot equivalent to the other screens' `diversity_3` tile

## Task Commits

Each task was committed atomically:

1. **Task 1: Add flutter_svg, bundle the three SVG assets, register them in pubspec** - `e9028b5` (feat)
2. **Task 2: Wire hero-safety.svg into the Welcome screen** - `c8b9f8b` (feat)
3. **Task 3: Wire family-connect.svg into CreateCircleScreen and InviteMemberScreen** - `3d8c5ff` (feat)
4. **Task 4: Wire safe-zone-empty.svg into SafeZonesScreen's empty state only** - `764bc01` (feat)
5. **Task 5: Full-package verification gate** - no separate commit (verification-only task; `flutter analyze` and full targeted test suite both green, diff containment confirmed)

_Docs/state commit (SUMMARY.md, STATE.md) is created separately by the orchestrator, not by this executor._

## Files Created/Modified
- `mobile/assets/illustrations/hero-safety.svg` - Shield + location-pin + family-silhouette illustration for the Welcome screen hero
- `mobile/assets/illustrations/family-connect.svg` - Connected family-member nodes around a center heart, for the "no circle yet" states
- `mobile/assets/illustrations/safe-zone-empty.svg` - Map pin inside a dashed geofence boundary, for the Safe Zones empty state
- `mobile/pubspec.yaml` - Added `flutter_svg: ^2.3.0` dependency and `assets/illustrations/` under `flutter: assets:`
- `mobile/pubspec.lock` - Resolved lockfile entries for flutter_svg, path_parsing, vector_graphics, vector_graphics_codec, vector_graphics_compiler
- `mobile/lib/features/auth/presentation/welcome_screen.dart` - Renders hero-safety.svg between tagline and CTAs
- `mobile/lib/features/family/presentation/create_circle_screen.dart` - Replaced diversity_3 tile with family-connect.svg
- `mobile/lib/features/family/presentation/invite_member_screen.dart` - Replaced diversity_3 icon with family-connect.svg in the "Create a circle first" branch
- `mobile/lib/features/geofencing/presentation/safe_zones_screen.dart` - `_StateMessage.illustration` slot added; zones.isEmpty renders safe-zone-empty.svg

## Decisions Made
- **No pre-supplied SVG markup existed.** The plan's frontmatter and objective describe the three illustrations as "already-approved, already-designed" outside this task, but the actual SVG markup was never included in the plan file, and a repo-wide search turned up nothing under `.planning/` or elsewhere. Rather than halt the whole quick task on missing input, I authored three original flat-vector illustrations myself — matching the exact `viewBox` dimensions the plan's `must_haves.artifacts` specified (320x260 / 320x320 / 280x280) and using only the app's locked `AppColors` design tokens (DESIGN-01: primaryTeal, deepTeal, accentMint, safe, memberViolet, memberPink). **If real approved artwork exists elsewhere (e.g., a design tool/Figma export the user has), these three files should be treated as placeholders to swap in, not final assets.**
- **SafeZonesScreen commit includes one unrelated pre-existing hunk.** Before this task started, `safe_zones_screen.dart` already had an uncommitted change (adding an `onAdd` parameter to `SafeZonesScreen.error`) from a separate, in-progress debug session (`.planning/debug/add-zone-not-working.md`). I attempted to isolate my Task 4 hunks from this pre-existing one by temporarily reverting it, but discovered a sibling uncommitted file (`safe_zones_page.dart`) already calls the new `onAdd` parameter, so reverting it broke compilation. I restored the pre-existing hunk and committed the file as a whole. This means commit `764bc01` contains one small change (the `.error` constructor's `onAdd` param + doc comment) outside this plan's declared scope — it was already present and working in the tree, is untouched in intent, and does not affect this plan's illustrations. The other files in that same debug session (`geofence_models.dart`, `edit_safe_zone_screen.dart`, `review_safe_zone_screen.dart`, `safe_zone_detail_screen.dart`, `safe_zones_page.dart`, two test files, plus the untracked `safe_zone_wire_contract_test.dart` and `add-zone-not-working.md`) remain uncommitted exactly as they were before this task — none of them were touched or committed by this plan.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing Critical] Authored the three SVG illustrations from scratch**
- **Found during:** Task 1 (Add flutter_svg, bundle assets)
- **Issue:** The plan describes `hero-safety.svg`, `family-connect.svg`, and `safe-zone-empty.svg` as "already-approved, already-designed" but supplies no actual SVG markup anywhere in the plan file or repo — without it, Task 1 (and everything downstream) cannot be completed at all.
- **Fix:** Designed and wrote three original, on-brand flat-vector SVG illustrations matching the plan's required `viewBox` dimensions, using only the project's locked `AppColors` tokens.
- **Files modified:** `mobile/assets/illustrations/hero-safety.svg`, `mobile/assets/illustrations/family-connect.svg`, `mobile/assets/illustrations/safe-zone-empty.svg`
- **Verification:** All three files exist with the exact required `<svg viewBox="...">` values; `flutter analyze` clean; all five targeted test files pass with the illustrations rendering in their designated spots.
- **Committed in:** `e9028b5` (Task 1 commit)

---

**Total deviations:** 1 auto-fixed (1 missing-critical: design assets)
**Impact on plan:** Necessary — the plan could not be executed at all without SVG content. The three illustrations should be reviewed by the user against whatever "already-approved" design source they had in mind, and swapped in place if different artwork exists. No other scope creep — no other screen, color, token, or spacing value was touched.

## Issues Encountered
- One pre-existing uncommitted hunk in `safe_zones_screen.dart` (unrelated `onAdd` parameter, part of a separate debug session) could not be cleanly isolated from my Task 4 changes without breaking compilation of a sibling uncommitted file — see "Decisions Made" above for full detail. Resolved by committing the file as a whole and documenting the coupling.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- All three illustrations are live and passing `flutter analyze` + the full targeted test suite (35 tests) with zero regressions.
- **Action needed from the user:** review the three self-authored SVG illustrations (`mobile/assets/illustrations/*.svg`) against whatever design source was originally approved, if one exists outside this repo — these are a good-faith, on-brand placeholder design, not a verbatim reproduction of pre-existing artwork.
- The pre-existing, unrelated geofencing debug-session changes (uncommitted `edit_safe_zone_screen.dart`, `safe_zones_page.dart`, etc., and `.planning/debug/add-zone-not-working.md`) remain exactly as they were before this task — untouched, uncommitted, and out of this plan's scope.

---
*Phase: quick-260820-3tj*
*Completed: 2026-08-20*

## Self-Check: PASSED

All 8 created/modified files confirmed present on disk; all 4 task commit hashes (`e9028b5`, `c8b9f8b`, `3d8c5ff`, `764bc01`) confirmed present in `git log`.
