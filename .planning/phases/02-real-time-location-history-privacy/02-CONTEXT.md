# Phase 2: Real-Time Location, History & Privacy - Context

**Gathered:** 2026-07-12
**Status:** Ready for planning

<domain>
## Phase Boundary

Family members can see each other's live and past location on a shared map, with full control over what's shared and with whom. Covers: live location tracking + presence (LOC-01..05), historical timeline/route/stats (HIST-01..03), low-battery alert (NOTIF-01), and the Privacy Center (PRIV-01..05). Does NOT cover SOS (Phase 3), geofencing (Phase 4), or AI analytics (Phase 5) — this phase is the data plumbing those later phases build on.

</domain>

<decisions>
## Implementation Decisions

### Live Tracking Mechanism
- **D-01:** Foreground-only tracking for MVP. Location updates while the app is open/active via `geolocator`. Background/killed-app tracking (`flutter_foreground_task` + native background service wiring) is explicitly deferred to a later hardening phase — not built now.
- **D-02:** Live location updates are delivered via SignalR push (a dedicated hub), not REST polling. Backend broadcasts location updates as they arrive; mobile clients subscribe and update the map in real time.
- **D-03:** Presence ("online/offline", "last-seen") is computed from both an explicit heartbeat/SignalR connection state AND location-ping recency — not a simple ping-timeout heuristic alone. This is a second state machine to build (connection open/close events) in addition to tracking last location-ping timestamp.

### Shared Map & History UX
- **D-04:** Stale/imprecise location is shown via a faded pin (opacity decreases with staleness) plus a translucent accuracy-radius circle around the pin.
- **D-05:** A "stop" in the historical timeline/travel stats is defined by a dwell-time threshold — staying within a small radius (e.g. ~100m) longer than a threshold (e.g. ~5 min). Exact radius/threshold values are Claude's discretion at planning time; the mechanism (dwell-time, not ML) is locked, and should stay consistent with how Phase 4 geofence dwell-time/hysteresis will later work.
- **D-06:** Historical route is visualized as a polyline drawn on the map (Google Maps), paired with a separate scrollable list/timeline below showing stops, distance, and time-away stats.

### Privacy Center
- **D-07:** Sharing toggles are a per-data-type × per-recipient matrix (live location / history / wellness, independently toggleable per family member) — reuses the existing FAM-04 per-member permission model from Phase 1 rather than introducing a new permission concept.
- **D-08:** Temporary auto-stopping location sharing uses a duration picker (e.g. 1h/4h/8h/custom); a scheduled flag/timer flips sharing back off automatically when it expires. Exact preset values are Claude's discretion.
- **D-09:** "Export data" (PRIV-04) produces a JSON download of the user's own location/history records for MVP — not a full GDPR-style multi-format export pipeline.

### Permission Priming & Battery Transparency
- **D-10:** The permission-priming screen (LOC-05) uses value-first framing — explains that location access lets the family see each other and is what makes SOS work, framed around safety benefit (consistent with SafePath's privacy-first/no-data-resale positioning). Shown once before the first OS location prompt; re-shown only if permission was previously denied and the user re-enters the flow.
- **D-11:** The battery-usage transparency screen (LOC-04) gives a plain-language estimate (foreground-only tracking = minimal battery impact, consistent with D-01) plus a couple of usage tips — no live battery graphs or detailed analytics needed for this phase.

### Claude's Discretion
- Exact dwell-time/radius thresholds for "stop" detection (D-05).
- Exact duration presets for temporary sharing (D-08).
- SignalR hub naming/shape and reconnection-handling details for D-02/D-03 (research/planner to design against the existing Clean Architecture Infrastructure-layer pattern used in Phase 1, e.g. keep hub logic behind an `INotificationService`-style abstraction per CLAUDE.md guidance).

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Project-level architecture & stack constraints
- `.claude/CLAUDE.md` — Project tech stack (geolocator, flutter_foreground_task, google_maps_flutter, SignalR `Hub<IAlertClient>` pattern, Clean Architecture layering), and the "no background-polling geofence" / "SOS bypass" constraints that also shape how the live-tracking pipeline must not become a future bottleneck for Phase 3.
- `.planning/REQUIREMENTS.md` — LOC-01..05, HIST-01..03, NOTIF-01, PRIV-01..05 (full requirement text, source of truth for acceptance criteria).
- `.planning/ROADMAP.md` §"Phase 2: Real-Time Location, History & Privacy" — phase goal, success criteria, dependency on Phase 1.
- `.planning/STATE.md` — "Blockers/Concerns" section notes Phase 4's dwell-time/hysteresis parameters need re-verification at build time; D-05 here should stay compatible with that future work.

### Prior-phase auth/family patterns to reuse
- Phase 1 family-permission model (FAM-04: per-member permissions — view-only/full-location/notification-only) — reuse this as the basis for the Privacy Center's per-recipient matrix (D-07). See `backend/src/SafePath.Application/Families/` and `backend/src/SafePath.Domain/Entities/` for the existing entity/permission shape.
- Phase 1 Supabase-owned-auth architecture (`.planning/phases/01-backend-auth-foundation/01-11-PLAN.md` and its SUMMARY) — backend validates Supabase JWTs; `ICurrentUserService` is the current-user mechanism new location/history/privacy endpoints must authenticate against.

No other external specs/ADRs exist for this phase — requirements are otherwise fully captured in decisions above.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `backend/src/SafePath.Application/Families/` — existing per-member permission model (FAM-04) to extend for Privacy Center's per-data-type/per-recipient toggles (D-07), rather than building a new permission concept from scratch.
- `mobile/lib/features/family/` — existing family-circle UI/data/application layers (Riverpod-based) to extend with location/map/history/privacy screens as sibling or nested features.
- Mobile test convention established in Phase 1 (`FakeAuthApi`-style fakes, `ProviderContainer`-driven tests, no real network/Supabase calls) — carry this pattern into location/tracking tests.

### Established Patterns
- Backend: Clean Architecture layering (Api → Application → Domain → Infrastructure), Repository Pattern, `ICurrentUserService` for the authenticated user, FluentValidation-style command/handler structure per Phase 1 family features.
- Mobile: Riverpod `Notifier`/`NotifierProvider` (not legacy `StateProvider` — unavailable in this project's `flutter_riverpod` 3.3.2, per Phase 01.1 decision).
- No SignalR, no `google_maps_flutter`/`geolocator`/`native_geofence` packages installed yet — this phase introduces all of them; nothing to migrate, but nothing to reuse either.

### Integration Points
- New SignalR location hub sits in Infrastructure layer, exposed via an abstraction (not referenced directly from Application layer), matching the CLAUDE.md-recommended `INotificationService`-style pattern already anticipated for Phase 3's SOS hub — keep the two hubs architecturally consistent since Phase 3 depends on Phase 2.
- New location/history/privacy mobile screens integrate into the existing bottom-nav/home shell alongside the `family` and `profile` features.

</code_context>

<specifics>
## Specific Ideas

No further specific UI examples or reference apps were given beyond "Life360/Find My style" faded-pin staleness treatment (D-04) and "matches typical family-safety app UX" for the polyline + stats-list history view (D-06).

</specifics>

<deferred>
## Deferred Ideas

- Full background/killed-app location tracking (`flutter_foreground_task`) — explicitly deferred past this phase's MVP scope (see D-01); revisit as a hardening pass once foreground tracking is proven.
- Live battery-usage graphs/detailed analytics on the battery transparency screen — deferred in favor of plain-language messaging (D-11).
- Full GDPR-style multi-format/multi-scope data export — deferred in favor of a simple JSON-of-own-history export (D-09).

### Reviewed Todos (not folded)
None — no pending todos matched this phase.

</deferred>

---

*Phase: 2-Real-Time Location, History & Privacy*
*Context gathered: 2026-07-12*
