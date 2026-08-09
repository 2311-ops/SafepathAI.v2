# Phase 4: Geofencing - Context

**Gathered:** 2026-08-10
**Status:** Ready for planning

<domain>
## Phase Boundary

Deliver Guardian-managed safe zones for family members, reliable native enter/exit detection that suppresses GPS-drift false alarms, routine geofence notifications, and a per-zone activity history. Geofence processing must remain isolated from and must never delay or weaken the SOS fast path.

</domain>

<decisions>
## Implementation Decisions

### Zone creation
- **D-01:** Zone creation is map-first: the Guardian positions a movable pin and can use a **Use current location** shortcut.
- **D-02:** Radius selection combines quick presets with fine slider adjustment.
- **D-03:** Zones support both standard categories (Home, School, University, and Workplace) and custom names.
- **D-04:** Before saving, show a confirmation preview containing the zone circle, center, radius, assigned member, and notification settings.

### Alert sensitivity
- **D-05:** Favor reliability over immediacy near boundaries; a transition requires continuous inside/outside dwell confirmation, and crossing back resets the timer.
- **D-06:** Do not confirm a transition while the reported GPS accuracy range overlaps the zone boundary; wait for a clearly inside or outside reading.
- **D-07:** The Guardian can adjust sensitivity independently for each zone.

### Alert recipients and delivery
- **D-08:** Each zone has a configurable Guardian recipient list.
- **D-09:** The tracked member may receive their own enter/exit notification through a Guardian-controlled per-zone switch.
- **D-10:** Every confirmed transition must appear through push notification and in the in-app notification feed. The activity record remains durable even when push delivery fails.
- **D-11:** Geofence alerts are routine-priority and respect quiet hours. SOS remains high-priority, bypasses quiet hours, and is unaffected by geofence delivery behavior.

### Zone activity history
- **D-12:** Each activity entry shows the member, zone, transition type, exact timestamp, and completed visit duration.
- **D-13:** Display activity newest-first, grouped by day, and pair matching entry and exit events into one visit when possible.
- **D-14:** Guardians can filter history by family member, zone, transition type, and date range.
- **D-15:** Retain geofence activity for seven days, then delete it automatically.

### the agent's Discretion
- Exact radius preset values and slider bounds.
- Exact dwell/hysteresis thresholds and how each Guardian-facing sensitivity level maps to them, while honoring D-05 through D-07.
- Native geofencing package selection, permission flow details, and platform-specific recovery behavior, subject to current Android and iOS policy verification during research.
- Empty-state wording, visual styling, and loading/error presentation within established app patterns.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Product scope and requirements
- `.planning/PROJECT.md` — Product core value and the requirement that SOS always works independently of other features.
- `.planning/REQUIREMENTS.md` — GEO-01, GEO-02, GEO-03, and NOTIF-02 definitions.
- `.planning/ROADMAP.md` — Phase 4 boundary, dependencies, success criteria, and map dependency note.

### Location and map foundations
- `.planning/phases/02-real-time-location-history-privacy/02-CONTEXT.md` — Prior foreground-location and dwell-time decisions that Phase 4 must extend consistently.
- `.planning/phases/02-real-time-location-history-privacy/02-OSM-MIGRATION-IMPACT.md` — Map migration constraints and affected geofence visualization assumptions.
- `.planning/quick/260806-3zb-migrate-map-rendering-from-flutter-map-t/260806-3zb-SUMMARY.md` — Newer map-renderer migration outcome; current code is authoritative where older documents still mention `flutter_map`.

### SOS isolation
- `.planning/phases/03-sos-fast-path/03-CONTEXT.md` — Locked SOS delivery and isolation decisions that routine geofence notifications must not alter.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `mobile/lib/features/location/presentation/vector_map.dart`: Current map abstraction; supports metre-based `MapCircle` overlays and movable marker-style overlays without leaking the underlying map SDK.
- `mobile/lib/features/location/presentation/live_map_screen.dart`: Existing use of `VectorMap` and accuracy circles provides a visual pattern for zone previews.
- `mobile/lib/core/push/push_service.dart`: Existing token lifecycle and local heads-up notification mechanics can inform geofence delivery, but its SOS-specific routing and semantics must stay isolated.

### Established Patterns
- Map rendering is centralized behind `VectorMap`; new geofence UI should not import the map SDK directly.
- Current source uses MapLibre/OpenFreeMap even though older planning text mentions `flutter_map`; implementation should follow current source and the newer migration summary.
- Phase 2 established foreground location updates and SignalR live updates. Phase 4 research must explicitly resolve the native background-geofencing lifecycle without silently broadening general background tracking.
- Routine geofence notifications must use a distinct path from SOS notification behavior.

### Integration Points
- Zone creation and preview connect to the existing location presentation layer through `VectorMap`.
- Transition processing connects native OS geofencing to backend persistence, the in-app feed, push delivery, and seven-day activity cleanup.
- Recipient selection connects zones to existing family roles and membership data.

</code_context>

<specifics>
## Specific Ideas

- The save preview should make the configured circle and its assigned member immediately verifiable before activation.
- Sensitivity is user-facing per zone, but its implementation must still enforce accuracy-aware dwell confirmation rather than exposing raw technical thresholds without guidance.
- A paired visit is the preferred history representation; unmatched transitions may remain individual records until a counterpart exists.

</specifics>

<deferred>
## Deferred Ideas

### Reviewed Todos (not folded)
- Existing `FamilyController` cold-start todo — reviewed during Phase 4 discussion and deliberately kept outside this phase because it does not belong to geofencing scope.

</deferred>

---

*Phase: 4-Geofencing*
*Context gathered: 2026-08-10*
