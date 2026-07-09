---
phase: 01-backend-auth-foundation
plan: 05
subsystem: api
tags: [aspnet-core, clean-architecture, ef-core, npgsql, rate-limiting, xunit, sqlite, idor]

# Dependency graph
requires:
  - phase: 01-backend-auth-foundation (plan 01)
    provides: Clean Architecture backend solution, Supabase-validated JWT auth pipeline, Role/PermissionLevel/InvitationStatus enums
  - phase: 01-backend-auth-foundation (plan 04, superseded)
    provides: n/a — 01-04 was closed via Supabase Auth supersession with no new backend code
provides:
  - Family circle backend: create circle, generate share-code/QR invites, accept/decline invites, manage per-member permissions, remove members (FAM-01..05)
  - FamilyAuthorizationService — server-side membership+role re-check used by every family-scoped handler (IDOR prevention, D5)
  - FamilyCircle EF migration applied to the live Supabase database (Families, FamilyMembers, FamilyInvitations)
  - Per-IP rate-limit policy on /invites/redeem
affects: [01-07, 02-real-time-location]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Server-side family authorization: IFamilyAuthorizationService.RequireMembership/RequireRole re-verify the caller's own active FamilyMember row on every handler that operates on an existing family (never CreateFamily/RedeemInvite, which have no pre-existing family scope to check)"
    - "IDOR-safe target lookup: every mutation on a memberId re-scopes the query to the route's familyId (m.Id == memberId && m.FamilyId == familyId) so a memberId from a different family is treated as not-found, not silently applied"
    - "CSPRNG invite secrets: RandomNumberGenerator.GetBytes for both the short display code and the long opaque link token — never Guid.NewGuid()"
    - "Integration-test auth: a header-driven TestAuthHandler + PostConfigure<AuthenticationOptions> replaces the real Supabase JwtBearer scheme in WebApplicationFactory tests that need a real authenticated HTTP round-trip"
    - "TDD RED/GREEN commit pairs per task: handlers temporarily stubbed with NotImplementedException, tests run red, implementation restored, tests run green, each phase committed separately"

key-files:
  created:
    - backend/src/SafePath.Domain/Entities/Family.cs
    - backend/src/SafePath.Domain/Entities/FamilyMember.cs
    - backend/src/SafePath.Domain/Entities/FamilyInvitation.cs
    - backend/src/SafePath.Application/Common/Interfaces/IFamilyAuthorizationService.cs
    - backend/src/SafePath.Application/Common/Interfaces/IInviteCodeGenerator.cs
    - backend/src/SafePath.Application/Families/CreateFamilyCommand.cs
    - backend/src/SafePath.Application/Families/ListFamilyMembersQuery.cs
    - backend/src/SafePath.Application/Families/GenerateInviteCommand.cs
    - backend/src/SafePath.Application/Families/RedeemInviteCommand.cs
    - backend/src/SafePath.Application/Families/UpdateMemberPermissionsCommand.cs
    - backend/src/SafePath.Application/Families/RemoveMemberCommand.cs
    - backend/src/SafePath.Infrastructure/Identity/FamilyAuthorizationService.cs
    - backend/src/SafePath.Infrastructure/Identity/InviteCodeGenerator.cs
    - backend/src/SafePath.Infrastructure/Persistence/EntityConfigurations/FamilyConfiguration.cs
    - backend/src/SafePath.Infrastructure/Persistence/EntityConfigurations/FamilyMemberConfiguration.cs
    - backend/src/SafePath.Infrastructure/Persistence/EntityConfigurations/FamilyInvitationConfiguration.cs
    - backend/src/SafePath.Infrastructure/Persistence/Migrations/20260709082519_FamilyCircle.cs
    - backend/src/SafePath.Api/Controllers/FamiliesController.cs
    - backend/src/SafePath.Api/Controllers/InvitesController.cs
    - backend/tests/SafePath.Application.Tests/Families/CreateFamilyCommandTests.cs
    - backend/tests/SafePath.Application.Tests/Families/FamilyInvitationTests.cs
    - backend/tests/SafePath.Application.Tests/Families/UpdateMemberPermissionsCommandTests.cs
    - backend/tests/SafePath.Api.IntegrationTests/RemoveMemberCommandTests.cs
  modified:
    - backend/src/SafePath.Application/Common/Interfaces/IApplicationDbContext.cs
    - backend/src/SafePath.Application/DependencyInjection.cs
    - backend/src/SafePath.Infrastructure/Persistence/ApplicationDbContext.cs
    - backend/src/SafePath.Infrastructure/Persistence/Migrations/ApplicationDbContextModelSnapshot.cs
    - backend/src/SafePath.Infrastructure/DependencyInjection.cs
    - backend/src/SafePath.Api/Program.cs

key-decisions:
  - "Adapted to the post-migration Supabase Auth current-user mechanism (ICurrentUserService reads the sub claim from the Supabase-issued JWT) instead of the plan's original custom-JWT assumption — no AuthController/custom identity code exists to reference, per the D6 supersession noted in 01-01-PLAN.md"
  - "Added IInviteCodeGenerator as an Application-layer interface (not in the plan's file list) so GenerateInviteCommand does not depend on the concrete Infrastructure InviteCodeGenerator class, preserving the Clean Architecture boundary already established for IPasswordHasher/IJwtTokenGenerator in plan 01"
  - "Display code length is 6 characters (not the mockup's 4) for extra entropy against brute-forcing, backed by a CSPRNG with visually-ambiguous characters (0/O, 1/I) removed"
  - "Single-use invite enforcement uses a check-then-mutate pattern inside one SaveChangesAsync (status flip + membership insert commit in the same DB transaction) rather than a raw ExecuteUpdateAsync compare-and-swap — sufficient for this phase's sequential redeem tests; documented as a known simplification, not a true optimistic-concurrency guard"
  - "Remove-member guards against removing the last active Guardian of a family (own discretion per plan's 'Claude's discretion, document it' instruction) — implemented as a live count check, not a DB constraint"
  - "Integration tests for authenticated endpoints use a custom TestAuthHandler (header-driven ClaimsPrincipal) wired via PostConfigure<AuthenticationOptions>, since the prior AuthEndpointsTests.cs harness referenced by the plan's read_first no longer exists (removed in the Supabase Auth migration)"

patterns-established:
  - "TDD RED->GREEN commit pairs per task (test(01-05) commit -> feat(01-05) commit), verified via dotnet test showing NotImplementedException failures before implementation and passing tests after"
  - "Family-scoped mutation handlers always re-scope the target lookup to the route's familyId, never trusting memberId alone — the concrete IDOR-prevention idiom for this codebase going forward"

requirements-completed: [FAM-01, FAM-02, FAM-03, FAM-04, FAM-05]

coverage:
  - id: D1
    description: "A Guardian can POST /families to create a circle, which also creates their own Guardian FamilyMember row (FAM-01)"
    requirement: "FAM-01"
    verification:
      - kind: unit
        ref: "backend/tests/SafePath.Application.Tests/Families/CreateFamilyCommandTests.cs#Handle_CreatesFamilyAndGuardianMembership"
        status: pass
    human_judgment: false
  - id: D2
    description: "A Guardian can generate a single-use, 24h-expiring invite (short display code + longer opaque link token); a non-member cannot generate invites for that family (FAM-02)"
    requirement: "FAM-02"
    verification:
      - kind: unit
        ref: "backend/tests/SafePath.Application.Tests/Families/FamilyInvitationTests.cs#GenerateInvite_ByGuardian_CreatesPendingInviteWithCodeAndLinkToken"
        status: pass
      - kind: unit
        ref: "backend/tests/SafePath.Application.Tests/Families/FamilyInvitationTests.cs#GenerateInvite_ByNonMember_IsDenied"
        status: pass
    human_judgment: false
  - id: D3
    description: "An authenticated invitee can accept (creating a Member row) or decline an invite; an expired or already-used code is rejected (FAM-03)"
    requirement: "FAM-03"
    verification:
      - kind: unit
        ref: "backend/tests/SafePath.Application.Tests/Families/FamilyInvitationTests.cs#RedeemInvite_Accept_TransitionsToAcceptedAndInsertsMembership"
        status: pass
      - kind: unit
        ref: "backend/tests/SafePath.Application.Tests/Families/FamilyInvitationTests.cs#RedeemInvite_SameCodeTwice_SecondRedeemIsRejected"
        status: pass
      - kind: unit
        ref: "backend/tests/SafePath.Application.Tests/Families/FamilyInvitationTests.cs#RedeemInvite_Expired_IsRejected"
        status: pass
      - kind: unit
        ref: "backend/tests/SafePath.Application.Tests/Families/FamilyInvitationTests.cs#RedeemInvite_Decline_TransitionsToDeclinedAndCreatesNoMembership"
        status: pass
    human_judgment: false
  - id: D4
    description: "A Guardian can update a member's permission level; a non-Guardian is denied (FAM-04)"
    requirement: "FAM-04"
    verification:
      - kind: unit
        ref: "backend/tests/SafePath.Application.Tests/Families/UpdateMemberPermissionsCommandTests.cs#Handle_ByGuardian_PersistsNewPermissionLevel"
        status: pass
      - kind: unit
        ref: "backend/tests/SafePath.Application.Tests/Families/UpdateMemberPermissionsCommandTests.cs#Handle_ByNonGuardianMember_IsDenied"
        status: pass
    human_judgment: false
  - id: D5
    description: "A Guardian can remove a member (soft-remove); a removed member fails subsequent family-scoped authorization; the last active Guardian cannot be removed (FAM-05)"
    requirement: "FAM-05"
    verification:
      - kind: integration
        ref: "backend/tests/SafePath.Api.IntegrationTests/RemoveMemberCommandTests.cs#RemoveMember_ByGuardian_SoftRemovesAndDeniesFurtherAccess"
        status: pass
      - kind: unit
        ref: "backend/tests/SafePath.Application.Tests/Families/UpdateMemberPermissionsCommandTests.cs#RemoveMemberCommandLastGuardianGuardTests.Handle_RemovingTheOnlyGuardian_IsRejected"
        status: pass
    human_judgment: false
  - id: D6
    description: "Every family-scoped endpoint re-verifies the caller's own FamilyMember row + role server-side — cross-family and removed-member requests are denied at the server (IDOR prevention, T-05-01)"
    verification:
      - kind: unit
        ref: "backend/tests/SafePath.Application.Tests/Families/CreateFamilyCommandTests.cs#FamilyAuthorizationServiceTests.RequireMembership_DeniesUserWithNoFamilyMemberRow"
        status: pass
      - kind: integration
        ref: "backend/tests/SafePath.Api.IntegrationTests/RemoveMemberCommandTests.cs#RemoveMember_CrossFamily_IsDenied"
        status: pass
    human_judgment: false

# Metrics
duration: 27min
completed: 2026-07-09
status: complete
---

# Phase 01 Plan 05: Family Circle Backend Summary

**Family-circle backend (create/invite/accept-decline/manage-permissions/remove) with server-side FamilyAuthorizationService as the sole authorization mechanism — no Postgres RLS, share-code/QR invites backed by CSPRNG secrets, applied FamilyCircle migration to the live Supabase database**

## Performance

- **Duration:** 27 min
- **Started:** 2026-07-09T08:12:00Z
- **Completed:** 2026-07-09T08:38:19Z
- **Tasks:** 3
- **Files modified:** 29 (23 created, 6 modified)

## Accomplishments
- `Family`, `FamilyMember`, `FamilyInvitation` domain entities + EF configurations + `FamilyCircle` migration, applied to the live Supabase database
- `FamilyAuthorizationService` (`RequireMembership`/`RequireRole`) — the single server-side authorization mechanism for every family-scoped handler, proven to deny non-members and cross-family targets
- `CreateFamilyCommand` — creates a `Family` + first Guardian `FamilyMember` in one transaction (FAM-01)
- `GenerateInviteCommand`/`RedeemInviteCommand` — CSPRNG display code + opaque link token, 24h expiry, single-use, Guardian-gated generation, authenticated redeem with accept/decline (FAM-02, FAM-03)
- `UpdateMemberPermissionsCommand`/`RemoveMemberCommand` — Guardian-gated, family-rescoped target lookups (IDOR prevention), soft-remove with a last-active-Guardian guard (FAM-04, FAM-05)
- `FamiliesController` (`POST /families`, `GET /families/{id}/members`, `PATCH /families/{id}/members/{id}/permissions`, `DELETE /families/{id}/members/{id}`) and `InvitesController` (`POST /families/{id}/invites`, `POST /invites/redeem`) with a per-IP rate-limit policy on redeem
- 18/18 backend tests green (14 Application unit tests, 4 API integration tests), including a real-HTTP-pipeline IDOR test proving a removed member and a cross-family Guardian are both denied server-side

## Task Commits

Each task was executed as a TDD RED -> GREEN commit pair:

1. **Task 1: Family/FamilyMember/FamilyInvitation entities + migration + CreateFamily + authorization service**
   - `0114c35` (test) — failing tests for family creation and server-side authorization
   - `d810228` (feat) — CreateFamilyCommandHandler + FamilyAuthorizationService implementation
2. **Task 2: Invite generation + redeem (accept/reject)**
   - `1d3c3b3` (test) — failing tests for invite generation and redeem
   - `a76c1b4` (feat) — GenerateInviteCommandHandler + RedeemInviteCommandHandler implementation
3. **Task 3: Manage permissions + remove member with an IDOR integration test**
   - `7174460` (test) — failing tests for permission management and member removal
   - `f5de156` (feat) — UpdateMemberPermissionsCommandHandler + RemoveMemberCommandHandler implementation

_Migration `20260709082519_FamilyCircle` was generated in Task 1 and applied to the live Supabase database via `dotnet ef database update` after Task 3 completed (all three tables now exist)._

## Files Created/Modified
- `backend/src/SafePath.Domain/Entities/Family.cs` - Family circle root entity
- `backend/src/SafePath.Domain/Entities/FamilyMember.cs` - Membership row (Role, Permissions, soft-remove fields)
- `backend/src/SafePath.Domain/Entities/FamilyInvitation.cs` - Share-code/QR invite state machine
- `backend/src/SafePath.Application/Common/Interfaces/IFamilyAuthorizationService.cs` - Server-side membership+role contract
- `backend/src/SafePath.Application/Common/Interfaces/IInviteCodeGenerator.cs` - CSPRNG invite-secret contract (added beyond plan's file list to preserve Clean Architecture boundary)
- `backend/src/SafePath.Application/Families/CreateFamilyCommand.cs` - Family + Guardian membership transaction
- `backend/src/SafePath.Application/Families/ListFamilyMembersQuery.cs` - Membership-gated member roster
- `backend/src/SafePath.Application/Families/GenerateInviteCommand.cs` - Guardian-gated invite generation, unique-code retry
- `backend/src/SafePath.Application/Families/RedeemInviteCommand.cs` - Accept/decline, single-use, expiry enforcement
- `backend/src/SafePath.Application/Families/UpdateMemberPermissionsCommand.cs` - Guardian-gated permission update
- `backend/src/SafePath.Application/Families/RemoveMemberCommand.cs` - Guardian-gated soft-remove, last-Guardian guard
- `backend/src/SafePath.Infrastructure/Identity/FamilyAuthorizationService.cs` - RequireMembership/RequireRole implementation
- `backend/src/SafePath.Infrastructure/Identity/InviteCodeGenerator.cs` - RandomNumberGenerator-backed code + token generation
- `backend/src/SafePath.Infrastructure/Persistence/EntityConfigurations/Family*.cs` (3 files) - EF configurations, unique indexes on Code/LinkToken and (FamilyId, UserId)
- `backend/src/SafePath.Infrastructure/Persistence/Migrations/20260709082519_FamilyCircle.cs` - Families/FamilyMembers/FamilyInvitations migration
- `backend/src/SafePath.Api/Controllers/FamiliesController.cs` - Create/list-members/update-permissions/remove-member endpoints
- `backend/src/SafePath.Api/Controllers/InvitesController.cs` - Generate/redeem endpoints
- `backend/src/SafePath.Api/Program.cs` - Added per-IP `invite-redeem` rate-limit policy
- `backend/tests/SafePath.Application.Tests/Families/*.cs` (3 files) - Unit tests for all five commands + authorization service
- `backend/tests/SafePath.Api.IntegrationTests/RemoveMemberCommandTests.cs` - IDOR integration tests + TestAuthHandler harness

## Decisions Made
- Adapted `ICurrentUserService`/current-user resolution to the post-migration Supabase Auth mechanism (JWT `sub` claim), not the plan's original custom-JWT assumption — see key-decisions in frontmatter for full detail
- Added `IInviteCodeGenerator` interface (not explicitly in the plan's file list) so the Application layer never references the concrete Infrastructure `InviteCodeGenerator` class
- Display code is 6 characters (vs. the mockup's 4) for extra entropy; alphabet excludes visually ambiguous characters
- Single-use invite redemption is enforced via check-then-mutate inside one `SaveChangesAsync` transaction, not a raw compare-and-swap `ExecuteUpdateAsync` — sufficient for sequential redeem tests, documented as a simplification
- Remove-member blocks removing the last active Guardian of a family (discretionary per plan instruction)
- Built a custom `TestAuthHandler` + `FamilyApiFactory` for the IDOR integration test since the plan's referenced `AuthEndpointsTests.cs` harness no longer exists post-Supabase-migration

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Adapted to post-migration Supabase Auth current-user mechanism**
- **Found during:** Task 1 (planning read-first)
- **Issue:** The plan's `<read_first>` for Task 3 referenced `backend/tests/SafePath.Api.IntegrationTests/AuthEndpointsTests.cs` as the WebApplicationFactory harness pattern to reuse. That file was removed during the Supabase Auth migration (see `01-03-SUMMARY.md` addendum) — no custom-JWT `AuthController`/`ICurrentUserService` implementation exists to model against.
- **Fix:** Read the actual current-user mechanism (`ICurrentUserService`/`CurrentUserService` reading the Supabase JWT `sub` claim, `MeController`, `Program.cs`'s JwtBearer configuration against the Supabase issuer) and built all Application/Infrastructure/Api code against that, plus a new `TestAuthHandler`-based integration-test harness (`MeEndpointTests.cs`'s `ProtectedApiFactory` was the closest prior art, extended with an authenticated test scheme).
- **Files modified:** All Task 1-3 files (built correctly from the start using this mechanism); `backend/tests/SafePath.Api.IntegrationTests/RemoveMemberCommandTests.cs` (new `TestAuthHandler`/`FamilyApiFactory`)
- **Verification:** All 18 backend tests pass; integration tests confirm real authenticated HTTP round-trips (401 without a test-auth header, 403 on IDOR denial, 200/204 on success)
- **Committed in:** All task commits (0114c35, d810228, 1d3c3b3, a76c1b4, 7174460, f5de156)

**2. [Rule 2 - Missing Critical] Per-IP rate-limit partitioning on /invites/redeem**
- **Found during:** Task 2
- **Issue:** The existing "login" rate limiter in `Program.cs` (from plan 01) is a single shared fixed window across all callers, not partitioned per client — a global limiter would let one caller exhaust the budget for everyone, providing no real per-attacker brute-force protection for invite-code guessing (RESEARCH Pitfall 4 explicitly calls for per-IP limiting).
- **Fix:** Implemented `options.AddPolicy("invite-redeem", ...)` using `RateLimitPartition.GetFixedWindowLimiter` keyed by `httpContext.Connection.RemoteIpAddress`, applied via `[EnableRateLimiting("invite-redeem")]` on the redeem action.
- **Files modified:** `backend/src/SafePath.Api/Program.cs`, `backend/src/SafePath.Api/Controllers/InvitesController.cs`
- **Verification:** Build succeeds; policy registered and applied (not covered by an automated load test — acceptable for this phase's scope, matching the plan's own unverified "login" limiter precedent)
- **Committed in:** `1d3c3b3` (test commit, included as part of the RED-phase scaffolding since it's structural, not behavioral)

---

**Total deviations:** 2 auto-fixed (1 blocking — auth mechanism adaptation, 1 missing critical — per-IP rate limiting)
**Impact on plan:** Both were necessary for correctness/security given the codebase's actual current state; no scope creep beyond what FAM-01..05 require.

## Issues Encountered
None beyond the deviations documented above.

## User Setup Required
None - no external service configuration required. The `FamilyCircle` migration was applied directly to the already-configured Supabase connection via `dotnet ef database update`.

## Next Phase Readiness
- Family-circle backend (FAM-01..05) is fully implemented, tested, and live on Supabase — ready for plan 01-07 (family-circle mobile UI) to build against `FamiliesController`/`InvitesController`.
- `IFamilyAuthorizationService` and the family-rescoped-lookup IDOR pattern are established conventions later phases (location sharing, geofencing, SOS routing to guardians) should reuse when adding new family-scoped endpoints.
- No blockers.

---
*Phase: 01-backend-auth-foundation*
*Completed: 2026-07-09*

## Self-Check: PASSED

All 23 claimed files (22 created + this SUMMARY.md) verified present on disk; all 6 task commits (0114c35, d810228, 1d3c3b3, a76c1b4, 7174460, f5de156) verified present in `git log`.
