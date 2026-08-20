---
phase: quick-260820-ciz
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - mobile/lib/features/home/presentation/main_shell.dart
  - mobile/lib/features/privacy/presentation/privacy_center_screen.dart
autonomous: true
requirements: [QUICK-260820-ciz]
tags: [flutter, ui, icons, assets, navigation, privacy]

must_haves:
  truths:
    - "The four bottom-nav tabs (Map, Activity, Insights, Privacy) render the user's own PNG icons at their native full colour, with no tint or colour filter applied."
    - "Selected-tab state is still visually obvious: the AppColors.primaryTintBg AnimatedContainer background, the AnimatedScale bump, and the teal label colour all still switch on selection."
    - "Each nav item still announces exactly one screen-reader label (its tab label) — the swap adds no extra image semantics node."
    - "The Privacy Center app bar's Guardian-only Invite and Circle members buttons render join.png and participation.png; their tooltips, routes, and Guardian guards are byte-identical to before."
    - "The Insights tab's own placeholder body still renders its large centred Material icon — only the nav bar changed."
    - "flutter analyze on the whole mobile package reports no new issues, including no unused-field or unused-import warnings from the removed IconData fields."
    - "No file under mobile/lib/features/geofencing/, mobile/test/features/geofencing/, or mobile/test/helpers/ is modified — those belong to a separate in-progress debug session."
    - "mobile/pubspec.yaml is unmodified."
  artifacts:
    - "mobile/lib/features/home/presentation/main_shell.dart with a single-field _ShellTab and Image.asset nav icons"
    - "mobile/lib/features/privacy/presentation/privacy_center_screen.dart with Image.asset app-bar action icons"
  key_links:
    - "_ShellTab.iconAsset -> Image.asset(tab.iconAsset) in _NavItem.build(). Collapsing two IconData fields into one String is the whole structural change; if the field is renamed in one place and not the other the file will not compile."
    - "assets/icons/*.png -> the EXISTING `- assets/icons/` declaration at mobile/pubspec.yaml:112. Already present from quick task 260820-av2. If pubspec is edited, this plan has gone wrong."
    - "Image.asset excludeFromSemantics:true -> _NavItem's existing Semantics(button, selected, label) wrapper and IconButton's tooltip. Without it, Image merges an isImage flag plus an empty label into the parent node and degrades the announcement."
    - "The `color` local in _NavItem.build() -> the label Text only. It must survive the Icon removal, or the selected-state label colour is lost."
---

<objective>
Replace six generic Material icons with the user's own PNG icon assets: the four bottom-nav tab icons in `main_shell.dart` and the two Guardian-only circle-management icon buttons in the Privacy Center app bar.

Purpose: These are the last stock Material glyphs on the app's two most-visited surfaces, called out in the pending "stock icons" UI polish todo. The supplied PNGs are full-colour flat illustrations, so this is not a like-for-like `IconData` swap — the nav bar's icon-tinting selected-state mechanism has to change shape to accommodate them.

Output: Two modified Dart files. No new assets, no pubspec change, no test rewrites expected.
</objective>

<execution_context>
@$HOME/.claude/gsd-core/workflows/execute-plan.md
@$HOME/.claude/gsd-core/templates/summary.md
</execution_context>

<context>
@.planning/STATE.md

@mobile/lib/features/home/presentation/main_shell.dart
@mobile/lib/features/privacy/presentation/privacy_center_screen.dart

**Assets — already on disk, already declared, do not regenerate/redraw/resize:**
`mobile/assets/icons/` contains `map.png`, `games.png`, `consumer-behavior.png`, `protection.png`, `participation.png`, `join.png` (plus four `activity-*.png` from quick task 260820-av2). `mobile/pubspec.yaml` line 112 already declares `- assets/icons/` under `flutter.assets`, which covers the whole directory. **No pubspec edit is needed and none should be made.**

**Established precedent to copy:** `mobile/lib/features/location/presentation/history_timeline_screen.dart` already renders these same-directory PNGs via `Image.asset('assets/icons/activity-history.png', width: 26, height: 26)`. That screen is the Activity tab, hosted inside `MainShell`'s `IndexedStack`, so every widget test that builds `MainShell` already loads PNGs from `assets/icons/` successfully. Asset resolution under `flutter test` is therefore a solved, proven problem here — not a risk.

**Working-tree warning:** the tree is dirty with an unrelated, in-progress geofencing debug session (`mobile/lib/features/geofencing/*`, `mobile/test/features/geofencing/*`, `mobile/test/helpers/fake_geofence_api.dart`, `.planning/debug/add-zone-not-working.md`). Those files are off-limits and must never be staged by this task.
</context>

<tasks>

<task type="auto">
  <name>Task 1: Swap the four bottom-nav tab icons to PNG assets</name>
  <files>mobile/lib/features/home/presentation/main_shell.dart</files>
  <action>
**Step 0 — record the baseline.** Before editing anything, run `git status --porcelain` and paste the output verbatim into your summary under a "Pre-edit working tree baseline" heading. Every entry in that baseline belongs to a separate in-progress geofencing debug session. This task may add exactly one new entry to it (`main_shell.dart`) and may not alter, resolve, or remove any existing entry.

**Then edit `mobile/lib/features/home/presentation/main_shell.dart`:**

1. `_ShellTab` (around line 137) currently declares two `IconData` fields (a default and a selected variant) plus a `label`. Collapse both icon fields into a single `required final String iconAsset`. These assets ship one full-colour variant each — there is no outlined/filled pair to model — so a second field would have nothing to hold.

2. Update the four `_tabs` entries (around line 26) to pass `iconAsset`, mapped by label:
   - `'Map'` -> `'assets/icons/map.png'`
   - `'Activity'` -> `'assets/icons/games.png'`
   - `'Insights'` -> `'assets/icons/consumer-behavior.png'`
   - `'Privacy'` -> `'assets/icons/protection.png'`

   Labels, list order, and the index-2 SOS-spacer arithmetic in `build()` (`i < 2 ? i : i - 1`) are all unchanged. The list stays `static const`.

3. In `_NavItem.build()` (around line 186), replace the `Icon(...)` child of the `AnimatedScale` with:
   `Image.asset(tab.iconAsset, width: 24, height: 24, excludeFromSemantics: true)`

   - Pass **no** `color` and no `colorBlendMode`. These are full-colour flat illustrations; a tint or colour filter would flatten their detail. This is the reason the two-`IconData` design cannot survive.
   - `24x24` is the Material `Icon` default size, so the nav row's layout stays pixel-identical.
   - `excludeFromSemantics: true` because `Image` otherwise merges an `isImage` flag and an empty label into `_NavItem`'s existing `Semantics(button: true, selected: selected, label: tab.label)` wrapper. That wrapper must remain the single, clean announcement per this project's established marker-semantics convention (quick task 260720-3u4).

4. Keep the `color` local in `_NavItem.build()` — the label `Text` still consumes it. Keep the `AnimatedScale` and keep the `AnimatedContainer`'s `AppColors.primaryTintBg` selected background. With the icon no longer changing colour, the tint background + scale bump + label colour/weight are now the *only* selected-state signals, so removing any of them would leave selection ambiguous.

5. Out of scope, leave exactly as-is: `_PlainTabPlaceholder` and its `IconData` field (that is the Insights tab's screen *body*, not the nav bar), and the `package:flutter/material.dart` import (still required for `Image`, `Widget`, `AnimatedScale`).

**Staging:** stage only this one path — `git add mobile/lib/features/home/presentation/main_shell.dart`. Never `git add -A` or `git add .`; the tree is dirty with unrelated geofencing work.
  </action>
<!-- planner-discipline-allow: activeIcon -->
  <verify>
    <automated>cd mobile && flutter analyze lib/features/home/presentation/main_shell.dart</automated>
    <automated>cd mobile && for a in map games consumer-behavior protection; do test "$(grep -c "assets/icons/$a.png" lib/features/home/presentation/main_shell.dart)" = "1" || { echo "MISSING $a"; exit 1; }; done; echo OK</automated>
    <automated>cd mobile && test "$(grep -v '^\s*//' lib/features/home/presentation/main_shell.dart | grep -cE 'activeIcon|Icons\.map|Icons\.history|Icons\.privacy_tip')" = "0" && echo "OK: old nav IconData fully removed"</automated>
    <automated>cd mobile && test "$(grep -c 'Icons\.insights' lib/features/home/presentation/main_shell.dart)" = "1" && echo "OK: placeholder body icon preserved"</automated>
    <automated>cd mobile && test "$(grep -c 'AppColors.primaryTintBg' lib/features/home/presentation/main_shell.dart)" = "1" && test "$(grep -c 'AnimatedScale' lib/features/home/presentation/main_shell.dart)" = "1" && echo "OK: selected-state indicators preserved"</automated>
    <automated>cd mobile && flutter test test/features/home/sos_button_press_hold_test.dart test/features/location/location_permission_gate_test.dart</automated>
  </verify>
  <done>
`main_shell.dart` compiles clean under `flutter analyze` with zero unused-field/unused-import warnings. `_ShellTab` has exactly one icon field, a `String` asset path. All four nav tabs render their PNG untinted at 24x24. The tint background, scale bump, and label colour still switch on selection. The Insights placeholder body's Material icon is untouched. Both MainShell-building test files pass. `git status --porcelain` shows exactly one new entry versus the Step 0 baseline.
  </done>
</task>

<task type="auto">
  <name>Task 2: Swap the two Privacy Center app-bar icons and verify the package</name>
  <files>mobile/lib/features/privacy/presentation/privacy_center_screen.dart</files>
  <action>
**Edit `mobile/lib/features/privacy/presentation/privacy_center_screen.dart`, `AppBar.actions` (around lines 204-217).** Two Guardian-gated `IconButton`s live there. Change **only** their `icon:` values, identified by tooltip:

- the button with `tooltip: 'Invite'` (pushes `/circle/invite`) -> `icon: Image.asset('assets/icons/join.png', width: 24, height: 24, excludeFromSemantics: true)`
- the button with `tooltip: 'Circle members'` (pushes `/circle/permissions'`) -> `icon: Image.asset('assets/icons/participation.png', width: 24, height: 24, excludeFromSemantics: true)`

Notes:
- Drop the `const` on those two icon expressions only — `Image.asset` is not a const constructor. Every other `const` in the file stays.
- `excludeFromSemantics: true` for the same reason as Task 1: `IconButton`'s `tooltip` already supplies the accessible name, and an extra empty-label image node would dilute it.
- Do **not** change `tooltip`, `onPressed`, either `if (hasFamily && isGuardian)` guard, or `LogoutAction`.
- Do **not** touch the `_PrivacyMessage` no-circle empty state's Material icon (around line 192) — different icon, not requested.

**Explicitly out of scope — do not open or edit:**
- `mobile/lib/features/home/presentation/landing_stub_screen.dart`, which carries the same two Material icons. Per STATE.md it is confirmed dead code, superseded by `MainShell` and unreachable via any route.
- `mobile/lib/features/location/presentation/live_map_screen.dart`'s profile icon.
- Anything under `mobile/lib/features/geofencing/`, `mobile/test/features/geofencing/`, or `mobile/test/helpers/`.

**Test handling.** A `find.byIcon` inventory across all of `mobile/test` was run during planning: **no existing test asserts on any of these six icons.** The nav-bar-adjacent assertions that do exist go through labels (`find.text('Map')`, `find.text('Insights')`) and are unaffected by an icon swap. So no test edit is expected. If one nevertheless breaks because a `find.byIcon(...)` finder no longer resolves, re-target it to an equivalently strong finder — `find.byTooltip('Invite')`, `find.byTooltip('Circle members')`, or the tab's label `Text` — rather than deleting the assertion or loosening it to `findsAny`/`findsWidgets`. Record in the summary exactly which finder changed and why.

**Staging:** `git add mobile/lib/features/privacy/presentation/privacy_center_screen.dart` only.
  </action>
  <verify>
    <automated>cd mobile && test "$(grep -c 'assets/icons/join.png' lib/features/privacy/presentation/privacy_center_screen.dart)" = "1" && test "$(grep -c 'assets/icons/participation.png' lib/features/privacy/presentation/privacy_center_screen.dart)" = "1" && echo "OK: both PNGs wired"</automated>
    <automated>cd mobile && test "$(grep -v '^\s*//' lib/features/privacy/presentation/privacy_center_screen.dart | grep -cE 'Icons\.person_add_alt_1|Icons\.groups_2_outlined')" = "0" && echo "OK: old app-bar IconData removed"</automated>
    <automated>cd mobile && test "$(grep -c "tooltip: 'Invite'" lib/features/privacy/presentation/privacy_center_screen.dart)" = "1" && test "$(grep -c "tooltip: 'Circle members'" lib/features/privacy/presentation/privacy_center_screen.dart)" = "1" && test "$(grep -c '/circle/invite' lib/features/privacy/presentation/privacy_center_screen.dart)" = "1" && test "$(grep -c '/circle/permissions' lib/features/privacy/presentation/privacy_center_screen.dart)" = "1" && test "$(grep -c 'if (hasFamily && isGuardian)' lib/features/privacy/presentation/privacy_center_screen.dart)" = "2" && echo "OK: tooltips, routes, guards unchanged"</automated>
    <automated>cd mobile && flutter analyze</automated>
    <automated>cd mobile && flutter test test/features/privacy/privacy_center_screen_test.dart test/features/home/sos_button_press_hold_test.dart test/core/router/auth_flow_navigation_test.dart</automated>
    <automated>git diff --name-only -- mobile/pubspec.yaml | wc -l | grep -qx '0' && echo "OK: pubspec.yaml untouched"</automated>
    <automated>git status --porcelain -- mobile/lib/features/geofencing mobile/test/features/geofencing mobile/test/helpers && git diff --stat</automated>
  </verify>
  <done>
Both Guardian app-bar buttons render their PNG at 24x24 with tooltips, routes, and `hasFamily && isGuardian` guards untouched. `flutter analyze` on the whole `mobile/` package reports no issues. All named test files pass with no assertion weakened. `git diff --stat` shows `main_shell.dart` and `privacy_center_screen.dart` as the only files this task changed; `pubspec.yaml` is untouched; every geofencing/helper entry matches the Task 1 Step 0 baseline exactly.
  </done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| (none new) | This task swaps compile-time-bundled local image assets for compile-time-bundled icon fonts. No untrusted input, no network fetch, no user-supplied path, no serialization crosses any boundary. |

## STRIDE Threat Register

| Threat ID | Category | Component | Severity | Disposition | Mitigation Plan |
|-----------|----------|-----------|----------|-------------|-----------------|
| T-ciz-01 | Tampering | `assets/icons/*.png` bundled at build time | low | accept | Assets are committed repo files resolved through the pubspec-declared bundle; there is no runtime path construction and no remote source, so no injection surface exists. |
| T-ciz-02 | Denial of Service | `Image.asset` decode on the nav bar | low | accept | Six static ~20-70 KB PNGs rendered at 24x24, decoded once and cached by Flutter's image cache. Identical in kind to the four `activity-*.png` assets already shipping on the Activity tab. |
| T-ciz-SC | Tampering | package-manager installs | n/a | n/a | No npm/pip/cargo/pub package is added or upgraded by this task; `pubspec.yaml` is explicitly gated as unmodified. |
</threat_model>

<verification>
1. `cd mobile && flutter analyze` — whole package, no issues. This is the gate for the unused-field/unused-import risk created by removing the `IconData` fields.
2. `cd mobile && flutter test` — full suite, if runtime allows; otherwise at minimum the five files named in the task verify blocks (`sos_button_press_hold_test.dart`, `location_permission_gate_test.dart`, `privacy_center_screen_test.dart`, `auth_flow_navigation_test.dart`, plus any test the executor discovers touching these surfaces). Note: two pre-existing unrelated failures were logged during quick task 260820-av2 — if they reappear, confirm they are the same two and do not attempt to fix them here.
3. `git diff --stat` — `mobile/lib/features/home/presentation/main_shell.dart` and `mobile/lib/features/privacy/presentation/privacy_center_screen.dart` are the only files this task touched. `mobile/pubspec.yaml` must show zero changes.
4. `git status --porcelain` compared against the Task 1 Step 0 baseline — every geofencing / `test/helpers` / `.planning/debug` entry unchanged, exactly two new entries added.
5. Manual (optional, not blocking): launch the app and confirm the four nav icons render in full colour, the selected tab still reads as selected via its tint background and teal label, and the Privacy Center app bar shows the two new icons for a Guardian.
</verification>

<success_criteria>
- Six Material icons replaced by the six specified PNG assets, none tinted or resized away from 24x24.
- `_ShellTab` carries one `String iconAsset` field; no dead `IconData` field, no dead import.
- Selected-tab affordance preserved via tint background + scale + label colour.
- Screen-reader announcements unchanged (one label per nav item; tooltip per icon button).
- Tooltips, routes, and Guardian guards on the two Privacy Center buttons byte-identical.
- `flutter analyze` clean on `mobile/`; named tests pass with no assertion weakened.
- Exactly two files modified; `pubspec.yaml` and all geofencing-session files untouched.
</success_criteria>

<output>
Create `.planning/quick/260820-ciz-replace-6-bottom-nav-and-circle-manageme/260820-ciz-SUMMARY.md` when done, including the Step 0 working-tree baseline and any test-finder change with its rationale.
</output>
