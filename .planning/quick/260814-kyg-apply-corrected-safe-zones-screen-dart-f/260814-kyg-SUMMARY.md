---
phase: quick-260814-kyg
plan: 01
subsystem: ui
tags: [flutter, riverpod, design-system, geofencing, safe-zones]

requires:
  - phase: 04-geofencing
    provides: SafeZonesScreen/SafeZonesPage, GeofenceListController, VectorMap/MapCircle geometry helpers
provides:
  - "/safe-zones list matching the locked design system: zone-overview map header, per-category tinted icon tiles, per-zone switch (disabled when unwired), amber caution row, merged radius/member subtitle, hairline cards, single add affordance"
  - "mapOverride test seam wired through SafeZonesPage's list route"
  - "Repaired and extended widget/router test coverage for the corrected screen"
  - "Tracked pending todo for geofencing UI audit sections B-E"
affects: [geofencing-ui-polish, phase-05]

tech-stack:
  added: []
  patterns:
    - "mapOverride Riverpod provider seam for widget-testing screens that mount VectorMap (native platform view)"
    - "Disabled-when-unwired Switch pattern: passing null onChanged instead of wiring a lying/half-functional toggle"

key-files:
  created:
    - .planning/todos/pending/2026-08-14-geofencing-ui-audit-sections-b-e.md
  modified:
    - mobile/lib/features/geofencing/presentation/safe_zones_screen.dart
    - mobile/lib/features/geofencing/presentation/safe_zones_page.dart
    - mobile/test/features/geofencing/safe_zone_flow_test.dart
    - mobile/test/features/geofencing/safe_zone_router_flow_test.dart

key-decisions:
  - "onToggle left unwired (null) on SafeZonesScreen; no setActive method added to GeofenceListController — the backend's PUT /families/{id}/geofences/{zoneId} cannot express activation, and the only deactivation path (ZoneCommandValidation.Deactivate) is one-way with no re-activate endpoint. A wired switch would lie in both directions."
  - "Audit sections B (zone_activity_screen), C (safe_zone_detail_screen), D (notifications_screen), and E (cross-cutting AppCard/gutter/university styling) preserved as a pending todo rather than implemented — only section A (safe_zones_screen) was in scope for this quick task."

patterns-established:
  - "Screens that mount VectorMap take an optional mapOverride: Widget? param; route wrappers pass ref.watch(safeZoneMapOverrideProvider); widget tests pass a SizedBox.expand() stand-in."

requirements-completed: [GEO-01, DESIGN-01]

coverage:
  - id: D1
    description: "SafeZonesScreen replaced with design-system-correct version: map header, category-tinted icon tiles, per-zone switch/caution row, merged subtitle, hairline cards, single add affordance, 'Places & zones' title"
    requirement: "DESIGN-01"
    verification:
      - kind: unit
        ref: "mobile/test/features/geofencing/safe_zone_flow_test.dart#safe zones list renders empty, error, and truthful cards"
        status: pass
      - kind: unit
        ref: "mobile/test/features/geofencing/safe_zone_flow_test.dart#safe zones list map header renders through mapOverride"
        status: pass
      - kind: unit
        ref: "mobile/test/features/geofencing/safe_zone_flow_test.dart#safe zones list shows a category-specific icon tile per zone"
        status: pass
      - kind: unit
        ref: "mobile/test/features/geofencing/safe_zone_flow_test.dart#safe zones list wires onToggle to the tapped zone"
        status: pass
      - kind: unit
        ref: "mobile/test/features/geofencing/safe_zone_flow_test.dart#safe zones list shows exactly one add affordance"
        status: pass
    human_judgment: false
  - id: D2
    description: "SafeZonesPage passes mapOverride through to the list screen on all four safe-zone route wrappers, so router-level tests exercise real routing without crashing on a native platform view"
    requirement: "GEO-01"
    verification:
      - kind: integration
        ref: "mobile/test/features/geofencing/safe_zone_router_flow_test.dart#/safe-zones renders the family's zones with a real member name"
        status: pass
      - kind: integration
        ref: "mobile/test/features/geofencing/safe_zone_router_flow_test.dart#create journey: list -> add -> review -> save calls create once"
        status: pass
    human_judgment: false
  - id: D3
    description: "Audit sections B-E preserved as a tracked pending todo before deleting the handoff scratch files"
    verification:
      - kind: other
        ref: "grep -c 'zone_activity_screen|safe_zone_detail_screen|notifications_screen|AppCard' .planning/todos/pending/2026-08-14-geofencing-ui-audit-sections-b-e.md (10 matches)"
        status: pass
    human_judgment: false
  - id: D4
    description: "Visual verification that /safe-zones actually renders the intended design (map header, category tiles, hairline cards) on device/emulator"
    verification: []
    human_judgment: true
    rationale: "Widget tests confirm structural presence (widget types, text, icons) but not final visual fidelity against the hi-fi mockup — a human should glance at the rendered screen before considering section A fully closed."

duration: resumed session (~35min from Task 1 verification through Task 3 completion; Task 1's code was already present, uncommitted, from a prior interrupted run)
completed: 2026-08-14
status: complete
---

# Quick Task 260814-kyg: Apply corrected safe_zones_screen.dart fixes Summary

**Landed the design-system-correct `/safe-zones` list (map header, category-tinted icon tiles, per-zone switch, hairline cards, single add affordance), wired the `mapOverride` test seam, repaired/extended the widget and router tests it broke, and archived audit sections B-E as a pending todo before deleting the two root-level handoff scratch files.**

## Performance

- **Duration:** ~35 min for this session (resuming a prior interrupted executor run whose Task 1 changes were already correct but uncommitted)
- **Completed:** 2026-08-14T12:44:56Z
- **Tasks:** 3 completed
- **Files modified:** 5 (2 lib files, 2 test files, 1 new todo file) + 2 deleted root-level scratch files

## Accomplishments

- Replaced `safe_zones_screen.dart` with the corrected design-system version — zone-overview map header, 42px category-tinted icon tiles (Home safe-green, School/University primary-teal, Workplace member-violet, Custom body-secondary), per-zone `Switch` (disabled when `onToggle` is null), amber caution row for zones needing location permission, merged `"<radius> m · <member>"` subtitle, flat hairline-bordered cards, single circular add affordance, and the title "Places & zones"
- Wired `mapOverride: ref.watch(safeZoneMapOverrideProvider)` into `SafeZonesPage`'s list route, matching the pattern already used by the editor/review/detail route wrappers
- Confirmed `onToggle` stays unwired and no `setActive` method exists on `GeofenceListController`, per the plan's deferred-by-decision note (backend has no re-activation endpoint)
- Fixed all stale widget/router test assertions broken by the new screen structure and added five new test cases covering the map header seam, per-category icons, the wired toggle callback, and the single add affordance
- Preserved audit sections B (zone activity screen), C (safe zone detail screen), D (notifications screen), and E (cross-cutting: `AppCard`, screen gutter, university styling) as `.planning/todos/pending/2026-08-14-geofencing-ui-audit-sections-b-e.md`, flagging B2 (per-zone enter/exit notification toggles) as the one genuinely functional gap
- Deleted both root-level handoff scratch files (`GEOFENCING_UI_FIXES.md`, `safe_zones_screen.dart`)
- `flutter analyze`: no issues. Full mobile test suite: 437 tests passed.

## Task Commits

Each task was committed atomically:

1. **Task 1: Land the corrected screen and wire the map test seam** - `b3bbf01` (feat)
2. **Task 2: Repair and extend the widget and router tests** - `d8036cf` (test)
3. **Task 3: Preserve the unactioned audit findings, then delete the handoff files** - `6f689e5` (docs)

_Note: Task 1's code changes were already present in the working tree as uncommitted work from a prior interrupted executor run; this session verified them against the plan's done criteria (flutter analyze clean, code matches interface_contracts, onToggle/setActive correctly absent) before committing._

## Files Created/Modified

- `mobile/lib/features/geofencing/presentation/safe_zones_screen.dart` - Corrected design-system implementation (map header, category tiles, switch/caution row, hairline cards)
- `mobile/lib/features/geofencing/presentation/safe_zones_page.dart` - Added `mapOverride` wiring to the list route
- `mobile/test/features/geofencing/safe_zone_flow_test.dart` - Fixed stale assertions, added map header/category-icon/toggle/add-affordance coverage
- `mobile/test/features/geofencing/safe_zone_router_flow_test.dart` - Fixed merged-subtitle assertion and the create-journey add tap (now by icon)
- `.planning/todos/pending/2026-08-14-geofencing-ui-audit-sections-b-e.md` - New pending todo transcribing audit sections B-E
- `GEOFENCING_UI_FIXES.md` - Deleted (root-level handoff scratch file)
- `safe_zones_screen.dart` - Deleted (root-level handoff scratch file, distinct from the real file under `mobile/lib/...`)

## Decisions Made

- `onToggle` intentionally left `null`/unwired; no `setActive` added to `GeofenceListController` — the backend's `PUT /families/{id}/geofences/{zoneId}` cannot express activation at all (no `Active` field on the request/command, handler never writes `IsActive`, and the list query filters on `IsActive` so an inactive zone 404s). The only deactivation path (`ZoneCommandValidation.Deactivate`) is shared by disable/delete with no re-activate command anywhere. Wiring the switch to `update` would produce a control that lies in both directions — a safety-relevant false belief for a guardian. Deferred until a real activation endpoint exists.
- Audit sections B-E captured as a single pending todo (not four separate ones) so the original item identifiers (B1-B6, C1-C4, D1-D3, E1-E3) and the audit's own "suggested order" stay together and individually addressable without fragmenting context across multiple files.

## Deviations from Plan

None - plan executed exactly as written. Task 1's code (found already staged uncommitted from a prior interrupted run) was verified against every `done` criterion in the plan (all four constructors preserved, `onToggle`/`mapOverride` added as the only new params, no `FloatingActionButton`/`Chip` remnants, `flutter analyze` clean, `mapOverride` wired exactly once on the list route) before being committed — no rework was needed.

## Issues Encountered

- Initial draft of two new test cases (category-tile coverage) used `activeZone.copyWith(id: ..., category: ...)`, but `SafeZone.copyWith` only accepts an `activation` parameter (per the plan's own `<interface_contracts>` note). Caught immediately via a compile error on first test run; fixed by constructing separate `const SafeZone(...)` literals for the school/workplace test zones instead of trying to extend `copyWith`. No plan deviation — this was a test-authoring correction, not a source change.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Section A of the geofencing UI audit is fully closed on `/safe-zones`. `flutter analyze` clean, full 437-test mobile suite passes.
- Audit sections B-E are tracked in `.planning/todos/pending/2026-08-14-geofencing-ui-audit-sections-b-e.md` for future pickup; none of them block Phase 5.
- A human should glance at the rendered `/safe-zones` screen on device/emulator to confirm final visual fidelity against the hi-fi mockup (widget tests confirm structure, not pixel-level appearance) — see coverage item D4.

---
*Phase: quick-260814-kyg*
*Completed: 2026-08-14*

## Self-Check: PASSED

- All 5 created/modified files confirmed present on disk.
- Both root-level handoff scratch files confirmed deleted.
- All 3 task commit hashes (b3bbf01, d8036cf, 6f689e5) confirmed present in git log.
