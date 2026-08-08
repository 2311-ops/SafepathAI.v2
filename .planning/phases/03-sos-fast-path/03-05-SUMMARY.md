---
phase: 03-sos-fast-path
plan: 05
subsystem: api
tags: [twilio, libphonenumber, sms, aspnetcore, ef-core, clean-architecture, sos]

# Dependency graph
requires:
  - phase: 03-01
    provides: EmergencyContact/SosDeliveryAttempt schema, idempotent TriggerSosCommand with ResolveRecipients extension point, Twilio/libphonenumber-csharp/FirebaseAdmin package references
  - phase: 03-03
    provides: SosAlertDispatcher's Sms no-op arm extension point, IAlertBroadcastService.DeliveryStatusChanged, SosSessionProjection.ResolveRecipientUserIds
provides:
  - EmergencyContact CRUD (Add/Update/Delete/List) with server-side E.164 normalisation via libphonenumber-csharp, owner always forced to ICurrentUserService
  - GET/POST /me/emergency-contacts, PUT/DELETE /me/emergency-contacts/{id}
  - ISmsGateway seam + LoggingSmsGateway (zero-cost default) + TwilioSmsGateway, conditionally registered on TwilioOptions.IsConfigured
  - TriggerSosCommandHandler.ResolveRecipients widened -- Guardians (SignalR) + the caller's active EmergencyContacts (Sms), still bypassing ISharingAuthorizationService
  - SosAlertDispatcher's Sms arm: per-contact send, Queued+ProviderMessageId or Failed, never Delivered
  - ISmsWebhookSignatureValidator/TwilioWebhookSignatureValidator + RecordSmsDeliveryStatusCommand/Handler + SmsWebhookController (POST /webhooks/sms/status) -- the only path allowed to write SMS Delivered
affects: [03-06, 03-07]

# Tech tracking
tech-stack:
  added:
    - "libphonenumber-csharp 9.0.35 added to SafePath.Application.csproj (already present in SafePath.Infrastructure.csproj from 03-01) so PhoneNumberNormalizer can live in the Application layer without an extra IPhoneNumberNormalizer indirection"
    - "Microsoft.Extensions.Configuration.Abstractions 9.0.9 added to SafePath.Application.csproj so Add/UpdateEmergencyContactCommandHandler can read Sms:DefaultRegion from configuration"
  patterns:
    - "Per-contact failure isolation inside one channel: SosAlertDispatcher's DispatchSms catches per-contact rather than letting one bad number's exception mark every SMS row in the batch Failed"
    - "Raw-webhook-payload command: RecordSmsDeliveryStatusCommand carries the unparsed request URL/form parameters/signature header so signature validation happens inside the (unit-testable) Application-layer handler, never in the controller alone"

key-files:
  created:
    - backend/src/SafePath.Application/Sos/PhoneNumberNormalizer.cs
    - backend/src/SafePath.Application/Sos/EmergencyContactCommands.cs
    - backend/src/SafePath.Api/Controllers/EmergencyContactsController.cs
    - backend/src/SafePath.Application/Common/Interfaces/ISmsGateway.cs
    - backend/src/SafePath.Infrastructure/Sms/TwilioOptions.cs
    - backend/src/SafePath.Infrastructure/Sms/LoggingSmsGateway.cs
    - backend/src/SafePath.Infrastructure/Sms/TwilioSmsGateway.cs
    - backend/src/SafePath.Application/Common/Interfaces/ISmsWebhookSignatureValidator.cs
    - backend/src/SafePath.Infrastructure/Sms/TwilioWebhookSignatureValidator.cs
    - backend/src/SafePath.Application/Sos/RecordSmsDeliveryStatusCommand.cs
    - backend/src/SafePath.Api/Controllers/SmsWebhookController.cs
    - backend/tests/SafePath.Application.Tests/Sos/EmergencyContactCommandTests.cs
    - backend/tests/SafePath.Application.Tests/Sos/SmsFanOutTests.cs
  modified:
    - backend/src/SafePath.Application/Sos/SosDtos.cs
    - backend/src/SafePath.Application/DependencyInjection.cs
    - backend/src/SafePath.Application/SafePath.Application.csproj
    - backend/src/SafePath.Application/Sos/TriggerSosCommand.cs
    - backend/src/SafePath.Application/Sos/SosAlertDispatcher.cs
    - backend/src/SafePath.Infrastructure/DependencyInjection.cs
    - backend/tests/SafePath.Application.Tests/Sos/AlertFanOutTests.cs

key-decisions:
  - "PhoneNumberNormalizer lives in SafePath.Application.Sos; libphonenumber-csharp was added as a direct package reference on SafePath.Application.csproj (same version 9.0.35 already vetted/installed on SafePath.Infrastructure.csproj in 03-01) rather than introducing an IPhoneNumberNormalizer indirection -- the plan explicitly offered either choice and this one avoids an extra interface for a same-assembly-family, already-approved package."
  - "Add/UpdateEmergencyContactCommandHandler take an optional IConfiguration (default null) for Sms:DefaultRegion rather than a required dependency, so unit tests can construct the handler directly (matching TriggerSosCommandHandler's existing optional-IServiceScopeFactory pattern) without needing a real IConfiguration instance."
  - "SosAlertDispatcher's Sms arm isolates failures per-contact (catches inside the per-contact loop) rather than only per-channel, so one bad phone number cannot flip an already-successfully-queued sibling contact's row to Failed."
  - "Kept Twilio's signature-validation logic behind an ISmsWebhookSignatureValidator seam (Application interface, TwilioWebhookSignatureValidator implementation) instead of inline in SmsWebhookController, so RecordSmsDeliveryStatusCommandHandler's mutation behaviour is unit-testable from SafePath.Application.Tests without an HTTP host -- required to satisfy the plan's own acceptance criterion that all 12 SmsFanOutTests run via that test project."
  - "TwilioWebhookSignatureValidator refuses every request when no auth token is configured (not just on a signature mismatch), matching the plan's requirement that the LoggingSmsGateway/no-Twilio-configured path can never accept a provider callback."

patterns-established:
  - "Provider-agnostic gateway seam (ISmsGateway) with a zero-cost logging default registered whenever credentials are absent, and the real provider registered only when IsConfigured -- the same shape 03-06's IPushSender is expected to follow."

requirements-completed: [SOS-02, NOTIF-03]

coverage:
  - id: D1
    description: "A user can add, list, edit and deactivate their own emergency contacts; numbers are validated and stored in E.164 form via libphonenumber-csharp (no regex); another user cannot read or mutate them; no phone number is reachable through any guardian-facing payload"
    requirement: "SOS-02"
    verification:
      - kind: unit
        ref: "backend/tests/SafePath.Application.Tests/Sos/EmergencyContactCommandTests.cs#Add_NormalisesANationalNumberToE164, Add_RejectsAnUnparseableNumber, Add_ForcesOwnerToTheAuthenticatedCaller, List_ReturnsOnlyTheCallersOwnContacts, Update_RejectsAContactOwnedBySomeoneElse, Delete_SoftDeactivatesRatherThanRemoving, List_ReturnsTheFullNumberToItsOwner"
        status: pass
    human_judgment: false
  - id: D2
    description: "SOS recipients are exactly active Guardians plus the sender's active emergency contacts (never all family members, never gated by sharing preferences); the SMS channel runs with zero cost/no Twilio account via LoggingSmsGateway, and configuring Twilio credentials switches providers with no code change; a throwing SMS gateway fails only that contact's row while other channels/contacts stay Queued"
    requirement: "SOS-02"
    verification:
      - kind: unit
        ref: "backend/tests/SafePath.Application.Tests/Sos/SmsFanOutTests.cs#Resolve_IncludesActiveEmergencyContactsOfTheTriggeringUser, Resolve_IncludesGuardiansAndContactsAndNobodyElse, Resolve_DoesNotConsultSharingPreferences, Dispatch_MarksSmsQueuedAndStoresTheProviderMessageId, Dispatch_MarksSmsFailedWhenTheGatewayThrows, LoggingGateway_ReturnsASyntheticIdAndSendsNothing, Message_ContainsSenderNameAndALocationLink"
        status: pass
      - kind: other
        ref: "dotnet run --project backend/src/SafePath.Api with no Twilio configuration -- boots cleanly and logs 'SMS gateway active: LoggingSmsGateway'"
        status: pass
    human_judgment: false
  - id: D3
    description: "An SMS delivery row shows Delivered only on a signature-validated provider receipt; a forged/invalid signature is rejected and mutates nothing; an unrecognised ProviderMessageId is a harmless no-op; the sender's live session receives DeliveryStatusChanged the moment a valid receipt lands"
    requirement: "NOTIF-03"
    verification:
      - kind: unit
        ref: "backend/tests/SafePath.Application.Tests/Sos/SmsFanOutTests.cs#Webhook_MarksTheMatchingRowDeliveredOnADeliveredStatus, Webhook_MarksTheMatchingRowFailedOnAFailedStatus, Webhook_IgnoresAnUnknownProviderMessageId, Webhook_RejectsAnInvalidSignature, Webhook_BroadcastsTheStatusChangeToTheSender"
        status: pass
    human_judgment: false
  - id: D4
    description: "Full backend solution builds and all suites (Application.Tests, Api.IntegrationTests) are green, including 03-01/03-03's pre-existing Sos suites, after this plan's recipient-widening and constructor changes"
    requirement: "NOTIF-03"
    verification:
      - kind: other
        ref: "dotnet build backend/SafePath.sln; dotnet test backend/SafePath.sln -- 149 Application.Tests + 13 Api.IntegrationTests passing (38 in the Sos filter alone)"
        status: pass
    human_judgment: false
  - id: D5
    description: "A real Twilio trial account, verified recipient numbers, and a publicly reachable status-callback URL are needed to observe an actual SMS arrive and flip to Delivered end-to-end -- outside what an automated sandbox run can verify"
    verification: []
    human_judgment: true
    rationale: "Requires the user's own Twilio Console setup (TWILIO_ACCOUNT_SID/AUTH_TOKEN/FROM_NUMBER, Verified Caller IDs, status callback URL) per this plan's user_setup block; the code path is fully covered by unit tests and the LoggingSmsGateway boot-log check, but a live send/receive requires human-owned credentials and cannot be produced automatically in this environment."

duration: 15min
completed: 2026-08-02
status: complete
---

# Phase 03 Plan 05: Emergency Contacts + SMS Fallback Channel Summary

**Emergency-contact CRUD with libphonenumber-csharp E.164 normalisation, widened SOS recipient resolution (Guardians + emergency contacts), a Twilio-behind-ISmsGateway SMS channel that defaults to a zero-cost LoggingSmsGateway, and a signature-validated Twilio delivery-status webhook that is the only path allowed to mark an SMS row Delivered.**

## Performance

- **Duration:** 15 min
- **Started:** 2026-08-02T14:13:00+03:00
- **Completed:** 2026-08-02T14:28:11+03:00
- **Tasks:** 3 (all complete)
- **Files modified:** 20 (13 created, 7 modified)

## Accomplishments

- Emergency contacts can be added, listed, edited, and soft-deactivated, always owner-scoped, with phone numbers normalised to E.164 by `libphonenumber-csharp` (`PhoneNumberNormalizer.ToE164`) -- never a hand-rolled regex.
- `EmergencyContactDto` is the only DTO in the codebase carrying a phone number, returned exclusively from `/me/emergency-contacts` (threat T-03-03).
- `TriggerSosCommandHandler.ResolveRecipients` now also resolves the triggering user's active `EmergencyContacts`, creating `Sms`-channel `SosDeliveryAttempt` rows alongside the existing Guardian `SignalR` rows -- still deliberately bypassing `ISharingAuthorizationService` so a privacy preference can never suppress an emergency contact either.
- `SosAlertDispatcher`'s `Sms` arm sends one message per contact via `ISmsGateway`, composing a body with the sender's display name and a maps link (never the recipient's own number), writing `Queued`+`ProviderMessageId` per successful send and `Failed` per-contact on a throw -- one bad number never swallows a sibling contact's successful queue.
- `LoggingSmsGateway` is the default `ISmsGateway` registration whenever Twilio credentials are absent (D-07): the whole pipeline is exercisable with zero account and zero cost, and the active gateway is logged once at startup.
- `SmsWebhookController` (`POST /webhooks/sms/status`, no `[Authorize]`, no rate limit) accepts Twilio's delivery-status callback; `RecordSmsDeliveryStatusCommandHandler` validates the signature before any mutation, maps delivered/failed statuses, ignores in-flight statuses and unknown ids, and broadcasts `DeliveryStatusChanged` to the sender's live session.

## Task Commits

Each task was committed atomically:

1. **Task 1: Emergency-contact CRUD with E.164 normalisation, scoped to the owning user** - `43831e5` (feat)
2. **Task 2: Widen SOS recipient resolution to include emergency contacts and add the SMS channel to fan-out** - `31fc897` (feat)
3. **Task 3: Accept the provider's delivery receipt so the SMS channel's Delivered state is truthful** - `2b71a99` (feat)

**Plan metadata:** commit pending (this SUMMARY + STATE/ROADMAP update)

## Files Created/Modified

- `backend/src/SafePath.Application/Sos/PhoneNumberNormalizer.cs` - `ToE164` over `PhoneNumberUtil.Parse`/`IsValidNumber`/`Format`, configurable default region
- `backend/src/SafePath.Application/Sos/EmergencyContactCommands.cs` - Add/Update/Delete/List handlers, owner always `ICurrentUserService`
- `backend/src/SafePath.Api/Controllers/EmergencyContactsController.cs` - GET/POST/PUT/DELETE `/me/emergency-contacts*`
- `backend/src/SafePath.Application/Sos/SosDtos.cs` - Added `EmergencyContactDto` (the only phone-number-carrying DTO)
- `backend/src/SafePath.Application/Common/Interfaces/ISmsGateway.cs` - Provider-agnostic `SendAsync`/`SmsSendResult`
- `backend/src/SafePath.Infrastructure/Sms/TwilioOptions.cs` - Binds `Twilio:*` config, `IsConfigured` gate
- `backend/src/SafePath.Infrastructure/Sms/LoggingSmsGateway.cs` - Zero-cost default, redacts destination to last 4 digits
- `backend/src/SafePath.Infrastructure/Sms/TwilioSmsGateway.cs` - Twilio SDK `MessageResource.CreateAsync`, translates SDK exceptions to a credential-free message
- `backend/src/SafePath.Application/Sos/TriggerSosCommand.cs` - Added `ResolveEmergencyContacts`, wired into `Handle`
- `backend/src/SafePath.Application/Sos/SosAlertDispatcher.cs` - Filled `AlertChannel.Sms` arm (`DispatchSms`, `ComposeSmsBody`)
- `backend/src/SafePath.Application/Common/Interfaces/ISmsWebhookSignatureValidator.cs` - Application-layer signature-check seam
- `backend/src/SafePath.Infrastructure/Sms/TwilioWebhookSignatureValidator.cs` - Wraps Twilio's `RequestValidator`
- `backend/src/SafePath.Application/Sos/RecordSmsDeliveryStatusCommand.cs` - Signature-gated status mapping + broadcast
- `backend/src/SafePath.Api/Controllers/SmsWebhookController.cs` - `POST /webhooks/sms/status`, no auth attribute, no rate limit
- `backend/src/SafePath.Application/DependencyInjection.cs` - Registered 5 new handlers
- `backend/src/SafePath.Infrastructure/DependencyInjection.cs` - Registers `TwilioOptions`, conditional `ISmsGateway`, `ISmsWebhookSignatureValidator`, startup gateway-choice log
- `backend/src/SafePath.Application/SafePath.Application.csproj` - Added `libphonenumber-csharp` 9.0.35 and `Microsoft.Extensions.Configuration.Abstractions` 9.0.9
- `backend/tests/SafePath.Application.Tests/Sos/EmergencyContactCommandTests.cs` - 7 tests
- `backend/tests/SafePath.Application.Tests/Sos/SmsFanOutTests.cs` - 12 tests (7 fan-out + 5 webhook)
- `backend/tests/SafePath.Application.Tests/Sos/AlertFanOutTests.cs` - Updated 4 `SosAlertDispatcher` constructions for the new `ISmsGateway` parameter (`NoOpSmsGateway` fake)

## Decisions Made

See `key-decisions` in frontmatter above.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Updated AlertFanOutTests.cs's SosAlertDispatcher constructions for the new ISmsGateway parameter**
- **Found during:** Task 2 (first build after adding `ISmsGateway` to `SosAlertDispatcher`'s constructor)
- **Issue:** `SosAlertDispatcher`'s constructor gained a required `ISmsGateway` parameter per the plan's own design; 03-03's pre-existing `AlertFanOutTests.cs` constructed it with only `(db, broadcast)`, which no longer compiles
- **Fix:** Added an internal `NoOpSmsGateway` test double and passed it to all four `new SosAlertDispatcher(...)` call sites in `AlertFanOutTests.cs` (those tests only exercise the SignalR arm and never invoke the SMS gateway)
- **Files modified:** `backend/tests/SafePath.Application.Tests/Sos/AlertFanOutTests.cs`
- **Verification:** Full `Sos`-filtered suite green (38 tests, including all of 03-01/03-03's original tests)
- **Committed in:** `31fc897` (Task 2 commit)

**2. [Rule 1 - Design correction] Moved Twilio signature validation behind an Application-layer seam instead of inline in the controller**
- **Found during:** Task 3 (structuring the webhook so its 5 test behaviours could live in `SmsFanOutTests.cs` per the plan's own acceptance criteria)
- **Issue:** The plan's prose described validating the signature "inside `SmsWebhookController`," but the plan's acceptance criteria also require all 12 `SmsFanOutTests` (including the 5 webhook tests) to run via `dotnet test backend/tests/SafePath.Application.Tests` -- a controller-only implementation would need an ASP.NET Core test host to exercise signature rejection, which contradicts running purely from the Application test project
- **Fix:** Introduced `ISmsWebhookSignatureValidator` (Application interface) and `TwilioWebhookSignatureValidator` (Infrastructure, wraps Twilio's `RequestValidator`); `RecordSmsDeliveryStatusCommand` carries the raw request URL/form parameters/signature header, and `RecordSmsDeliveryStatusCommandHandler` validates before any mutation -- fully unit-testable with a `FakeSignatureValidator` test double, with the controller reduced to marshalling the HTTP request into the command
- **Files modified:** `backend/src/SafePath.Application/Common/Interfaces/ISmsWebhookSignatureValidator.cs`, `backend/src/SafePath.Infrastructure/Sms/TwilioWebhookSignatureValidator.cs`, `backend/src/SafePath.Application/Sos/RecordSmsDeliveryStatusCommand.cs`, `backend/src/SafePath.Api/Controllers/SmsWebhookController.cs`
- **Verification:** All 5 webhook tests pass from `SafePath.Application.Tests`; `dotnet test backend/SafePath.sln` green (149 Application.Tests + 13 Api.IntegrationTests)
- **Committed in:** `2b71a99` (Task 3 commit)

---

**Total deviations:** 2 (1 Rule 3 blocking fix, 1 Rule 1 design correction that satisfies the plan's own acceptance criteria more literally than the prose description)
**Impact on plan:** No scope creep -- both changes were required for the plan's own stated tests/acceptance criteria to pass; no file outside the plan's `<files>` lists was touched except the pre-existing `AlertFanOutTests.cs` constructor-compat fix.

## Issues Encountered

None beyond the two deviations documented above.

## User Setup Required

**External Twilio service requires manual configuration to send real SMS.** No code change is needed to enable it -- see this plan's `user_setup` block in `03-05-PLAN.md`:
- Environment variables: `TWILIO_ACCOUNT_SID`, `TWILIO_AUTH_TOKEN`, `TWILIO_FROM_NUMBER`
- Twilio Console: verify each demo emergency-contact phone number as a Verified Caller ID (trial accounts can only send to verified numbers)
- Twilio Console: set the messaging status callback URL to `{PUBLIC_API_BASE}/webhooks/sms/status` so delivery receipts can flip the SMS channel to Delivered

Until these are set, the app runs on `LoggingSmsGateway` at zero cost -- this is expected, not a defect.

## Next Phase Readiness

- 03-06 (FCM push) has the same `ISmsGateway`-shaped seam pattern to follow for `IPushSender`.
- 03-07 (mobile emergency-contact management screen + offline call action) can now call `AddEmergencyContactCommand`/`UpdateEmergencyContactCommand`/`DeleteEmergencyContactCommand`/`ListEmergencyContactsQuery` against real, tested endpoints, and `PhoneNumberNormalizer.ToE164` establishes the server as the normalisation authority the client only surfaces errors from.
- REQUIREMENTS.md's SOS-02 (multi-channel: SignalR+FCM+SMS) is now genuinely complete on the SMS side -- this plan is the one that makes that prior claim true.
- No blockers identified.

---
*Phase: 03-sos-fast-path*
*Completed: 2026-08-02*

## Self-Check: PASSED

All 13 created files verified present on disk; all 3 task commits (`43831e5`, `31fc897`, `2b71a99`) verified present in `git log --oneline --all`.
