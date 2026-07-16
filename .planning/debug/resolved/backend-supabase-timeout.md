---
status: resolved
trigger: "Phase 2 A30 UAT found a backend log entry showing an unhandled transient Supabase/Postgres read timeout on GET /me while the app later recovered."
created: 2026-07-13T13:52:00+03:00
updated: 2026-07-13T13:57:13+03:00
---

# Debug Session: backend-supabase-timeout

## Symptoms

- expected_behavior: "The A30 app should call the local SafePath API through USB reverse without surfacing backend 500s during Phase 2 UAT."
- actual_behavior: "The device UI recovered and continued to render Phase 2 surfaces, but backend-api.out.log contains an unhandled Npgsql transient read timeout while handling GET /me."
- error_messages: "System.InvalidOperationException: An exception has been raised that is likely due to a transient failure. Inner exception: Npgsql.NpgsqlException: Exception while reading from stream; System.TimeoutException: Timeout during reading attempt."
- timeline: "Observed during 2026-07-13 Phase 2 UAT on SM A305F / R58M30TGNXV. Successful family queries appear after the failure."
- reproduction: "Run backend on localhost:5059, reverse tcp:5059 to the A30, use the signed-in app through Map/Activity/Privacy surfaces."

## Current Focus

- hypothesis: "The backend process experienced a transient Supabase pooler/database read timeout; the app recovered on a later request, so this may be infrastructure flakiness rather than a deterministic Phase 2 code defect."
- test: "Inspect logs, current connection state, and relevant retry/error handling around /me and family bootstrap."
- expecting: "Either identify a missing retry/resilience path that could surface user-facing errors, or classify this as recovered external transient evidence."
- next_action: "Gather initial evidence from backend logs, network state, and app error surfaces."
- reasoning_checkpoint:
- tdd_checkpoint:

## Evidence

- timestamp: 2026-07-13T13:52:00+03:00
  observation: "A30 app remained foregrounded and continued rendering populated Live Map, Activity route history, route sheet, and Privacy Center after the logged timeout."
- timestamp: 2026-07-13T13:52:00+03:00
  observation: "netstat showed an established local connection on 127.0.0.1:5059 between backend PID 22536 and the app/dev tooling side after the error."
- timestamp: 2026-07-13T13:52:00+03:00
  observation: "Recent adb logcat sample showed no FlutterError, unhandled Dart exception, or AndroidRuntime crash for com.safepath.mobile."
- timestamp: 2026-07-13T13:57:13+03:00
  observation: "backend-api.out.log shows a single EF/Npgsql connection failure against tcp://aws-0-eu-west-1.pooler.supabase.com:5432 during GET /me: NpgsqlReadBuffer timed out while opening/authenticating a pooled connector."
- timestamp: 2026-07-13T13:57:13+03:00
  observation: "The failing stack reaches SafePath.Application.Families.GetMeQueryHandler.Handle and SafePath.Api.Controllers.MeController.Get; the handler is a single Users.SingleOrDefaultAsync read."
- timestamp: 2026-07-13T13:57:13+03:00
  observation: "Immediately after the failure, backend-api.out.log records successful FamilyMembers and Users queries with normal latencies, including 898ms, 308ms, 102ms, and ~99-100ms commands."
- timestamp: 2026-07-13T13:57:13+03:00
  observation: "Current netstat still shows SafePath.Api PID 22536 listening on 0.0.0.0:5059 with an established localhost connection to adb.exe PID 9408; adb reports device R58M30TGNXV connected and app pid 6164 running."
- timestamp: 2026-07-13T13:57:13+03:00
  observation: "SafePath.Infrastructure registers UseNpgsql(connectionString) without EnableRetryOnFailure, so a transient provider read/open timeout can bubble out as an unhandled request exception."
- timestamp: 2026-07-13T13:57:13+03:00
  observation: "Mobile DioProfileApi maps /me HTTP 500 to an unknown profile error, but UAT evidence shows populated Live Map, Activity, route sheet, and Privacy Center after the event, so any user-visible impact recovered or was not observed."

## Eliminated

- Deterministic /me query bug: the handler is a single user lookup by authenticated user id, and subsequent identical user/family queries succeeded.
- USB reverse or local backend outage: port 5059 remained listening and connected to adb after the failure.
- Mobile crash/regression: recent logcat sample showed no FlutterError, unhandled Dart exception, AndroidRuntime crash, or matching network error for com.safepath.mobile.
- Persistent Supabase/Postgres outage: successful database reads resumed immediately after the timeout in the same log.

## Resolution

- root_cause: "Recovered external dependency transient: one Supabase/Postgres pooler connection-open/read timeout bubbled through GET /me because backend EF/Npgsql retry handling is not configured for this path."
- fix: "Not applied in this diagnosis-only session; recommended future hardening is to add backend transient retry/resilience for safe reads and/or normalize transient database exceptions to a retryable 503 instead of an unhandled 500."
- verification: "Correlated backend stack trace, post-failure successful EF queries, live port/process state, adb device/app state, and absence of sampled mobile crash/error logs."
- files_changed: ".planning/debug/backend-supabase-timeout.md only"
