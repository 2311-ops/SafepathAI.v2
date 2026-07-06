# Stack Research

**Domain:** Software-only family-safety / real-time location-intelligence platform (Flutter + ASP.NET Core + Supabase Postgres + Python AI service, Azure-hosted)
**Researched:** 2026-07-06
**Confidence:** MEDIUM (versions cross-checked directly against pub.dev, PyPI, NuGet, npgsql.org, Microsoft Learn, and official Apple/Google policy pages; no Context7/Exa/Tavily MCP providers were available in this environment, so every claim below is WebSearch/WebFetch-sourced against primary registries rather than a curated docs provider — treat exact patch numbers as "verify at build time," but the architectural guidance is stable)

The four stack pillars (Flutter/Dart, ASP.NET Core, Supabase/Postgres, Python AI) are fixed by the project brief and are **not** re-litigated here. This document is about *how to implement that exact combination well in 2026* — current versions, the specific packages/patterns that fit SafePath AI's requirements (continuous background location, geofencing, SOS-priority push, explainable AI serving), and where the brief's implied approach needs a specific correction.

---

## Recommended Stack

### Core Technologies

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| Flutter SDK | **3.44.x** (stable channel, May 2026) | Mobile app framework (Android + iOS) | Current stable as of mid-2026; ships the modern Impeller rendering engine by default on both platforms and the current Android Embedding v2 model that all recommended plugins below target. Pin via `.fvmrc`/FVM or `flutter --version` in CI so the whole team (or your CI) builds against one known SDK. |
| Dart SDK | **3.9.x** (bundled with Flutter 3.44) | Language runtime | Ships with the Flutter SDK; no separate install needed. Use `sdk: ^3.9.0` in `pubspec.yaml`. |
| .NET / ASP.NET Core | **.NET 10 (ASP.NET Core 10)** | Backend Web API + SignalR host | Released Nov 11, 2025 as an **LTS** release (supported through Nov 2028) — the correct choice for a project with no fixed ship date that needs 2-3 years of runway without a forced framework migration. Do not target .NET 9 (STS, already past its "current" window by mid-2026) or wait for .NET 11 (preview-only, not GA). |
| EF Core | **10.0.x** | ORM over Supabase Postgres | Ships/versions in lockstep with the .NET 10 SDK. Needed for the Clean-Architecture Repository Pattern the brief specifies. |
| Npgsql.EntityFrameworkCore.PostgreSQL | **10.0.x** (requires `Microsoft.EntityFrameworkCore >= 10.0.4, < 11.0.0`) | Postgres provider for EF Core | Official, actively maintained Postgres/EF Core bridge; version numbers track EF Core major versions 1:1, so "Npgsql EFCore 10" + "EF Core 10" + ".NET 10" is the only mutually-compatible triple — do not mix an EF Core 10 app with the 9.x Npgsql provider. |
| Python | **3.12** (3.13 acceptable) | AI analytics service runtime | XGBoost 3.3.x now requires Python **≥3.12** (it dropped 3.9-3.11 support). scikit-learn 1.9.x requires ≥3.11. Python 3.12 is the safe intersection that also has full wheel support across pandas/numpy/scikit-learn/XGBoost/FastAPI as of mid-2026. Do not use 3.11 (XGBoost incompatible) or bleeding-edge 3.14 (some ML wheels lag). |
| scikit-learn | **1.9.0** (June 2026) | Isolation Forest, preprocessing, model evaluation | Current stable; requires Python ≥3.11. If you need a longer-tested baseline, 1.7.2 (Sept 2025, first version to support Python 3.14) is a safe fallback, but there's no reason to pin below 1.9 for a greenfield project. |
| XGBoost | **3.3.0** (June 2026) | ETA prediction (regression) | Current stable. Note the **Python ≥3.12 floor** — this is the constraint that should drive your Python version choice above, not the other way around. |
| FastAPI | **0.136.x** (April 2026) + Pydantic **≥2.7** | Internal AI microservice web framework | The de-facto standard for wrapping a scikit-learn/XGBoost model in a small internal HTTP service: async-native, auto-validates request/response schemas via Pydantic (which doubles as your explainability-payload contract), and needs almost no boilerplate for a service this size. |
| Uvicorn | latest (ASGI server, ships with `fastapi[standard]`) | ASGI server for FastAPI | Run behind Gunicorn with `uvicorn.workers.UvicornWorker` (or plain `uvicorn --workers N`) in the container; do not use Flask/WSGI here — FastAPI/uvicorn is async and pairs naturally with Isolation Forest/XGBoost inference which is CPU-bound but short. |

### Supporting Libraries — Flutter / Mobile

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `google_maps_flutter` | **2.17.x** (+ `google_maps_flutter_android`, `google_maps_flutter_ios`, federated platform packages, kept in lockstep) | Live map, geofence visualization, history/route rendering | This is the brief's specified map SDK; current federated-plugin architecture means you pull the umbrella package and the platform packages resolve automatically. Requires a Google Cloud Maps SDK API key per platform. |
| `geolocator` | **14.0.x** | Foreground location, one-shot/position-stream API, permission handling wrapper | Use for **all in-app / foreground location reads** (live map "my location," ETA calc inputs, ETA-mode "Walk Me Home"). It is intentionally a thin, honest wrapper around `CLLocationManager`/`FusedLocationProviderClient` with **no** built-in battery intelligence — that's fine for foreground use, it's the background case where you need more. |
| `flutter_foreground_task` | **9.2.x** | Android foreground service + iOS background execution for **continuous** background tracking | Pair with `geolocator` to keep a location stream alive while the app is backgrounded/killed-and-relaunched on Android (mandatory since Android 8+ background execution limits) and to keep a background task alive on iOS within Apple's background modes. This is the standard, MIT/free-licensed pattern used in place of `flutter_background_geolocation`'s $500/app-per-year commercial license — appropriate for a graduation project budget. Requires Flutter ≥3.22, Android ≥5.0, iOS ≥12. |
| `native_geofence` | current stable (battery-efficient wrapper) | **Geofencing** (safe zones: Home/School/Work) | Do **not** implement geofencing via location polling. This package binds directly to Android's `GeofencingClient` and iOS's `CLCircularRegion`/region-monitoring — the OS handles the enter/exit detection in a battery-optimized way (Android: geofence transitions delivered every ~couple of minutes regardless of app state; iOS: region monitoring wakes the app on boundary cross). See **Pitfall flag** below — as of the April 2026 Google Play policy update, using a *foreground service* to “poll and check geofence bounds yourself” is explicitly **no longer an approved use case** on Android; you must use the native Geofence API path this package provides. Requires iOS 14+/Android API 23+, plus background location permission on both platforms. |
| `flutter_local_notifications` | current stable | Local notification fallback (SOS confirmation, low-battery, geofence enter/exit) | Combine with FCM for a belt-and-braces notification path so SOS/geofence alerts still surface even if a push is delayed. |
| `firebase_core` + `firebase_messaging` | **firebase_messaging 16.4.x** (paired `firebase_core` latest) | Push notifications (FCM): SOS delivery to guardians, geofence/low-battery/inactivity alerts | This is the brief's specified push channel. Android needs no extra native wiring beyond `google-services.json` (Embedding v2, default since Flutter ≥1.12). iOS requires an APNs auth key uploaded to Firebase console plus `UNUserNotificationCenter`/background-mode entitlements — budget explicit setup time for this in the roadmap (it is the most common FCM-on-iOS stumbling block). |
| `health` | **13.3.x** | Health & Wellness module: steps/calories/sleep/heart rate | Single cross-platform wrapper over Android **Health Connect** and Apple **HealthKit** — exactly the two platform integrations the brief calls for, via one Dart API. Health Connect is a system-level app that must be present (bundled by default from Android 14+; earlier OEM builds may require a Play Store install prompt) — plan a "Health Connect not installed" empty state. |
| `flutter_secure_storage` | current stable | Storing auth tokens, encryption keys client-side | Required for the "privacy by design" / E2E-encrypted-communication requirement — do not store JWTs or refresh tokens in plain `SharedPreferences`. |

### Supporting Libraries — ASP.NET Core / Backend

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `Microsoft.AspNetCore.SignalR` (built into ASP.NET Core 10) | 10.0.x | Real-time hub for live location pushes + alert broadcast | Define one strongly-typed hub interface (`Hub<IAlertClient>`) rather than untyped `Clients.All.SendAsync("...")` — gives you compile-time safety on the event contract your Flutter client (via `signalr_netcore` or `socket_io`-style client package) depends on. Wrap all hub-triggering logic behind an `INotificationService` abstraction (a plain service, not the hub itself) so Application-layer code in your Clean Architecture never references `IHubContext` directly — keeps SignalR an infrastructure-layer implementation detail. |
| `Npgsql` (ADO.NET driver, transitive via EF Core provider) | 10.0.x | Low-level Postgres connectivity | Comes along with the EF Core provider; rarely referenced directly except for raw SQL/bulk operations. |
| `MediatR` (or hand-rolled CQRS) | current stable | Decoupling Application-layer use cases from Controllers, keeping the SOS pipeline callable directly without going through the general request pipeline | Optional but common in Clean-Architecture ASP.NET Core projects; if used, make sure the **SOS command handler path** is a short, dedicated pipeline (no generic validation/logging behaviors that add latency) — the brief's "bypass every routine and AI pipeline" constraint is an architectural constraint, not just a UX one. |
| `Serilog` + `Serilog.Sinks.ApplicationInsights` (or Azure Monitor OpenTelemetry) | current stable | Structured logging / observability on Azure | ASP.NET Core 10 leans on OpenTelemetry-native diagnostics; Azure Monitor's OpenTelemetry Distro is the current Microsoft-recommended path over the older Application Insights SDK for new projects. |
| `FluentValidation` | current stable | Request/DTO validation in the Application layer | Standard companion to Clean Architecture + MediatR; keeps validation out of controllers. |
| `Polly` | current stable | Resilience (retry/circuit-breaker) around the call to the Python AI microservice | The AI service is a separate deployable — treat it as an unreliable external dependency from the backend's point of view and wrap calls in a circuit breaker with a sane timeout + fallback (e.g., "AI insight unavailable, showing last cached score") so a slow/down AI service can never block the location/SOS hot path. |

### Supporting Libraries — Python AI Service

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `pandas` / `numpy` | current stable, pinned to versions compatible with scikit-learn 1.9/XGBoost 3.3 | Feature engineering for anomaly/ETA models | Pin exact versions in `requirements.txt`/`pyproject.toml` and lock (e.g., `uv.lock` or `poetry.lock`) — a Python ML service is far more version-fragile than the .NET/Flutter sides. |
| `joblib` | current stable | Serializing the trained Isolation Forest / XGBoost pipeline for serving | Standard scikit-learn model-persistence mechanism (see Pitfall flag below re: pickle/joblib deserialization risk — mitigated here because this is a single-team, internal-only service with no untrusted model uploads). |
| `pydantic` (v2) | ≥2.7 | Request/response schema for the FastAPI service, and for the plain-language Explainability payload contract | Reuse the same Pydantic model shape on both the "raw prediction" and "explanation" response fields so the ASP.NET Core client has one stable contract to deserialize against. |
| `shap` (optional) | current stable | Underpinning the plain-language Explainability Layer for Isolation Forest/XGBoost outputs | SHAP's TreeExplainer works natively and cheaply on both Isolation Forest and XGBoost (both are tree ensembles), making it the natural engine behind "every AI output ships with a plain-language explanation" — translate SHAP feature attributions into the templated natural-language sentences your Explainability Layer requires, don't invent a bespoke explanation method. |
| `httpx` | current stable | Outbound HTTP calls from the Python side, if it ever needs to call back into ASP.NET Core | Async-native, pairs with FastAPI's async handlers. |

---

## Installation

```bash
# Flutter (from project root)
flutter --version   # confirm 3.44.x
flutter pub add google_maps_flutter geolocator flutter_foreground_task native_geofence \
  firebase_core firebase_messaging flutter_local_notifications health flutter_secure_storage

# ASP.NET Core (backend solution)
dotnet --version    # confirm 10.0.x SDK
dotnet add package Npgsql.EntityFrameworkCore.PostgreSQL --version 10.0.*
dotnet add package Microsoft.EntityFrameworkCore.Design --version 10.0.*
dotnet add package FluentValidation.AspNetCore
dotnet add package MediatR
dotnet add package Polly
dotnet add package Serilog.AspNetCore

# Python AI service
python --version    # confirm 3.12.x
pip install "fastapi[standard]" "scikit-learn==1.9.*" "xgboost==3.3.*" pandas numpy joblib shap
```

---

## Alternatives Considered

| Recommended | Alternative | When to Use Alternative |
|-------------|-------------|--------------------------|
| `geolocator` + `flutter_foreground_task` (open-source background tracking) | `flutter_background_geolocation` (commercial, battery-aware motion detection) | If, post-graduation, this becomes a funded product needing best-in-class battery life and you can absorb the ~$500/app license — its adaptive motion-detection sampling genuinely beats a hand-rolled foreground-service loop. Not justified for a graduation project budget. |
| `native_geofence` (native OS geofencing) | Manual polling loop comparing lat/lng to a stored radius on a timer | Never, for this project — Android's April 2026 policy change explicitly disallows the foreground-service-polling pattern for geofencing, and it drains battery far faster than the native Geofence APIs regardless of policy. |
| Direct HTTP connection to Supabase Postgres (port 5432) | Supavisor Session Pooler (port 5432, IPv4-only) | Use the pooler only if your Azure hosting environment is IPv4-only and you have not purchased Supabase's IPv4 add-on for the direct connection — ASP.NET Core is a long-running, persistent process (not serverless/edge functions), so direct connection is the documented best fit and avoids pooler overhead and prepared-statement caveats. |
| REST for ASP.NET Core → Python AI service calls | gRPC | Switch to gRPC only if you outgrow simple request/response (e.g., need bidirectional streaming of live anomaly scores) — at this scale (one small internal service, one caller), REST/JSON over HTTP with Polly-wrapped retries is simpler to build, debug, and demo for a graduation project, with negligible latency cost versus gRPC for this call volume. |
| Async REST call (ASP.NET Core → FastAPI) for AI scoring | Message queue (RabbitMQ/Azure Service Bus) between backend and AI service | Introduce a queue only if AI scoring becomes a genuinely async, best-effort background job (e.g., nightly batch re-scoring of all users' safety scores) — for per-event scoring (an anomaly check per new location ping) synchronous REST is simpler and there's no requirement in the brief for guaranteed at-least-once delivery or backpressure buffering that would justify the operational overhead of a broker for a solo-dev project. |
| Azure App Service (single container, "always on") for both the ASP.NET Core API and the Python AI microservice | Azure Container Apps | Prefer Container Apps only once you have multiple independently-scaling services and want KEDA-based autoscale-to-zero; for a graduation project's steady, low traffic, App Service's simpler "always on" model avoids the cold-start/background-task pitfall Container Apps has (CPU throttles down after a request unless "Always On" style config is set) — simpler to reason about and cheaper to demo reliably. |
| `joblib` model persistence for the internal AI service | ONNX / skops.io | Move to ONNX or `skops` if the model ever needs to be loaded by an untrusted party, shipped client-side, or audited for supply-chain risk. For a single internal service where only your own training pipeline produces the artifact, joblib's simplicity outweighs the theoretical deserialization risk — just don't accept model files from anywhere but your own CI/training job. |

---

## What NOT to Use

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| Manual `Timer.periodic` GPS polling for geofencing | Explicitly moved outside Google Play's approved foreground-service use cases as of the April 15, 2026 policy update; also the classic battery-drain anti-pattern flagged in every current Android location best-practice guide | `native_geofence` (native `GeofencingClient`/`CLCircularRegion`) |
| `flutter_background_geolocation` as a default choice without budget sign-off | $500/app commercial license; overkill for a graduation project when the open pattern (`geolocator` + `flutter_foreground_task`) meets requirements | `geolocator` + `flutter_foreground_task` |
| Targeting .NET 9 (STS) for a new project in mid/late-2026 | Standard Term Support ends well before a project with an open-ended timeline would want to replatform; .NET 10 is the current LTS | .NET 10 (ASP.NET Core 10) |
| Python 3.11 (or older) for the AI service | XGBoost 3.x's current release line requires Python ≥3.12 — pinning to 3.11 locks you out of current XGBoost patches/security fixes | Python 3.12 (or 3.13) |
| Supavisor **transaction pooler** (port 6543) with EF Core without disabling prepared statements | Transaction-mode pooling does not guarantee session affinity, so a prepared statement created by Npgsql/EF Core on one physical connection may not exist when the pooler routes the next query to a different backend connection — this produces intermittent, hard-to-reproduce runtime errors | Direct connection (port 5432) for the persistent ASP.NET Core process; fall back to Session Pooler only if IPv4-only networking forces it, and disable prepared statement caching (`Multiplexing`/`Max Auto Prepare` settings) if you must use transaction mode |
| Loading ML model files (`joblib`/pickle) from any source other than your own training pipeline/CI artifact store | Pickle/joblib deserialization executes arbitrary code — a well-documented, actively-exploited supply-chain vector (malicious models found in the wild on public model hubs) | Keep model artifacts inside your own repo/registry only; if you ever accept third-party or user-uploaded models, switch to `skops` or ONNX |
| Untyped/loose SignalR hub methods (`Clients.All.SendAsync("string-event-name", obj)` scattered through business logic) | Breaks the Clean Architecture boundary the brief requires (Application layer would depend on SignalR types) and makes the client contract fragile | Strongly-typed `Hub<IAlertClient>` + a dedicated `INotificationService` abstraction in the Infrastructure layer |
| Azure Container Apps default config for the Python AI microservice if it does any background/async work after responding | CPU can be throttled/scaled to zero right after a request completes unless explicitly configured "Always On"-equivalent, which can kill in-flight background tasks | Azure App Service (Premium tier) for steady, always-on small services, or explicitly configure Container Apps scaling/min-replica settings if you do go that route |

---

## Stack Patterns by Variant

**If the AI service needs to score every incoming location ping in near-real-time (anomaly detection on the live stream):**
- Keep the ASP.NET Core → FastAPI call synchronous REST, but put a strict timeout (e.g., 300-500ms) + Polly circuit breaker around it, with the SOS/location-write path never blocking on the AI response.
- Because scoring must never delay ingestion, design the endpoint so the AI call happens *after* the location has already been persisted and broadcast via SignalR — the AI insight arrives as a follow-up event, not a gate.

**If nightly/periodic aggregate jobs are needed (family safety-score rollups, ETA-model retraining):**
- Use Azure's built-in scheduling (WebJobs/Azure Functions Timer trigger, or a simple hosted `BackgroundService` in the ASP.NET Core app) rather than standing up a message queue just for this — a queue is unnecessary machinery at this scale.

**If Health Connect is unavailable on a given Android device (older OEM skin, user declined install):**
- Design the Health & Wellness module to degrade gracefully to a "connect Health Connect" empty state rather than crashing or silently showing zeros — this is a real, common runtime condition, not an edge case.

---

## Version Compatibility

| Package A | Compatible With | Notes |
|-----------|-----------------|-------|
| `Npgsql.EntityFrameworkCore.PostgreSQL 10.0.x` | `Microsoft.EntityFrameworkCore >= 10.0.4, < 11.0.0` | Provider version tracks EF Core major version 1:1 — always match the two majors. |
| XGBoost `3.3.x` | Python `>=3.12` only | Do not attempt to install on 3.10/3.11 environments; will fail to resolve a wheel. |
| scikit-learn `1.9.x` | Python `>=3.11` | Compatible with the Python 3.12 chosen for XGBoost compatibility above. |
| `flutter_foreground_task 9.2.x` | Flutter `>=3.22.0`, Dart `>=3.4.0`, Android `>=5.0 (API 21)`, iOS `>=12.0` | Comfortably covered by the recommended Flutter 3.44 SDK. |
| `native_geofence` | iOS `>=14`, Android API `>=23` | Set these as your app's minimum OS targets; both are reasonable floors for a 2026 app. |
| `google_maps_flutter` federated packages | Must upgrade `google_maps_flutter`, `_android`, `_ios`, `_platform_interface` together | Flutter's federated plugin pattern — pinning only the umbrella package and letting the platform packages float can cause API-surface mismatches; upgrade as a set. |

---

## Sources

- pub.dev package pages (direct WebFetch, current as of access date 2026-07-06): `google_maps_flutter` (2.17.1), `firebase_messaging` (16.4.1), `geolocator` (14.0.3), `health` (13.3.1), `flutter_foreground_task` (9.2.2), `native_geofence` — MEDIUM confidence (primary registry, but fetched via generic WebFetch tool rather than a curated docs provider)
- PyPI package pages (direct WebFetch): `scikit-learn` (1.9.0), `xgboost` (3.3.0) — MEDIUM confidence
- NuGet / npgsql.org release notes: `Npgsql.EntityFrameworkCore.PostgreSQL` 10.0.x compatibility matrix — MEDIUM confidence
- Microsoft: "Announcing .NET 10" (devblogs.microsoft.com), dotnet/core release-notes/10.0 — MEDIUM confidence (official vendor blog/repo)
- Supabase official docs: `supabase.com/docs/guides/database/connecting-to-postgres`, Supavisor FAQ, Supavisor 1.0 blog post — MEDIUM confidence
- Google Play Console Help: "Understanding location in the background permissions," Policy announcement April 15, 2026 (background location foreground-service restriction, Geofence API mandate) — MEDIUM confidence, and **time-sensitive** — re-verify against `support.google.com/googleplay/android-developer` before Android geofencing implementation, since this is a recent policy change
- Apple Developer / App Store Review Guidelines discussion (aggregated via WebSearch, no single canonical Apple page cites 2025-2026 wording verbatim) — LOW-MEDIUM confidence; verify final wording directly against `developer.apple.com/app-store/review/guidelines/` §5.1.1 at build time
- General ecosystem/architecture guidance (SignalR Clean Architecture patterns, REST vs gRPC vs queue, FastAPI model-serving patterns, Isolation Forest serving architectures, pickle/joblib security) — aggregated from multiple independent WebSearch results (Microsoft Learn, Medium engineering write-ups, ProtectAI/AWS security blogs) — MEDIUM confidence on the architectural consensus, LOW confidence on any single article's specifics

**Note on provider limitations:** No Context7, Exa, Tavily, or Firecrawl MCP tools were available in this session; all research used the built-in `WebSearch`/`WebFetch` tools. Version numbers should be re-confirmed against `pub.dev`, `pypi.org`, and `nuget.org` directly at the start of implementation, since this ecosystem (especially the Flutter package layer and Play/App Store policy) moves quickly.

---
*Stack research for: SafePath AI (family-safety / location-intelligence platform)*
*Researched: 2026-07-06*
