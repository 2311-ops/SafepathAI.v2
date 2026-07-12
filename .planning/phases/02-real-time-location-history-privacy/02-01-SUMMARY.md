---
phase: 02-real-time-location-history-privacy
plan: 01
subsystem: real-time-location
tags: [signalr, supabase-jwt, flutter, signalr_netcore, websocket, privacy]

# Dependency graph
requires:
  - phase: 01-backend-auth-foundation
    provides: Supabase Auth JWT validation, current user subject claim, family membership authorization, /families/mine
provides:
  - Authenticated SignalR /hubs/location transport using Supabase JWT query-string auth scoped to the hub path
  - Per-family SignalR group join guarded by IFamilyAuthorizationService.RequireMembership
  - PresenceTracker singleton and ILocationBroadcastService application seam
  - Mobile LocationHubClient abstraction with signalr_netcore 1.4.4, reconnect state, live Supabase accessTokenFactory, and hand-written fake
  - Integration guard proving SignalR users map to Supabase JWT subject values
affects: [02-02, 02-03, 02-06, 02-07, 03-sos-fast-path]

# Tech tracking
tech-stack:
  added:
    - signalr_netcore 1.4.4
    - Microsoft.AspNetCore.SignalR.Client 9.0.7
  patterns:
    - "Application owns ILocationBroadcastService and LocationUpdateDto/PresenceChangeDto; Infrastructure owns Hub/IHubContext implementation."
    - "SignalR access_token query-string auth is accepted only for /hubs/location."
    - "Mobile SignalR accessTokenFactory re-reads Supabase auth.currentSession on every connection attempt."
    - "SignalR user identity is normalized through SupabaseUserIdProvider using the JWT sub claim."

key-files:
  created:
    - backend/src/SafePath.Application/Common/Interfaces/ILocationBroadcastService.cs
    - backend/src/SafePath.Application/Common/Interfaces/LocationDtos.cs
    - backend/src/SafePath.Infrastructure/RealTime/ILocationClient.cs
    - backend/src/SafePath.Infrastructure/RealTime/LocationBroadcastService.cs
    - backend/src/SafePath.Infrastructure/RealTime/LocationHub.cs
    - backend/src/SafePath.Infrastructure/RealTime/PresenceTracker.cs
    - backend/src/SafePath.Infrastructure/RealTime/SupabaseUserIdProvider.cs
    - backend/tests/SafePath.Api.IntegrationTests/LocationHubSmokeTests.cs
    - mobile/lib/features/location/data/location_hub_client.dart
    - mobile/lib/features/location/data/location_models.dart
    - mobile/test/helpers/fake_location_hub_client.dart
    - .planning/phases/02-real-time-location-history-privacy/02-01-USER-SETUP.md
  modified:
    - backend/src/SafePath.Api/Program.cs
    - backend/src/SafePath.Infrastructure/DependencyInjection.cs
    - backend/src/SafePath.Infrastructure/SafePath.Infrastructure.csproj
    - backend/tests/SafePath.Api.IntegrationTests/SafePath.Api.IntegrationTests.csproj
    - mobile/pubspec.yaml
    - mobile/pubspec.lock

key-decisions:
  - "Approved and retained signalr_netcore 1.4.4 after package legitimacy review and physical-device smoke verification."
  - "Introduced SupabaseUserIdProvider so SignalR Clients.User/Context.UserIdentifier use the JWT sub claim that matches application user IDs."
  - "Removed all temporary smoke-only hub method and Flutter smoke entrypoint before close-out; permanent verification lives in an integration guard plus recorded device smoke evidence."
  - "Generated 02-01-USER-SETUP.md for Google Maps API keys declared in plan frontmatter; the keys are not required for this transport skeleton but must be configured before later map UI plans."

patterns-established:
  - "Hub connections must derive user identity from the authenticated Supabase JWT subject, never a client-supplied user ID."
  - "Every SignalR connection and reconnect must call RequireMembership before joining family:{familyId}."
  - "Mobile real-time clients should expose an abstract interface plus hand-written fake, matching existing FamilyApi test conventions."

requirements-completed: [LOC-01, LOC-02, PRIV-01]

coverage:
  - id: D1
    description: "Backend /hubs/location SignalR skeleton authenticates with Supabase JWT query-string tokens, gates group membership by family, tracks presence, and exposes an application-layer broadcast seam."
    requirement: LOC-01
    verification:
      - kind: unit
        ref: "dotnet build backend\\SafePath.sln -c Debug"
        status: pass
      - kind: integration
        ref: "dotnet test backend\\tests\\SafePath.Api.IntegrationTests\\SafePath.Api.IntegrationTests.csproj --filter LocationHubSmokeTests"
        status: pass
    human_judgment: false
  - id: D2
    description: "Mobile SignalR hub client wraps signalr_netcore 1.4.4, re-reads the active Supabase session token in accessTokenFactory, exposes reconnect state and streams, and provides a test fake."
    requirement: LOC-01
    verification:
      - kind: unit
        ref: "flutter analyze lib/features/location test/helpers/fake_location_hub_client.dart"
        status: pass
    human_judgment: false
  - id: D3
    description: "Physical Android device smoke proved connect + JWT + /families/mine family lookup + family-group callback delivery against the real net9.0 hub."
    requirement: LOC-02
    verification:
      - kind: manual_procedural
        ref: "SM A305F Android 11 R58M30TGNXV; adb reverse tcp:5059 tcp:5059; API_BASE_URL=http://127.0.0.1:5059; received LocationUpdated for user 00d60457-820a-430c-9f57-b15091c17f28 in family a16955a1-7a2b-42d5-93b8-3e1a2b31ab46"
        status: pass
    human_judgment: true
    rationale: "This was the required human/device smoke checkpoint for real network, device, JWT, package callback, and family-group behavior."
  - id: D4
    description: "Sensitive hub communication uses authenticated SignalR over the existing ASP.NET HTTPS pipeline, with query-string token handling scoped only to /hubs/location."
    requirement: PRIV-01
    verification:
      - kind: unit
        ref: "dotnet build backend\\SafePath.sln -c Debug"
        status: pass
    human_judgment: true
    rationale: "Static build proves the auth path compiles, but production TLS/logging posture still needs deployment-time verification in later privacy/deploy work."

duration: multi-session
completed: 2026-07-12
status: complete
---

# Phase 02 Plan 01: Real-Time Transport Walking Skeleton Summary

**Supabase-authenticated SignalR location transport with per-family group membership and a Flutter signalr_netcore client proven on a physical Android device.**

## Performance

- **Duration:** Multi-session execution plus Task 4 human/device smoke
- **Started:** Prior executor session
- **Completed:** 2026-07-12T19:40:40Z
- **Tasks:** 4 completed
- **Files modified:** 17 plan files plus 2 close-out artifacts

## Accomplishments

- Added the backend `LocationHub` at `/hubs/location`, `[Authorize]` protected, with Supabase JWT query-string token extraction scoped to the hub path, per-family group joins after `RequireMembership`, presence tracking, and an `ILocationBroadcastService` seam that keeps SignalR out of application logic.
- Added the Flutter `LocationHubClient` abstraction and `SignalRLocationHubClient` implementation using `signalr_netcore` 1.4.4, automatic reconnect state, event streams, and an access token factory that reads `supabase.auth.currentSession` per connection attempt.
- Added a hand-written `FakeLocationHubClient` for later location UI/controller tests.
- Fixed SignalR user identity to use the Supabase JWT `sub` claim through `SupabaseUserIdProvider`, backed by `LocationHubSmokeTests`.
- Completed physical-device smoke verification on SM A305F Android 11: the client connected to `/hubs/location` with the Supabase JWT and received the family-scoped `LocationUpdated` callback.

## Task Commits

Each implementation task was committed atomically:

1. **Task 1: Verify signalr_netcore package legitimacy before install** - human-approved checkpoint; no commit
2. **Task 2: Minimal LocationHub + Supabase-JWT query-string wiring + broadcast seam** - `e6c8908` (feat)
3. **Task 3: Mobile signalr_netcore hub-client wrapper + fake** - `6ad5a12` (feat)
4. **Task 4: Live reconnect spike smoke test / defect fix** - `90b2fa2` (fix)

**Plan metadata:** pending close-out commit

## Files Created/Modified

- `backend/src/SafePath.Application/Common/Interfaces/ILocationBroadcastService.cs` - Application-layer broadcast interface.
- `backend/src/SafePath.Application/Common/Interfaces/LocationDtos.cs` - Shared location/presence DTO records used by the broadcast seam and hub client contract.
- `backend/src/SafePath.Infrastructure/RealTime/LocationHub.cs` - Authorized SignalR hub with family membership gate and presence broadcasts.
- `backend/src/SafePath.Infrastructure/RealTime/PresenceTracker.cs` - Thread-safe connection tracking by user.
- `backend/src/SafePath.Infrastructure/RealTime/LocationBroadcastService.cs` - Infrastructure `IHubContext<LocationHub, ILocationClient>` wrapper.
- `backend/src/SafePath.Infrastructure/RealTime/SupabaseUserIdProvider.cs` - SignalR user ID provider using Supabase JWT subject.
- `backend/src/SafePath.Api/Program.cs` - `/hubs/location` token extraction and hub mapping.
- `backend/tests/SafePath.Api.IntegrationTests/LocationHubSmokeTests.cs` - Integration guard for Supabase-sub SignalR users.
- `mobile/lib/features/location/data/location_hub_client.dart` - Mobile SignalR client abstraction and implementation.
- `mobile/lib/features/location/data/location_models.dart` - Mobile live-location and presence models.
- `mobile/test/helpers/fake_location_hub_client.dart` - Hand-written fake for downstream tests.
- `mobile/pubspec.yaml` / `mobile/pubspec.lock` - `signalr_netcore` 1.4.4 dependency.
- `.planning/phases/02-real-time-location-history-privacy/02-01-USER-SETUP.md` - Google Maps API key setup checklist from plan frontmatter.

## Decisions Made

- Kept `signalr_netcore` at 1.4.4 because the package legitimacy checkpoint was approved and the physical device smoke confirmed callback delivery.
- Added `SupabaseUserIdProvider` after Task 4 smoke found the hub was not consistently using the Supabase subject for SignalR user addressing. This keeps hub identity aligned with the rest of the backend auth model.
- Moved location DTOs into `SafePath.Application.Common.Interfaces` so the Application interface can reference them without depending on Infrastructure.
- Removed temporary smoke-only hub and Flutter entrypoint code before close-out; no throwaway smoke method remains in permanent code.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed SignalR user identity mapping to Supabase JWT subject**
- **Found during:** Task 4 live smoke and integration guard
- **Issue:** SignalR user addressing needed to resolve to the Supabase JWT `sub` claim so `Context.UserIdentifier` / `Clients.User(...)` match the application user ID model.
- **Fix:** Added `SupabaseUserIdProvider`, registered it in Infrastructure DI, and added `LocationHubSmokeTests`.
- **Files modified:** `backend/src/SafePath.Infrastructure/DependencyInjection.cs`, `backend/src/SafePath.Infrastructure/RealTime/SupabaseUserIdProvider.cs`, `backend/tests/SafePath.Api.IntegrationTests/LocationHubSmokeTests.cs`, `backend/tests/SafePath.Api.IntegrationTests/SafePath.Api.IntegrationTests.csproj`
- **Verification:** `dotnet test backend\\tests\\SafePath.Api.IntegrationTests\\SafePath.Api.IntegrationTests.csproj --filter LocationHubSmokeTests`
- **Committed in:** `90b2fa2`

**2. [Rule 3 - Blocking] Generated required user setup document from plan frontmatter**
- **Found during:** Close-out
- **Issue:** The plan declared `user_setup` for Google Maps Platform keys; execute-plan requires a user setup artifact when this frontmatter exists.
- **Fix:** Added `02-01-USER-SETUP.md` with environment variables, dashboard configuration, and later-plan verification notes.
- **Files modified:** `.planning/phases/02-real-time-location-history-privacy/02-01-USER-SETUP.md`
- **Verification:** File exists and is referenced from this summary.
- **Committed in:** pending close-out commit

---

**Total deviations:** 2 auto-fixed (1 Rule 1 bug, 1 Rule 3 close-out requirement)
**Impact on plan:** Both changes preserve the planned architecture and improve correctness/traceability. No temporary smoke code was retained.

## Issues Encountered

- Task 4 used physical-device development plumbing (`adb reverse tcp:5059 tcp:5059` and `API_BASE_URL=http://127.0.0.1:5059`) to reach the local backend. This was smoke-only setup and is not permanent app configuration.
- Task 4 temporary hub method and Flutter smoke entrypoint were removed before close-out.

## User Setup Required

**External services require manual configuration.** See [02-01-USER-SETUP.md](./02-01-USER-SETUP.md) for:
- `MAPS_API_KEY_ANDROID`
- `MAPS_API_KEY_IOS`
- Google Cloud Console Maps SDK enablement and key restriction steps

These keys are not required for the Plan 01 SignalR transport, but they are required before the later map UI plan can render map tiles.

## Known Stubs

None. Stub-pattern scanning of the plan-created/modified location files found only normal nullable-control-flow assignments in `location_hub_client.dart`, not placeholder UI data or mock-only production code.

## Threat Flags

| Flag | File | Description |
|------|------|-------------|
| threat_flag: query-token-logging | `backend/src/SafePath.Api/Program.cs` | The plan already accepted T-02-06: SignalR uses `access_token` in the query string for WebSocket auth. Production request logging for `/hubs/location` query strings still needs suppression before deploy. |

## Verification

- `dotnet test backend\\tests\\SafePath.Api.IntegrationTests\\SafePath.Api.IntegrationTests.csproj --filter LocationHubSmokeTests` - passed after the Supabase subject fix.
- `dotnet build backend\\SafePath.sln -c Debug` - passed after temporary smoke code removal.
- `flutter analyze lib/features/location test/helpers/fake_location_hub_client.dart` - passed after temporary smoke code removal.
- Physical-device smoke passed on SM A305F Android 11 (`R58M30TGNXV`): `signalr_netcore` 1.4.4 connected to `/hubs/location` with the Supabase JWT and received `LocationUpdated` for user `00d60457-820a-430c-9f57-b15091c17f28`, family `a16955a1-7a2b-42d5-93b8-3e1a2b31ab46`.

## Next Phase Readiness

- Plan 02-02 can wire location persistence and real broadcast calls onto the `ILocationBroadcastService` seam.
- Plan 02-06/02-07 can depend on the mobile `LocationHubClient` and fake for UI/controller testing.
- Production deployment still needs the accepted T-02-06 logging mitigation for hub query strings.
- Google Maps Platform keys remain a user setup item before map tiles render.

---
*Phase: 02-real-time-location-history-privacy*
*Completed: 2026-07-12*

## Self-Check: PASSED

Created/modified close-out artifacts exist on disk (`02-01-SUMMARY.md`, `02-01-USER-SETUP.md`); task commits `e6c8908`, `6ad5a12`, and `90b2fa2` are present in git log; permanent-code checks listed in this summary passed after temporary smoke code removal.
