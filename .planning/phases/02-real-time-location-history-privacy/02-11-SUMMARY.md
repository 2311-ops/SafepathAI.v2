---
phase: 02-real-time-location-history-privacy
plan: 11
subsystem: mobile-privacy
tags: [flutter, riverpod, privacy, temporary-sharing, widget-tests]

requires:
  - phase: 02-real-time-location-history-privacy
    provides: Backend temporary sharing expiry and PrivacyController.startTemporaryShare
  - phase: 02-real-time-location-history-privacy
    provides: Mobile Privacy Center sharing matrix from 02-09
provides:
  - Recipient-scoped temporary live-location sharing controls in the Privacy Center
  - Custom duration dialog with minutes/hours input validation and 7-day cap
  - Widget coverage for non-first-recipient temporary sharing and user-entered custom duration
affects: [03-sos-fast-path, 05-ai-analytics-family-dashboard, 07-health-wellness-module]

tech-stack:
  added: []
  patterns:
    - "Temporary sharing controls live under each recipient row and always pass that row's memberId."
    - "Custom duration input validates in the dialog before constructing a Duration."

key-files:
  created:
    - .planning/phases/02-real-time-location-history-privacy/02-11-SUMMARY.md
  modified:
    - mobile/lib/features/privacy/presentation/privacy_center_screen.dart
    - mobile/test/features/privacy/privacy_center_screen_test.dart

key-decisions:
  - "Temporary sharing is recipient-scoped inside each recipient row instead of a global Privacy Center section."
  - "Custom duration defaults to hours but exposes a minutes/hours unit choice and rejects invalid or longer-than-7-day values."
  - "Active temporary-share context is filtered to the matching recipient's live-location sharing cell."

patterns-established:
  - "Use stable keys of the form temporary-share-<memberId>-<duration> for Privacy Center recipient controls."
  - "Use custom-duration-field and custom-duration-unit keys for custom duration dialog coverage."

requirements-completed: [PRIV-03]

coverage:
  - id: D1
    description: "A 4-hour temporary share started from a non-first recipient row calls PrivacyController.startTemporaryShare with that row's memberId."
    requirement: PRIV-03
    verification:
      - kind: automated_ui
        ref: "mobile/test/features/privacy/privacy_center_screen_test.dart#4-hour duration chip uses the selected recipient row"
        status: pass
      - kind: other
        ref: "Select-String privacy_center_screen.dart -Pattern recipients.first.memberId"
        status: pass
    human_judgment: false
  - id: D2
    description: "Custom opens a duration input dialog and passes the user-entered positive duration to PrivacyController.startTemporaryShare."
    requirement: PRIV-03
    verification:
      - kind: automated_ui
        ref: "mobile/test/features/privacy/privacy_center_screen_test.dart#custom duration accepts user-entered hours"
        status: pass
      - kind: other
        ref: "Select-String privacy_center_screen.dart -Pattern onPresetSelected!(const Duration(hours: 1))"
        status: pass
    human_judgment: false
  - id: D3
    description: "Advertised 1 hour, 4 hours, 8 hours, and Custom controls remain visible for temporary live-location sharing."
    requirement: PRIV-03
    verification:
      - kind: automated_ui
        ref: "mobile/test/features/privacy/privacy_center_screen_test.dart#renders toggle matrix and duration controls"
        status: pass
    human_judgment: false

duration: 7min
completed: 2026-07-13
status: complete
---

# Phase 02 Plan 11: PRIV-03 Temporary Sharing UI Gap Summary

**Recipient-scoped temporary live-location sharing with real custom duration input in the Flutter Privacy Center.**

## Performance

- **Duration:** 7 min
- **Started:** 2026-07-12T22:51:59Z
- **Completed:** 2026-07-12T22:58:45Z
- **Tasks:** 2 completed
- **Files modified:** 2 production/test files plus this summary

## Accomplishments

- Added RED widget coverage for two non-self recipients, proving a 4-hour temporary share can target the second recipient instead of an implicit first recipient.
- Moved temporary sharing controls under each recipient row and wired presets to `PrivacyController.startTemporaryShare(recipientId: recipient.memberId, dataType: SharedDataType.liveLocation, duration: chosenDuration)`.
- Replaced the fixed Custom preset with a duration dialog that accepts minutes or hours, rejects empty/non-numeric/non-positive/greater-than-7-day values, and passes the parsed `Duration`.
- Made active-share remaining-time context recipient-aware by filtering to the matching recipient's live-location sharing cell.

## Task Commits

Each task was committed atomically:

1. **Task 1 RED: Recipient/custom duration widget tests** - `e8d663a` (test)
2. **Task 2 GREEN: Recipient-scoped temporary sharing UI** - `50698e8` (feat)

**Plan metadata:** pending close-out commit

## Files Created/Modified

- `mobile/test/features/privacy/privacy_center_screen_test.dart` - Seeds two recipients, records temporary share calls, and covers non-first-recipient plus custom-duration flows.
- `mobile/lib/features/privacy/presentation/privacy_center_screen.dart` - Renders per-recipient temporary sharing controls, custom duration dialog, validation, stable keys, and recipient-aware active-share context.

## Decisions Made

- Temporary sharing controls were attached directly to each recipient row to make "who receives it" explicit at the point of action.
- Custom durations default to hours in the dialog because the advertised presets are hour-based, while the unit dropdown still supports minutes for shorter shares.
- Active-share copy now only appears for the matching recipient's live-location temporary share, avoiding misleading global context.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Removed disposed TextEditingController from the custom duration dialog**
- **Found during:** Task 2 verification
- **Issue:** The dialog initially disposed its `TextEditingController` as the route animated out, which caused a widget rebuild error in the custom-duration test and could affect runtime dialog dismissal.
- **Fix:** Stored the typed duration through `onChanged` state in the dialog instead of owning a disposable controller.
- **Files modified:** `mobile/lib/features/privacy/presentation/privacy_center_screen.dart`
- **Verification:** `flutter test test/features/privacy/privacy_center_screen_test.dart` passed.
- **Committed in:** `50698e8`

**2. [Rule 3 - Blocking] Updated DropdownButtonFormField API usage for analyzer compliance**
- **Found during:** Task 2 verification
- **Issue:** `flutter analyze lib/features/privacy` rejected the new dropdown's deprecated `value:` parameter.
- **Fix:** Switched to `initialValue:` for the unit dropdown.
- **Files modified:** `mobile/lib/features/privacy/presentation/privacy_center_screen.dart`
- **Verification:** `flutter analyze lib/features/privacy` passed.
- **Committed in:** `50698e8`

**Total deviations:** 2 auto-fixed (1 bug, 1 blocking verification issue)
**Impact on plan:** Both fixes were required for correctness and clean verification; no scope beyond the PRIV-03 UI gap was added.

## Issues Encountered

- The RED tests were tightened during Task 2 to scroll by Flutter's internal `Scrollable` instead of the `ListView` widget, keeping assertions stable with lazy list rendering.

## Auth Gates

None.

## User Setup Required

None - no external service configuration required.

## Known Stubs

None in files created or modified by this plan. Scoped stub scan found only normal null checks in the Privacy Center code.

## Threat Flags

None. The changed surface stays within the plan threat model: user-controlled recipient and duration inputs are passed to the existing privacy controller path, with validation before constructing the custom `Duration`.

## Verification

- `flutter test test/features/privacy/privacy_center_screen_test.dart` - passed, 5 tests.
- `flutter analyze lib/features/privacy` - passed, no issues.
- Source assertion: `recipients.first.memberId` - no matches.
- Source assertion: `onPresetSelected!(const Duration(hours: 1))` - no matches.

## TDD Gate Compliance

- RED commit present: `e8d663a`
- GREEN commit present after RED: `50698e8`
- No refactor commit was needed.

## Next Phase Readiness

- Phase 02 PRIV-03 UI verification gap is closed for recipient choice and Custom duration input.
- Phase 03 SOS work can continue to treat routine privacy sharing as user-controlled while preserving SOS bypass semantics separately.

---
*Phase: 02-real-time-location-history-privacy*
*Completed: 2026-07-13*

## Self-Check: PASSED

Created/modified plan artifacts exist on disk (`privacy_center_screen.dart`, `privacy_center_screen_test.dart`, and `02-11-SUMMARY.md`); task commits `e8d663a` and `50698e8` are present in git log; final verification commands listed above passed.
