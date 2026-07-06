# Project Research Summary

**Project:** SafePath AI
**Domain:** Family-safety / real-time location-intelligence platform (software-only, solo-dev graduation project)
**Researched:** 2026-07-06
**Confidence:** MEDIUM

## Executive Summary

SafePath AI is a family-safety platform built on a fixed four-pillar stack (Flutter mobile app, ASP.NET Core backend, Supabase/Postgres, Python AI microservice) that competes with Life360, Apple Find My, and hardware-wearable products (Jiobit, GizmoWatch) but does so software-only, with an explicit "SOS must always work, bypassing every routine and AI pipeline" Core Value. Experts build this class of product around one non-negotiable architectural discipline: the emergency/SOS path is structurally isolated from everything else (no shared middleware, no AI calls, no geofence evaluation), while all "smart" functionality (anomaly detection, ETA prediction, geofence enrichment) is treated as async, eventually-consistent enrichment layered on top of a synchronous, always-on ingestion/notification core.

The recommended approach is a three-project monorepo (mobile/, backend/, ai-service/) following Clean Architecture in the backend, with location ingestion -> cheap synchronous geofence check -> live SignalR push as the default path, and a decoupled background worker calling the Python AI service for anomaly/ETA scoring that writes results back to Postgres asynchronously. Stack choices (.NET 10 LTS, Flutter 3.44/Dart 3.9, Python 3.12 + scikit-learn 1.9/XGBoost 3.3, native OS geofencing APIs instead of polling) are current-as-of-2026 and cross-checked against primary registries, though exact patch versions should be re-verified at build time.

The two dominant risk categories are (1) silent failure modes invisible until real-device/real-network testing - background location dying on OEM devices, SOS "sent" with no actual delivery confirmation, geofence flapping, AI cold-start garbage - all of which look fine in a dev environment and fail in the field; and (2) solo-dev scope collapse, given this brief describes a multi-team product (5 signature AI features, a 36-screen design system, a Health module) with no external deadline pressure to force scope cuts. The highest-leverage mitigation for both is to treat the Core Value literally as the MVP: sequence phases core-first (auth -> location ingestion -> SOS fast path -> SignalR -> geofencing) each gated on a real, demoable artifact, before any AI or signature feature work begins, and build every "smart" feature with an explicit degraded/fallback state (stale-location UX, cold-start suppression, offline SOS queueing) from day one rather than retrofitting it later.

## Key Findings

### Recommended Stack

The four pillars are fixed by the brief; research focused on how to implement them well in 2026. Key correction to the brief implied approach: geofencing must use native OS APIs (native_geofence/GeofencingClient/CLCircularRegion), not a foreground-service polling loop - Google Play April 2026 policy update explicitly disallows the polling pattern. Background tracking should use geolocator + flutter_foreground_task (free/open-source) rather than the 500-dollar-per-app commercial flutter_background_geolocation. The backend-to-AI integration must be async (internal queue/background worker), never synchronous-awaited inline, to structurally protect the SOS latency guarantee.

**Core technologies:**
- Flutter 3.44 / Dart 3.9 - mobile app, Impeller rendering, current stable
- .NET 10 / ASP.NET Core 10 (LTS through Nov 2028) - backend API + SignalR hub host
- EF Core 10 + Npgsql.EntityFrameworkCore.PostgreSQL 10.0.x - ORM over Supabase Postgres (versions must match 1:1 across the triple)
- Python 3.12 + FastAPI + scikit-learn 1.9 (Isolation Forest) + XGBoost 3.3 (ETA) - AI microservice; Python 3.12 floor driven by XGBoost 3.x dropping support for 3.9-3.11
- native_geofence, geolocator+flutter_foreground_task, firebase_messaging, health, flutter_secure_storage - the mobile-side supporting library set matched to this exact feature set

### Expected Features

Beyond what PROJECT.md already lists (auth/roles, family circles, live location, geofencing, SOS, smart notifications, 4 AI features, dashboards, privacy controls, 5 signature differentiators, optional Health module), research surfaced specific trust-critical gaps.

**Must have (table stakes / P1, protects Core Value):**
- Offline/no-connectivity SOS fallback (retry-queue, clear "not sent yet" state) - critical gap, the Core Value assumes network availability today
- Stale-location / "last seen" UX with visible accuracy radius
- Battery-usage transparency screen
- Background-location permission-priming screen before the OS dialog

**Should have (differentiators, P2, low-cost given planned infra):**
- Phone-accelerometer crash/fall detection reusing the Cross-Modal Anomaly pipeline
- Explanation-in-push-notification pattern (extends the already-planned Explainability Layer)
- Consent-first re-share gate on the Mutual Visibility Ledger
- SOS verify-before-dispatch self-cancel channel (must never delay the guardian alert)
- Companion/Kiosk Mode for non-smartphone family members (software-only answer to the no-hardware constraint)

**Defer / do not build (anti-features):**
- Wearable-grade fall detection or continuous heart-rate monitoring (already Out of Scope)
- Human-staffed 24/7 dispatch center (not code-buildable, incompatible with solo-dev scope)
- Driving-behavior analytics (already Out of Scope)
- A second memorized duress PIN (documented UX failure mode - keep the decoy-gesture pattern already planned)
- Training AI models from scratch pre-launch instead of using seeded/synthetic data (already correctly scoped)

### Architecture Approach

Three independently-buildable projects (mobile/, backend/, ai-service/) in one monorepo, with the backend following Clean Architecture (Domain -> Application -> Infrastructure -> API) exactly as the folder structure. The single most important pattern is the SOS Fast-Path: a dedicated command handler that inserts an Alert row, pushes via SignalR AlertHub, and fire-and-forgets an FCM push - structurally incapable of calling the AI service or geofence evaluator. Routine location ingestion is a separate pipeline: persist -> cheap synchronous geofence check (cached boundaries) -> live SignalR push -> fire-and-forget enqueue to an async AI-scoring worker. The backend-to-Python integration always goes through an internal queue/background worker (in-process Channel-based BackgroundService is sufficient at this scale), never a synchronous awaited call inline.

**Major components:**
1. Flutter app - UI, background location capture, SignalR client, SOS trigger (visible + covert)
2. ASP.NET Core backend (Clean Architecture) - auth, SOS fast-path, location ingestion, geofence CRUD, SignalR hubs (LocationHub, AlertHub), AI integration orchestration
3. Supabase/Postgres - system of record (Users, Families, Locations, Geofences, Alerts, SafetyScores, ExplanationLogs), accessed only through the backend, never directly from Flutter
4. Python AI service (FastAPI) - stateless Isolation Forest anomaly scoring, XGBoost ETA prediction, SHAP-based explainability, no direct DB writes

### Critical Pitfalls

1. **Background location silently dies on real OEM devices** (Xiaomi/Huawei/Samsung battery killers, iOS background limits) - mitigate with foreground service + SLC fallback + a visible staleness indicator; test on real budget Android hardware, not just emulator.
2. **SOS has a hidden single point of failure** (push accepted is not delivered, SignalR reconnect loses subscription state) - mitigate with multi-channel delivery (SignalR + high-priority push + SMS fallback), server-side delivery-ack tracking, and re-subscribe/gap-fill on every reconnect.
3. **Geofence flapping from GPS noise** near boundaries - mitigate with minimum radius (about 100-150m), dwell-time/hysteresis (about 60-120s), and notification rate-limiting; must be designed into the initial evaluator, not retrofitted.
4. **Isolation Forest alert fatigue** on normal-but-varied family routines - mitigate with per-user/per-family baselines, rule-based filters on top of the model, cold-start suppression (about 2-3 weeks), and human-adjustable sensitivity.
5. **Solo-dev scope collapse** - the brief describes a multi-team product; mitigate by treating the Core Value (SOS) as the literal MVP and sequencing every other feature strictly after the core loop is solid and demoable.

## Implications for Roadmap

Based on combined research, the dependency graph is unusually clear: SOS explicitly does not depend on SignalR, geofencing, or AI - it can and should be proven end-to-end before those exist. Geofencing has zero dependency on the AI service. Only Predictive/Soft Geofencing and Cross-Modal Detection have genuine hard dependencies on the AI layer.

### Phase 1: Backend + Supabase + Auth Walking Skeleton
**Rationale:** Nothing can be built or demoed on top without a working auth+DB baseline; this is infrastructure, not a feature.
**Delivers:** ASP.NET Core solution scaffolded (all four Clean Architecture projects), Supabase provisioned, EF Core migrations for identity tables, register/login/refresh working.
**Addresses:** Foundational plumbing for every later feature.
**Avoids:** Pitfall 7 (JWT/refresh-token handling) - get secure storage and rotation right here, not retrofitted later.

### Phase 2: Location Ingestion + REST-only Map (no SignalR yet)
**Rationale:** Proves the data model and mobile-to-backend contract before adding real-time complexity; polling is a legitimate intermediate step.
**Delivers:** Locations table, batch-ingestion endpoint, get-latest-location REST endpoint polled by Flutter.
**Uses:** geolocator + flutter_foreground_task for background capture.
**Implements:** Infrastructure-layer repositories, first vertical slice of the location pipeline.

### Phase 3: SOS Fast Path
**Rationale:** SOS has no hard dependency on SignalR/geofencing/AI - prove the Core Value end-to-end as early as possible; every later phase must be checked against whether it slows down or complicates SOS.
**Delivers:** Minimal SOS (REST -> DB write -> FCM push, guardian polls/refreshes), architected as a structurally isolated command handler.
**Addresses:** Core Value guarantee; offline/no-connectivity SOS fallback (P1 feature gap).
**Avoids:** Pitfall 2 (SOS single point of failure) and Anti-Pattern 1 (shared alert pipeline) - build the multi-channel delivery + ack tracking discipline in from the start.

### Phase 4: SignalR Real-Time Layer
**Rationale:** Upgrades Phases 2-3 from polling to real-time; requires (1)+(2), benefits from (3) existing.
**Delivers:** LocationHub and AlertHub, group-scoped per family, replacing REST polling.
**Uses:** ASP.NET Core SignalR, strongly-typed Hub-of-IAlertClient pattern.
**Avoids:** Pitfall 2 reconnect/re-subscription gap - build gap-fill via HTTP query into the reconnect flow immediately.

### Phase 5: Geofencing
**Rationale:** Requires location data flowing (Phase 2); zero dependency on the AI service; much more valuable once SignalR (Phase 4) exists for live enter/exit alerts.
**Delivers:** Geofence CRUD, native OS geofencing integration (native_geofence), dwell-time/hysteresis evaluation logic.
**Addresses:** Core geofencing requirement.
**Avoids:** Pitfall 3 (flapping/false positives) and the What-NOT-to-Use flag on manual polling - must use native Geofence APIs per the April 2026 Play policy change.

### Phase 6: Python AI Service + Async Integration Plumbing
**Rationale:** Requires historical location data (Phase 2) and ideally geofence baselines (Phase 5); does not block, and is not blocked by, SOS. Stand up the async queue/worker pattern at the same time as the first AI integration.
**Delivers:** FastAPI service with Isolation Forest (anomaly), XGBoost (ETA), SHAP-based explainability; backend-side background worker + IAiServiceClient abstraction with Polly circuit breaker.
**Uses:** Python 3.12, scikit-learn 1.9, XGBoost 3.3, FastAPI, SHAP.
**Avoids:** Pitfall 4 (alert fatigue - build per-user baselines and cold-start suppression in from the start) and Pitfall 5 (ETA/geofencing cold-start - build the two-tier fallback system alongside the personalized model, not after).

### Phase 7: Signature Features Layer
**Rationale:** Each of the five signature features has a distinct, now-satisfiable dependency; sequence by dependency depth, not by impressiveness.
**Delivers:** Walk-Me-Home (naive ETA v1, no hard AI dependency, upgradeable to XGBoost later behind the same interface), Silent/Duress SOS (Flutter decoy UI + kind=Duress flag on the existing Alert pipeline), Mutual Visibility Ledger (logging/audit bolted onto existing read paths), Predictive/Soft Geofencing (genuine hard dependency on Phase 5+6), Cross-Modal Anomaly Detection (depends on Phase 6 + Health module, build last).
**Avoids:** Pitfall 6 (duress secret storage/observability) - threat-model the Silent/Duress feature explicitly as security-under-coercion, not just UI logic.

### Phase 8: Health & Wellness Module
**Rationale:** Independent data domain; can run in parallel with Phases 5-6 once the walking skeleton is solid; nothing else hard-depends on it except Cross-Modal Detection.
**Delivers:** HealthKit/Health Connect integration via the health package, narrowly-scoped permission requests at first module use.
**Avoids:** Pitfall 8 (broad upfront health permissions, App Store rejection risk).

### Phase Ordering Rationale

- Core-value-first sequencing (auth -> location -> SOS -> real-time -> geofencing) directly follows the architecture research dependency graph and the pitfalls research number-one mitigation for solo-dev scope collapse: prove the one non-negotiable feature (SOS) before building anything that could complicate it.
- AI/signature features are deliberately sequenced last and built to degrade gracefully (naive ETA fallback, cold-start suppression) so the product is fully demoable at every phase boundary, not partially done on many things.
- Every phase from 3 onward should be reviewed against the explicit anti-pattern: nothing added later should route through, block, or share a pipeline with the SOS command handler.

### Research Flags

Phases likely needing deeper research during planning:
- **Phase 3 (SOS Fast Path):** multi-channel delivery/ack design (SMS fallback provider choice, e.g. Twilio integration specifics) needs implementation-time research.
- **Phase 5 (Geofencing):** exact dwell-time/hysteresis parameters and Android April 2026 policy wording should be re-verified against support.google.com/googleplay/android-developer at build time.
- **Phase 6 (AI Service):** cold-start fallback design (two-tier prediction system, seeding synthetic location history for demo) needs concrete design during planning.
- **Phase 7 (Silent/Duress SOS):** security-under-coercion threat modeling is domain-specific and underspecified beyond the general pattern.

Phases with standard patterns (skip research-phase):
- **Phase 1 (Auth/Backend skeleton):** well-documented Clean Architecture + ASP.NET Core 10 + EF Core patterns.
- **Phase 2 (Location Ingestion):** standard REST/EF Core CRUD, no novel patterns.
- **Phase 4 (SignalR):** well-documented Microsoft Learn patterns for hub/group setup.

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | MEDIUM | Versions cross-checked against pub.dev/PyPI/NuGet/Microsoft Learn directly, but no Context7/curated-docs provider was available; re-verify exact patch versions at build time. |
| Features | MEDIUM | Web-sourced, cross-checked across 2+ independent sources per topic; no single authoritative spec exists for this product category. |
| Architecture | MEDIUM | Patterns are well-established industry practice (Clean Architecture, SOS-isolation, async AI integration); specific numeric targets (latency budgets) are directional, not benchmarked for this exact stack. |
| Pitfalls | MEDIUM | Broad web/community + official-docs corroboration across multiple sources per topic; no single-vendor primary-source deep dive; treat exact numbers as directional. |

**Overall confidence:** MEDIUM

### Gaps to Address

- Android Play Store policy on background-location foreground services changed April 15, 2026 - re-verify current wording before implementing geofencing (Phase 5).
- Apple App Store Review Guidelines Section 5.1.1 wording on background location/health data was not confirmed against a single canonical page - verify directly at build time.
- SMS-fallback provider for SOS (Twilio or equivalent) needs a concrete integration decision and cost/complexity check during Phase 3 planning - not resolved here.
- Exact dwell-time/hysteresis parameter values for geofencing are directional recommendations, not validated against this app actual usage patterns - treat as a starting point to tune during Phase 5.
- No official primary-source benchmarking exists for SignalR fan-out limits or AI-service backpressure thresholds at this project actual scale - acceptable since scale is explicitly out of scope for a graduation-project milestone, but flag if the project pivots toward real user growth.

## Sources

### Primary (MEDIUM confidence - official registries/docs, no curated-docs provider available)
- pub.dev, PyPI, NuGet, npgsql.org - package version/compatibility data (STACK.md)
- Microsoft Learn, devblogs.microsoft.com (.NET 10, SignalR, Clean Architecture) - architecture and stack guidance
- developer.apple.com (Core Location, HealthKit privacy) - background location and health-permission guidance
- developer.android.com (geofencing) - Android geofencing best practices
- Google Play Console Help - background location policy (April 2026 update, time-sensitive)
- Supabase official docs - connection pooling/RLS guidance

### Secondary (MEDIUM confidence - aggregated web/community sources, cross-checked)
- Competitor analysis: Life360, Apple Find My/Google Find Hub, Jiobit, GizmoWatch, HeyPolo, Glympse, OtoZen (FEATURES.md)
- Engineering write-ups on SignalR reconnection, push delivery reliability, geofencing accuracy, Isolation Forest alert fatigue, ML cold-start problem (PITFALLS.md, ARCHITECTURE.md)
- Flutter secure-storage and background-service benchmarking articles (Medium, LeanCode)

### Tertiary (LOW-MEDIUM confidence - needs validation)
- Apple App Store Review Guidelines wording on background location (no single canonical page cited verbatim - verify at build time)
- Exact numeric thresholds (dwell-time, geofence radius, push delivery rates) - directional, not contractual

---
*Research completed: 2026-07-06*
*Ready for roadmap: yes*
