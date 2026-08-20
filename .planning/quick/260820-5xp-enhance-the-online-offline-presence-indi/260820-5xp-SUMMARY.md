---
phase: quick-260820-5xp
plan: 01
subsystem: mobile-location-presence
tags: [flutter, design-tokens, animation, live-map, member-detail]
dependency-graph:
  requires: []
  provides:
    - "AppColors.offline design token"
    - "Animated (pulsing) online presence dot"
  affects:
    - mobile/lib/features/location/presentation/live_map_screen.dart
    - mobile/lib/features/location/presentation/member_detail_sheet.dart
tech-stack:
  added: []
  patterns:
    - "FadeTransition over AnimatedBuilder+Opacity for animated opacity when the tree already has an Opacity widget-test finder to avoid colliding with"
    - "Eager AnimationController creation in initState (not a lazy `late final` field initializer) when a State's build() has a conditional early-return path that may never touch the controller"
key-files:
  created: []
  modified:
    - mobile/lib/core/theme/app_colors.dart
    - mobile/lib/features/location/presentation/live_map_screen.dart
    - mobile/lib/features/location/presentation/member_detail_sheet.dart
decisions:
  - "FadeTransition (not AnimatedBuilder+Opacity) drives the online dot's pulse -- FadeTransition uses RenderAnimatedOpacity internally rather than composing an Opacity widget, avoiding a collision with an existing find.byType(Opacity) single-match test finder used for the marker's unrelated staleness-fade wrapper."
  - "_PresenceDotState creates its AnimationController eagerly in initState rather than as a `late final` field initializer, since the offline/reduced-motion early-return in build() never touches the controller -- a lazy initializer would otherwise construct a fresh controller for the first time inside dispose(), crashing on the deactivating widget tree."
metrics:
  duration: ~35min
  completed: 2026-08-20
status: complete
---

# Quick Task 260820-5xp: Enhance the online/offline presence indicator Summary

Added a dedicated `AppColors.offline` (#8B96A3) design token distinct from the general-purpose
`bodySecondary` text color, wired it into every presence-driven offline color (map marker dot,
rail-card dot, inline "Offline" text+dot, member detail OFFLINE badge text), and gave the online
presence dot a subtle 1600ms looping pulse that respects reduced-motion accessibility settings.

## What Was Built

- **`AppColors.offline`** (`app_colors.dart`): a new `Color(0xFF8B96A3)` token with a doc comment
  distinguishing it from `bodySecondary` and warning against confusion with `sosRed`/`sosRedDeep`.
- **`_PresenceDot`** (`live_map_screen.dart`): converted from a `StatelessWidget` to a
  `StatefulWidget` (`_PresenceDotState` + `SingleTickerProviderStateMixin`) with a 1600ms
  `AnimationController` (`repeat(reverse: true)`). The online + motion-enabled dot pulses via
  `FadeTransition` (opacity oscillating 1.0 -> 0.55 -> 1.0); the offline dot and any dot under
  `MediaQuery.disableAnimations` render statically. The public constructor (`isOnline`, `size`) is
  unchanged, so both existing call sites (`LiveMemberMarker`'s avatar badge,
  `_MemberAvatar`'s rail-card badge) needed no edits.
- **`_InlinePresence`** (`live_map_screen.dart`): offline text/dot foreground color now reads
  `AppColors.offline` instead of `AppColors.bodySecondary`.
- **`_StatusBadge`** (`member_detail_sheet.dart`): the OFFLINE badge's text color now reads
  `AppColors.offline` instead of `AppColors.bodySecondary`; background/border untouched.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Interface contract's `late final` field initializer crashed on offline dots**

- **Found during:** Task 2, first `flutter test` run against the plan's exact
  `_PresenceDot`/`_PresenceDotState` interface-contract code.
- **Issue:** The plan's specified `late final AnimationController _pulseController = AnimationController(...)..repeat(reverse: true);`
  field initializer is lazy -- it only runs the first time `_pulseController` is read. Offline
  dots' `build()` returns early (`if (!widget.isOnline || reduceMotion) return dot;`) before ever
  touching `_pulseController`, so for an offline `_PresenceDot`, the field stayed uninitialized
  until `dispose()` called `_pulseController.dispose()` -- which triggered the initializer to run
  for the *first time* while the widget tree was already deactivating, crashing with "Looking up a
  deactivated widget's ancestor is unsafe" inside `AnimationController`'s `vsync` ticker lookup.
- **Fix:** Moved controller construction into `initState()` (eager, unconditional) instead of a
  lazy `late final` field initializer, so the controller always exists while the widget is
  mounted regardless of which `build()` path executes.
- **Files modified:** `mobile/lib/features/location/presentation/live_map_screen.dart`
- **Commit:** 4184c01

**2. [Rule 1 - Bug] `Opacity`-wrapped pulse broke an existing widget-test finder**

- **Found during:** Task 2, `flutter test` against `live_member_marker_test.dart` after fixing
  deviation #1 above -- "family member marker still fades when its ping is stale" started failing
  with `Iterable.single` throwing on 2 matches (was passing pre-change with exactly 1 match).
- **Issue:** The plan's specified pulse wrapper (`AnimatedBuilder` + `Opacity`) adds a second
  `Opacity` widget to `LiveMemberMarker`'s tree whenever the rendered member is online. The
  existing test `tester.widget<Opacity>(find.descendant(of: find.byType(LiveMemberMarker),
  matching: find.byType(Opacity)))` requires *exactly one* `Opacity` descendant (the marker's own
  staleness-fade wrapper) and throws on ambiguous matches once a second `Opacity` (the pulse) is
  also present.
- **Fix:** Replaced `AnimatedBuilder` + `Opacity` with `FadeTransition(opacity: _pulseOpacity,
  child: dot)`, using a `Tween<double>(begin: 1.0, end: 0.55).animate(_pulseController)`. Flutter's
  `FadeTransition` drives opacity via `RenderAnimatedOpacity` directly rather than composing an
  `Opacity` widget, so it produces the identical visual pulse (same 1.0 -> 0.55 -> 1.0 range, same
  1600ms cycle) without colliding with the existing finder. Verified this restores the test to
  passing while confirming the fix produces the exact same opacity formula as originally specified
  (`0.55 + 0.45 * (1 - value)` inverted into an equivalent `Tween`).
- **Files modified:** `mobile/lib/features/location/presentation/live_map_screen.dart`
- **Commit:** 4184c01

### Out-of-Scope Discoveries (logged, not fixed)

Two pre-existing test failures were found in the full-suite run (Task 4) and confirmed, by
isolated reproduction against the unmodified code, to be unrelated to this task's three files.
Logged to `deferred-items.md` in this quick task's directory per the scope-boundary rule; neither
was fixed:

1. `live_member_marker_test.dart`: "renders the battery percent when known" -- `LiveMemberMarker`
   does not render any battery text; the test expects `find.text('72%')` which no longer exists in
   the widget tree post the `5782ce6` "revert: restore original locked design system" commit.
2. `splash_redirect_gate_test.dart`: "existing routing unchanged after splash: unauthenticated ->
   Welcome -> Login still works" -- fails identically in complete isolation with zero dependency
   on any file this task touched; looks like a pre-existing Welcome-screen viewport/hit-test issue.

Auth gates: None encountered.

## Verification

- `flutter analyze` (full mobile package): clean, no issues.
- `flutter test` (full mobile package): 456 tests run, 454 passed. The 2 failures are the
  pre-existing, out-of-scope items documented above and in `deferred-items.md` -- both
  independently reproduced as failing against the original, unmodified codebase.
- `git diff --name-only` across this task's 3 commits lists exactly the 3 `files_modified`:
  `mobile/lib/core/theme/app_colors.dart`,
  `mobile/lib/features/location/presentation/live_map_screen.dart`,
  `mobile/lib/features/location/presentation/member_detail_sheet.dart`.
- Grepped all three modified files for stray `AppColors.bodySecondary` in presence contexts (none
  found outside the explicitly out-of-scope `_MarkerPresenceLabel` dead code and unrelated
  `_MapMessage` usages) and for any SOS-red hex literal/token (`DE3B40`, `C42A30`, `sosRed`) --
  none introduced.
- No new tests added, per plan.

## Self-Check

- `mobile/lib/core/theme/app_colors.dart` -- FOUND, contains `AppColors.offline`.
- `mobile/lib/features/location/presentation/live_map_screen.dart` -- FOUND, contains
  `_PresenceDotState`.
- `mobile/lib/features/location/presentation/member_detail_sheet.dart` -- FOUND, contains
  `AppColors.offline`.
- Commit f7f45f7 -- FOUND in `git log`.
- Commit 4184c01 -- FOUND in `git log`.
- Commit 806ab02 -- FOUND in `git log`.

## Self-Check: PASSED
