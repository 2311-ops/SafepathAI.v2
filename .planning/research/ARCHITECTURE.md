# Architecture Research

**Domain:** Family-safety / real-time location-intelligence platform (mobile + backend + AI microservice)
**Researched:** 2026-07-06
**Confidence:** MEDIUM (patterns are well-established industry practice; specific numeric targets are directional, not benchmarked for this exact stack)

## Standard Architecture

### System Overview

```
┌──────────────────────────────────────────────────────────────────────────┐
│  FLUTTER APP (Android/iOS)                                               │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌────────────────┐ │
│  │ Auth UI  │ │ Live Map │ │  SOS btn │ │ Geofence │ │ Walk-Me-Home /  │ │
│  │          │ │ (SignalR │ │ (direct  │ │  mgmt UI │ │ Duress / Ledger │ │
│  │          │ │  client) │ │  REST)   │ │          │ │                 │ │
│  └──────────┘ └──────────┘ └──────────┘ └──────────┘ └────────────────┘ │
└───────────────────────────┬───────────────────────────┬──────────────────┘
              REST (auth, CRUD, SOS)        WebSocket (SignalR: LocationHub, AlertHub)
                            │                           │
┌───────────────────────────▼───────────────────────────▼──────────────────┐
│  ASP.NET CORE BACKEND  (Clean Architecture)                               │
│  ┌────────────────────────────────────────────────────────────────────┐  │
│  │  API layer: Controllers, SignalR Hubs, Middleware (auth, logging)   │  │
│  ├────────────────────────────────────────────────────────────────────┤  │
│  │  Application layer: Use cases (SOS, LocationIngestion, Geofence     │  │
│  │  evaluation orchestration, AI-result handling), DTOs, interfaces    │  │
│  ├────────────────────────────────────────────────────────────────────┤  │
│  │  Domain layer: Entities (User, Family, Location, Geofence, Alert…), │  │
│  │  value objects, domain events — zero external dependencies          │  │
│  ├────────────────────────────────────────────────────────────────────┤  │
│  │  Infrastructure layer: EF Core/Npgsql repos, background jobs,       │  │
│  │  Supabase client, push (FCM), HTTP client to AI service             │  │
│  └────────────────────────────────────────────────────────────────────┘  │
└──────────────┬─────────────────────────────────────────┬─────────────────┘
               │ Npgsql/EF Core                           │ internal REST (async, off SOS path)
┌──────────────▼─────────────┐               ┌────────────▼───────────────┐
│  SUPABASE / POSTGRESQL      │               │  PYTHON AI SERVICE          │
│  Users, Families, Locations,│               │  FastAPI + IsolationForest  │
│  Geofences, Alerts, Safety  │◄──────────────┤  (anomaly), XGBoost (ETA),  │
│  Scores, ExplanationLogs…   │  reads batches │  Explainability layer       │
└──────────────────────────────┘  writes back  └─────────────────────────────┘
                                    scores/explanations
```

### Component Responsibilities

| Component | Responsibility | Typical Implementation |
|-----------|----------------|-------------------------|
| Flutter app | UI, local caching, foreground/background location capture, SignalR client subscriptions, SOS trigger (visible + covert) | Riverpod/Bloc, `google_maps_flutter`, `signalr_netcore` or `signalr_core`, background geolocation plugin |
| ASP.NET Core API | AuthN/AuthZ, request validation, SOS fast-path orchestration, location batch ingestion endpoint, geofence CRUD, SignalR hub hosting, calling the AI service | Minimal APIs or Controllers, JWT bearer + refresh tokens, FluentValidation |
| Application layer (use cases) | Business orchestration: "record SOS," "ingest location batch," "evaluate geofence," "request safety score" — each as an explicit use-case/command handler | MediatR-style command/query handlers, or plain application services if MediatR is overkill for solo dev |
| Domain layer | Entities and invariants (e.g., a Geofence has a center+radius; an Alert has a severity; a WalkSession has an ETA and overrun rule) | POCOs, no EF/ASP.NET references |
| Infrastructure layer | Repository implementations, Supabase/Postgres access, background workers (hosted services), HTTP client wrapper for AI service, push notification sender | EF Core + Npgsql, `IHostedService` for batch/queue consumers, `HttpClientFactory` |
| SignalR Hubs (`LocationHub`, `AlertHub`) | Push live location + alerts to connected family members' devices, scoped via Groups per family | ASP.NET Core SignalR, group = `family:{familyId}` |
| Supabase/PostgreSQL | System of record for all persistent state; row-level security as a second auth layer if exposed directly to Flutter for anything (not recommended — go through the API) | Managed Postgres, EF Core migrations owned by the backend, not by Supabase's own tooling |
| Python AI service | Stateless(ish) inference: Isolation Forest anomaly scoring, XGBoost ETA prediction, safety-score computation, explanation generation | FastAPI, scikit-learn/XGBoost models loaded at startup, no direct DB writes — returns results to backend which persists them |

## Recommended Project Structure

```
safepathai/                                # monorepo root
├── mobile/                                # Flutter app — independent Flutter project
│   ├── lib/
│   │   ├── core/                          # theming (ThemeData from design tokens), routing, DI
│   │   ├── data/                          # API clients, SignalR client wrappers, local cache
│   │   ├── features/
│   │   │   ├── auth/
│   │   │   ├── family/
│   │   │   ├── location_map/
│   │   │   ├── geofencing/
│   │   │   ├── sos/                       # visible SOS + Silent/Duress decoy flow
│   │   │   ├── walk_me_home/
│   │   │   ├── dashboard/
│   │   │   └── health/                    # optional module, built last
│   │   └── shared_widgets/                # design-system components matching the 36-screen spec
│   ├── pubspec.yaml
│   └── test/
│
├── backend/                                # ASP.NET Core solution — independent .sln
│   ├── src/
│   │   ├── SafePath.Domain/                # entities, enums, domain events — no dependencies
│   │   ├── SafePath.Application/           # use cases, DTOs, interfaces (IAiServiceClient, IRepository<T>)
│   │   │   ├── Auth/
│   │   │   ├── Families/
│   │   │   ├── Locations/
│   │   │   ├── Geofencing/
│   │   │   ├── Sos/                        # kept intentionally thin/fast — see data flow below
│   │   │   ├── Alerts/
│   │   │   └── AiIntegration/              # commands that call into the AI service, always async
│   │   ├── SafePath.Infrastructure/         # EF Core DbContext, repos, Supabase/Npgsql config,
│   │   │   │                                 # HostedServices (batch consumers), AI HTTP client, FCM sender
│   │   │   ├── Persistence/
│   │   │   ├── BackgroundJobs/
│   │   │   └── ExternalServices/
│   │   └── SafePath.Api/                    # Controllers, SignalR Hubs, Program.cs, DI wiring
│   │       ├── Controllers/
│   │       ├── Hubs/                        # LocationHub.cs, AlertHub.cs
│   │       └── Middleware/
│   ├── tests/
│   │   ├── SafePath.Domain.Tests/
│   │   ├── SafePath.Application.Tests/
│   │   └── SafePath.Api.IntegrationTests/
│   └── SafePath.sln
│
├── ai-service/                              # Python service — independently deployable
│   ├── app/
│   │   ├── main.py                          # FastAPI app entrypoint
│   │   ├── models/                          # trained model artifacts (or fetched from storage)
│   │   ├── anomaly/                         # Isolation Forest pipeline
│   │   ├── eta/                             # XGBoost pipeline
│   │   ├── explainability/                  # plain-language explanation generation
│   │   └── schemas/                         # pydantic request/response contracts
│   ├── training/                            # offline notebooks/scripts to (re)train models
│   ├── requirements.txt
│   └── tests/
│
├── db/                                      # schema-as-code, shared reference for both backend & AI service
│   ├── migrations/                          # EF Core migrations are source of truth; mirrored SQL here for review
│   └── schema.sql                           # full ERD-derived schema, checked in for reference
│
├── docs/
│   └── design/                              # SYSTEM_DESIGN, HTML mockups, brief — read-only reference material
│
├── .planning/                               # GSD planning artifacts (this file lives here)
└── infra/                                   # deployment manifests (Azure App Service config, CI/CD, Docker)
    ├── backend.Dockerfile
    ├── ai-service.Dockerfile
    └── ci/
```

### Structure Rationale

- **Three top-level, independently buildable projects (`mobile/`, `backend/`, `ai-service/`):** each has its own dependency manifest (`pubspec.yaml`, `.sln`, `requirements.txt`) and can be opened, built, tested, and deployed without touching the others. This is what "somewhat independent" deployment means for a solo dev in one repo — no shared build tool, no cross-project imports at compile time, only network contracts.
- **`backend/src/*` mirrors Clean Architecture exactly as named in the brief** (Domain → Application → Infrastructure → API) so the folder structure *is* the dependency graph — if `Domain` ever references `Infrastructure`, that's a visible smell in the `.csproj` references, not just a convention violation.
- **`SafePath.Application/Sos/` is called out separately** because it must stay deliberately thin: no calls into `AiIntegration`, no dependency on anything that can block. Treat it as a boundary that code review (even self-review) checks specifically.
- **`ai-service/` has no direct DB access** — it receives feature payloads from the backend and returns scores/explanations; the backend persists everything. This keeps Postgres as the single source of truth and keeps the AI service stateless and trivially horizontally scalable/replaceable.
- **`db/` as a visible top-level folder** even though EF Core migrations technically live under `backend/`: with a schema this large (19 tables) it's worth having a human-reviewable `schema.sql` snapshot that both the backend dev-you and the AI-service dev-you can reference without opening the .NET project.
- **`infra/` centralizes deployment** so CI can build/push each of the three components independently (three Docker images / one Flutter build), matching "deploy somewhat independently."

## Architectural Patterns

### Pattern 1: SOS Fast-Path (bypass, don't optimize)

**What:** The SOS command handler does the absolute minimum synchronous work — persist the Alert row + last known location, then fan out notification via SignalR `AlertHub` group and a push notification — and nothing else touches it. It must never call the AI service, never wait on geofence evaluation, and never share a request pipeline/middleware stack with routine location ingestion beyond auth.
**When to use:** Any user action explicitly framed as "must work in seconds, always" (visible SOS, Silent/Duress).
**Trade-offs:** Duplicates a little code (a slimmed-down "create alert + notify" path exists independently of the general alert pipeline) but guarantees that a slow AI service, a Postgres hiccup on a non-critical table, or a geofence recalculation storm can never add latency to the one feature the whole product's trust is built on.

```csharp
// SafePath.Application/Sos/TriggerSosCommandHandler.cs
public async Task<SosResult> Handle(TriggerSosCommand cmd, CancellationToken ct)
{
    var alert = Alert.CreateSos(cmd.UserId, cmd.Lat, cmd.Lng, cmd.Kind); // Kind: Visible | Duress
    await _alertRepo.InsertAsync(alert, ct);                 // single fast write
    await _alertHub.NotifyFamily(cmd.FamilyId, alert);       // SignalR push, fire immediately
    _ = _pushSender.NotifyGuardiansAsync(alert);             // FCM, fire-and-forget, not awaited on critical path
    return SosResult.Delivered(alert.Id);
}
// No call to IAiServiceClient. No call to IGeofenceEvaluator. Ever.
```

### Pattern 2: Routine Location Pipeline (batch → persist → fan-out → enrich)

**What:** Location updates arrive in small batches (e.g., every 15-60s or on significant movement), are persisted first, then trigger two independent downstream paths: (1) an immediate, cheap geofence check against cached fence boundaries, pushed live over SignalR; (2) an async, decoupled call to the AI service for scoring, which updates the map/dashboard on its own schedule (seconds-to-minutes later, not blocking the location push).
**When to use:** All non-emergency location flow — this is the default/high-volume path.
**Trade-offs:** Slightly stale AI scores are acceptable (anomaly/ETA insight is inherently a lagging signal); geofence enter/exit notifications feel "instant" because they're decoupled from AI and computed from cached, indexed fence data.

```csharp
public async Task Handle(IngestLocationBatchCommand cmd, CancellationToken ct)
{
    var saved = await _locationRepo.InsertBatchAsync(cmd.Points, ct);      // 1. persist
    var events = _geofenceEvaluator.Evaluate(cmd.UserId, saved.Last());   // 2. cheap, cached, sync
    if (events.Any()) await _alertHub.NotifyFamily(cmd.FamilyId, events);
    await _locationHub.PushLocation(cmd.FamilyId, saved.Last());          // 3. live map update, always
    _aiQueue.Enqueue(new ScoreRequest(cmd.UserId, saved));                // 4. fire-and-forget to AI, async
}
```

### Pattern 3: Backend ↔ AI Service Integration (async job, correlation via DB, not sync REST)

**What:** The backend never blocks a user-facing request on the AI service. Location batches (and periodic feature windows) are pushed onto an internal queue (in-process channel/`BackgroundService` is enough at this scale — no need for Kafka/RabbitMQ for a graduation project); a background worker POSTs feature payloads to the Python service's REST endpoint, and on response, writes `SafetyScores`/`ExplanationLogs`/anomaly `Alerts` back to Postgres, which then triggers a SignalR push if relevant.
**When to use:** Any AI-service call (anomaly scoring, ETA prediction, safety score, cross-modal detection).
**Trade-offs:** Slightly more moving parts than "just call the API and await it," but this is the one architectural decision that structurally guarantees the SOS non-negotiable — the AI service can be down, slow, or mid-deploy and the rest of the app (including SOS) is unaffected. Solo-dev-appropriate: use .NET's built-in `Channel<T>` + `IHostedService` instead of standing up RabbitMQ/Azure Service Bus initially; migrate to a real broker only if throughput or reliability (at-least-once delivery across restarts) demands it later.

## Data Flow

### (a) SOS Priority Path

```
[User taps visible SOS button]  OR  [Silent/Duress gesture behind decoy screen]
    ↓ (Flutter: single REST POST /api/sos, includes last-known GPS fix already cached on-device)
[ASP.NET Core API: SosController.Trigger()]
    ↓ (auth middleware only — no AI middleware, no geofence middleware in this pipeline)
[TriggerSosCommandHandler]
    ├─→ INSERT Alerts row (severity=Critical, kind=SOS|Duress) ─── Postgres (single fast write, own connection)
    ├─→ AlertHub.Clients.Group(familyId).Send("SosTriggered", payload)  ─── SignalR, immediate push
    └─→ fire-and-forget FCM push to guardians/EmergencyContacts (not awaited)
    ↓
[Guardian's Flutter app] receives SignalR event within the same second the DB write commits
    → live location shown from the payload directly (no extra fetch needed for the first frame)
    → subsequent live tracking of the SOS-triggering user upgrades to full LocationHub stream automatically
```
**Latency-critical points:** the single Postgres INSERT and the SignalR group send. Both must be un-batched, un-queued, and on a hot path with no dependency on the AI service, geofence evaluator, or any batch job. FCM push (for guardians who don't have the app foregrounded) can be fire-and-forget since SignalR already carries the fast, connected-guardian case.
**What must NOT be on this path:** AI service calls, geofence recalculation, safety-score updates, ExplanationLogs writes, ActivityLogs writes (log those asynchronously after the fact if needed for audit).

### (b) Routine Location-Ingestion Path

```
[Flutter background location plugin buffers points, batch-uploads every ~15-60s or N meters moved]
    ↓ REST POST /api/locations/batch (or a lightweight ingestion endpoint over SignalR client→server invoke)
[ASP.NET Core: IngestLocationBatchCommandHandler]
    ↓
 1. INSERT batch into Locations table (Postgres) — bulk insert, single round trip
    ↓
 2. GeofenceEvaluator.Evaluate(latest point)
    — reads cached Geofence boundaries (in-memory or Redis, refreshed on Geofence CRUD, not per-request DB hit)
    — spatial check (radius/point-in-circle for MVP; geohash/R-tree only needed once fence count is large)
    — compares against last known inside/outside state (GeofenceBaselines / small state cache)
    → if state transition: INSERT GeofenceEvents, INSERT Notifications, push via AlertHub
    ↓ (this step is synchronous but cheap — pure math + cache lookup, no external service call)
 3. LocationHub.Clients.Group(familyId).Send("LocationUpdated", latest point) — live map push, always fires
    ↓
 4. Enqueue ScoreRequest(userId, recent window) onto internal channel — fire-and-forget, not awaited
    ↓ (background worker, decoupled in time)
[AiIngestionBackgroundService]
    ↓ internal REST POST to Python AI service /score (feature payload built from recent Locations window)
[Python AI Service: FastAPI]
    ├─ Isolation Forest → anomaly flag/score
    ├─ XGBoost → ETA (if a WalkSession is active)
    ├─ Explainability layer → plain-language string
    └─ returns { score, explanation, anomalyFlag } synchronously to the backend's internal call
    ↓
[Backend] persists SafetyScores + ExplanationLogs (+ Alerts if anomalyFlag and severity warrants it)
    ↓
[AlertHub / dashboard] pushed to family map/dashboard as an enrichment, arriving seconds-to-minutes
  after the raw location dot already moved — never blocking step 3.
```
**Latency-critical points:** step 1 (persist) and step 3 (live map push) — these define "does the map feel real-time." Step 2 (geofence) is latency-sensitive but cheap enough to stay synchronous as long as fence lookups are cached, not re-queried from Postgres per point. Step 4 onward (AI) is explicitly NOT latency-critical and should be treated as eventual-consistency enrichment.
**Where batching/async is safe:** the entire AI leg (step 4+) end-to-end; ActivityLogs/analytics aggregation; SafetyScores history rollups; anything feeding the family dashboard's charts (as opposed to the live map dot).
**Where it is not safe:** the Locations insert and the LocationHub push (users will notice a stale dot); the geofence enter/exit notification (a "left school" alert delivered 5 minutes late defeats its purpose almost as badly as SOS delay would, though with lower stakes).

## Scaling Considerations

| Scale | Architecture Adjustments |
|-------|--------------------------|
| Solo-dev MVP / demo (single family, handful of users) | Single ASP.NET Core instance (in-memory SignalR, no backplane needed), Supabase free/small tier, AI service as a single container called synchronously-from-a-background-worker over plain HTTP. In-process `Channel<T>` is sufficient as the "queue." |
| Small pilot (tens to low-hundreds of users, multiple families) | Still one backend instance is fine; add Redis for geofence-boundary caching and for a SignalR backplane if you ever run 2+ backend instances; keep AI as one instance behind the backend's HTTP client with retry/circuit-breaker (Polly). |
| Hypothetical scale-up (thousands+ concurrent, out of scope for this milestone) | Move SignalR to Azure SignalR Service to drop backplane management; replace in-process channel with a real broker (Azure Service Bus/RabbitMQ) between backend and AI service for durability across restarts; consider geohash/spatial-index for geofence evaluation once fence count grows past a few hundred per region. |

### Scaling Priorities

1. **First likely bottleneck:** SignalR fan-out and geofence cache correctness if the in-memory cache isn't invalidated properly on Geofence CRUD — not raw scale. Fix by keeping geofence cache invalidation simple and explicit (invalidate-on-write) long before worrying about spatial indexing.
2. **Second likely bottleneck (only if this grows beyond a graduation project):** the AI service becoming a queue backlog under load if it's slower than the location-ingestion rate. Fix by adding backpressure/sampling (score every Nth batch per user, not every batch) before reaching for a heavier broker.

## Anti-Patterns

### Anti-Pattern 1: Routing SOS through the same command pipeline as routine alerts

**What people do:** Reuse a generic `CreateAlertCommand` for both SOS and routine geofence/anomaly alerts "for consistency," with shared middleware/validators/enrichment steps.
**Why it's wrong:** Any shared pipeline step (even something as innocuous as an audit-log write or an AI-enrichment call added later "just for this alert type too") becomes a latent risk to the SOS latency guarantee. Shared code paths get modified for reasons unrelated to SOS and quietly regress it.
**Do this instead:** Give SOS its own command/handler/hub-method that is structurally incapable of calling the AI service or geofence evaluator (they're simply not injected into that handler). Shared concerns (e.g., "what does an Alert entity look like") can live in Domain; shared *pipelines* should not.

### Anti-Pattern 2: Making the AI service call synchronous and awaited inline in the ingestion request

**What people do:** `await _aiClient.ScoreAsync(...)` directly inside `IngestLocationBatchCommandHandler`, blocking the HTTP response (and therefore the client's perceived "did my location upload succeed") on a Python service round-trip.
**Why it's wrong:** Couples the reliability/latency of the entire location pipeline (including the live map) to a service that legitimately may be slow (model inference), being redeployed, or briefly down. It also makes "AI service is never on the SOS path" true only by convention, not by structure — a future refactor could easily blur the line.
**Do this instead:** Enqueue and return immediately; let a background worker own the AI round-trip and write results back asynchronously. This is the same discipline as Pattern 3 above.

### Anti-Pattern 3: Letting Flutter talk to Supabase directly for "simple" reads

**What people do:** Use the Supabase client SDK straight from Flutter for some tables (common Supabase quick-start pattern) while going through the ASP.NET backend for everything else, to "save a hop."
**Why it's wrong:** Splits authorization logic across two systems (Postgres RLS policies vs. backend AuthZ), breaks the Clean Architecture boundary the brief specifies, and makes the audit trail (Mutual Visibility Ledger, ActivityLogs) unreliable since some reads never pass through the backend that's supposed to log them.
**Do this instead:** Flutter talks only to the ASP.NET Core API (REST) and SignalR hubs. Supabase is purely the backend's database; Flutter never holds a Supabase key.

## Integration Points

### External Services

| Service | Integration Pattern | Notes |
|---------|---------------------|-------|
| Supabase/PostgreSQL | EF Core + Npgsql, backend-owned migrations | Treat Supabase here as "managed Postgres hosting," not as a BaaS with its own client-side SDK usage from Flutter |
| Firebase Cloud Messaging | Backend-initiated push via server SDK/HTTP v1 API, fire-and-forget from Infrastructure layer | Used as SOS's guarantee-of-delivery fallback when a guardian's app isn't foregrounded/connected to SignalR |
| Google Maps SDK | Flutter-side only (map rendering); backend never calls Google Maps directly for MVP (no server-side geocoding/routing needed unless ETA prediction later wants route-based features) | Keep server-side simple: XGBoost ETA can start from straight-line distance + historical speed, not live routing API calls |
| Azure (hosting) | Separate App Service (or container) per component: backend, AI service; each with its own CI/CD pipeline and Docker image | Matches "deploy somewhat independently" requirement directly |

### Internal Boundaries

| Boundary | Communication | Notes |
|----------|---------------|-------|
| Flutter ↔ ASP.NET Core API | REST (auth, CRUD, SOS trigger, location batch upload) | Stateless, JWT bearer + refresh token rotation |
| Flutter ↔ ASP.NET Core SignalR | WebSocket, two hubs: `LocationHub` (live position stream), `AlertHub` (SOS + geofence + anomaly alerts) | Client joins `family:{familyId}` group on connect after auth handshake |
| ASP.NET Core Application ↔ Infrastructure | C# interfaces (`ILocationRepository`, `IAiServiceClient`, `IPushNotificationSender`) implemented in Infrastructure, injected via DI | Enables swapping Supabase/Postgres or the AI transport without touching Application logic |
| ASP.NET Core ↔ Python AI service | Internal REST (`POST /score`, `POST /eta`), always invoked from a background worker/queue consumer, never from a synchronous user-facing request handler | This is the one integration decision that structurally protects the SOS guarantee — treat it as non-negotiable, not a performance nice-to-have |

## Suggested Build Order (Walking Skeleton → Layers)

This is the dependency reasoning that should drive roadmap phase slicing.

1. **Backend + Supabase + Auth walking skeleton.** Stand up the ASP.NET Core solution (all four projects, even if Infrastructure/Domain are nearly empty), provision Supabase, wire EF Core migrations for the core identity tables (Users, Families, FamilyMembers, RefreshTokens), implement register/login/refresh. *Hard dependency:* nothing can be demoed or built on top without a working auth+DB baseline. This is true infrastructure, not a feature — do it first regardless of feature-parallelization preference.
2. **Basic location ingestion + REST-only map (no SignalR yet).** Add `Locations` table, a batch-ingestion endpoint, and a simple "get latest location" REST endpoint the Flutter app polls. This proves the data model and the mobile↔backend contract before adding real-time complexity. *Hard dependency:* requires (1). *Not a hard dependency:* SignalR — polling is a legitimate, demoable intermediate step.
3. **SOS fast path, built directly on (1)+(2), before SignalR/geofencing/AI exist.** This is the most important sequencing insight: **SOS does not depend on SignalR, geofencing, or AI at all.** A minimal SOS (REST endpoint → DB write → FCM push, or even just DB write + guardian polls/refreshes) can be demoed as early as phase 2-3. Since SOS is the core value proposition, prove it end-to-end early — it de-risks the single most important requirement first, and every later phase must be checked against "did this slow down or complicate SOS?"
4. **SignalR layer (`LocationHub`, `AlertHub`) replacing polling.** Upgrades (2) and (3) to real-time push. *Hard dependency:* requires (1)+(2); benefits from (3) existing so `AlertHub` has a real event to carry, but SignalR infrastructure itself (hub setup, group management, auth handshake) can be built and tested independently with dummy events first.
5. **Geofencing.** Requires (2)'s location data flowing; does NOT require AI/anomaly detection or SignalR to exist first in principle (could be REST-notification-only), but is much more valuable once (4) exists so enter/exit alerts arrive live. Build geofence CRUD + evaluation logic once (2) is stable; wire its notifications through (4) once that lands. **Geofencing has zero dependency on the AI service** — this is a second key insight: hard/soft geofencing, safe zones, and enter/exit logging are pure business logic + spatial math, entirely independent of Isolation Forest/XGBoost.
6. **Python AI service (anomaly detection, ETA prediction, safety scoring, explainability) + async integration plumbing.** *Hard dependency:* requires (2) for historical location data to train/score against, and ideally (5) for baseline/geofence-deviation features feeding Predictive Soft Geofencing. Does NOT block, and is not blocked by, SOS. Stand up the async job/queue plumbing (Pattern 3) at the same time as the first AI integration, not after — retrofitting "make this async" onto an already-synchronous call is exactly the kind of refactor likely to accidentally leak into the SOS path.
7. **Signature features layered on top, each with a distinct dependency:**
   - **Walk-Me-Home:** does **not** strictly require XGBoost ETA prediction to ship a first version — a v1 using straight-line-distance + average historical speed (or even a user-set duration) to compute an "expected arrival window" is a legitimate, demoable slice that auto-escalates to the SOS pipeline (3) on overrun. XGBoost ETA can replace the naive estimate later as a drop-in upgrade behind the same interface (`IEtaEstimator`), without changing the escalation logic. Treat "ETA prediction accuracy" and "Walk-Me-Home escalation mechanics" as separably shippable.
   - **Silent/Duress SOS:** builds directly on (3); mainly a Flutter-side decoy-UI + trigger-gesture concern, backend-side it's the same Alert pipeline with a `kind=Duress` flag. No AI dependency.
   - **Mutual Visibility Ledger:** requires (2)/(4) (location viewing must be happening) but not AI; it's a logging/read-audit feature (`LocationViewLogs`) bolted onto existing read paths.
   - **Predictive (Soft) Geofencing:** requires both (5) (geofences) and (6) (baseline/anomaly modeling on `GeofenceBaselines`) — this is the one signature feature with a genuine hard dependency on the AI layer.
   - **Cross-Modal Anomaly Detection:** requires (6) plus the Health module; explicitly the last thing to build per the brief's own note that it depends on Health.
8. **Health & Wellness module.** Independent data domain; can be built in parallel with (5)/(6) once the walking skeleton is solid, since nothing else hard-depends on it except Cross-Modal Detection.
9. **Full Flutter design-system pass (all 36 screens).** This can and should run in parallel with backend phases throughout, feature-by-feature, rather than as a single terminal phase — screen shells (using mock data) can be built as soon as a feature's contract is defined, then wired to real endpoints as each backend phase lands.

**Summary of the "what blocks what" graph:**
```
Auth+DB (1) ──→ Location ingestion (2) ──→ SOS fast path (3)  [earliest demoable core-value milestone]
                       │                         │
                       ├──→ SignalR (4) ◄─────────┘ (4 upgrades 2 & 3 to real-time, not a prerequisite of either)
                       │
                       ├──→ Geofencing (5) ──────────────────┐
                       │                                     │
                       └──→ AI service + async plumbing (6) ─┴──→ Predictive Soft Geofencing
                                      │                            Cross-Modal Detection (+ Health)
                                      └──→ Walk-Me-Home v1 (naive ETA, no hard dep on 6)
                                                │
                                           Walk-Me-Home v2 (XGBoost ETA swapped in behind same interface)
```

## Sources

- [Clean Architecture In ASP.NET Core Web API — C# Corner](https://www.c-sharpcorner.com/article/clean-architecture-in-asp-net-core-web-api/)
- [Implementing Clean Architecture in .NET 10 — codewithmukesh](https://codewithmukesh.com/blog/clean-architecture-dotnet/)
- [Common web application architectures — Microsoft Learn](https://learn.microsoft.com/en-us/dotnet/architecture/modern-web-apps-azure/common-web-application-architectures)
- [What is Azure SignalR Service? — Microsoft Learn](https://learn.microsoft.com/en-us/azure/architecture/example-scenario/signalr)
- [How to build real-time delivery tracking with Azure Maps and SignalR](https://www.qservicesit.com/how-to-build-real-time-delivery-tracking-with-azure-maps-and-signalr)
- [How to Scale ASP.NET Core SignalR Apps — NCache](https://www.alachisoft.com/blogs/scaling-real-time-asp-net-core-signalr-apps/)
- [Microservices Communication Patterns: REST, gRPC, or Message Queues — DEV Community](https://dev.to/benyusouf/microservices-communication-patterns-when-to-use-rest-grpc-or-message-queues-2dl4)
- [Patterns for Microservices — Sync vs. Async — DZone](https://dzone.com/articles/patterns-for-microservices-sync-vs-async)
- [Optimizing ML Serving with Asynchronous Architectures — ODSC](https://odsc.medium.com/optimizing-ml-serving-with-asynchronous-architectures-1071fc1be8e2)
- [Geofencing Architecture: Location-Aware Systems at Scale — Codelit.io](https://codelit.io/blog/geofencing-location-services)
- [Using Geofence to Trigger Real-Time Events — NextBillion.ai](https://nextbillion.ai/feeds/blog/geofence-trigger-event)
- [Developing real-time IoT-based public safety alert and emergency response systems — Nature Scientific Reports](https://www.nature.com/articles/s41598-025-13465-7)

---
*Architecture research for: SafePath AI (family-safety / real-time location platform, solo-dev monorepo)*
*Researched: 2026-07-06*
