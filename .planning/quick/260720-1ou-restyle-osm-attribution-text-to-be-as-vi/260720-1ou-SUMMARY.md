---
phase: quick-260720-1ou
plan: 01
subsystem: ui
tags: [flutter, flutter_map, osm-attribution, design-tokens]

requires: []
provides:
  - Shared const OsmAttribution widget (small/muted/low-opacity OSM credit chip)
  - Both maps (Live Map, route-history map) now share one attribution treatment
affects: [location, map-ui]

tech-stack:
  added: []
  patterns:
    - "Shared presentational widgets for FlutterMap children (OsmAttribution) reused via relative import instead of duplicated inline SimpleAttributionWidget"

key-files:
  created:
    - mobile/lib/features/location/presentation/osm_attribution.dart
    - mobile/test/features/location/osm_attribution_test.dart
  modified:
    - mobile/lib/features/location/presentation/live_map_screen.dart
    - mobile/lib/features/location/presentation/route_stats_sheet.dart

key-decisions:
  - "Kept flutter_map's SimpleAttributionWidget (no new dependency, no RichAttributionWidget) — only restyled its source Text/backgroundColor"
  - "Styled the credit text via AppTypography.bodySecondary.copyWith(fontSize: 9, alpha 0.55) and AppColors.surface at alpha 0.45 background — no hardcoded colors/fonts"

patterns-established:
  - "Pattern: small always-visible map overlay credits reuse AppTypography roles via .copyWith rather than inventing new TextStyle literals"

requirements-completed: [OSM-ATTRIB-MINIMAL]

coverage:
  - id: D1
    description: "Shared OsmAttribution widget renders the ODbL-required 'OpenStreetMap contributors' credit as small/muted/low-opacity text"
    requirement: "OSM-ATTRIB-MINIMAL"
    verification:
      - kind: unit
        ref: "mobile/test/features/location/osm_attribution_test.dart#renders the OpenStreetMap credit text"
        status: pass
    human_judgment: false
  - id: D2
    description: "Live Map and route-history map both render OsmAttribution as their final FlutterMap child, replacing the duplicated inline SimpleAttributionWidget"
    requirement: "OSM-ATTRIB-MINIMAL"
    verification:
      - kind: unit
        ref: "mobile/test/features/location/live_map_screen_test.dart (existing suite, all 9 cases)"
        status: pass
      - kind: unit
        ref: "mobile/test/features/location/route_stats_sheet_test.dart (existing suite)"
        status: pass
      - kind: other
        ref: "flutter analyze lib/features/location/presentation/{live_map_screen,route_stats_sheet,osm_attribution}.dart"
        status: pass
    human_judgment: false

duration: 8min
completed: 2026-07-19
status: complete
---

# Quick Task 260720-1ou: Restyle OSM attribution text Summary

**Shared `OsmAttribution` widget replaces the duplicated default `SimpleAttributionWidget` chip on both maps with a small (9px), muted (55% alpha), low-opacity credit on a faint translucent background — always visible, never hidden.**

## Performance

- **Duration:** 8 min
- **Started:** 2026-07-19T22:14:00Z
- **Completed:** 2026-07-19T22:22:47Z
- **Tasks:** 2
- **Files modified:** 4 (2 created, 2 modified)

## Accomplishments
- Created `OsmAttribution`, a const `StatelessWidget` wrapping flutter_map's `SimpleAttributionWidget` with design-token-derived minimal styling (no new dependency)
- Added a Nyquist widget test proving the ODbL-required credit text still renders
- Replaced the two duplicated inline `SimpleAttributionWidget(...)` usages in `live_map_screen.dart` and `route_stats_sheet.dart` with `const OsmAttribution()`

## Task Commits

Each task was committed atomically:

1. **Task 1: Create shared minimal OsmAttribution widget + Nyquist test** - `acfe931` (feat)
2. **Task 2: Wire both maps to OsmAttribution** - `0dd46cf` (feat)

**Plan metadata:** (this commit)

## Files Created/Modified
- `mobile/lib/features/location/presentation/osm_attribution.dart` - Shared const widget rendering the minimal OSM credit chip
- `mobile/test/features/location/osm_attribution_test.dart` - Widget test asserting the credit text renders
- `mobile/lib/features/location/presentation/live_map_screen.dart` - Live Map's FlutterMap now uses `const OsmAttribution()` as its final child
- `mobile/lib/features/location/presentation/route_stats_sheet.dart` - Route-history map's FlutterMap now uses `const OsmAttribution()` as its final child

## Decisions Made
- Reused `AppTypography.bodySecondary` and `AppColors.bodySecondary` / `AppColors.surface` via `.copyWith(...)` and `.withValues(alpha: ...)` rather than introducing new hardcoded colors/fonts, per the plan's design-token constraint.
- Kept `SimpleAttributionWidget` (already a dependency in use) instead of switching to `RichAttributionWidget`, avoiding unnecessary scope/complexity for a purely visual restyle.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- Both maps now share a single attribution treatment; any future restyling only needs to touch `osm_attribution.dart`.
- No blockers for subsequent location/map work.

---
*Phase: quick-260720-1ou*
*Completed: 2026-07-19*

## Self-Check: PASSED

- FOUND: mobile/lib/features/location/presentation/osm_attribution.dart
- FOUND: mobile/test/features/location/osm_attribution_test.dart
- FOUND: commit acfe931
- FOUND: commit 0dd46cf
