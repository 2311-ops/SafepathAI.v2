---
phase: quick-260820-ciz
plan: 01
subsystem: mobile-ui
tags: [flutter, ui, icons, assets, navigation, privacy]
dependency_graph:
  requires: []
  provides:
    - "MainShell bottom-nav icons rendered from mobile/assets/icons/*.png (full colour, untinted)"
    - "Privacy Center Guardian app-bar icons rendered from mobile/assets/icons/join.png and participation.png"
  affects:
    - mobile/lib/features/home/presentation/main_shell.dart
    - mobile/lib/features/privacy/presentation/privacy_center_screen.dart
tech_stack:
  added: []
  patterns:
    - "Image.asset(..., excludeFromSemantics: true) for icon buttons that already carry their own Semantics label/tooltip"
key_files:
  created:
    - mobile/assets/icons/map.png (newly git-tracked, was already on disk)
    - mobile/assets/icons/games.png (newly git-tracked, was already on disk)
    - mobile/assets/icons/consumer-behavior.png (newly git-tracked, was already on disk)
    - mobile/assets/icons/protection.png (newly git-tracked, was already on disk)
    - mobile/assets/icons/join.png (newly git-tracked, was already on disk)
    - mobile/assets/icons/participation.png (newly git-tracked, was already on disk)
  modified:
    - mobile/lib/features/home/presentation/main_shell.dart
    - mobile/lib/features/privacy/presentation/privacy_center_screen.dart
decisions: []
metrics:
  duration: 6min
  completed: 2026-08-20
status: complete
---

# Quick Task 260820-ciz: Replace 6 bottom-nav and circle-management icons Summary

Replaced the four bottom-nav tab icons and two Privacy Center Guardian app-bar icons (generic Material `IconData`) with the user's own full-colour PNG illustrations, rendered untinted via `Image.asset`.

## What Was Built

**Task 1 — `main_shell.dart` bottom nav:**
- Collapsed `_ShellTab`'s two `IconData` fields (`icon` + `activeIcon`) into a single `required final String iconAsset`, since the supplied PNGs are one full-colour illustration each with no outlined/filled pair.
- `_tabs` now maps: Map -> `assets/icons/map.png`, Activity -> `assets/icons/games.png`, Insights -> `assets/icons/consumer-behavior.png`, Privacy -> `assets/icons/protection.png`.
- `_NavItem.build()`'s `Icon(...)` replaced with `Image.asset(tab.iconAsset, width: 24, height: 24, excludeFromSemantics: true)` — no `color`/`colorBlendMode`, preserving the flat illustrations' own colour.
- Selected-state signalling (tint background `AnimatedContainer`, `AnimatedScale` bump, teal label colour via the existing `color` local) is unchanged — these are now the only selected-state cues since the icon itself no longer changes colour or shape.
- `_PlainTabPlaceholder`'s own `Icons.insights` body icon (Insights tab's screen content, not the nav bar) was left untouched.

**Task 2 — `privacy_center_screen.dart` app bar:**
- The two Guardian-gated `IconButton`s in `AppBar.actions` now render `Image.asset('assets/icons/join.png', ...)` (tooltip `'Invite'`, pushes `/circle/invite`) and `Image.asset('assets/icons/participation.png', ...)` (tooltip `'Circle members'`, pushes `/circle/permissions'`), both at 24x24 with `excludeFromSemantics: true` since `IconButton.tooltip` already supplies the accessible name.
- `const` was dropped only on those two icon expressions (`Image.asset` is not const); every other `const` in the file is unchanged.
- `tooltip`, `onPressed`, both `if (hasFamily && isGuardian)` guards, and `LogoutAction` are byte-identical to before.
- No test in `mobile/test` asserted on `Icons.person_add_alt_1` or `Icons.groups_2_outlined` (confirmed via grep before and after), so no test finder needed re-targeting.

## Pre-edit Working Tree Baseline (Step 0, before any edit)

```
 M mobile/lib/features/geofencing/data/geofence_models.dart
 M mobile/lib/features/geofencing/presentation/review_safe_zone_screen.dart
 M mobile/lib/features/geofencing/presentation/safe_zone_detail_screen.dart
 M mobile/lib/features/geofencing/presentation/safe_zones_page.dart
 M mobile/test/features/geofencing/safe_zone_router_flow_test.dart
 M mobile/test/helpers/fake_geofence_api.dart
?? .planning/debug/add-zone-not-working.md
?? distance.png
?? fast-time.png
?? flag.png
?? mobile/assets/icons/consumer-behavior.png
?? mobile/assets/icons/games.png
?? mobile/assets/icons/join.png
?? mobile/assets/icons/map.png
?? mobile/assets/icons/participation.png
?? mobile/assets/icons/protection.png
?? mobile/test/features/geofencing/safe_zone_wire_contract_test.dart
?? siblings.png
```

(Note: this differs slightly from the git status shown at conversation start — `edit_safe_zone_screen.dart` and `safe_zones_screen.dart` were no longer dirty by the time this task started; this is the geofencing debug session's own concurrent activity, unrelated to this task, and was left alone.)

Post-execution `git status --short` (after both commits) shows every one of these entries unchanged except the six PNGs, which resolved into this task's two commits:

```
 M mobile/lib/features/geofencing/data/geofence_models.dart
 M mobile/lib/features/geofencing/presentation/review_safe_zone_screen.dart
 M mobile/lib/features/geofencing/presentation/safe_zone_detail_screen.dart
 M mobile/lib/features/geofencing/presentation/safe_zones_page.dart
 M mobile/test/features/geofencing/safe_zone_router_flow_test.dart
 M mobile/test/helpers/fake_geofence_api.dart
?? .planning/debug/add-zone-not-working.md
?? distance.png
?? fast-time.png
?? flag.png
?? mobile/test/features/geofencing/safe_zone_wire_contract_test.dart
?? siblings.png
```

## Deviations from Plan

None - plan executed exactly as written. No test finder needed re-targeting (grep confirmed zero existing `find.byIcon` assertions on either replaced icon before or after the swap).

## Flagged For User (not acted on, per task scope)

The four stray root-level PNGs — `distance.png`, `fast-time.png`, `flag.png`, `siblings.png` — remain untracked and unstaged, exactly as instructed. They sit in the repo root rather than `mobile/assets/icons/` and are not part of this task; the user should decide whether they belong somewhere in the project or should be deleted.

## Verification

- `flutter analyze` on the whole `mobile/` package: **No issues found.**
- Both `main_shell.dart`-scoped and package-wide grep checks (removed `IconData` fields, preserved placeholder/selected-state markers, wired asset paths, unchanged tooltips/routes/guards): all passed.
- `flutter test test/features/home/sos_button_press_hold_test.dart test/features/location/location_permission_gate_test.dart`: 17/17 passed.
- `flutter test test/features/privacy/privacy_center_screen_test.dart test/features/home/sos_button_press_hold_test.dart test/core/router/auth_flow_navigation_test.dart`: 37/37 passed.
- `git ls-files mobile/assets/icons/` returns 10 entries (4 pre-existing `activity-*.png` + 6 newly committed by this task).
- `git ls-files distance.png fast-time.png flag.png siblings.png` returns 0 — stray root PNGs confirmed untracked.
- `git diff --diff-filter=D --name-only` against both commits: empty — no accidental deletions.
- `mobile/pubspec.yaml`: confirmed unmodified (`git diff --name-only -- mobile/pubspec.yaml` empty).
- Geofencing/helper files: `git status --porcelain` for those paths matches the Step 0 baseline exactly after both commits.

## Commits

- `c67aefd` — feat(quick-260820-ciz): swap bottom-nav tab icons to PNG assets (main_shell.dart + map.png, games.png, consumer-behavior.png, protection.png)
- `982b308` — feat(quick-260820-ciz): swap Privacy Center circle-management icons to PNGs (privacy_center_screen.dart + join.png, participation.png)

## Self-Check: PASSED

- FOUND: mobile/lib/features/home/presentation/main_shell.dart
- FOUND: mobile/lib/features/privacy/presentation/privacy_center_screen.dart
- FOUND: mobile/assets/icons/map.png
- FOUND: mobile/assets/icons/games.png
- FOUND: mobile/assets/icons/consumer-behavior.png
- FOUND: mobile/assets/icons/protection.png
- FOUND: mobile/assets/icons/join.png
- FOUND: mobile/assets/icons/participation.png
- FOUND commit c67aefd in `git log --oneline --all`
- FOUND commit 982b308 in `git log --oneline --all`
