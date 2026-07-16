---
phase: 02-real-time-location-history-privacy
plan: 09
subsystem: mobile-privacy
tags: [flutter, riverpod, privacy, sharing-matrix, share-plus, ui]

requires:
  - phase: 02-real-time-location-history-privacy
    provides: SharingPreference backend matrix and update endpoints
  - phase: 02-real-time-location-history-privacy
    provides: Privacy export/delete/policy backend endpoints
  - phase: 02-real-time-location-history-privacy
    provides: Authenticated mobile shell and family state
provides:
  - Mobile PrivacyApi and PrivacyController for sharing matrix, temporary shares, export, delete, and policy retrieval
  - Privacy Center tab with per-recipient/per-data-type toggles and temporary sharing controls
  - Ink-styled export/delete/policy actions, confirmation-gated delete, and no-data-resale policy screen
affects: [03-sos-fast-path, 05-ai-analytics-family-dashboard, 07-health-wellness-module]

tech-stack:
  added: []
  patterns:
    - "Mobile privacy state mirrors the FamilyController AsyncNotifier pattern and reacts to auth plus loaded family state."
    - "Sharing toggles are optimistic but always PATCH the backend and revert on failure."
    - "Privacy destructive actions use Ink text plus confirmation friction instead of SOS red."

key-files:
  created:
    - mobile/lib/features/privacy/data/privacy_api.dart
    - mobile/lib/features/privacy/data/privacy_models.dart
    - mobile/lib/features/privacy/application/privacy_controller.dart
    - mobile/lib/features/privacy/presentation/privacy_center_screen.dart
    - mobile/lib/features/privacy/presentation/privacy_policy_screen.dart
    - mobile/lib/shared_widgets/toggle_row.dart
    - mobile/test/features/privacy/privacy_controller_test.dart
    - mobile/test/features/privacy/privacy_center_screen_test.dart
    - mobile/test/features/privacy/privacy_policy_screen_test.dart
    - mobile/test/helpers/fake_privacy_api.dart
  modified:
    - mobile/lib/features/home/presentation/main_shell.dart
    - mobile/lib/core/router/app_router.dart

key-decisions:
  - "PrivacyController loads the sharing matrix from the current FamilyController family rather than duplicating family discovery."
  - "Temporary sharing uses an injectable privacyNowProvider clock so expiry and remaining-time behavior are deterministic in tests."
  - "Export shares the returned JSON through the existing share_plus ShareParams text path without adding a storage dependency."
  - "Delete my data uses AppColors.ink at 700 weight and the UI-SPEC confirmation copy; no SOS-red token appears in the Privacy Center."

patterns-established:
  - "Use FakePrivacyApi implements PrivacyApi for mobile privacy tests."
  - "Use ToggleRow for labeled SafePath switch rows with primaryTeal active track and toggleOffTrack inactive track."
  - "Policy screens can fetch static authenticated backend policy DTOs through feature APIs and render them as SafePathCard sections."

requirements-completed: [PRIV-02, PRIV-03, PRIV-04, PRIV-05]

coverage:
  - id: D1
    description: "PrivacyApi, PrivacyController, and models load the sharing matrix, PATCH toggle changes, revert on failure, and expose temporary-share remaining time."
    requirement: PRIV-02
    verification:
      - kind: unit
        ref: "mobile/test/features/privacy/privacy_controller_test.dart"
        status: pass
      - kind: integration
        ref: "flutter test test/features/privacy"
        status: pass
    human_judgment: false
  - id: D2
    description: "Privacy Center renders per-recipient live-location/history/wellness ToggleRows and calls PrivacyController on toggle changes."
    requirement: PRIV-02
    verification:
      - kind: automated_ui
        ref: "mobile/test/features/privacy/privacy_center_screen_test.dart#renders toggle matrix and duration controls"
        status: pass
      - kind: automated_ui
        ref: "mobile/test/features/privacy/privacy_center_screen_test.dart#tapping a toggle calls the privacy controller"
        status: pass
    human_judgment: false
  - id: D3
    description: "Temporary sharing duration chips render and start time-boxed live-location sharing with active remaining-time context."
    requirement: PRIV-03
    verification:
      - kind: automated_ui
        ref: "mobile/test/features/privacy/privacy_center_screen_test.dart#duration chip starts temporary live-location sharing"
        status: pass
      - kind: unit
        ref: "mobile/test/features/privacy/privacy_controller_test.dart#temporary share sets expiry and exposes remaining time"
        status: pass
    human_judgment: false
  - id: D4
    description: "Privacy Center export/delete actions call backend-backed controller methods; delete is confirmation-gated and Ink-styled."
    requirement: PRIV-04
    verification:
      - kind: unit
        ref: "mobile/test/features/privacy/privacy_controller_test.dart#export failure surfaces the exact UI copy"
        status: pass
      - kind: automated_ui
        ref: "mobile/test/features/privacy/privacy_center_screen_test.dart#delete data is confirmation-gated"
        status: pass
      - kind: other
        ref: "Select-String privacy_center_screen.dart -Pattern sosRed"
        status: pass
    human_judgment: false
  - id: D5
    description: "Privacy policy route renders the backend no-data-resale commitment and Privacy tab hosts the real Privacy Center."
    requirement: PRIV-05
    verification:
      - kind: automated_ui
        ref: "mobile/test/features/privacy/privacy_policy_screen_test.dart"
        status: pass
      - kind: integration
        ref: "flutter analyze"
        status: pass
    human_judgment: false

duration: 11min
completed: 2026-07-13
status: complete
---

# Phase 02 Plan 09: Mobile Privacy Center Summary

**Flutter Privacy Center with server-backed sharing toggles, temporary sharing, JSON export/delete controls, and no-data-resale policy access.**

## Performance

- **Duration:** 11 min
- **Started:** 2026-07-12T21:38:50Z
- **Completed:** 2026-07-12T21:50:09Z
- **Tasks:** 3 completed
- **Files modified:** 12 production/test files plus this summary

## Accomplishments

- Added `PrivacyApi`, `PrivacyController`, privacy models, and `FakePrivacyApi` for server-backed sharing matrix, toggle mutation, temporary sharing, export, delete, and policy operations.
- Built the Privacy Center UI with per-recipient live-location/history/wellness toggles, duration chips, active-share remaining-time context, and no SOS-red styling.
- Added subordinate export/delete/policy actions, confirmation-gated Ink delete, `/privacy/policy`, and replaced the Privacy tab placeholder with the real screen.

## Task Commits

1. **Task 1 RED: Privacy controller tests** - `4c1a6c0` (test)
2. **Task 1 GREEN: Privacy API/controller** - `d61686b` (feat)
3. **Task 2: Sharing matrix UI** - `e8d1bc8` (feat)
4. **Task 3: Export/delete/policy wiring** - `186bdc9` (feat)

**Plan metadata:** pending close-out commit

## Files Created/Modified

- `mobile/lib/features/privacy/data/privacy_models.dart` - Sharing matrix, sharing cell, shared data type, and privacy policy models.
- `mobile/lib/features/privacy/data/privacy_api.dart` - Abstract privacy API, Dio implementation, provider, and UI-copy-aware error mapping.
- `mobile/lib/features/privacy/application/privacy_controller.dart` - Auth/family-reactive privacy state controller with optimistic toggles, rollback, temporary expiry, export, and delete.
- `mobile/lib/features/privacy/presentation/privacy_center_screen.dart` - Matrix UI, temporary-sharing controls, export/delete/policy actions, and confirmation dialog.
- `mobile/lib/features/privacy/presentation/privacy_policy_screen.dart` - Scrollable no-data-resale policy screen.
- `mobile/lib/shared_widgets/toggle_row.dart` - Reusable labeled switch card.
- `mobile/lib/features/home/presentation/main_shell.dart` - Privacy tab now hosts `PrivacyCenterScreen`.
- `mobile/lib/core/router/app_router.dart` - Authenticated `/privacy/policy` route.
- `mobile/test/features/privacy/*.dart` and `mobile/test/helpers/fake_privacy_api.dart` - Controller, widget, policy, and fake coverage.

## Decisions Made

- `PrivacyController` derives `familyId` from `FamilyController`, matching the established Phase 02 mobile pattern and avoiding duplicate family lookup.
- Export uses the OS share sheet with JSON text via existing `share_plus`; no file-storage dependency was added.
- Delete uses UI-SPEC friction and Ink styling instead of red, preserving SOS red exclusively for emergency surfaces.

## Deviations from Plan

None - plan executed as written.

## Issues Encountered

- Widget test delete confirmation initially tapped an off-screen text node; fixed the test by scrolling the list before tapping. Production code was unchanged.
- Controller export-error test initially disposed before `FamilyController` bootstrap settled; fixed the test setup by awaiting the family/privacy bootstrap first. Production code was unchanged.

## Auth Gates

None.

## User Setup Required

None - no external service configuration required.

## Known Stubs

| File | Line | Stub | Reason |
|------|------|------|--------|
| `mobile/lib/features/home/presentation/main_shell.dart` | 52 | "Emergency tools are coming soon." | Pre-existing Phase 02 shell placeholder; SOS behavior is Phase 03 scope and was not modified by this plan. |
| `mobile/lib/features/home/presentation/main_shell.dart` | 57 | "Insights are coming soon" | Pre-existing Phase 02 shell placeholder; Insights are Phase 05 scope and were not modified by this plan. |

No stubs exist in the new privacy feature files that prevent the Privacy Center goal from being achieved.

## Threat Flags

None. The new mobile surfaces match the plan threat model: toggles PATCH the server enforcement point, export/delete send no target user id, and delete is confirmation-gated.

## Verification

- `flutter test test/features/privacy` - passed, 10 tests.
- `flutter analyze` - passed, no issues.
- `Select-String` no-red design check across Privacy Center, ToggleRow, battery, live-map, and member-pin files - passed.

## TDD Gate Compliance

- RED commit present: `4c1a6c0`
- GREEN commit present after RED: `d61686b`
- No refactor commit was needed.

## Next Phase Readiness

- Phase 03 can rely on Privacy Center copy that explicitly reassures users that SOS receives live location regardless of routine sharing toggles.
- Future health/wellness work can populate the already-visible Wellness sharing axis without adding a new privacy-control surface.

---
*Phase: 02-real-time-location-history-privacy*
*Completed: 2026-07-13*

## Self-Check: PASSED

Created/modified plan artifacts exist on disk (`privacy_api.dart`, `privacy_models.dart`, `privacy_controller.dart`, `privacy_center_screen.dart`, `privacy_policy_screen.dart`, `toggle_row.dart`, `main_shell.dart`, `app_router.dart`, privacy tests, `fake_privacy_api.dart`, and `02-09-SUMMARY.md`); task commits `4c1a6c0`, `d61686b`, `e8d1bc8`, and `186bdc9` are present in git log; final verification commands listed above passed.
