---
phase: 02-real-time-location-history-privacy
plan: 07
subsystem: mobile-location-presence
tags: [flutter, riverpod, google-maps, signalr, location, presence, battery]

requires:
  - phase: 02-real-time-location-history-privacy
    provides: SignalR LocationHubClient streams, live-location REST client, LiveMapScreen, foreground location controller, Phase 2 UI-SPEC staleness/battery contract
provides:
  - Pure staleness band and accuracy-radius mapping for live map pins
  - MemberMapPin staleness opacity, badges, accuracy circle, and live self-dot treatment
  - Independent member presence state beside latest location ping state
  - Live map marker staleness alpha, Google Maps accuracy circles, and member detail sheet on marker tap
  - LowBattery hub event stream, controller state, fake emitter, and dismissible caution banner
affects: [02-08, 02-09, 03-sos-fast-path]

tech-stack:
  added: []
  patterns:
    - "Staleness rendering is driven by a pure Dart mapper so UI opacity/badge behavior is unit-testable without widgets."
    - "LocationController keeps presence and ping recency as separate state maps; online/offline never substitutes for last-seen staleness."
    - "SignalR hub event additions remain typed streams on LocationHubClient with hand-written fake emitters for tests."

key-files:
  created:
    - mobile/lib/features/location/application/staleness.dart
    - mobile/lib/features/location/presentation/member_detail_sheet.dart
    - mobile/lib/features/location/presentation/low_battery_banner.dart
    - mobile/test/features/location/staleness_test.dart
    - mobile/test/features/location/member_presence_test.dart
    - mobile/test/features/location/low_battery_banner_test.dart
  modified:
    - mobile/lib/shared_widgets/member_map_pin.dart
    - mobile/lib/features/location/application/location_controller.dart
    - mobile/lib/features/location/data/location_hub_client.dart
    - mobile/lib/features/location/data/location_models.dart
    - mobile/lib/features/location/presentation/live_map_screen.dart
    - mobile/test/helpers/fake_location_hub_client.dart

key-decisions:
  - "Aligned the mobile LiveLocation model with the existing backend MemberLiveLocationDto by adding displayName and isOnline, while keeping hub PresenceChanged as a separate state signal."
  - "Implemented LowBattery as a typed client stream for the planned hub event even though 02-05-SUMMARY.md is absent and the backend event is not present yet; the mobile surface is additive and future-compatible."
  - "Used Google Maps Marker.alpha and Circle overlays for map staleness/accuracy, plus MemberMapPin's pure-widget accuracy rendering for the 24px screen-space minimum contract."

patterns-established:
  - "Member detail bottom sheets use a small MemberDetail DTO and showMemberDetailSheet helper so marker taps stay thin."
  - "Low-battery alerts are displayed with caution tokens only and dismissed through LocationController state."

requirements-completed: [LOC-02, LOC-03, NOTIF-01]

coverage:
  - id: D1
    description: "Pins use UI-SPEC staleness bands, never fade below 0.3 opacity, and map accuracy meters to a visible accuracy radius with a 24px widget minimum."
    requirement: LOC-03
    verification:
      - kind: unit
        ref: "mobile/test/features/location/staleness_test.dart"
        status: pass
      - kind: other
        ref: "Select-String staleness.dart/member_map_pin.dart -Pattern sosRed"
        status: pass
    human_judgment: false
  - id: D2
    description: "Member presence and last-seen are tracked independently: PresenceChanged flips ONLINE/OFFLINE without deleting the last known pin, and latest LocationUpdated controls last-seen."
    requirement: LOC-02
    verification:
      - kind: unit
        ref: "mobile/test/features/location/member_presence_test.dart"
        status: pass
      - kind: integration
        ref: "flutter test test/features/location/location_controller_test.dart"
        status: pass
    human_judgment: false
  - id: D3
    description: "Tapping a member marker opens a detail sheet with name, ONLINE/OFFLINE badge, and last-seen copy."
    requirement: LOC-02
    verification:
      - kind: automated_ui
        ref: "mobile/test/features/location/member_presence_test.dart#member detail sheet shows name, status badge, and last seen"
        status: pass
      - kind: integration
        ref: "flutter analyze lib/features/location"
        status: pass
    human_judgment: true
    rationale: "The sheet content is automated, but the real Google Maps marker tap path and visual placement still need device/manual map review."
  - id: D4
    description: "LowBattery hub events surface as a dismissible amber in-app banner with exact UI-SPEC copy and no SOS-red styling."
    requirement: NOTIF-01
    verification:
      - kind: automated_ui
        ref: "mobile/test/features/location/low_battery_banner_test.dart"
        status: pass
      - kind: integration
        ref: "flutter analyze lib/features/location"
        status: pass
      - kind: other
        ref: "Select-String low_battery_banner.dart -Pattern sosRed"
        status: pass
    human_judgment: false

duration: 12min
completed: 2026-07-12
status: complete
---

# Phase 02 Plan 07: Mobile Family Presence, Staleness, and Battery Alert Summary

**Live map trust signals now show staleness, accuracy, online/offline state, last-seen detail, and calm low-battery alerts.**

## Performance

- **Duration:** 12 min
- **Started:** 2026-07-12T20:52:57Z
- **Completed:** 2026-07-12T21:04:21Z
- **Tasks:** 3 completed
- **Files modified:** 12 plan files plus this summary

## Accomplishments

- Added a pure `stalenessFor` mapper and `accuracyCircleRadius` helper covering the UI-SPEC opacity bands, 0.3 floor, and 24px minimum accuracy radius.
- Expanded `MemberMapPin` and `LiveMapScreen` with staleness alpha, accuracy circles, and marker tap detail sheets.
- Added independent presence state in `LocationController` so connection status and last-ping staleness stay distinct.
- Added `LowBatteryAlert`, `LocationHubClient.lowBatteryAlerts`, fake hub emission, controller state, and a dismissible caution banner using the UI-SPEC copy.

## Task Commits

1. **Task 1 RED: Staleness mapping tests** - `59ccfc1` (test)
2. **Task 1 GREEN: Staleness bands + MemberMapPin accuracy** - `d11a061` (feat)
3. **Task 2 RED: Member presence tests** - `466d7dd` (test)
4. **Task 2 GREEN: Presence + last-seen + detail sheet** - `ea0fdd1` (feat)
5. **Task 3: Low-battery in-app banner** - `d49cda5` (feat)

**Plan metadata:** pending close-out commit

## Files Created/Modified

- `mobile/lib/features/location/application/staleness.dart` - Pure staleness and accuracy-radius contract.
- `mobile/lib/shared_widgets/member_map_pin.dart` - Staleness opacity, badge rendering, accuracy circle, and self live-dot treatment.
- `mobile/lib/features/location/data/location_models.dart` - Display name, online status, and low-battery alert models.
- `mobile/lib/features/location/data/location_hub_client.dart` - Typed `LowBattery` event stream.
- `mobile/test/helpers/fake_location_hub_client.dart` - Fake low-battery emitter.
- `mobile/lib/features/location/application/location_controller.dart` - Independent presence map and low-battery alert state/dismissal.
- `mobile/lib/features/location/presentation/live_map_screen.dart` - Marker alpha, accuracy circles, member detail sheet taps, and banner mount.
- `mobile/lib/features/location/presentation/member_detail_sheet.dart` - Name, ONLINE/OFFLINE badge, and last-seen bottom sheet.
- `mobile/lib/features/location/presentation/low_battery_banner.dart` - Dismissible amber low-battery banner.
- `mobile/test/features/location/staleness_test.dart` - Band edge/floor/min-radius unit tests.
- `mobile/test/features/location/member_presence_test.dart` - Presence, last-seen, and detail sheet tests.
- `mobile/test/features/location/low_battery_banner_test.dart` - Exact copy and dismissal widget test.

## Decisions Made

- Used backend `MemberLiveLocationDto`'s existing `DisplayName` and `IsOnline` contract to fill the mobile model gap needed for member names and initial online status.
- Kept presence and staleness independent in state: `members` holds latest pings, `memberPresence` holds hub connection state.
- Added mobile low-battery event handling ahead of the absent backend event summary because the plan explicitly required the client stream and banner surface.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Missing 02-05-SUMMARY.md read-first source**
- **Found during:** Task 3
- **Issue:** The plan instructed reading `02-05-SUMMARY.md` for the backend `LowBattery` hub event shape, but Plan 02-05 is still incomplete and the summary file does not exist.
- **Fix:** Implemented the mobile event stream from the explicit plan/UI-SPEC contract and existing hub-client event pattern, accepting `userId`, `name`/`displayName`, and `batteryPercent`/`pct` payload keys.
- **Files modified:** `location_models.dart`, `location_hub_client.dart`, `fake_location_hub_client.dart`, `location_controller.dart`, `low_battery_banner.dart`, `live_map_screen.dart`
- **Verification:** `flutter analyze lib/features/location`; `flutter test test/features/location/low_battery_banner_test.dart`
- **Committed in:** `d49cda5`

**2. [Rule 1 - Bug] Fixed missing LiveLocation import in LiveMapScreen**
- **Found during:** Task 2 focused analyze
- **Issue:** The marker detail helper referenced `LiveLocation` without importing `location_models.dart`.
- **Fix:** Added the missing import and reran focused tests/analyze.
- **Files modified:** `mobile/lib/features/location/presentation/live_map_screen.dart`
- **Verification:** `flutter analyze lib/features/location/application lib/features/location/presentation lib/features/location/data/location_models.dart lib/shared_widgets/member_map_pin.dart`
- **Committed in:** `ea0fdd1`

---

**Total deviations:** 2 auto-fixed (1 Rule 3 blocking plan-reference issue, 1 Rule 1 compile bug)
**Impact on plan:** The implementation stays within the planned mobile surface. The low-battery client is ready for the future backend event, but end-to-end NOTIF-01 still depends on Plan 02-05 emitting `LowBattery`.

## Issues Encountered

- Plan 02-05 is not complete, so the low-battery backend event is not available for an end-to-end test in this plan.

## User Setup Required

None new. Existing Google Maps API key setup from Plan 02-06 still applies for map tiles on device.

## Known Stubs

None. Stub-pattern scanning of the 02-07 production files found no TODO/FIXME/placeholder/coming-soon strings.

## Verification

- `flutter test test/features/location/staleness_test.dart` - passed.
- `flutter test test/features/location/member_presence_test.dart` - passed.
- `flutter test test/features/location/location_controller_test.dart` - passed as regression coverage.
- `flutter test test/features/location/low_battery_banner_test.dart` - passed.
- `flutter test test/features/location` - passed, 15 tests.
- `flutter analyze lib/features/location` - passed.
- `flutter analyze` - passed.
- No-red checks passed for `staleness.dart`, `member_map_pin.dart`, and `low_battery_banner.dart`.

## TDD Gate Compliance

- Task 1 RED commit present: `59ccfc1`
- Task 1 GREEN commit present after RED: `d11a061`
- Task 2 RED commit present: `466d7dd`
- Task 2 GREEN commit present after RED: `ea0fdd1`
- No refactor commit was needed.

## Next Phase Readiness

- Plan 02-08 can build mobile history screens without changing live-map trust signals.
- Plan 02-05 must still provide the backend low-battery falling-edge event for true end-to-end NOTIF-01 delivery.
- Plan 02-09 can reuse the no-red caution/neutral styling precedent for privacy surfaces.

---
*Phase: 02-real-time-location-history-privacy*
*Completed: 2026-07-12*

## Self-Check: PASSED

Created/modified plan files exist on disk (`staleness.dart`, `member_map_pin.dart`, `location_controller.dart`, `location_hub_client.dart`, `location_models.dart`, `live_map_screen.dart`, `member_detail_sheet.dart`, `low_battery_banner.dart`, and the three location tests); task commits `59ccfc1`, `d11a061`, `466d7dd`, `ea0fdd1`, and `d49cda5` are present in git log; plan-level verification commands listed above passed.
