# Phase 2: Real-Time Location, History & Privacy - Research

**Researched:** 2026-07-12
**Domain:** Real-time push (SignalR) + foreground GPS streaming (geolocator/google_maps_flutter) + EF Core/Postgres location-history persistence + a permission/privacy data model extension
**Confidence:** MEDIUM (backend/SignalR patterns HIGH — verified against current Microsoft Learn docs; mobile package facts MEDIUM — verified directly against pub.dev but the research tooling's generic confidence classifier scores raw WebFetch as LOW by default, see Metadata; dwell-time/thresholds and the privacy-matrix schema shape are this agent's engineering recommendations, tagged ASSUMED)

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01:** Foreground-only tracking for MVP. Location updates while the app is open/active via `geolocator`. Background/killed-app tracking (`flutter_foreground_task` + native background service wiring) is explicitly deferred to a later hardening phase — not built now.
- **D-02:** Live location updates are delivered via SignalR push (a dedicated hub), not REST polling. Backend broadcasts location updates as they arrive; mobile clients subscribe and update the map in real time.
- **D-03:** Presence ("online/offline", "last-seen") is computed from both an explicit heartbeat/SignalR connection state AND location-ping recency — not a simple ping-timeout heuristic alone. This is a second state machine to build (connection open/close events) in addition to tracking last location-ping timestamp.
- **D-04:** Stale/imprecise location is shown via a faded pin (opacity decreases with staleness) plus a translucent accuracy-radius circle around the pin.
- **D-05:** A "stop" in the historical timeline/travel stats is defined by a dwell-time threshold — staying within a small radius (e.g. ~100m) longer than a threshold (e.g. ~5 min). Exact radius/threshold values are Claude's discretion at planning time; the mechanism (dwell-time, not ML) is locked, and should stay consistent with how Phase 4 geofence dwell-time/hysteresis will later work.
- **D-06:** Historical route is visualized as a polyline drawn on the map (Google Maps), paired with a separate scrollable list/timeline below showing stops, distance, and time-away stats.
- **D-07:** Sharing toggles are a per-data-type × per-recipient matrix (live location / history / wellness, independently toggleable per family member) — reuses the existing FAM-04 per-member permission model from Phase 1 rather than introducing a new permission concept.
- **D-08:** Temporary auto-stopping location sharing uses a duration picker (e.g. 1h/4h/8h/custom); a scheduled flag/timer flips sharing back off automatically when it expires. Exact preset values are Claude's discretion.
- **D-09:** "Export data" (PRIV-04) produces a JSON download of the user's own location/history records for MVP — not a full GDPR-style multi-format export pipeline.
- **D-10:** The permission-priming screen (LOC-05) uses value-first framing — explains that location access lets the family see each other and is what makes SOS work, framed around safety benefit. Shown once before the first OS location prompt; re-shown only if permission was previously denied and the user re-enters the flow.
- **D-11:** The battery-usage transparency screen (LOC-04) gives a plain-language estimate (foreground-only tracking = minimal battery impact, consistent with D-01) plus a couple of usage tips — no live battery graphs or detailed analytics needed for this phase.

### Claude's Discretion

- Exact dwell-time/radius thresholds for "stop" detection (D-05). **Resolved by this research:** 100m radius / 5 minutes dwell (see Architecture Patterns → Pattern 3), matching the example values CONTEXT.md itself proposed, and kept as simple round numbers so Phase 4's geofence hysteresis logic can reuse the same constants.
- Exact duration presets for temporary sharing (D-08). **Already locked by 02-UI-SPEC.md's Copywriting Contract:** "1 hour" / "4 hours" / "8 hours" / "Custom" — treat as fixed, do not re-derive.
- SignalR hub naming/shape and reconnection-handling details for D-02/D-03 (research/planner to design against the existing Clean Architecture Infrastructure-layer pattern used in Phase 1, e.g. keep hub logic behind an `INotificationService`-style abstraction per CLAUDE.md guidance). **Resolved by this research:** see Architecture Patterns → Pattern 1/2.

### Deferred Ideas (OUT OF SCOPE)

- Full background/killed-app location tracking (`flutter_foreground_task`) — explicitly deferred past this phase's MVP scope (see D-01); revisit as a hardening pass once foreground tracking is proven.
- Live battery-usage graphs/detailed analytics on the battery transparency screen — deferred in favor of plain-language messaging (D-11).
- Full GDPR-style multi-format/multi-scope data export — deferred in favor of a simple JSON-of-own-history export (D-09).
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| LOC-01 | Live location updates continuously, appears on shared family map | Pattern 1 (SignalR `LocationHub`), Pattern 4 (geolocator foreground stream), Code Examples §1/§4 |
| LOC-02 | Last-seen timestamp + online/offline status per member | Pattern 2 (presence state machine — connection tracker + ping recency), Common Pitfall 3 |
| LOC-03 | Stale-location indicator with visible accuracy radius | Already locked by 02-UI-SPEC.md staleness bands table; Pattern 4 documents how `Position.accuracy` maps to the circle radius |
| LOC-04 | Battery-usage transparency screen | Environment/mobile-only screen, no new backend/library research needed beyond copy already locked in UI-SPEC |
| LOC-05 | In-app permission-priming screen before OS dialog | Pattern 4 (geolocator permission flow — `checkPermission`/`requestPermission`, `deniedForever` handling), Common Pitfall 6 |
| HIST-01 | Historical timeline of stays/movements | Pattern 3 (dwell-time stop detection), Pattern 5 (EF Core schema) |
| HIST-02 | Route visualization of past travel | Pattern 5 (raw `LocationPing` retrieval query + polyline), Don't-Hand-Roll (`google_maps_flutter` Polyline, not custom canvas drawing) |
| HIST-03 | Travel statistics (distance, time away, stops) | Pattern 3 (dwell/stop + Haversine distance aggregation), Common Pitfall 4 (don't reach for PostGIS at this scale) |
| NOTIF-01 | Low-battery alert for self/family member | Pattern 6 (`battery_plus` + threshold check server-side), Common Pitfall 7 (alert-spam suppression) |
| PRIV-01 | All sensitive communication end-to-end encrypted | Already satisfied at transport layer by HTTPS + WSS (TLS) for both REST and SignalR — see Security Domain; no new phase-specific work beyond confirming `RequireHttpsMetadata`/WSS in production config |
| PRIV-02 | Toggle sharing per data type (live location/history/wellness) and per recipient | Pattern 7 (new `SharingPreference` entity — extends, doesn't replace, FAM-04's `PermissionLevel`) |
| PRIV-03 | Temporary, time-boxed location sharing that auto-stops | Pattern 7 (`SharingPreference.ExpiresAt` + `BackgroundService` sweep), consistent with CLAUDE.md's "use a hosted BackgroundService, not a queue" guidance |
| PRIV-04 | Export or delete data from a Privacy Center | Pattern 8 (JSON export handler), Don't-Hand-Roll (reuse `System.Text.Json`, not a bespoke serializer) |
| PRIV-05 | Documented, verifiable no-data-resale commitment | Documentation/policy concern, not a code pattern — flag as an Open Question for the planner (needs a static "Privacy Policy" page/copy, not new architecture) |
</phase_requirements>

## Summary

Phase 2 is the first phase to introduce four new pieces of technical surface area at once: SignalR (backend real-time push), `google_maps_flutter` + `geolocator` (mobile map/GPS), a new EF Core-backed location-history subsystem, and an extension of Phase 1's FAM-04 permission model into a genuine per-data-type × per-recipient sharing matrix. None of these are exotic — every one of them has a well-documented, standard pattern — but three things in this phase carry real implementation risk and deserve the most planning attention: (1) SignalR's bearer-token authentication for WebSocket/SSE transports requires a specific `OnMessageReceived` query-string wiring that is easy to get wrong and silently fail closed; (2) the Dart SignalR client ecosystem is thin — `signalr_netcore` is the only actively-referenced option and it is a community package with real (documented) reliability caveats, not a Microsoft-maintained SDK; (3) the "reuse FAM-04" instruction in CONTEXT.md needs a concrete resolution, because FAM-04's existing `PermissionLevel` is a single enum per member (Guardian-imposed ceiling), not a matrix — this research recommends adding a new `SharingPreference` entity alongside it, not repurposing the existing column.

**Primary recommendation:** Build the live-location pipeline as `LocationHub : Hub<ILocationClient>` (SignalR, JWT-authenticated via the existing Supabase JWT bearer scheme, `OnMessageReceived` query-string token wiring, one SignalR group per family circle), wrapped behind an `INotificationService`-style `ILocationBroadcastService` abstraction in Infrastructure so the Application layer never references SignalR types directly (mirrors the CLAUDE.md-mandated pattern Phase 3's SOS hub will also use). Persist raw pings to a new `LocationPing` EF Core entity (composite index on `(UserId, RecordedAtUtc)`), derive presence from an in-memory per-user connection tracker plus ping recency, compute "stops" via a 100m/5-minute dwell-time pass over pings at read time (no ML, no background aggregation job needed at this phase's scale), and model the Privacy Center's per-data-type/per-recipient toggle matrix as a new `SharingPreference` table that sits alongside — not inside — FAM-04's `FamilyMember.Permissions` enum.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Foreground GPS acquisition (LOC-01/03) | Browser/Client (mobile) | — | `geolocator` reads the OS location APIs; this never touches the backend directly, it feeds the SignalR client |
| Live location broadcast to family members (LOC-01/02) | API/Backend | Client (renders) | SignalR hub is server-authoritative for *who* receives a location update (group membership = family circle, gated by `SharingPreference`); client only renders what it's pushed |
| Presence/online-offline (LOC-02) | API/Backend | Client (renders) | Connection-open/close events only exist server-side; the client cannot know another device's socket state except via what the server tells it |
| Stale/accuracy rendering (LOC-03) | Client (mobile) | — | Purely a rendering decision over data the client already has (last-ping timestamp + accuracy field); no new backend logic beyond passing `accuracy` and `recordedAt` through unchanged |
| Location history storage (HIST-01/02/03) | Database/Storage | API/Backend (query/aggregation) | Raw pings persist in Postgres; stop-detection/distance aggregation is a backend read-time computation over that storage, not a client concern |
| Route/stats computation (HIST-02/03) | API/Backend | — | Keeps the (potentially large) raw-ping dataset server-side; the client receives only the already-reduced polyline points + stat summary, not every raw row |
| Privacy Center toggle matrix (PRIV-02/03) | API/Backend | Database/Storage | Authorization-adjacent data — must be server-authoritative (same IDOR-prevention posture as FAM-04's `IFamilyAuthorizationService`, D5 from Phase 1) |
| Data export/delete (PRIV-04) | API/Backend | — | Must run server-side against the source-of-truth tables; a client-side "export" would only see what it was already shown, not necessarily everything stored |
| Low-battery detection (NOTIF-01) | Client (mobile) reads value | API/Backend (alert decision + suppression) | The battery percentage can only be read on-device (`battery_plus`); whether to *alert* (threshold crossed, not already alerted) is a stateful decision best made server-side alongside the existing notification channel, to avoid per-client duplicate-alert logic |

## Project Constraints (from CLAUDE.md)

The project's global `.claude/CLAUDE.md` recommends **.NET 10 (ASP.NET Core 10)** as the backend target. **This phase must NOT follow that recommendation.** Phase 1's actual, already-shipped backend targets **`net9.0`** end-to-end:

- All four backend `.csproj` files (`SafePath.Api`, `.Application`, `.Domain`, `.Infrastructure`) pin `<TargetFramework>net9.0</TargetFramework>`.
- Installed SDKs on this machine are `9.0.201` / `9.0.205` — **no .NET 10 SDK is installed**, and no .NET 10 package versions (`Microsoft.EntityFrameworkCore.*` `10.0.x`, `Npgsql.EntityFrameworkCore.PostgreSQL` `10.0.x`) are referenced anywhere in the existing lockfile-equivalent (`.csproj` `PackageReference` versions are all `9.0.x`).
- Migrating the whole solution to .NET 10 mid-milestone is out of scope for a location/SignalR feature phase and is not something CONTEXT.md asked for.

**Directive for this phase's plans:** Add SignalR (`Microsoft.AspNetCore.SignalR`, built into the `net9.0` ASP.NET Core shared framework — no separate package reference needed) and any new EF Core packages at **`9.0.x`**, matching every existing `PackageReference` in the solution. Do not bump `TargetFramework` or introduce `10.0.x` package versions as part of this phase. If a future phase wants to adopt .NET 10, that must be its own explicit, planned migration — not an incidental side effect of "the CLAUDE.md stack table says 10."

Other CLAUDE.md directives that bind this phase:
- SignalR hub logic must sit behind an `INotificationService`-style abstraction in the Infrastructure layer — the Application layer must never reference `IHubContext`/`Hub` types directly (see Pattern 1/2).
- Do not implement geofencing-style polling loops — not applicable this phase (GEO is Phase 4), but the same "no `Timer.periodic` GPS polling" principle applies to presence: use SignalR connection events, not a client-side poll-and-report loop, for online/offline.
- `flutter_foreground_task`/background geofencing packages are explicitly **not** installed this phase (D-01) — do not add them to `pubspec.yaml` even though CLAUDE.md's stack table lists them for the project overall; they belong to a later hardening phase.
- Reuse `flutter_secure_storage` (already a project convention per CLAUDE.md; confirm whether Phase 1 actually added it — if not yet present, this phase does not need it either, since it is not storing new secrets, only ephemeral SignalR access tokens sourced from the existing Supabase session).
- SOS red (`AppColors.sosRed`/`sosRedDeep`) must never appear in any Phase 2 UI (already enforced and locked in 02-UI-SPEC.md Scope Resolution #2 — carry this into task-level verification, e.g. a code-review grep for `sosRed` outside the SOS tab widget).

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `Microsoft.AspNetCore.SignalR` | Built into `net9.0` ASP.NET Core shared framework (no separate NuGet package needed for the server) | Real-time hub for live location push + presence | The brief's specified real-time channel (CLAUDE.md); ships in-box with ASP.NET Core, no version to track separately from the SDK `[VERIFIED: learn.microsoft.com/aspnet/core/signalr]` |
| `google_maps_flutter` | **2.17.1** (+ `_android`/`_ios`/`_platform_interface`, upgraded as a set) | Live map, polyline route rendering, member pins | Project's fixed map SDK (CLAUDE.md); confirmed current on pub.dev, published ~45 days before this research date `[CITED: pub.dev/packages/google_maps_flutter]` |
| `geolocator` | **14.0.3** | Foreground position stream + permission-flow API | Project's fixed location package (CLAUDE.md); confirmed current on pub.dev, published ~30 days before this research date `[CITED: pub.dev/packages/geolocator]` |
| `signalr_netcore` | **1.4.4** | Dart/Flutter SignalR client for the mobile app | The only actively-referenced Dart SignalR client with automatic-reconnect support and JSON/MessagePack protocol support; supports Android/iOS/Windows/Linux/macOS `[CITED: pub.dev/packages/signalr_netcore]` — see Package Legitimacy Audit below, this package needs a `checkpoint:human-verify` before install |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `battery_plus` | current stable (Flutter Community "plus_plugins", requires Flutter ≥3.22, Dart ≥3.4) | Reading local battery level/charging state for NOTIF-01 | Cross-platform battery API wrapper; well-established (`fluttercommunity/plus_plugins` monorepo, same family as other "_plus" plugins this ecosystem trusts) `[CITED: pub.dev/packages/battery_plus + github.com/fluttercommunity/plus_plugins]` |
| `Microsoft.EntityFrameworkCore.Relational` / `.Design` | **9.0.9** (match existing `.csproj` pins exactly) | New `LocationPing`/`SharingPreference` EF entities + migrations | Already the project's ORM version; do not introduce a version drift for two new entities `[VERIFIED: backend/src/*/*.csproj — read directly from repo]` |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `signalr_netcore` (community Dart SignalR client) | Roll a raw WebSocket client speaking the SignalR JSON hub protocol by hand | Only justified if `signalr_netcore`'s documented reliability issues (see Package Legitimacy Audit) prove blocking during a spike — hand-rolling the hub protocol is significantly more work and loses automatic reconnect/negotiate handling for a graduation-project timeline; not recommended as a default choice |
| Read-time Haversine distance/stop-detection (this research's recommendation) | PostGIS + `NetTopologySuite` spatial types in EF Core | Only justified once raw-ping row counts per family climb into the millions and read-time aggregation becomes measurably slow — premature at this phase's MVP scale (a handful of family members, foreground-only tracking) |
| In-memory per-user connection tracker for presence | Redis-backed presence store / Azure SignalR Service backplane | Only needed once the API scales to multiple server instances — CLAUDE.md's own "Alternatives Considered" table already picks single-instance Azure App Service ("always on") for this project's scale, so an in-memory singleton is the consistent choice |
| New `SharingPreference` entity for the per-data-type/per-recipient matrix | Overload `FamilyMember.Permissions` (add more enum values / a bitmask) | A bitmask/expanded-enum approach can't represent "share history with Guardian A but not Guardian B" (per-recipient granularity) without becoming an ad-hoc serialized blob — a proper join-table entity is the standard relational-modeling answer and keeps FAM-04 (Guardian-imposed ceiling) and PRIV-02 (owner's own sharing choices) as the two conceptually distinct authorization axes they actually are |

**Installation:**
```bash
# Backend — from backend/src/SafePath.Api (SignalR itself needs no package reference; already in the ASP.NET Core shared framework)
dotnet add backend/src/SafePath.Infrastructure package Microsoft.EntityFrameworkCore.Relational --version 9.0.9   # already referenced; only if a new project needs it

# Mobile — from mobile/
flutter pub add google_maps_flutter geolocator signalr_netcore battery_plus
```

**Version verification:** Confirmed via direct `WebFetch` of the live pub.dev package pages (`google_maps_flutter` 2.17.1, `geolocator` 14.0.3, `signalr_netcore` 1.4.4, `battery_plus` current) on this research date — these match the versions CLAUDE.md's stack table already specifies for `google_maps_flutter`/`geolocator`, and the phase's own new addition (`signalr_netcore`) was newly identified this session, not pre-specified in CLAUDE.md. Backend package versions (`9.0.x`) were verified by reading the actual `.csproj` files in the repo, not by assumption.

## Package Legitimacy Audit

> This project's `gsd-tools package-legitimacy check` seam only supports `npm`/`pypi`/`crates` ecosystems — it does not cover `pub.dev` (Dart/Flutter). The table below is a **manual** audit performed via direct `WebFetch` of the pub.dev package/score pages and the upstream GitHub repository, using the same signals (age, downloads/likes, source repo, maintenance activity) the automated seam would apply.

| Package | Registry | Age/Version | Downloads/Likes | Source Repo | Verdict | Disposition |
|---------|----------|--------------|------------------|-------------|---------|--------------|
| `google_maps_flutter` | pub.dev | v2.17.1, ~45 days old | Flutter Favorite, verified publisher (google.dev/flutter.dev-adjacent federated plugin) | `github.com/flutter/packages` | OK | Approved |
| `geolocator` | pub.dev | v14.0.3, ~30 days old | Flutter Favorite, verified publisher (baseflow.com) | `github.com/Baseflow/flutter-geolocator` | OK | Approved |
| `battery_plus` | pub.dev | current stable | Part of `fluttercommunity/plus_plugins` monorepo (same family as `connectivity_plus`, `device_info_plus` — widely used) | `github.com/fluttercommunity/plus_plugins` | OK | Approved |
| `signalr_netcore` | pub.dev | v1.4.4, published ~10 months ago | 229 likes, 73.6k weekly downloads, 140/160 pub points | `github.com/sefidgaran/signalr_client` (99 stars, 135 forks, 56 open issues) | **SUS** | Flagged — planner must add `checkpoint:human-verify` before install |

**Packages removed due to [SLOP] verdict:** none.

**Packages flagged as suspicious [SUS]:** `signalr_netcore` — not a hallucinated/typosquat package (it is real, has meaningful adoption: 73.6k weekly downloads), but it carries genuine maintenance-quality signals worth a human gate before committing to it as the mobile SignalR client:
- The package's own README (as of this research) recommends falling back to an older version (`0.1.7+2-nullsafety.3`) "if you are experiencing issues (for example not receiving message callback) with the latest version" — a maintainer-acknowledged regression risk in the current release line.
- Static analysis flags 25 lint issues on pub.dev's own scoring page (missing type annotations, suboptimal collection checks) and an out-of-date transitive dependency constraint (`sse_channel ^0.1.1` vs. the actual latest `0.2.0`).
- The repo shows 56 open issues and is described by the package's own score page context as "maintained but not actively developed."
- It is tested against ASP.NET Core 3.1 and 6 only (per its README) — not explicitly verified against .NET 9 SignalR, though the SignalR hub wire protocol has been stable across these versions and this is a low-probability compatibility risk, not a known-broken one.

**Planner action required:** insert a `checkpoint:human-verify` task immediately after `signalr_netcore` is added to `pubspec.yaml` and before building real feature logic on top of it — spike a minimal hub connection (connect, receive one broadcast message, force a network drop, confirm auto-reconnect + group rejoin) against this project's actual `net9.0` SignalR hub before committing to it as the phase's real-time transport. If the spike surfaces the documented "not receiving message callback" issue, fall back to the `0.1.7+2-nullsafety.3` version pin the package's own README suggests, or reconsider a raw-WebSocket hand-rolled client as a last resort (see Alternatives Considered).

*Package names in this audit were discovered via `WebSearch`/`WebFetch`, not a curated docs provider — per the provenance rule, treat all four as `[ASSUMED]`-tier package identity even though `google_maps_flutter`/`geolocator` are also explicitly named in this project's own CLAUDE.md (so their identity is doubly corroborated, not just WebSearch-discovered).*

## Architecture Patterns

### System Architecture Diagram

```
┌─────────────────────────────┐          ┌──────────────────────────────────────┐
│   Mobile (Flutter/Riverpod)  │          │        ASP.NET Core 9 API             │
│                               │          │                                        │
│  geolocator.getPositionStream│          │  ┌──────────────┐   ┌───────────────┐ │
│    │ (foreground only, D-01)  │          │  │ LocationHub   │   │ FamiliesCtrl/  │ │
│    ▼                          │  invoke  │  │ (SignalR)     │   │ PrivacyCtrl/   │ │
│  LocationController (Notifier)├─────────►│  │ - ReportLoc() │   │ HistoryCtrl    │ │
│    │                          │          │  │ - OnConnected │   │ (REST)         │ │
│    ▼                          │  push    │  │ - OnDisconn.  │   └──────┬────────┘ │
│  HubConnection (signalr_netcore)◄────────┤  └──────┬────────┘          │          │
│    │  .on("LocationUpdated")  │          │         │ via                │          │
│    │  .on("PresenceChanged")  │          │         ▼                    ▼          │
│    ▼                          │          │  ILocationBroadcastService  IApplicationDbContext
│  MapController → GoogleMap    │          │  (Infrastructure abstraction, wraps    │
│  (pins, staleness fade,       │          │   IHubContext<LocationHub> — Application│
│   accuracy circle)            │          │   layer never touches SignalR types)   │
│                               │          │         │                    │          │
│  HistoryController (REST)     │  GET     │         ▼                    ▼          │
│  ─ polyline + stats ──────────┼─────────►│  LocationHistoryQuery   Postgres (Supabase)
│                               │          │  (dwell-time stop        - LocationPings │
│  PrivacyController (REST)     │  PATCH   │   detection, Haversine   - SharingPreferences│
│  ─ toggle matrix ─────────────┼─────────►│   distance)              - FamilyMembers (existing)│
│                               │          │         ▲                                │
│  battery_plus → BatteryLevel  │  (piggy- │         │ SharingPreference check gates   │
│  attached to each ping        │  backed) │         │ who receives each broadcast +   │
└───────────────────────────────┘          │         │ who can query whose history     │
                                            │  BackgroundService (auto-stop sweep,     │
                                            │  D-08: flips expired SharingPreference   │
                                            │  rows IsEnabled=false every minute)      │
                                            └──────────────────────────────────────────┘
```

### Recommended Project Structure

```
backend/src/SafePath.Domain/Entities/
├── LocationPing.cs           # raw location event (UserId, Lat, Lng, AccuracyM, BatteryPct?, RecordedAtUtc)
└── SharingPreference.cs      # (OwnerUserId, FamilyId, RecipientMemberId?, DataType, IsEnabled, ExpiresAtUtc?)

backend/src/SafePath.Domain/Enums/
├── SharedDataType.cs          # LiveLocation, History, Wellness
└── PresenceStatus.cs          # Online, Offline  (or compute inline, no enum strictly required)

backend/src/SafePath.Application/Location/
├── ReportLocationCommand.cs        # from hub → persists ping + triggers broadcast
├── GetLiveLocationsQuery.cs        # initial map load (last known ping per visible member)
├── GetLocationHistoryQuery.cs      # HIST-01/02: timeline + polyline points for a date range
├── GetTravelStatsQuery.cs          # HIST-03: distance/time-away/stop-count
└── StopDetection.cs                # pure function: List<LocationPing> -> List<Stop> (dwell-time)

backend/src/SafePath.Application/Privacy/
├── UpdateSharingPreferenceCommand.cs   # PRIV-02/03 toggle + optional ExpiresAtUtc
├── GetSharingMatrixQuery.cs
└── ExportMyDataQuery.cs / DeleteMyDataCommand.cs   # PRIV-04

backend/src/SafePath.Infrastructure/RealTime/
├── LocationHub.cs                   # SignalR Hub<ILocationClient>, [Authorize]
├── ILocationClient.cs                # strongly-typed client contract (LocationUpdated, PresenceChanged)
├── ILocationBroadcastService.cs       # Application-facing abstraction (Infrastructure impl wraps IHubContext)
├── LocationBroadcastService.cs
├── PresenceTracker.cs                # in-memory ConcurrentDictionary<Guid, HashSet<string>> userId->connectionIds
└── SharingPreferenceSweepService.cs  # BackgroundService, D-08 auto-stop

mobile/lib/features/location/
├── data/location_api.dart            # REST: history/stats/privacy endpoints
├── data/location_hub_client.dart      # wraps signalr_netcore HubConnection
├── application/location_controller.dart   # Notifier: live pins, presence, staleness
├── application/history_controller.dart
└── presentation/
    ├── live_map_screen.dart
    ├── history_timeline_screen.dart
    ├── route_stats_sheet.dart
    ├── permission_priming_screen.dart   # LOC-05
    └── battery_transparency_screen.dart # LOC-04

mobile/lib/features/privacy/
├── data/privacy_api.dart
├── application/privacy_controller.dart
└── presentation/privacy_center_screen.dart

mobile/lib/shared_widgets/
├── member_map_pin.dart      # per UI-SPEC: new shared widget
├── stat_tile.dart
├── toggle_row.dart
└── timeline_node.dart
```

### Pattern 1: `LocationHub` — strongly-typed SignalR hub behind an Infrastructure abstraction

**What:** A `Hub<ILocationClient>` in the Infrastructure layer, `[Authorize]`-gated by the existing Supabase JWT bearer scheme (same `AddJwtBearer` config already in `Program.cs` — no second auth scheme needed). The Application layer never references `Hub`/`IHubContext` — it depends on `ILocationBroadcastService`, implemented in Infrastructure by wrapping `IHubContext<LocationHub, ILocationClient>`.

**When to use:** Every live-location push (LOC-01) and presence change (LOC-02) — this is the phase's sole real-time channel; Phase 3's SOS alert hub is a *separate* hub (per STATE.md's decision to fold the standalone SignalR phase into Phase 2, SOS-02 gets "its own dedicated `AlertHub`" — do not conflate the two hubs or route SOS through this one).

**Example:**
```csharp
// Source: pattern synthesized from learn.microsoft.com/aspnet/core/signalr/authn-and-authz
// and learn.microsoft.com/aspnet/core/signalr/groups (fetched this session)
// SafePath.Infrastructure/RealTime/ILocationClient.cs
public interface ILocationClient
{
    Task LocationUpdated(LocationUpdateDto update);
    Task PresenceChanged(PresenceChangeDto change);
}

// SafePath.Infrastructure/RealTime/LocationHub.cs
[Authorize]
public class LocationHub : Hub<ILocationClient>
{
    private readonly IFamilyAuthorizationService _authorization;
    private readonly PresenceTracker _presence;

    public override async Task OnConnectedAsync()
    {
        var userId = Guid.Parse(Context.UserIdentifier!); // "sub" claim, per Program.cs NameClaimType config
        var familyId = await _authorization.RequireMembership(userId, GetFamilyIdFromQuery(), Context.ConnectionAborted)
            is var member ? member.FamilyId : throw new HubException("no active family");

        await Groups.AddToGroupAsync(Context.ConnectionId, $"family:{familyId}");
        _presence.AddConnection(userId, Context.ConnectionId);
        await Clients.OthersInGroup($"family:{familyId}").PresenceChanged(new(userId, IsOnline: true));
    }

    public override async Task OnDisconnectedAsync(Exception? exception)
    {
        var userId = Guid.Parse(Context.UserIdentifier!);
        var stillOnline = _presence.RemoveConnection(userId, Context.ConnectionId);
        if (!stillOnline)
        {
            // last connection for this user closed — mark offline, broadcast
        }
        await base.OnDisconnectedAsync(exception);
    }
}
```

### Pattern 2: `ILocationBroadcastService` — the Application-facing seam

**What:** Application-layer command handlers (e.g. `ReportLocationCommandHandler`) call `ILocationBroadcastService.BroadcastLocation(...)`, an interface defined in `SafePath.Application.Common.Interfaces` and implemented in Infrastructure wrapping `IHubContext<LocationHub, ILocationClient>`. This is the exact `INotificationService`-style pattern CLAUDE.md mandates, and keeps Phase 3's future `AlertHub` architecturally consistent (same seam shape, different hub).

**When to use:** Any Application-layer code that needs to push a real-time event — never inject `IHubContext` directly into a command handler.

### Pattern 3: Dwell-time stop detection (D-05) — 100m / 5 minutes

**What:** A pure function over an ordered `List<LocationPing>` (by `RecordedAtUtc`) that walks the sequence and groups consecutive pings into a "stop" when they stay within a **100-meter radius** of each other for **at least 5 minutes**. Movement between stops becomes the polyline/route segment; stop clusters become timeline nodes with a start/end time and (reverse-geocoded, out of scope this phase unless trivial) place label.

**When to use:** HIST-01 (timeline), HIST-03 (stop count/time-away stats). Computed at read time over a bounded date range (e.g., a single day/week view), not as a standing background aggregation job — the phase's expected data volume (foreground-only tracking, single-family scale) does not yet justify precomputed rollups.

**Example (pseudocode, ASSUMED — not sourced from a library, this is the standard "dwell-time clustering" algorithm shape used across GPS-trip-summarization codebases):**
```csharp
// SafePath.Application/Location/StopDetection.cs
public static IReadOnlyList<Stop> DetectStops(IReadOnlyList<LocationPing> pings, double radiusMeters = 100, TimeSpan? minDwell = null)
{
    minDwell ??= TimeSpan.FromMinutes(5);
    var stops = new List<Stop>();
    var clusterStart = 0;
    for (var i = 1; i <= pings.Count; i++)
    {
        var outOfRadius = i == pings.Count ||
            HaversineMeters(pings[clusterStart].Lat, pings[clusterStart].Lng, pings[i].Lat, pings[i].Lng) > radiusMeters;
        if (outOfRadius)
        {
            var duration = pings[i - 1].RecordedAtUtc - pings[clusterStart].RecordedAtUtc;
            if (duration >= minDwell) stops.Add(new Stop(pings[clusterStart].RecordedAtUtc, pings[i - 1].RecordedAtUtc, pings[clusterStart].Lat, pings[clusterStart].Lng));
            clusterStart = i;
        }
    }
    return stops;
}
```

**Consistency note for Phase 4:** keep `radiusMeters`/`minDwell` as named constants in one place (e.g. a shared `Domain.Constants.DwellTimeDefaults`) so Phase 4's geofence enter/exit hysteresis can reference or deliberately diverge from these same defaults, per STATE.md's carried-forward concern that "Phase 4's exact dwell-time/hysteresis parameters need re-verification at build time."

### Pattern 4: geolocator foreground streaming + permission priming (LOC-01/03/05)

**What:** `Geolocator.getPositionStream(locationSettings: LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 10))` for continuous foreground updates. Permission flow: check `Geolocator.checkPermission()` first; if `denied`, show the LOC-05 priming screen *before* calling `Geolocator.requestPermission()` (which triggers the actual OS dialog); if `deniedForever`, direct the user to app settings (`Geolocator.openAppSettings()`) rather than re-prompting (matches the UI-SPEC's "Error state — OS permission denied" copy).

**When to use:** LOC-01 (continuous updates), LOC-03 (the `Position.accuracy` field feeds the UI-SPEC's already-locked accuracy-radius circle sizing — no new research needed there, just wire `accuracy` through unchanged).

**Example:**
```dart
// Source: pub.dev/packages/geolocator/example (fetched this session)
Future<bool> _handlePermission() async {
  if (!await Geolocator.isLocationServiceEnabled()) return false;
  var permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    // Show LOC-05 priming screen HERE, before this call, per D-10 —
    // only call requestPermission() after the user taps "Turn on location sharing".
    permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied) return false;
  }
  if (permission == LocationPermission.deniedForever) return false; // -> "Open Settings" error state
  return true;
}

final positions = Geolocator.getPositionStream(
  locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 10),
);
```

**Platform manifest note (ASSUMED, standard geolocator setup, verify at implementation time against the installed version's own README):** Android needs `ACCESS_FINE_LOCATION`/`ACCESS_COARSE_LOCATION` in `AndroidManifest.xml`; iOS needs `NSLocationWhenInUseUsageDescription` in `Info.plist`. Since D-01 is foreground-only, do **not** add `NSLocationAlwaysAndWhenInUseUsageDescription` or request "Always" permission this phase — that triggers a more invasive OS prompt and App Store background-location justification that isn't needed until the deferred background-tracking phase.

### Pattern 5: `LocationPing` EF Core schema

**What:** One append-only table for raw location events, one composite index for the query pattern that actually matters (per-user, time-ranged history reads).

```csharp
// SafePath.Domain/Entities/LocationPing.cs
public class LocationPing
{
    public Guid Id { get; set; }
    public Guid UserId { get; set; }
    public double Latitude { get; set; }
    public double Longitude { get; set; }
    public double AccuracyMeters { get; set; }
    public int? BatteryPercent { get; set; }       // feeds NOTIF-01
    public DateTime RecordedAtUtc { get; set; }     // client-reported timestamp
    public DateTime ReceivedAtUtc { get; set; }     // server-observed timestamp (clock-skew/staleness fallback)
}

// EntityConfiguration
builder.HasIndex(p => new { p.UserId, p.RecordedAtUtc });
```

**When to use:** Every `ReportLocationCommand` invocation writes one row, then triggers `ILocationBroadcastService.BroadcastLocation`. History/stats queries read a bounded `RecordedAtUtc` range filtered by `UserId` (already covered by the composite index) — never a full-table scan.

### Pattern 6: Low-battery detection plumbing (NOTIF-01)

**What:** `battery_plus`'s `Battery().batteryLevel` is read on the mobile client and attached as `BatteryPercent` on each `ReportLocationCommand` payload (piggy-backed on the existing location-ping channel — no separate battery-reporting endpoint needed). The backend evaluates a threshold (e.g. ≤20%) on receipt and only fires the NOTIF-01 alert on a **falling edge** (crossed the threshold since the last ping), not on every subsequent ping while still low — see Common Pitfall 7.

### Pattern 7: `SharingPreference` — the PRIV-02/03 matrix, alongside (not inside) FAM-04

**What:** A new entity, independent of `FamilyMember.Permissions` (`PermissionLevel` enum — Guardian-imposed ceiling from Phase 1). `SharingPreference` is the data *owner's* own choice of what to share with whom:

```csharp
// SafePath.Domain/Entities/SharingPreference.cs
public class SharingPreference
{
    public Guid Id { get; set; }
    public Guid FamilyId { get; set; }
    public Guid OwnerUserId { get; set; }       // whose data is being shared
    public Guid? RecipientMemberId { get; set; } // null = "everyone in the family" default row
    public SharedDataType DataType { get; set; } // LiveLocation | History | Wellness
    public bool IsEnabled { get; set; }
    public DateTime? ExpiresAtUtc { get; set; }  // PRIV-03 temporary sharing
}
```

Authorization for "can user A see user B's live location/history" becomes: **both** (a) `IFamilyAuthorizationService` confirms A and B share an active family membership (existing FAM-04/D5 IDOR-prevention check — unchanged), **and** (b) a `SharingPreference` row for `(OwnerUserId: B, RecipientMemberId: A or null, DataType: LiveLocation, IsEnabled: true, ExpiresAtUtc null-or-future)` exists. Both checks gate: SignalR group broadcast eligibility (who's in the group is *membership*; whether they actually get pushed *this specific* update is the `SharingPreference` check inside `ReportLocationCommandHandler`) and REST history/stats reads.

**When to use:** PRIV-02 (toggle), PRIV-03 (temporary sharing — set `ExpiresAtUtc`, swept by `SharingPreferenceSweepService : BackgroundService` per D-08, matching CLAUDE.md's "hosted `BackgroundService`, not a queue, for scheduling at this scale" guidance).

### Pattern 8: JSON export/delete (PRIV-04, D-09)

**What:** `ExportMyDataQuery` serializes the caller's own `LocationPing` rows (+ any `SharingPreference` rows they own) via `System.Text.Json` (already the project's JSON stack — `Program.cs` already configures `JsonStringEnumConverter`) into a downloadable file. `DeleteMyDataCommand` hard-deletes the caller's own `LocationPing` rows (per the UI-SPEC's locked destructive-confirmation copy: "This permanently removes your live location, history, and stats... This can't be undone.") — this is a real, irreversible delete, not a soft-delete/`IsActive` flag like `FamilyMember`'s removal pattern.

### Anti-Patterns to Avoid

- **Client-side polling for presence/location instead of the SignalR push (D-02):** defeats the entire purpose of D-02 and duplicates the "no `Timer.periodic` polling" lesson CLAUDE.md already states for geofencing — apply the same principle here.
- **Injecting `IHubContext<LocationHub>` directly into an Application-layer command handler:** breaks the Clean Architecture boundary CLAUDE.md explicitly calls out for SignalR; always go through `ILocationBroadcastService`.
- **Storing the per-recipient sharing matrix as a JSON blob column on `FamilyMember`:** loses queryability (can't efficiently ask "who has live-location access to user X right now" for the broadcast-gating check) and fights against EF Core's relational model; use a proper table (Pattern 7).
- **Requesting "Always" location permission this phase:** D-01 is foreground-only; requesting `NSLocationAlwaysAndWhenInUseUsageDescription`/`ACCESS_BACKGROUND_LOCATION` now is scope creep that also drags in App Store background-location review requirements prematurely.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Real-time push transport/reconnect logic | A custom WebSocket + retry/backoff client | `signalr_netcore`'s `withAutomaticReconnect` (mobile) / built-in ASP.NET Core SignalR (server) | Reconnect/backoff/negotiate-handshake edge cases are exactly the kind of thing a maintained library gets right after years of real-world bugs; only fall back to hand-rolling if the Package Legitimacy checkpoint spike surfaces a genuine blocker |
| Route polyline rendering | Custom `CustomPainter` drawing over a static map image | `google_maps_flutter`'s `Polyline`/`Marker`/`Circle` overlay APIs | Native map SDK overlays handle camera transforms, zoom-level detail reduction, and hit-testing for free |
| Distance-between-two-GPS-points math | A hand-rolled flat-earth approximation | The standard Haversine formula (a ~10-line, well-known function — still worth centralizing in one `GeoMath.HaversineMeters` helper rather than re-deriving it per call site) | Haversine is simple enough it isn't really a "library," but it must be centralized/tested once, not re-derived ad hoc in multiple query handlers |
| Permission-state UI branching (denied/deniedForever/granted/restricted) | A custom platform-channel permission prober | `geolocator`'s `checkPermission()`/`requestPermission()`/`LocationPermission` enum | This is exactly what the package exists to abstract across Android/iOS permission model differences |
| JSON export serialization | A bespoke CSV/XML writer | `System.Text.Json` (already wired into `Program.cs`'s controller JSON options) | No new serialization stack needed for a "download your own rows as JSON" MVP feature (D-09) |

**Key insight:** Every "don't hand-roll" item above is not because the underlying math/logic is hard (Haversine is trivial; a WebSocket client is not rocket science) — it's because this phase's actual risk is edge-case correctness under real network conditions (reconnect timing, permission-state transitions, GPS accuracy jitter) that a library has already been battle-tested against, and a from-scratch implementation would silently reintroduce.

## Common Pitfalls

### Pitfall 1: SignalR JWT bearer auth silently fails for WebSocket connections without the `OnMessageReceived` query-string wiring
**What goes wrong:** Standard `AddJwtBearer` reads the `Authorization: Bearer <token>` HTTP header — but browsers/native WebSocket clients cannot set custom headers on the WebSocket handshake, so SignalR clients (including `signalr_netcore`) send the token as an `access_token` query-string parameter instead. Without an explicit `OnMessageReceived` handler that reads `context.Request.Query["access_token"]` and assigns it to `context.Token`, every hub connection attempt gets rejected as unauthenticated with no obvious error on the client side beyond "connection failed."
**Why it happens:** This is a documented, real limitation of browser/WebSocket APIs, not a bug — but it's easy to miss because REST endpoints (`FamiliesController`, etc.) work fine with the header-based token and give no hint that the hub needs different wiring.
**How to avoid:** Add the `OnMessageReceived` event to the *same* `AddJwtBearer` configuration already in `Program.cs`, scoped to the hub's path (e.g. `path.StartsWithSegments("/hubs/location")`) so REST endpoints are unaffected. `[VERIFIED: learn.microsoft.com/aspnet/core/signalr/authn-and-authz]` — this exact pattern (code sample) is the officially documented fix.
**Warning signs:** Hub connections fail immediately after `start()` with a 401/403 during negotiate, while REST calls with the same token succeed.

### Pitfall 2: SignalR group membership does not survive reconnects or server restarts
**What goes wrong:** A client that reconnects (e.g. after a brief network drop) is *not* automatically re-added to its `family:{familyId}` group — it must explicitly rejoin in the reconnection handler, or it will silently stop receiving broadcasts until the app is fully restarted.
**Why it happens:** Groups are an in-memory, per-connection-id construct by design (documented explicitly: "Group membership isn't preserved when a connection reconnects... Groups are kept in memory, so they won't persist through a server restart"). `[VERIFIED: learn.microsoft.com/aspnet/core/signalr/groups]`
**How to avoid:** Re-run the group-join logic (`Groups.AddToGroupAsync`) inside `OnConnectedAsync` — since `OnConnectedAsync` fires on every new connection including ones created by `signalr_netcore`'s automatic-reconnect, this is already correct if group-join lives there and nowhere else. Do not join the group once at app startup and assume it persists.
**Warning signs:** A family member's live pin stops updating after their phone briefly loses signal (e.g. entering an elevator), even though the SignalR client reports itself as "connected" again.

### Pitfall 3: Presence must combine connection state AND ping recency (D-03) — a naive implementation will pick only one
**What goes wrong:** Implementing presence as "online while a SignalR connection is open" alone misses the case where the app is foregrounded (socket open) but GPS has stalled (permission revoked mid-session, GPS chip issue) — the user would show "online" with a location pin that's actually stale/wrong. Implementing it as "online if last ping < N minutes ago" alone misses instant offline detection (closing the app should show offline immediately, not after a timeout).
**Why it happens:** These are genuinely two different signals with different latencies — connection close is instant, ping recency is a fallback signal for "is the data still trustworthy."
**How to avoid:** Track both explicitly (Pattern 2's `PresenceTracker` for connection state; `LocationPing.RecordedAtUtc` recency for staleness) and combine them in the client-facing DTO rather than collapsing to one boolean too early — the UI-SPEC's own staleness bands (0-2min/2-15min/15min-1hr/>1hr) already assume the pin can be "connected but stale," which only works if both signals are tracked independently.
**Warning signs:** A member shows as "online" while their pin is visibly faded/stale in the UI (the two signals disagreeing is itself informative — don't paper over it by picking one).

### Pitfall 4: Reaching for PostGIS/spatial types prematurely
**What goes wrong:** Adding `NetTopologySuite` + PostGIS extension for what is, at this phase's scale, a handful of family members' foreground-only GPS pings invites migration complexity (enabling a Postgres extension on the managed Supabase instance, new EF Core spatial-type mapping, geography-vs-geometry SRID decisions) for a problem plain `double Latitude/Longitude` columns + a Haversine helper function solve adequately.
**Why it happens:** Spatial databases are the "correct" long-term answer for large-scale geo workloads, which makes them tempting to reach for immediately — but this project's own CLAUDE.md doesn't mention PostGIS/NetTopologySuite anywhere in its stack, and Supabase's managed Postgres would need the extension explicitly enabled.
**How to avoid:** Use plain columns + the composite `(UserId, RecordedAtUtc)` index (Pattern 5) + an in-app Haversine helper for MVP; revisit only if/when raw-ping row counts and query latency actually demand it (see Alternatives Considered).
**Warning signs:** A plan task that says "enable PostGIS extension" or "add `NetTopologySuite` package" for this phase specifically — that's scope creep relative to CONTEXT.md's decisions.

### Pitfall 5: SignalR doesn't revalidate the JWT during a long-lived connection
**What goes wrong:** SignalR caches the authenticated principal at connection time and does not re-check token expiry/revocation for the life of an already-open connection (this is documented, cross-version behavior). A user whose Supabase JWT technically expired an hour into a long map session could, in principle, keep an open hub connection using stale claims.
**Why it happens:** This is by design for connection stability, not a bug — but it's a real security-posture nuance worth knowing given this app's privacy-first positioning. `[VERIFIED: learn.microsoft.com/aspnet/core/signalr/authn-and-authz]` — "SignalR doesn't automatically revalidate the user during the life of the connection... This behavior applies to all schemes."
**How to avoid:** For this phase's threat model (family location sharing, not a high-security admin panel) this is an acceptable, documented tradeoff — but flag it for the Security Domain review below; if stricter behavior is wanted later, `CloseOnAuthenticationExpiration` can force reconnect-and-reauthenticate on token expiry.
**Warning signs:** N/A for MVP — this is a forward-looking note, not a bug to fix now.

### Pitfall 6: Requesting the OS location permission dialog before the priming screen defeats LOC-05/D-10
**What goes wrong:** If `Geolocator.requestPermission()` is called eagerly on first app/screen load (a common mistake — many geolocator tutorials call it immediately), the OS dialog appears before the value-first priming screen ever renders, permanently losing the "explain why, then ask" UX this phase's LOC-05/D-10 requirement depends on. Worse, if the user denies at that point, some platforms make it harder to re-prompt.
**How to avoid:** Gate the `requestPermission()` call strictly behind the priming screen's own CTA tap ("Turn on location sharing") — `checkPermission()` (read-only, doesn't trigger a dialog) is safe to call anytime to decide whether to show the priming screen at all.
**Warning signs:** The OS permission dialog appears before the app has shown any of its own explanatory UI.

### Pitfall 7: Low-battery alert spam without falling-edge suppression (NOTIF-01)
**What goes wrong:** If every incoming `ReportLocationCommand` with `BatteryPercent <= 20` independently triggers a notification, a user sitting at 15% battery for an hour of active tracking receives dozens of duplicate "low battery" alerts (once per location ping, potentially every ~10 seconds at high accuracy).
**How to avoid:** Track "already alerted below threshold this session" (a per-user boolean/timestamp, reset once battery rises back above the threshold — e.g. by a hysteresis band, alert at ≤20%, clear the flag only once back above ≤25%) so the alert fires once per genuine crossing, not once per ping.
**Warning signs:** A plan/task that wires the alert directly inside `ReportLocationCommandHandler` with no state check beyond the raw threshold comparison.

## Code Examples

Verified patterns from official sources:

### JWT bearer auth for a SignalR hub (query-string token)
```csharp
// Source: learn.microsoft.com/aspnet/core/signalr/authn-and-authz (fetched this session, aspnetcore-9.0 moniker applies)
builder.Services
    .AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(options =>
    {
        options.Authority = supabaseIssuer; // unchanged from existing Program.cs config
        // ...existing TokenValidationParameters unchanged...
        options.Events = new JwtBearerEvents
        {
            OnMessageReceived = context =>
            {
                var accessToken = context.Request.Query["access_token"];
                var path = context.HttpContext.Request.Path;
                if (!string.IsNullOrEmpty(accessToken) && path.StartsWithSegments("/hubs/location"))
                {
                    context.Token = accessToken;
                }
                return Task.CompletedTask;
            }
        };
    });

// Program.cs, after existing app.UseAuthorization():
app.MapHub<LocationHub>("/hubs/location");
```

### Mobile SignalR client connection (signalr_netcore)
```dart
// Source: pub.dev/documentation/signalr_netcore/latest (fetched this session)
final httpOptions = HttpConnectionOptions(
  accessTokenFactory: () async => (await supabase.auth.currentSession)?.accessToken ?? '',
  logging: (level, message) => debugPrint(message),
);

final hubConnection = HubConnectionBuilder()
    .withUrl('$apiBaseUrl/hubs/location?familyId=$familyId', options: httpOptions)
    .withAutomaticReconnect(retryDelays: [2000, 5000, 10000, 20000, null])
    .build();

hubConnection.on('LocationUpdated', (args) => _handleLocationUpdate(args));
hubConnection.on('PresenceChanged', (args) => _handlePresenceChange(args));
// ASSUMED (verify exact callback name against the installed version's source):
// re-join is handled server-side in OnConnectedAsync on every reconnect, so no
// client-side group-rejoin call is needed — but confirm the connection's
// onreconnected-equivalent callback exists to refresh any client-side "stale
// connection" UI state.
await hubConnection.start();
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|---------------|--------|
| Custom cookie-based SignalR auth for mobile clients | JWT bearer via `accessTokenFactory` + `OnMessageReceived` query-string wiring | Standard since ASP.NET Core SignalR's inception (not a recent change) — but worth noting because REST auth in this project already uses JWT bearer, so this is "the same pattern, applied to a transport that needs slightly different wiring," not a new concept | Zero new auth infrastructure needed beyond the query-string handler — same Supabase-issued JWT, same `Authority`/`Audience` config |
| Android foreground-service GPS polling for geofencing | Native `GeofencingClient`/`CLCircularRegion` APIs (`native_geofence` package) | Google Play policy update, April 15 2026 (per CLAUDE.md) | Not directly this phase's concern (GEO is Phase 4), but confirms this phase must not build any GPS-polling code that could be mistaken for/repurposed into a geofencing mechanism later |

**Deprecated/outdated:** None specific to this phase's stack — `google_maps_flutter`, `geolocator`, and ASP.NET Core SignalR are all current, actively maintained as of this research date.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `signalr_netcore`'s exact reconnection callback name (e.g. `onreconnected`) and whether server-side group rejoin alone is sufficient without a client-side trigger | Code Examples §2 | Low — worst case, a manual spike during the mandated `checkpoint:human-verify` task surfaces the correct API and the plan adjusts; does not block architecture decisions |
| A2 | 100m radius / 5-minute dwell-time as the exact stop-detection thresholds | Pattern 3 | Low-medium — these are reasonable, CONTEXT.md-suggested defaults but not user-validated against real GPS jitter in this app's target environments (e.g. dense urban vs. rural accuracy differences); may need tuning after first real-device testing |
| A3 | Android/iOS manifest permission strings needed for foreground-only geolocator use | Pattern 4 | Low — well-documented, standard geolocator setup; easy to verify against the installed package version's own README at implementation time |
| A4 | `battery_plus` current version number (not explicitly pinned in this document — CLAUDE.md doesn't specify one) | Standard Stack | Low — run `flutter pub add battery_plus` and record whatever resolves; no compatibility risk identified |
| A5 | Exact severity of `signalr_netcore`'s "not receiving message callback" issue mentioned in its own README | Package Legitimacy Audit | Medium — this is the reason a `checkpoint:human-verify` spike is mandated before deep investment in this package; if the issue is severe/frequent, the phase's real-time architecture may need to pivot to a fallback client |

**If this table is empty:** N/A — see entries above; none of these block planning, they define what the mandated verification spike (A1/A5) and first-device-test tuning pass (A2) should confirm.

## Open Questions

1. **How should PRIV-05 (documented, verifiable no-data-resale commitment) be satisfied concretely in this phase?**
   - What we know: This is a policy/documentation requirement, not a new architectural pattern — SafePath's positioning already states "no-data-resale" throughout CLAUDE.md.
   - What's unclear: Whether "documented and verifiable" implies a static in-app Privacy Policy screen/link this phase, or is satisfied entirely by out-of-band documentation (e.g. a repo-level `PRIVACY.md` or landing-page copy) with no in-app surface needed for MVP.
   - Recommendation: Treat as a lightweight task — a static Privacy Policy screen/link reachable from the Privacy Center, with no new backend logic. Confirm scope with the planner/user rather than over-building.

2. **Does the mobile app need `flutter_secure_storage` for anything new this phase?**
   - What we know: CLAUDE.md recommends it project-wide for tokens/keys; Phase 1's actual token storage relies on `supabase_flutter`'s own session persistence (not confirmed whether that itself uses secure storage internally).
   - What's unclear: Whether this phase introduces any new secret that needs explicit secure storage (the SignalR access token is sourced live from the existing Supabase session each connection attempt, per the code example above — no new secret at rest).
   - Recommendation: No new secure-storage work needed this phase; confirm at planning time that the SignalR client indeed re-reads the token live rather than caching it somewhere insecure.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| .NET SDK | Backend build/run | ✓ | 9.0.205 (also 9.0.201 present) | — |
| Node.js | Tooling (gsd-tools, etc.) | ✓ | 22.14.0 | — |
| Flutter SDK | Mobile build/run | ✓ | Installed (update available, not blocking) | — |
| Google Cloud Maps SDK API key | `google_maps_flutter` (LOC-01/HIST-02) | ✗ (not verifiable from this environment) | — | Planner must add a task to provision/verify an Android + iOS Maps API key before map screens can render; no code-level fallback exists for a missing key (map tiles simply fail to load) |
| Postgres (Supabase) reachability | `LocationPing`/`SharingPreference` migrations | Not directly probed this session (no local DB check performed) | — | Existing Phase 1 migrations already run against Supabase successfully per STATE.md — assume same connection works; verify `dotnet ef database update` succeeds during execution, not blocking for planning |

**Missing dependencies with no fallback:**
- Google Maps SDK API key (per-platform) — required before any map rendering is possible; must be provisioned (Google Cloud Console) before or during this phase's execution.

**Missing dependencies with fallback:**
- None beyond the API key above — all libraries/SDKs needed are either already installed (.NET, Flutter) or added via `flutter pub add`/no-package-needed (SignalR is in-box).

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | Backend: xUnit 2.9.2 + Moq 4.20.72 + EF Core Sqlite in-memory provider (`Microsoft.EntityFrameworkCore.Sqlite` 9.0.9) — same as Phase 1's `SafePath.Application.Tests`. Mobile: `flutter_test` + hand-written fakes (no Mockito/mocktail — matches Phase 1's `FakeAuthApi`/`FakeFamilyApi` convention) |
| Config file | `backend/tests/SafePath.Application.Tests/SafePath.Application.Tests.csproj`; mobile has no separate config, uses default `flutter test` |
| Quick run command | `dotnet test backend/tests/SafePath.Application.Tests --filter FullyQualifiedName~Location` / `flutter test mobile/test/features/location` |
| Full suite command | `dotnet test backend/SafePath.sln` (or equivalent solution path) / `flutter test` (from `mobile/`) |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|--------------------|--------------|
| LOC-01/02 | `ReportLocationCommandHandler` persists a ping and calls `ILocationBroadcastService.BroadcastLocation` exactly once with the correct group | unit | `dotnet test --filter FullyQualifiedName~ReportLocationCommandHandlerTests` | ❌ Wave 0 |
| LOC-03 | Staleness-band mapping (ping age → opacity/badge) is a pure Dart function, unit-testable without a widget test | unit | `flutter test mobile/test/features/location/staleness_test.dart` | ❌ Wave 0 |
| LOC-05 | Priming screen never calls `requestPermission()` before its own CTA is tapped | widget | `flutter test mobile/test/features/location/permission_priming_screen_test.dart` | ❌ Wave 0 |
| HIST-01/03 | `DetectStops` pure function correctness (clusters pings within 100m/5min into stops; excludes movement segments) | unit | `dotnet test --filter FullyQualifiedName~StopDetectionTests` | ❌ Wave 0 |
| HIST-02 | `GetLocationHistoryQuery` returns polyline points scoped to caller's authorized family members only (IDOR check, mirrors Phase 1's FAM-04 test pattern) | unit (EF Core Sqlite in-memory) | `dotnet test --filter FullyQualifiedName~GetLocationHistoryQueryTests` | ❌ Wave 0 |
| NOTIF-01 | Falling-edge alert suppression (Pitfall 7) — alert fires once per threshold crossing, not once per ping | unit | `dotnet test --filter FullyQualifiedName~LowBatteryAlertTests` | ❌ Wave 0 |
| PRIV-02/03 | `UpdateSharingPreferenceCommand` enforces both FAM-04 membership AND `SharingPreference` authorization for a broadcast/read; expired temporary shares are excluded | unit | `dotnet test --filter FullyQualifiedName~SharingPreferenceTests` | ❌ Wave 0 |
| PRIV-03 | `SharingPreferenceSweepService` flips expired rows `IsEnabled = false` | unit (test the sweep logic as a pure/testable method, not the `BackgroundService` timer itself) | `dotnet test --filter FullyQualifiedName~SweepServiceTests` | ❌ Wave 0 |
| PRIV-04 | Export produces valid JSON of only the caller's own rows; delete removes them irreversibly | unit/integration | `dotnet test --filter FullyQualifiedName~ExportDeleteTests` | ❌ Wave 0 |

### Sampling Rate
- **Per task commit:** Backend — `dotnet test backend/tests/SafePath.Application.Tests --filter FullyQualifiedName~<Feature>`. Mobile — `flutter test mobile/test/features/<feature>`.
- **Per wave merge:** Full backend (`dotnet test` on the whole solution) + full mobile (`flutter test`) suites green.
- **Phase gate:** Full suite green before `/gsd-verify-work`.

### Wave 0 Gaps
- [ ] `backend/tests/SafePath.Application.Tests/Location/` — new test directory, mirrors the existing `Families/` test directory's fixture/fake conventions (EF Core Sqlite in-memory `IApplicationDbContext`, Moq for `IFamilyAuthorizationService`/`ILocationBroadcastService`)
- [ ] `backend/tests/SafePath.Application.Tests/Privacy/` — new test directory for `SharingPreference` command/query tests
- [ ] `mobile/test/features/location/` — new test directory; reuse the `FakeAuthApi`-style fake pattern for a `FakeLocationApi`/`FakeLocationHubClient`
- [ ] `mobile/test/features/privacy/` — new test directory
- [ ] No new framework installs needed — xUnit/Moq/EF Sqlite already referenced in `SafePath.Application.Tests.csproj`; `flutter_test` already the mobile default

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-------------------|
| V2 Authentication | yes | Existing Supabase JWT bearer scheme, extended to the SignalR hub via `OnMessageReceived` query-string wiring (Pitfall 1) — no new auth mechanism introduced |
| V3 Session Management | yes | SignalR's documented non-revalidation-mid-connection behavior (Pitfall 5) is an accepted, documented tradeoff for this phase's threat model; not a gap requiring new code, but worth a plan-level note |
| V4 Access Control | yes | Every location read/write must pass **both** `IFamilyAuthorizationService` (existing FAM-04/D5 membership check) **and** the new `SharingPreference` check (Pattern 7) — this is the phase's primary IDOR-prevention surface; a plan that implements one check without the other is a security gap |
| V5 Input Validation | yes | Location ping payloads (lat/lng bounds, accuracy sanity, timestamp not-in-future) should use the project's existing `FluentValidation` convention (per CLAUDE.md) mirroring Phase 1's family command validators |
| V6 Cryptography | yes | No new cryptography this phase beyond what's already in place (HTTPS/TLS for REST, WSS/TLS for SignalR in production) — never hand-roll; confirm `RequireHttpsMetadata = true` (already set) covers the hub's negotiate/WebSocket upgrade in production deployment config |

### Known Threat Patterns for this stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|----------------------|
| A family member queries another user's location history by guessing/enumerating a `userId`/`familyId` in the URL (IDOR) | Tampering, Information Disclosure | Server-side re-check via `IFamilyAuthorizationService` + `SharingPreference` on every read, never trust a client-supplied ID alone — exact continuation of Phase 1's locked D5 pattern |
| A user disables live-location sharing but a stale SignalR group broadcast still reaches a previously-authorized recipient (race between toggling `SharingPreference` and an in-flight broadcast) | Information Disclosure | Check `SharingPreference.IsEnabled` at broadcast time inside `ReportLocationCommandHandler`/`ILocationBroadcastService`, not only at initial group-join time — group membership (family circle) and sharing authorization (per-recipient toggle) are two separate, both-must-pass gates |
| A malicious/compromised client submits a spoofed `BatteryPercent`/location payload to trigger false alerts or pollute another user's history (payload doesn't include cryptographic proof of origin, only claims a `UserId`) | Spoofing, Tampering | `ReportLocationCommand`'s `UserId` must be derived from `Context.UserIdentifier` (the authenticated hub connection's own claim), never taken from the client-submitted payload body — mirrors `ICurrentUserService`'s existing pattern for REST endpoints |
| Access-token logging via query string (SignalR's documented `access_token` query param mechanism) | Information Disclosure | TLS protects the query string in transit, but server/proxy access logs may capture it — confirm production logging config does not log full request query strings for the `/hubs/location` path, per Microsoft's own security guidance referenced in the fetched docs (`learn.microsoft.com/aspnet/core/signalr/security`, not fetched in full this session — flag for the planner to review before production deployment) |

## Sources

### Primary (HIGH confidence)
- `learn.microsoft.com/aspnet/core/signalr/authn-and-authz` (fetched via WebFetch this session, `aspnetcore-9.0`/`10.0` monikers both present in the doc) — JWT bearer auth, `OnMessageReceived` query-string wiring, non-revalidation-mid-connection behavior
- `learn.microsoft.com/aspnet/core/signalr/groups` (fetched via WebFetch this session) — group join/leave API, reconnect/group-membership-not-preserved caveat, in-memory/no-scale-out-persistence caveat
- Direct repository reads: `backend/src/*/*.csproj` (confirms `net9.0` + `9.0.9` package versions actually in use), `backend/src/SafePath.Domain/Entities/*.cs`, `backend/src/SafePath.Application/Families/*.cs`, `backend/src/SafePath.Infrastructure/**`, `backend/src/SafePath.Api/Program.cs`, `mobile/pubspec.yaml`, `mobile/lib/core/**`, `mobile/lib/features/family/**`

### Secondary (MEDIUM confidence)
- `pub.dev/packages/google_maps_flutter`, `pub.dev/packages/geolocator`, `pub.dev/packages/signalr_netcore` (+ `/score`), `pub.dev/documentation/signalr_netcore/latest`, `pub.dev/packages/geolocator/example`, `pub.dev/packages/battery_plus` (all fetched via WebFetch this session — direct primary-registry pages, but the project's `classify-confidence` tool scores generic `webfetch` calls as LOW by default since it isn't a curated-docs-provider seam; treated here as MEDIUM on this agent's judgment because pub.dev is itself the authoritative registry, not a third-party aggregator — see Metadata)
- `github.com/sefidgaran/signalr_client` (fetched via WebFetch this session — upstream source repo for `signalr_netcore`, confirms star/fork/issue counts and maintenance-status language used in the Package Legitimacy Audit)

### Tertiary (LOW confidence)
- `github.com/Aksoyhlc/signalr_netcore` (fetched via WebFetch, turned out to be an unrelated low-activity fork/mirror, not the actual upstream — superseded by the `sefidgaran/signalr_client` fetch above; kept in this list only to document that it was checked and discarded)

## Metadata

**Confidence breakdown:**
- Standard stack: MEDIUM — `.NET`/SignalR facts are HIGH (official Microsoft Learn docs, current as of this research date); Flutter package version facts are MEDIUM by this agent's judgment (fetched directly from pub.dev, the authoritative Dart package registry) though the project's automated `classify-confidence` seam has no curated-provider case for pub.dev and would score raw `webfetch` calls as LOW by default — flagging this discrepancy explicitly rather than silently overriding the tool
- Architecture: HIGH for the SignalR hub/group/auth patterns (directly sourced from current Microsoft Learn docs); MEDIUM for the `SharingPreference` schema design and dwell-time stop-detection algorithm (sound, standard engineering judgment, but not sourced from an external authority — these are this agent's synthesized recommendations, tagged ASSUMED where appropriate)
- Pitfalls: HIGH for SignalR-specific pitfalls 1/2/5 (directly documented Microsoft behavior); MEDIUM for pitfalls 3/4/6/7 (sound engineering reasoning grounded in the locked CONTEXT.md/UI-SPEC.md decisions, not externally sourced)

**Research date:** 2026-07-12
**Valid until:** 2026-08-11 (30 days — stable ecosystem; re-verify package versions and the `signalr_netcore` reliability signals if planning is delayed past this window, since the flagged SUS package's own maintenance state could shift)
