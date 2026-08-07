---
phase: 03-sos-fast-path
fixed_at: 2026-08-07T23:27:58Z
review_path: .planning/phases/03-sos-fast-path/03-REVIEW.md
iteration: 1
findings_in_scope: 5
fixed: 5
skipped: 0
status: all_fixed
---

# Phase 03: Code Review Fix Report

**Fixed at:** 2026-08-07T23:27:58Z
**Source review:** .planning/phases/03-sos-fast-path/03-REVIEW.md
**Iteration:** 1

**Summary:**
- Findings in scope: 5 (fix_scope: critical_warning — CR-01 + WR-01..WR-04; IN-01 excluded)
- Fixed: 5
- Skipped: 0

## Fixed Issues

### CR-01: `TriggerSosCommandHandler`'s idempotent-replay branch leaked SOS session data to non-members (broken access control)

**Files modified:** `backend/src/SafePath.Application/Sos/TriggerSosCommand.cs`,
`backend/tests/SafePath.Api.IntegrationTests/SosControllerTests.cs`
**Commit:** `1c74172`
**Applied fix:** Moved `_authorization.RequireMembership` ahead of the idempotent-replay early
return, verifying against the *resolved* session's own `FamilyId` (not the caller-supplied one,
which could be mismatched on a replay) — matching the pattern already used by
`GetSosSessionQueryHandler`, `CancelSosCommandHandler`, and `AcknowledgeSosCommandHandler` in the
same file. Added `Trigger_ReturnsForbiddenWhenReplayingAnotherFamilysSessionId`, an integration
test mirroring `Trigger_ReturnsForbiddenForNonMemberFamily` but against an already-created session
id, asserting 403 for a non-member caller who replays it. Verified with the full backend test
suite (`dotnet test backend/SafePath.sln`): 200/200 passed after this and every subsequent fix in
this report.

### WR-01: `DeliveryStatusChip` labeled a permanently `Failed` delivery as "Retrying"

**Files modified:** `mobile/lib/features/sos/presentation/delivery_status_chip.dart`
**Commit:** `a560ec6`
**Applied fix:** Changed the `SosDeliveryStatus.failed` case to render `Icons.error_outline` /
"Not delivered" instead of `Icons.schedule` / "Retrying" — `Failed` is a terminal server-side
state with no retry path, so the label no longer implies an in-progress retry that doesn't exist
(D-09/D-10 honesty). No test referenced the old "Retrying" copy.

### WR-02: SMS webhook signature validation reconstructed the request URL from `Request.Scheme`/`Request.Host`, unreliable behind a reverse proxy

**Files modified:** `backend/src/SafePath.Api/Controllers/SmsWebhookController.cs`
**Commit:** `37a5544`
**Applied fix:** Added a `BuildValidatedUrl()` helper that prefers the operator-configured
`TwilioOptions.StatusCallbackUrl` (already the exact public URL `TwilioSmsGateway` tells Twilio to
call back) plus the live query string, falling back to the original `Request.Scheme`/`Request.Host`
reconstruction only when no callback URL is configured (local dev with `LoggingSmsGateway`, where
no real Twilio callback ever arrives). This avoids depending on `app.UseForwardedHeaders()` /
proxy-specific `KnownProxies` configuration, which is out of scope for this fix and carries a much
larger blast radius (affects the whole request pipeline, not just this webhook).

### WR-03: `SosController._composeRequest` could silently trigger with an empty `familyId`

**Files modified:** `mobile/lib/features/sos/application/sos_controller.dart`,
`mobile/lib/features/sos/data/sos_local_store.dart`,
`mobile/test/helpers/fake_sos_local_store.dart`
**Commit:** `3a7c4e3`
**Applied fix:** Added a `_cachedFamilyId` field to `SosController`, populated via a `ref.listen`
on `familyControllerProvider` (persisted to a new `SosLocalStore.writeFamilyId`/`readFamilyId` pair
backed by SharedPreferences) and seeded from disk during the existing `_rehydrate()` bootstrap.
`_composeRequest` now falls back to this cached value whenever `familyControllerProvider` hasn't
resolved yet, instead of sending an empty string the server can never bind as a `Guid`. Chose the
"cached last-known family id" approach over blocking `arm()` on the family fetch, since blocking
would itself violate the Core Value ("SOS must always work ... within seconds"). Updated
`FakeSosLocalStore` to implement the two new interface methods so existing tests keep compiling.

### WR-04: `SosDeliveryAttempts`' unique index didn't actually enforce "one row per (session, recipient, channel)" for SMS rows

**Files modified:**
`backend/src/SafePath.Infrastructure/Persistence/EntityConfigurations/SosDeliveryAttemptConfiguration.cs`,
`backend/src/SafePath.Infrastructure/Persistence/Migrations/20260807232627_AddPartialUniqueIndexesForSosDeliveryAttempts.cs`,
`backend/src/SafePath.Infrastructure/Persistence/Migrations/20260807232627_AddPartialUniqueIndexesForSosDeliveryAttempts.Designer.cs`,
`backend/src/SafePath.Infrastructure/Persistence/Migrations/ApplicationDbContextModelSnapshot.cs`,
`backend/tests/SafePath.Application.Tests/Sos/SosSchemaTests.cs`
**Commit:** `ec11b97`
**Applied fix:** Replaced the single composite unique index (`SosSessionId, RecipientUserId,
EmergencyContactId, Channel`) with two filtered/partial unique indexes — one on
`(SosSessionId, RecipientUserId, Channel)` filtered to `RecipientUserId IS NOT NULL`, one on
`(SosSessionId, EmergencyContactId, Channel)` filtered to `EmergencyContactId IS NOT NULL` — per
the review's suggested EF Core shape. Generated the corresponding migration via `dotnet ef
migrations add`. Added
`SosDeliveryAttempts_RejectsDuplicateSmsRowForSameContactAndChannel` to `SosSchemaTests.cs`,
proving two SMS rows for the same `(session, contact, channel)` now throw `DbUpdateException` on
SQLite (the test provider) as well.

## Skipped Issues

None — all in-scope findings were fixed.

---

_Fixed: 2026-08-07T23:27:58Z_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 1_
