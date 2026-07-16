# Phase 2: Real-Time Location, History & Privacy - Context

**Gathered:** 2026-07-12
**Status:** Ready for planning (addendum added 2026-07-13 — see below)

<domain>
## Phase Boundary

Family members can see each other's live and past location on a shared map, with full control over what's shared and with whom. Covers: live location tracking + presence (LOC-01..05), historical timeline/route/stats (HIST-01..03), low-battery alert (NOTIF-01), and the Privacy Center (PRIV-01..05). Does NOT cover SOS (Phase 3), geofencing (Phase 4), or AI analytics (Phase 5) — this phase is the data plumbing those later phases build on.

**Addendum (2026-07-13, additive post-close — User Profile & Map Identity):** Extends the live map with user identity — profile picture upload/replace/remove, editable display name, and avatar-bearing map markers with an online/offline indicator (PROFILE-01..07). This reuses the existing live-location pipeline (LOC-01/02) and its family-membership + sharing-preference authorization gate; it does not introduce a new visibility mechanism. Does NOT cover a general media/gallery feature, group/family-level avatars, or any profile field beyond display name + picture.

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

### User Profile & Map Identity (added 2026-07-13, additive post-close)

- **D-12:** Extend `User` (backend) with `DisplayName` (nullable string, independent of the Supabase-Auth-synced `FullName`), `ProfileImagePath` (nullable string — a Storage object **path**, not a URL) and `ProfileUpdatedAt` (nullable UTC timestamp). `DisplayName` falls back to `FullName` wherever rendered when unset — no member ever renders blank.
- **D-13:** Storage access is backend-mediated only. Mobile never calls Supabase Storage directly for profile images (even though `supabase_flutter` already exposes a storage client for auth) — authorization for "who can see whose avatar" must reuse the existing family-membership + `SharingPreference` server-side gate (02-PATTERNS.md "Server-side membership + role re-check"), which a direct client-side Storage call would bypass. Mobile uploads raw image bytes to a new ASP.NET Core endpoint; the backend validates and forwards to Supabase Storage's REST API using a service-role key (new `Supabase:ServiceRoleKey` config, sourced from environment/secrets exactly like `ConnectionStrings:DefaultConnection` — never committed to appsettings.json). Reads return a short-lived signed URL generated server-side, never a permanent public URL.
- **D-14:** Storage key convention: one deterministic object per user, `avatars/{userId}/avatar.jpg` (backend normalizes/re-encodes to JPEG server-side regardless of source format, per D-16). "Replace" overwrites the same key; "remove" deletes that key. No versioned filenames, no orphaned-object cleanup job needed.
- **D-15:** Validation is backend-enforced regardless of client behavior — a max upload size and a content-type check by sniffing file magic bytes server-side (never trusting the client's declared `Content-Type` or file extension), consistent with this codebase's existing "never trust client input" IDOR-prevention posture (02-PATTERNS.md). Reject anything that isn't a real JPEG/PNG/WebP.
- **D-16:** Client-side compression is a UX/bandwidth optimization only, not a trust boundary — mobile downscales/compresses before upload, but the backend re-validates/re-encodes independently per D-15 and must not assume the client complied.
- **D-17:** Avatar/name propagation does NOT ride on every `LocationUpdated` SignalR push (which stays lean: lat/lng/accuracy/battery only, unchanged). `DisplayName` + a signed `ProfileImageUrl` are delivered via (a) the existing `GetLiveLocationsQuery` REST snapshot, extended with both fields, fetched on screen load/reconnect, and (b) a new lightweight `ProfileUpdated(userId, displayName, profileImageUrl)` event added to `ILocationClient`, broadcast to the family SignalR group only when a member actually changes their name or picture. `location_controller.dart` merges `ProfileUpdated` into its per-member state the same way it already merges `PresenceChanged`.
- **D-18:** Default avatar reuses the existing `MemberMapPin` initial-letter treatment (`mobile/lib/shared_widgets/member_map_pin.dart`) — no separate default-avatar image asset is uploaded to Storage or bundled. `MemberMapPin` and the map marker widget in `live_map_screen.dart` (`_LiveMemberMarker`) both extend to render a circular cached network image when `profileImageUrl` is present, falling back to today's colored-initial circle when it is null — extend these existing widgets, do not build new ones from scratch.
- **D-19:** "Marker clustering compatibility" means markers must be structured so they could later be wrapped in `flutter_map_marker_cluster`'s cluster layer without a rewrite (a single `Marker`/child-widget shape, no per-marker global state) — it does NOT mean adding the `flutter_map_marker_cluster` dependency or building clustering now, matching 02-OSM-MIGRATION-IMPACT.md's existing note that clustering is optional at this scale. "Performance with multiple family members" is satisfied by adding `cached_network_image` (new dependency) so repeat marker rebuilds don't re-fetch the same signed URL.

### Claude's Discretion
- Exact dwell-time/radius thresholds for "stop" detection (D-05).
- Exact duration presets for temporary sharing (D-08).
- SignalR hub naming/shape and reconnection-handling details for D-02/D-03 (research/planner to design against the existing Clean Architecture Infrastructure-layer pattern used in Phase 1, e.g. keep hub logic behind an `INotificationService`-style abstraction per CLAUDE.md guidance).
- Exact max upload size / target compression dimensions for profile images (D-15/D-16) and exact signed-URL TTL for `ProfileImageUrl` (D-13/D-17) — long enough to comfortably outlive a foreground session.
- Exact REST route names for the new profile-image endpoints — follow the existing `MeController`/`ICommandHandler<TCommand,TResult>` convention (e.g. `PATCH /me/display-name`, `POST /me/profile-image`, `DELETE /me/profile-image`), extending `GET /me`'s response shape.
- Whether to offer a client-side center-crop-to-square step before compression (D-16) — a full cropping UI is not required; server-side normalization handles final framing.

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

### User Profile & Map Identity — existing code to extend (added 2026-07-13)
- `mobile/lib/features/profile/data/user_profile.dart`, `profile_controller.dart`, `profile_api.dart` — existing `/me` profile feature (currently userId/email/fullName/role only, `updateRole`). Extend in place with `displayName`/`profileImageUrl`/`profileUpdatedAt` and new `updateDisplayName`/`uploadProfileImage`/`deleteProfileImage` methods — do not create a parallel feature module.
- `backend/src/SafePath.Api/Controllers/MeController.cs` + `backend/src/SafePath.Domain/Entities/User.cs` — existing `GET /me` / `PATCH /me/role` endpoints and the `User` entity (`Id, Email, FullName, Role?, CreatedAt`) to extend with the new fields (D-12) and endpoints, following the exact `ICommandHandler<TCommand,TResult>` + constructor-injected-into-controller shape already used for `UpdateMyRoleCommand`/`GetMeQuery`.
- `mobile/lib/shared_widgets/member_map_pin.dart` — existing circular avatar widget (identity-color circle, initial-letter fallback, staleness opacity, online pulse dot) to extend with an optional avatar-image child (D-18), not replace.
- `mobile/lib/features/location/presentation/live_map_screen.dart` (`_LiveMemberMarker`) + `mobile/lib/features/location/data/location_models.dart` (`LiveLocation`) — current OSM marker rendering (post-`02-12` migration) and live-location model; extend `LiveLocation` with `profileImageUrl` and extend `_LiveMemberMarker` to render it, plus add the always-visible name label the requirement calls for (today the name only appears in the tap-triggered `member_detail_sheet.dart`).
- `backend/src/SafePath.Application/Location/LocationDtos.cs` (`MemberLiveLocationDto`) + the `GetLiveLocationsQuery` handler (02-PATTERNS.md) — extend the DTO with a signed `ProfileImageUrl` field; this query already applies the family-membership + `SharingPreference` double-gate, so extending it is how PROFILE-07's Family-Circle-only visibility is satisfied — do not build a new authorization path.
- `backend/src/SafePath.Api/appsettings.json` — existing `Supabase: { Url, Audience }` block; add `Supabase:ServiceRoleKey` sourced from environment/secrets (never committed), matching the `ConnectionStrings:DefaultConnection` env-injection convention already used in this file.
- `mobile/pubspec.yaml` — `supabase_flutter: ^2.16.0` is already a dependency but per D-13 is NOT used for profile-image calls. New dependencies needed: an image picker and `cached_network_image` (D-19); no `flutter_map_marker_cluster` addition (D-19 is compatibility only, not implementation).
- `.planning/phases/02-real-time-location-history-privacy/02-PATTERNS.md` — Phase 2's pattern map (command/query handler shape, Dio API-client error-mapping, Riverpod `AsyncNotifier` convention, EF entity+configuration pairing) applies directly to the new profile-image endpoints/entities; no new architectural pattern is introduced by this addendum.
- `.planning/phases/02-real-time-location-history-privacy/02-OSM-MIGRATION-IMPACT.md` — confirms `flutter_map`/`latlong2` is the current map stack and that `flutter_map_marker_cluster` is optional/deferred (D-19).

No other external specs/ADRs exist for this phase — requirements are otherwise fully captured in decisions above.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `backend/src/SafePath.Application/Families/` — existing per-member permission model (FAM-04) to extend for Privacy Center's per-data-type/per-recipient toggles (D-07), rather than building a new permission concept from scratch.
- `mobile/lib/features/family/` — existing family-circle UI/data/application layers (Riverpod-based) to extend with location/map/history/privacy screens as sibling or nested features.
- Mobile test convention established in Phase 1 (`FakeAuthApi`-style fakes, `ProviderContainer`-driven tests, no real network/Supabase calls) — carry this pattern into location/tracking tests.
- `mobile/lib/features/profile/` (`user_profile.dart`/`profile_controller.dart`/`profile_api.dart`) and `mobile/lib/shared_widgets/member_map_pin.dart` — existing profile feature + avatar widget (2026-07-13 addendum) to extend for PROFILE-01..07 per D-12/D-18; see `<canonical_refs>` for the full file list.

### Established Patterns
- Backend: Clean Architecture layering (Api → Application → Domain → Infrastructure), Repository Pattern, `ICurrentUserService` for the authenticated user, FluentValidation-style command/handler structure per Phase 1 family features.
- Mobile: Riverpod `Notifier`/`NotifierProvider` (not legacy `StateProvider` — unavailable in this project's `flutter_riverpod` 3.3.2, per Phase 01.1 decision).
- No SignalR, no `google_maps_flutter`/`geolocator`/`native_geofence` packages installed yet — this phase introduces all of them; nothing to migrate, but nothing to reuse either.

### Integration Points
- New SignalR location hub sits in Infrastructure layer, exposed via an abstraction (not referenced directly from Application layer), matching the CLAUDE.md-recommended `INotificationService`-style pattern already anticipated for Phase 3's SOS hub — keep the two hubs architecturally consistent since Phase 3 depends on Phase 2.
- New location/history/privacy mobile screens integrate into the existing bottom-nav/home shell alongside the `family` and `profile` features.
- Profile-image/display-name changes (2026-07-13 addendum) reuse the Location hub's existing `Groups.AddToGroupAsync(..., "family:{familyId}")` grouping (02-PATTERNS.md `LocationHub.OnConnectedAsync`) to broadcast the new `ProfileUpdated` event (D-17) — no new SignalR group or hub is created.

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
- Marker clustering implementation (`flutter_map_marker_cluster`) — deferred; only structural compatibility is required now (D-19).
- Group/family-level avatars, cover photos, or any profile field beyond display name + picture — out of scope for this addendum.
- A dedicated crop-to-circle UI before upload — server-side normalization (D-15/D-16) handles final framing; a client-side center-crop step is optional discretion, not a requirement.

### Reviewed Todos (not folded)
None — no pending todos matched this phase.

</deferred>

---

*Phase: 2-Real-Time Location, History & Privacy*
*Context gathered: 2026-07-12*
*Addendum gathered: 2026-07-13 — User Profile & Map Identity (PROFILE-01..07), additive post-close wave, force-replanned per operator confirmation*
