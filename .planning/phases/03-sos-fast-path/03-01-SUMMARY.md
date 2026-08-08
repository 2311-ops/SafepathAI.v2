---
phase: 03-sos-fast-path
plan: 01
subsystem: api
tags: [ef-core, postgres, aspnetcore, clean-architecture, sos, twilio, firebase-admin, libphonenumber]

# Dependency graph
requires:
  - phase: 01-backend-auth-foundation
    provides: IFamilyAuthorizationService.RequireMembership, ICurrentUserService, FamilyMember/Role model, ICommandHandler dispatch convention
  - phase: 02-real-time-location-history-privacy
    provides: SqliteInMemoryDbContextFactory test fixture, FamilyApiFactory/TestAuthHandler integration-test convention, ApplicationDbContext/IApplicationDbContext seam
provides:
  - SosSession, SosDeliveryAttempt, EmergencyContact, UserDeviceToken entities + EF configurations
  - SosKind, SosSessionStatus, AlertChannel, SosDeliveryStatus, DevicePlatform enums
  - Applied AddSosFastPath migration on the live Supabase database
  - Idempotent TriggerSosCommand/Handler with Guardian-only recipient resolution (ResolveRecipients extension point)
  - GetSosSessionQuery/Handler and shared SosSessionProjection
  - SosController: POST /sos/trigger, GET /sos/{sosSessionId:guid}
  - Twilio, libphonenumber-csharp, FirebaseAdmin package references in SafePath.Infrastructure
affects: [03-02, 03-03, 03-04, 03-05, 03-06, 03-08, 03-09]

# Tech tracking
tech-stack:
  added:
    - "Twilio 7.14.9 (NuGet, SafePath.Infrastructure) — SMS delivery, first consumed by 03-05"
    - "libphonenumber-csharp 9.0.35 (NuGet, SafePath.Infrastructure) — E.164 phone normalisation, first consumed by 03-05"
    - "FirebaseAdmin 3.6.0 (NuGet, SafePath.Infrastructure) — FCM push, first consumed by 03-06"
  patterns:
    - "Find-first idempotency: a command handler checks for an existing row keyed by a client-issued id before any write, and short-circuits to a replay-status result rather than re-running side effects"
    - "Shared internal static projection helper (SosSessionProjection) reused by both a command handler and a query handler to avoid duplicating per-recipient/per-channel DTO shaping"

key-files:
  created:
    - backend/src/SafePath.Domain/Entities/SosSession.cs
    - backend/src/SafePath.Domain/Entities/SosDeliveryAttempt.cs
    - backend/src/SafePath.Domain/Entities/EmergencyContact.cs
    - backend/src/SafePath.Domain/Entities/UserDeviceToken.cs
    - backend/src/SafePath.Domain/Enums/SosKind.cs
    - backend/src/SafePath.Domain/Enums/SosSessionStatus.cs
    - backend/src/SafePath.Domain/Enums/AlertChannel.cs
    - backend/src/SafePath.Domain/Enums/SosDeliveryStatus.cs
    - backend/src/SafePath.Domain/Enums/DevicePlatform.cs
    - backend/src/SafePath.Infrastructure/Persistence/EntityConfigurations/SosSessionConfiguration.cs
    - backend/src/SafePath.Infrastructure/Persistence/EntityConfigurations/SosDeliveryAttemptConfiguration.cs
    - backend/src/SafePath.Infrastructure/Persistence/EntityConfigurations/EmergencyContactConfiguration.cs
    - backend/src/SafePath.Infrastructure/Persistence/EntityConfigurations/UserDeviceTokenConfiguration.cs
    - backend/src/SafePath.Infrastructure/Persistence/Migrations/20260801200953_AddSosFastPath.cs
    - backend/src/SafePath.Application/Sos/SosDtos.cs
    - backend/src/SafePath.Application/Sos/SosSessionProjection.cs
    - backend/src/SafePath.Application/Sos/TriggerSosCommand.cs
    - backend/src/SafePath.Application/Sos/GetSosSessionQuery.cs
    - backend/src/SafePath.Api/Controllers/SosController.cs
    - backend/tests/SafePath.Application.Tests/Sos/SosSchemaTests.cs
    - backend/tests/SafePath.Application.Tests/Sos/TriggerSosCommandHandlerTests.cs
    - backend/tests/SafePath.Api.IntegrationTests/SosControllerTests.cs
  modified:
    - backend/src/SafePath.Infrastructure/Persistence/ApplicationDbContext.cs
    - backend/src/SafePath.Application/Common/Interfaces/IApplicationDbContext.cs
    - backend/src/SafePath.Infrastructure/SafePath.Infrastructure.csproj
    - backend/src/SafePath.Application/DependencyInjection.cs

key-decisions:
  - "Task 1's nine-package legitimacy checkpoint was approved by the user before this continuation started; all nine were installed exactly as listed, no substitutions."
  - "Recipient resolution (ResolveRecipients) queries FamilyMembers joined to Users for active Guardians only, explicitly bypassing ISharingAuthorizationService — an emergency must never be suppressed by a routine privacy preference."
  - "SosController carries no rate-limiting attribute (T-03-05, accepted disposition) so an offline retry storm can never be throttled away."
  - "GET /sos/{sosSessionId} is served by a new GetSosSessionQuery/Handler (not raw DbContext access in the controller) to match the LocationController convention of controllers only calling ICommandHandler; the per-recipient/per-channel projection logic was factored into a shared SosSessionProjection so TriggerSosCommandHandler and GetSosSessionQueryHandler never diverge."

patterns-established:
  - "Idempotent client-issued-id commands: find-first by primary key before validating/writing, return a WasExisting-style flag rather than throwing on replay."
  - "SqliteInMemoryDbContextFactory-seeded tests must insert parent Family/User rows before FK-constrained child rows, and multi-test class fixtures sharing one SQLite connection need per-test-unique unique-constrained fields (e.g. email)."

requirements-completed: [SOS-01, SOS-02, SOS-03]

coverage:
  - id: D1
    description: "SOS bounded context persists: four entities/tables materialise via EF, client-issued SosSession.Id is never regenerated, duplicate ids are rejected at the storage layer, and a user can hold multiple device tokens"
    requirement: "SOS-01"
    verification:
      - kind: unit
        ref: "backend/tests/SafePath.Application.Tests/Sos/SosSchemaTests.cs#CreateContext_MaterialisesAllSosTables, SosSession_DefaultsToVisibleKind, SosSession_RejectsDuplicateId, UserDeviceToken_AllowsMultipleTokensPerUser"
        status: pass
    human_judgment: false
  - id: D2
    description: "AddSosFastPath migration applied to the live Supabase database (not just build-verified)"
    requirement: "SOS-01"
    verification:
      - kind: other
        ref: "dotnet ef migrations list — 20260801200953_AddSosFastPath listed with no pending marker"
        status: pass
    human_judgment: false
  - id: D3
    description: "POST /sos/trigger is idempotent on a client-supplied sosSessionId, resolves only active non-caller Guardians as recipients, and never touches LocationPing"
    requirement: "SOS-01"
    verification:
      - kind: unit
        ref: "backend/tests/SafePath.Application.Tests/Sos/TriggerSosCommandHandlerTests.cs#Handle_PersistsSessionWithClientSuppliedId, Handle_IsIdempotentForRepeatedSessionId, Handle_CreatesOneAttemptPerGuardianRecipient, Handle_ExcludesTriggeringUserFromRecipients, Handle_ThrowsWhenCallerIsNotAFamilyMember, Handle_DoesNotWriteLocationPings, Handle_RejectsOutOfRangeCoordinates"
        status: pass
    human_judgment: false
  - id: D4
    description: "SosController exposes per-recipient/per-channel delivery state over real HTTP, enforces auth (401) and family membership (403), and GET returns the same session status after trigger"
    requirement: "SOS-02"
    verification:
      - kind: integration
        ref: "backend/tests/SafePath.Api.IntegrationTests/SosControllerTests.cs#Trigger_ReturnsPerChannelDeliveryState, Trigger_ReturnsUnauthorizedWithoutAuthenticatedUser, Trigger_ReturnsForbiddenForNonMemberFamily, Get_ReturnsCurrentSessionStatus"
        status: pass
    human_judgment: false
  - id: D5
    description: "Nine Phase 3 packages (six pub.dev, three NuGet) were human-verified as legitimate before any install command ran"
    requirement: "SOS-03"
    verification: []
    human_judgment: true
    rationale: "Package legitimacy is inherently a human trust judgment against registry pages the automated legitimacy seam cannot cover — the checkpoint required (and received) explicit user approval, not an automated check."

duration: 10min
completed: 2026-08-01
status: complete
---

# Phase 03 Plan 01: SOS Bounded Context Persistence + Idempotent Trigger Summary

**Idempotent POST /sos/trigger backed by a four-table EF Core schema (SosSession, SosDeliveryAttempt, EmergencyContact, UserDeviceToken), applied to the live Supabase database, with per-recipient/per-channel delivery state and zero coupling to the routine location pipeline.**

## Performance

- **Duration:** 10 min (this continuation session; Task 1's legitimacy checkpoint was resolved by the user in a prior session)
- **Started:** 2026-08-01T23:05:57+03:00
- **Completed:** 2026-08-01T23:16:03+03:00
- **Tasks:** 3 (Task 1 checkpoint approved, Task 2 + Task 3 executed)
- **Files modified:** 28

## Accomplishments
- Four SOS-domain tables (SosSessions, SosDeliveryAttempts, EmergencyContacts, UserDeviceTokens) mapped via EF Core and applied to the live Supabase database via the `AddSosFastPath` migration
- Idempotent `TriggerSosCommandHandler`: a replayed client-issued `sosSessionId` returns the original session instead of creating a duplicate emergency or duplicate delivery rows
- `POST /sos/trigger` and `GET /sos/{sosSessionId}` expose per-recipient, per-channel delivery state — never a single collapsed boolean
- Zero references from any SOS code path to `ReportLocationCommandHandler`, `ILocationBroadcastService`, or any rate-limiting policy — the SOS path is structurally isolated from the routine location pipeline and cannot be throttled
- Twilio, libphonenumber-csharp, and FirebaseAdmin added to `SafePath.Infrastructure` for plans 03-05/03-06

## Task Commits

Each task was committed atomically:

1. **Task 1: Package legitimacy gate for all nine new Phase 3 dependencies** - approved by user in prior session (checkpoint, no code commit)
2. **Task 2: Persist the SOS bounded context — entities, enums, EF configuration, and the applied migration** - `3f95403` (test, RED), `42830d9` (feat, GREEN)
3. **Task 3: Apply the SOS migration, then ship the idempotent trigger command and SosController** - `008db72` (feat)

**Plan metadata:** commit pending (this SUMMARY + STATE/ROADMAP update)

_Note: Task 2 followed the TDD RED→GREEN cycle (`3f95403` then `42830d9`); Task 3 combined migration-apply + implementation + tests into one commit since the migration-apply step is a non-code operation gating the rest of the task._

## Files Created/Modified
- `backend/src/SafePath.Domain/Entities/SosSession.cs` - Client-issued-id SOS emergency aggregate (Kind defaults Visible, Status defaults Active)
- `backend/src/SafePath.Domain/Entities/SosDeliveryAttempt.cs` - One row per (recipient, channel) pair
- `backend/src/SafePath.Domain/Entities/EmergencyContact.cs` - Non-app SMS-only contact
- `backend/src/SafePath.Domain/Entities/UserDeviceToken.cs` - Multi-device FCM token storage
- `backend/src/SafePath.Domain/Enums/{SosKind,SosSessionStatus,AlertChannel,SosDeliveryStatus,DevicePlatform}.cs` - Five closed enums
- `backend/src/SafePath.Infrastructure/Persistence/EntityConfigurations/{SosSessionConfiguration,SosDeliveryAttemptConfiguration,EmergencyContactConfiguration,UserDeviceTokenConfiguration}.cs` - EF mappings incl. `ValueGeneratedNever()` on `SosSession.Id` and the unique (SosSessionId, RecipientUserId, EmergencyContactId, Channel) index
- `backend/src/SafePath.Infrastructure/Persistence/ApplicationDbContext.cs` - Registered four new DbSets + configurations
- `backend/src/SafePath.Application/Common/Interfaces/IApplicationDbContext.cs` - Added four DbSet seams
- `backend/src/SafePath.Infrastructure/SafePath.Infrastructure.csproj` - Added Twilio 7.14.9, libphonenumber-csharp 9.0.35, FirebaseAdmin 3.6.0
- `backend/src/SafePath.Infrastructure/Persistence/Migrations/20260801200953_AddSosFastPath.cs` - Applied migration (four new tables, indexes, FKs)
- `backend/src/SafePath.Application/Sos/SosDtos.cs` - SosSessionDto/SosRecipientStatusDto/SosChannelStatusDto (display-name only, no phone/token leakage)
- `backend/src/SafePath.Application/Sos/SosSessionProjection.cs` - Shared session→DTO projection used by both handlers
- `backend/src/SafePath.Application/Sos/TriggerSosCommand.cs` - Idempotent trigger handler + `ResolveRecipients` extension point
- `backend/src/SafePath.Application/Sos/GetSosSessionQuery.cs` - Status query re-verifying family membership before returning delivery state
- `backend/src/SafePath.Api/Controllers/SosController.cs` - POST /sos/trigger, GET /sos/{sosSessionId:guid}, no rate-limiting attribute
- `backend/src/SafePath.Application/DependencyInjection.cs` - Registered both new handlers
- `backend/tests/SafePath.Application.Tests/Sos/{SosSchemaTests,TriggerSosCommandHandlerTests}.cs` - 11 unit tests
- `backend/tests/SafePath.Api.IntegrationTests/SosControllerTests.cs` - 4 integration tests against the real HTTP pipeline

## Decisions Made
- Recipient resolution deliberately bypasses `ISharingAuthorizationService` (which gates routine location visibility) — an emergency must never be suppressed by a privacy preference, per 03-RESEARCH.md's Anti-Patterns section.
- `GetSosSessionQuery`/`GetSosSessionQueryHandler` was added (not in the plan's original file list, but required to keep `SosController.Get` consistent with `LocationController`'s "controller never touches `IApplicationDbContext` directly" convention) — factored the shared `SosSessionProjection` helper so the per-recipient/per-channel shaping logic used by both `TriggerSosCommandHandler` and `GetSosSessionQueryHandler` exists in exactly one place instead of being duplicated inline in the controller.
- No rate-limiting attribute on `SosController` (matches plan's explicit non-goal and threat T-03-05's accepted disposition).

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed FK-violation in SosSchemaTests seeding**
- **Found during:** Task 2 (first `dotnet test` run after reaching GREEN)
- **Issue:** Test rows for `SosSession`/`EmergencyContact`/`UserDeviceToken` referenced `FamilyId`/`OwnerUserId`/`UserId` values with no corresponding `Family`/`User` row, tripping the FK constraints the plan itself required
- **Fix:** Added a `SeedFamilyAndUser` helper that persists a `User` + `Family` row before every FK-dependent insert, and swapped the duplicate-id assertion to `Assert.ThrowsAnyAsync<DbUpdateException>` to match the actual EF Core failure mode
- **Files modified:** `backend/tests/SafePath.Application.Tests/Sos/SosSchemaTests.cs`
- **Verification:** All 4 schema tests pass
- **Committed in:** `42830d9` (Task 2 commit)

**2. [Rule 1 - Bug] Fixed cross-test email collision in SosControllerTests**
- **Found during:** Task 3 (first integration test run)
- **Issue:** `FamilyApiFactory` is a shared `IClassFixture` backed by one open SQLite connection across all four tests in the class; hardcoded emails (`caller@example.com`) collided on the `Users.Email` unique index on the second test to run
- **Fix:** Interpolated each seeded user's own Guid into the email (`caller-{callerId}@example.com`)
- **Files modified:** `backend/tests/SafePath.Api.IntegrationTests/SosControllerTests.cs`
- **Verification:** All 4 integration tests pass independently of run order
- **Committed in:** `008db72` (Task 3 commit)

**3. [Rule 1 - Bug] Fixed enum JSON deserialization in integration test client**
- **Found during:** Task 3 (first integration test run)
- **Issue:** `Program.cs` registers `JsonStringEnumConverter` server-side, so `SosKind`/`AlertChannel`/etc. serialize as strings (e.g. `"Visible"`), but `HttpContent.ReadFromJsonAsync<T>()` in the test used default `JsonSerializerOptions` with no string-enum converter, throwing on deserialize
- **Fix:** Added a local `JsonSerializerOptions` with `JsonStringEnumConverter` + case-insensitive property matching, passed to both `ReadFromJsonAsync` calls
- **Files modified:** `backend/tests/SafePath.Api.IntegrationTests/SosControllerTests.cs`
- **Verification:** Both trigger and get tests deserialize and pass
- **Committed in:** `008db72` (Task 3 commit)

---

**Total deviations:** 3 auto-fixed (all Rule 1 — bugs in this plan's own new test code, not pre-existing code)
**Impact on plan:** All three were test-authoring bugs discovered while driving RED→GREEN; no production code was affected, no scope creep.

## Issues Encountered
- The manual sanity check (`curl -X POST {api}/sos/trigger` without an Authorization header returns 401) required launching the API with `ASPNETCORE_ENVIRONMENT=Development` explicitly — running the built DLL directly (not via `dotnet run`) does not default to Development, so `appsettings.Development.json`'s `Supabase:Url` was not picked up on the first attempt. Resolved by exporting the environment variable before starting the process; confirmed 401 and shut the process down cleanly afterward.

## User Setup Required
None - no external service configuration required. (Twilio/FirebaseAdmin credentials are consumed starting in plans 03-05/03-06, not this plan.)

## Next Phase Readiness
- 03-02 (mobile SOS button + sender session) can now call `POST /sos/trigger` / `GET /sos/{sosSessionId}` against a real, migrated backend endpoint.
- 03-03's fan-out dispatch can build on the `NotAttempted` `SosDeliveryAttempt` rows this plan creates.
- 03-05's `ResolveRecipients` widening (to also return `EmergencyContact` rows) has a single, documented extension point.
- No blockers identified.

---
*Phase: 03-sos-fast-path*
*Completed: 2026-08-01*

## Self-Check: PASSED

All 12 created files verified present on disk; all 4 commits (`3f95403`, `42830d9`, `008db72`, `6d0a7bb`) verified present in git log.
