---
status: resolved
trigger: "header-avatar-not-live-update: Live Map header identity avatar (top-left of \"Your family, live\" bar) does not update live when display name or profile photo changes, unlike the map member markers which do (built in 02-16)."
created: 2026-07-14T00:00:00+03:00
updated: 2026-07-14T01:30:00+03:00
---

## Current Focus

hypothesis: CONFIRMED — the header identity indicator in live_map_screen.dart (line ~155-160) is a hardcoded `const MemberMapPin(label: 'You', identityColor: AppColors.primaryTeal, isSelf: true, size: 36)` that (a) is declared `const`, so Flutter never rebuilds it regardless of state changes, and (b) even ignoring the `const` issue, never receives `profileImageUrl`, `profileUpdatedAt`, or the real `displayName` from `state.selfPosition` — unlike `LiveMemberMarker` (used for the map pins), which is built per-frame from `location.profileImageUrl`/`location.profileUpdatedAt`/`location.displayName` sourced from `LocationController.state.members`/`selfPosition`, which in turn IS updated live by `_applyProfileUpdate` (02-16 Task 2).
test: Static code read — confirmed via grep that this is the only `MemberMapPin(label: 'You'` instantiation in the codebase, and confirmed `MemberMapPin` widget itself DOES support `profileImageUrl`/`profileUpdatedAt`/`userId` params (used correctly elsewhere), so the widget is capable of live avatars — it's just not wired up in the header call site.
expecting: N/A — root cause confirmed via direct code inspection, no further testing needed for find_root_cause_only mode.
next_action: Return ROOT CAUSE FOUND to caller. Fix direction: replace the hardcoded `const MemberMapPin(label: 'You', ...)` at live_map_screen.dart ~line 155 with a non-const `MemberMapPin` that reads `state?.selfPosition` — passing `label: _memberName(state.selfPosition, state)` (or 'You' fallback), `userId: state?.selfPosition?.userId`, `profileImageUrl: state?.selfPosition?.profileImageUrl`, `profileUpdatedAt: state?.selfPosition?.profileUpdatedAt`.

## Symptoms

expected: When a user updates their display name or profile photo (via the Profile screen, plan 02-15), the change is reflected everywhere their identity is shown on the Live Map screen — including the map header's own identity indicator, not just the family member markers.
actual: The map markers correctly update live (confirmed working, screenshot evidence available), but the header's circular avatar/initial ("Y" in the screenshot, top-left of the "Your family, live" bar) does not reflect the change.
errors: None reported — this is a stale-display issue, not a crash.
reproduction: Test 72 in .planning/phases/02-real-time-location-history-privacy/02-UAT.md — On the Live Map, note the header's identity indicator. Update display name and/or profile photo via the Profile screen. Return to Live Map. The family member markers update; the header indicator does not.
started: Discovered during UAT of Phase 02 (2026-07-14), right after plan 02-16 (live map avatar/name markers with real-time ProfileUpdated updates) was verified and approved on a physical device.

## Eliminated

(none — root cause found on first pass via direct code read, no false hypotheses tested)

## Evidence

- timestamp: 2026-07-14
  checked: mobile/lib/features/location/presentation/live_map_screen.dart (header Row, lines ~139-188)
  found: >
    The header's identity pin is instantiated as:
    ```
    const MemberMapPin(
        label: 'You',
        identityColor: AppColors.primaryTeal,
        isSelf: true,
        size: 36,
    ),
    ```
    It is a compile-time `const` widget with a hardcoded literal label `'You'` and no `userId`/`profileImageUrl`/`profileUpdatedAt` arguments. It does not reference `state`, `state?.selfPosition`, or any Riverpod-watched value at all.
  implication: A `const` widget instance in Dart/Flutter is a single canonical, unchanging instance — it is structurally incapable of ever re-rendering differently, regardless of how many times the parent `build()` re-runs on state changes. Additionally, even if `const` were removed, no avatar/name data is threaded into it, so it would still show the static "You"/"Y" fallback.

- timestamp: 2026-07-14
  checked: mobile/lib/shared_widgets/member_map_pin.dart (full widget definition)
  found: >
    `MemberMapPin` DOES support live avatars: it accepts `userId`, `profileImageUrl`, `profileUpdatedAt` constructor params, and when `profileImageUrl` is non-empty it renders a `CachedNetworkImage` keyed on `'${userId ?? label}-${profileUpdatedAt}'`, falling back to initials-from-label otherwise. This is the exact same mechanism `LiveMemberMarker` (live_map_screen.dart, map pins) uses successfully.
  implication: The widget itself is fully capable of live-updating avatars. The bug is purely a wiring/call-site gap at the header instantiation, not a missing capability in `MemberMapPin`.

- timestamp: 2026-07-14
  checked: mobile/lib/features/location/application/location_controller.dart (_applyProfileUpdate, lines 398-434)
  found: >
    `_applyProfileUpdate` DOES correctly merge `ProfileUpdate` events into `state.selfPosition` when `update.userId == currentUserId` (line 427-429: `selfPosition: update.userId == currentUserId ? updatedLocation : _current.selfPosition`), including the new `displayName`, `profileImageUrl`, and a freshly stamped `profileUpdatedAt` (cache-bust).
  implication: The self-user's live profile data (name + avatar) IS available and IS kept live-updated in `LocationState.selfPosition` by the same 02-16 mechanism that updates the map markers. The header simply never reads this state — it's available data being ignored at the one call site that needs it.

- timestamp: 2026-07-14
  checked: "grep for other `MemberMapPin(label: 'You'` or `'Your family, live'` instantiations across mobile/lib"
  found: Exactly one match for each — both in live_map_screen.dart, confirming this is the single, isolated header composition described in the bug report (not duplicated elsewhere).
  implication: The fix is localized to one call site; no other screen/header shares this same static-avatar bug.

## Resolution

root_cause: >
  In `mobile/lib/features/location/presentation/live_map_screen.dart`, the Live Map header's identity indicator is composed as a hardcoded `const MemberMapPin(label: 'You', identityColor: AppColors.primaryTeal, isSelf: true, size: 36)`. This differs from the family-member map markers (`LiveMemberMarker`), which correctly source `profileImageUrl`, `profileUpdatedAt`, and `displayName` per-frame from `LocationState.members`/`selfPosition` — state that IS kept live by `LocationController._applyProfileUpdate` (built in plan 02-16, confirmed working). The header pin was never wired to read `state?.selfPosition` at all: it has both (a) a `const` modifier, which makes it a single unchanging widget instance immune to rebuilds regardless of state, and (b) no `userId`/`profileImageUrl`/`profileUpdatedAt` arguments passed even if `const` were removed. This is a call-site omission in 02-16's Task 3 (which extended `MemberMapPin`/`LiveMemberMarker` for the map pins but did not audit/update the pre-existing header usage of the same widget), not a missing capability — `MemberMapPin` itself already fully supports live avatars, proven by its correct use elsewhere in the same file.
fix: >
  Applied in plan 02-17 (gap_closure). Removed `const` from the header
  `MemberMapPin` instantiation in live_map_screen.dart and wired
  `userId`/`profileImageUrl`/`profileUpdatedAt` from `state?.selfPosition`,
  mirroring the existing `LiveMemberMarker` pattern. `label: 'You'` stays
  fixed; only the avatar now live-updates.
verification: >
  `flutter test test/features/location/live_map_screen_test.dart` passes
  (new TDD regression test, RED then GREEN — commits c522e4c/b59b567) and
  `flutter analyze` is clean. Physical-device confirmation (photo
  upload/replace/remove reflecting live on the header) is the plan's
  documented human-check step, tracked separately in 02-17-SUMMARY.md.
files_changed:
  - mobile/lib/features/location/presentation/live_map_screen.dart
  - mobile/test/features/location/live_map_screen_test.dart
