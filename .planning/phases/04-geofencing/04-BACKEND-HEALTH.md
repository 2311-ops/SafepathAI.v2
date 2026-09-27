# Backend Health: 2026-09-27

## Verified

- Public tunnel OpenAPI and authenticated Guardian profile, membership, zones and live-location reads return HTTP 200.
- Test family contains the Guardian and Member Youssef Ghallab. OPPO A52 / Android 11 is user-reported, not independently inspected by ADB.
- Backend full suite: 231 application + 25 API integration tests pass. The Domain.Tests project has no test source files and reports no tests; do not count it as extra coverage.
- Non-incremental Release solution rebuild: zero warnings and zero errors.
- EF model-drift check: no pending model changes. No schema changes were made.
- Patched backend restarted on localhost:5059. Public HTTPS URL remains unchanged. FirebasePushSender and WhatsAppSmsGateway are configured; this does not prove real message delivery.
- Fresh server log sample after restart: no fail/crit entries, stderr empty, successful database commands observed. This is a bounded observation, not a guarantee of future uptime.

## Defect Repaired

The retained live console sample contained two failed ReportLocation invocations with `RecordedAtUtc cannot be in the future`. The handler rejected any positive skew. The connected Guardian phone clock was about a second ahead of the PC; Windows time status reported not synchronized. The error sample does not identify which member submitted those fixes.

ReportLocation now accepts at most 30 seconds of positive device-clock skew and clamps the persisted and broadcast timestamp to the same server receipt time. Larger future timestamps remain rejected. Three regression cases cover small skew; existing tests retain past timestamps and reject a one-minute future fix. Membership and sharing checks are unchanged. No synthetic location was inserted into the live family to claim physical evidence.

## Remaining Warnings And Observations

| Observation | Assessment |
|---|---|
| One retained Npgsql stream write/reset exception, followed by EF retry | Transient transport failure, not proof of a schema/auth fault. Retry is already configured; post-restart database reads succeed. Monitor recurrence. |
| HTTPS redirection cannot determine a port | Non-blocking with the local HTTP launch profile behind the HTTPS ngrok tunnel. Local port 5059 has no HTTPS listener; do not point redirect traffic at an arbitrary port. Production TLS configuration was not changed. |
| EF CLI 9.0.3 is older than runtime 9.0.9 | Tool-version warning; drift check succeeds. No global tooling upgrade performed during device testing. |
| Android Kotlin compatibility and Gradle deprecation warnings | Present in earlier successful Android build/test logs. No Android rebuild in this backend-only audit. |
| GSD unknown config keys: tavily_search, ref_search, perplexity, jina | Workflow tool ignores these legacy keys; unrelated to app runtime. Left unchanged. |
| Domain.Tests contains no tests | Coverage gap in that project, not a failed application/API test suite. |

The retained ngrok request list includes one 502 on location negotiation during the deliberate API restart. Other historical responses include root-path 404s (no root page), registration 404s (no assigned zone), and pre-membership/session 403/401 responses. The registration controller deliberately returns 404 when no zone exists and mobile treats it as no registration; it is not a missing route.

Microsoft documents the HTTPS warning when no redirect port is available and the separate reverse-proxy TLS considerations: [Enforce HTTPS in ASP.NET Core](https://learn.microsoft.com/en-us/aspnet/core/security/enforcing-ssl).

Runtime logs remain local and ignored: `backend/logs/phase04-api-20260927.out.log` and `.err.log`. Do not commit raw logs, device auth preferences, coordinates, bearer tokens or service credentials.

## Next Physical Gate

There are zero current test zones. The last Member fix was several minutes old at audit time. Have the friend reopen SafePath with background location allowed, verify a fresh accurate location, create the 100 m test zone through the Guardian API, and confirm the Member's exact-generation acknowledgement before walking. Then follow `04-REMOTE-ANDROID-VERIFICATION.md` for process death, native candidate, authenticated upload, offline replay and coordinated SOS evidence. Signed iPhone/APNs acceptance remains mandatory. Phase 04 stays 15/17 plans complete.
