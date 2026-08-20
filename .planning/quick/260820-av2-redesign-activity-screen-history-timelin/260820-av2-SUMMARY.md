---
phase: quick-260820-av2
plan: 01
subsystem: mobile/location
tags: [flutter, ui, design-system, location, activity-screen]
dependency-graph:
  requires: []
  provides:
    - "SafePathCard color/border override params"
    - "StatTile icon-led color-coded rendering"
    - "PrimaryButton optional icon param"
    - "TimelineNode green transit badge + duration pill"
    - "HistoryTimelineScreen redesigned to approved mockup"
  affects:
    - mobile/lib/features/geofencing/presentation/zone_activity_screen.dart (TimelineNode transit badge recolor, by design)
tech-stack:
  added: []
  patterns:
    - "Backward-compatible shared-widget extension: new params default to null and reproduce prior rendering exactly (D-01)"
    - "Date-only normalization + clamping before showDatePicker to avoid assertion crashes (D-02)"
    - "Dedicated ValueChanged<DateTime> callback instead of simulating repeated day-step calls (D-03)"
key-files:
  created:
    - .planning/quick/260820-av2-redesign-activity-screen-history-timelin/deferred-items.md
  modified:
    - mobile/pubspec.yaml
    - mobile/lib/shared_widgets/safepath_card.dart
    - mobile/lib/shared_widgets/stat_tile.dart
    - mobile/lib/shared_widgets/primary_button.dart
    - mobile/lib/shared_widgets/timeline_node.dart
    - mobile/lib/features/location/presentation/history_timeline_screen.dart
    - mobile/assets/icons/activity-history.png (registered/tracked)
    - mobile/assets/icons/activity-distance.png (registered/tracked)
    - mobile/assets/icons/activity-time-away.png (registered/tracked)
    - mobile/assets/icons/activity-stops.png (registered/tracked)
decisions:
  - "D-01: Extended SafePathCard with optional color/border params rather than forking it — it had no color/border API at all, contrary to the task brief's assumption. All 31 existing call sites stay pixel-identical since both new params default to null."
  - "D-02: Normalized showDatePicker's initialDate/firstDate/lastDate to date-only and clamped initialDate to never exceed lastDate — selectedDate is UTC midnight, so .toLocal() in a positive-offset timezone can be 'today at 02:00', which exceeds a lastDate of DateTime.now() before 02:00 local and would otherwise assert/crash."
  - "D-03: Added a dedicated onDateSelected(DateTime) callback on _HistoryHeader plus a new static _goToDate helper, instead of simulating N chevron taps for a picked date — avoids firing N separate network loads for one date pick."
  - "D-04: The duration-badge text color (0xFF1E7A50) is a private const local to timeline_node.dart, not added to AppColors — it exists only for contrast (AppColors.safe on safeBg is ~2.6:1; this hex reaches ~4.4:1 at 11.5px). Flagged for explicit user acceptance since it is the one value in this task not drawn from the locked token file."
metrics:
  duration: ~45min
  completed: 2026-08-20
status: complete
---

# Phase quick-260820-av2 Plan 01: Redesign Activity Screen History Timeline Summary

Redesigned the Activity screen (`history_timeline_screen.dart`) to match the user-approved mockup: icon-led history header, a tappable member-switcher pill with avatar bottom sheet, human-readable date with a clamped date picker and today-capped next-day chevron, colour-coded icon-led stat cards, a map icon on "View route", and green transit timeline nodes with duration badges — while extending four shared widgets backward-compatibly so all 24+ unrelated call sites stay visually and behaviourally unchanged.

## What Was Built

**Task 1 — Shared widget extensions (commit `7a3ce45`):**
- Registered `assets/icons/` in `pubspec.yaml` and ran `flutter pub get`; the four pre-existing PNGs (`activity-history.png`, `activity-distance.png`, `activity-time-away.png`, `activity-stops.png`) are now tracked and asset-manifest-registered.
- `SafePathCard` gained optional `Color? color` / `BoxBorder? border` params (D-01) — both null by default, reproducing today's plain white/no-border fill exactly.
- `StatTile` gained optional `icon`, `backgroundColor`, `borderColor`, `valueColor`, `labelColor` params. When `icon` is non-null the tile centers its column and puts the icon above the value; when null the layout is byte-for-byte the prior left-aligned rendering.
- `PrimaryButton` gained an optional `IconData? icon` param — renders a centered `Row` (icon + 8px gap + label) when non-null, the bare `Text(label)` otherwise. The icon inherits the button's existing foreground color via `ButtonStyleButton`'s `IconTheme`.
- `TimelineNode`'s `isTransit` badge recolored from the teal tint to the `safe`/`safeBg`/`safeBgBorder` green palette (applies to both existing call sites, including `zone_activity_screen.dart` by design). Added an optional `durationLabel` trailing pill, appended as the outer `Row`'s final child only when non-null — structurally identical to today when null.

**Task 2 — Activity screen rewire (commit `f7203e9`):**
- Header icon box now shows `activity-history.png` instead of a stock `Icons.route_outlined`; title/subtitle sizes tightened to 15px/600 and 13px respectively.
- Replaced the `DropdownButtonFormField` with a new `_MemberSelectorPill` (avatar initial + name + chevron, 44dp touch target) that opens a `showModalBottomSheet` horizontal avatar picker; tapping an avatar switches the member and closes the sheet.
- Date label reformatted to `"Sat, Aug 15"` via two file-level lookup tables (no `intl`/date-formatting package added). Added a teal calendar icon that opens a `showDatePicker`, normalized/clamped per D-02. Added `onDateSelected` -> `_goToDate` wiring per D-03. The next-day chevron is disabled (`onPressed: null`) once the selected local day equals today.
- `_StatsRow` now renders three colour-coded, icon-led `StatTile`s: Distance (teal/`primaryTintBg`), Time away (amber/`cautionBg`/`cautionText`), Stops (violet, via `AppColors.memberViolet.withValues(alpha: ...)` since no dedicated violet-tint token exists).
- `PrimaryButton(label: 'View route', ...)` gained `icon: Icons.map_outlined`; the error-branch `'Try again'` button was left without an icon per the task brief.
- `_TimelineList`/`_nodes` now compute a `durationLabel` for the whole-day "On the move" entry (`history.stops.isEmpty` branch) via the existing `_durationLabel` helper; the synthetic "On the move" entries interleaved between stops still carry no `durationLabel` since they have no real start/end timestamps.

**Task 3 — Verification (no code changes, no commit):**
- `flutter test test/features/location/history_timeline_screen_test.dart` passed clean with **zero edits**, exactly as predicted by the plan's pre-verified fact 5 — the single `find.text('Maya Rivera')` expectation still resolves to one match since the new pill renders the name once with the sheet closed.
- Full `flutter test` surfaced two pre-existing, out-of-scope failures unrelated to this plan's changes (see "Deferred Issues" below) — no code in this task caused or touched either failing test's dependency graph.
- Protected-file guard (`git hash-object` over the 9 guarded geofencing files) printed `GUARD_OK` after every task.
- `route_stats_sheet.dart` and `zone_activity_screen.dart` are absent from `git status --porcelain` and from the scoped `git diff --stat` for this plan's touched paths — confirming zero edits to the 3 `StatTile` call sites in `route_stats_sheet.dart` and the 1 `TimelineNode` call site in `zone_activity_screen.dart` (the latter's only change is the intentional cross-cutting transit-badge recolor from Task 1's shared-widget edit, which is structural/token-level, not a source edit to that file).

## Deviations from Plan

### Auto-fixed Issues

None — plan executed exactly as written across all three tasks. No Rule 1/2/3 fixes were required.

## Deferred Issues

Discovered during Task 3's full `flutter test` run, out of scope for this plan (neither test imports any file this plan touched) and logged to `deferred-items.md` in this quick-task directory rather than fixed:

| Test | File | Failure |
|------|------|---------|
| `renders the battery percent when known` | `mobile/test/features/location/live_member_marker_test.dart` | `Found 0 widgets with text "72%"` |
| `existing routing unchanged after splash: unauthenticated -> Welcome -> Login still works` | `mobile/test/features/splash/splash_redirect_gate_test.dart` | Tap misses a widget outside the test viewport, then `Found 0 widgets with text "Welcome back."` |

## Decisions Requiring User Acceptance

**D-04 (hardcoded hex):** The duration-badge text uses `const Color(0xFF1E7A50)`, kept as a private constant local to `timeline_node.dart` rather than added to the locked `AppColors` token file. This is the one value in this task not drawn from the design-system tokens — it exists purely for contrast (`AppColors.safe` on `safeBg` is only ~2.6:1 at small badge sizes; this hex reaches ~4.4:1). The plan's brief specified this exact value from the approved mockup; flagging here per the plan's explicit instruction for the user to accept or reject it.

## Self-Check: PASSED

All 10 created/modified files listed above verified present on disk; both commit hashes (`7a3ce45`, `f7203e9`) verified present in `git log --all`.
