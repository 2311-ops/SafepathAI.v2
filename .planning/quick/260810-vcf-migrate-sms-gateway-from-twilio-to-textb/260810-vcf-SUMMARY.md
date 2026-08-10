---
phase: quick-260810-vcf
plan: 01
subsystem: api
tags: [sms, textbee, twilio-removal, sos, httpclient]

requires:
  - phase: 03-sos-fast-path
    provides: "ISmsGateway/ISmsWebhookSignatureValidator seam, SosAlertDispatcher SMS arm, RecordSmsDeliveryStatusCommand webhook handler (03-05)"
provides:
  - "TextBeeSmsGateway (typed HttpClient ISmsGateway implementation calling TextBee's send-sms REST API)"
  - "TextBeeOptions configuration binding (TextBee:ApiKey/DeviceId/BaseUrl) with an IsConfigured zero-cost-default gate"
  - "TextBeeWebhookSignatureValidator, a permanent unconditional-false ISmsWebhookSignatureValidator"
  - "Complete removal of Twilio (package, types, config keys, DI registrations, doc comments) from backend/src and backend/tests"
affects: [sos, notifications, backend-infrastructure]

tech-stack:
  added: []
  patterns: ["Typed HttpClient ISmsGateway registration via AddHttpClient<ISmsGateway, TextBeeSmsGateway>, matching the existing SupabaseProfileImageStorage typed-client convention"]

key-files:
  created:
    - backend/src/SafePath.Infrastructure/Sms/TextBeeSmsGateway.cs
    - backend/src/SafePath.Infrastructure/Sms/TextBeeOptions.cs
    - backend/src/SafePath.Infrastructure/Sms/TextBeeWebhookSignatureValidator.cs
  modified:
    - backend/src/SafePath.Infrastructure/DependencyInjection.cs
    - backend/src/SafePath.Api/Controllers/SmsWebhookController.cs
    - backend/src/SafePath.Infrastructure/SafePath.Infrastructure.csproj
    - backend/tests/SafePath.Application.Tests/Sos/SmsFanOutTests.cs
    - docs/EXTERNAL-SETUP.md
    - .planning/STATE.md

key-decisions:
  - "Plain HttpClient + System.Text.Json for TextBeeSmsGateway; no new NuGet package added."
  - "TextBeeWebhookSignatureValidator is a permanent no-op (always false) rather than configuration-gated, since TextBee has no delivery-status callback at all."
  - "SmsWebhookController's X-Twilio-Signature header read was renamed to X-Sms-Provider-Signature (vestigial, since the validator ignores it unconditionally) to satisfy the plan's zero-Twilio-references requirement."
  - "Doc-comment-only edits made to four files outside the plan's stated files_modified list (LoggingSmsGateway.cs, SosAlertDispatcher.cs, RecordSmsDeliveryStatusCommand.cs, SafePath.Application/DependencyInjection.cs) to eliminate residual 'Twilio' mentions, since the plan's own success criteria required zero Twilio references anywhere in backend source."

requirements-completed: [SOS-02, NOTIF-03]

coverage:
  - id: D1
    description: "TextBeeSmsGateway sends SMS via TextBee's send-sms REST API (typed HttpClient, x-api-key header, recipients/message JSON body) and extracts the provider message id defensively from the response"
    requirement: "SOS-02"
    verification:
      - kind: unit
        ref: "backend/tests/SafePath.Application.Tests/Sos/SmsFanOutTests.cs#TextBeeSmsGateway_SendsTheExpectedRequestShapeAndExtractsTheProviderMessageId"
        status: pass
    human_judgment: false
  - id: D2
    description: "TextBeeWebhookSignatureValidator unconditionally returns false, so no forged or genuine callback can ever mark a delivery attempt Delivered"
    requirement: "SOS-02"
    verification:
      - kind: unit
        ref: "backend/tests/SafePath.Application.Tests/Sos/SmsFanOutTests.cs#TextBeeWebhookSignatureValidator_IsAlwaysFalse"
        status: pass
    human_judgment: false
  - id: D3
    description: "SosAlertDispatcher's SMS fan-out (DispatchSms) is unaffected by the provider swap: a successful send still records Queued status and a non-empty ProviderMessageId"
    requirement: "NOTIF-03"
    verification:
      - kind: unit
        ref: "backend/tests/SafePath.Application.Tests/Sos/SmsFanOutTests.cs#Dispatch_MarksSmsQueuedAndStoresTheProviderMessageId"
        status: pass
      - kind: unit
        ref: "backend/tests/SafePath.Application.Tests/Sos/SmsFanOutTests.cs#Dispatch_MarksSmsFailedWhenTheGatewayThrows"
        status: pass
    human_judgment: false
  - id: D4
    description: "Zero Twilio references remain anywhere in backend/src or backend/tests (package, types, config keys, DI, doc comments)"
    verification:
      - kind: other
        ref: "grep -ric twilio backend/src backend/tests (returns 0)"
        status: pass
    human_judgment: false
  - id: D5
    description: "A fresh clone with no TextBee credentials configured still runs the entire SOS pipeline for free via LoggingSmsGateway"
    requirement: "SOS-02"
    verification:
      - kind: unit
        ref: "backend/tests/SafePath.Application.Tests/Sos/SmsFanOutTests.cs#LoggingGateway_ReturnsASyntheticIdAndSendsNothing"
        status: pass
    human_judgment: false
  - id: D6
    description: "docs/EXTERNAL-SETUP.md and .planning/STATE.md's SMS-provisioning blocker describe TextBee device registration instead of Twilio account provisioning"
    verification: []
    human_judgment: true
    rationale: "Documentation-content correctness is a prose/readability judgment, not something a unit test can verify."

duration: 65min
completed: 2026-08-10
status: complete
---

# Quick Task 260810-vcf: Migrate SMS Gateway from Twilio to TextBee Summary

**Replaced the Twilio-backed emergency-contact SMS channel with a TextBee typed-HttpClient gateway behind the unchanged `ISmsGateway` seam, removing every Twilio package/type/config reference from the backend.**

## Performance

- **Duration:** ~65 min
- **Completed:** 2026-08-10T19:55:00Z
- **Tasks:** 3
- **Files modified:** 20 (3 created, 3 deleted, 14 modified)

## Accomplishments
- `TextBeeSmsGateway` (typed `HttpClient` implementation of `ISmsGateway`) sends SMS via TextBee's `POST /api/v1/gateway/devices/{deviceId}/send-sms` endpoint, extracting the provider message id defensively from the response body with a synthetic-id fallback (matching `LoggingSmsGateway`'s convention).
- `TextBeeOptions` binds `TextBee:ApiKey`/`TextBee:DeviceId`/`TextBee:BaseUrl` with the same `IsConfigured` zero-cost-default gate shape as the superseded Twilio/Firebase options — `LoggingSmsGateway` remains the free default for a fresh clone.
- `TextBeeWebhookSignatureValidator` is a permanent, documented no-op (`IsValid` always returns `false`) since TextBee has no delivery-status webhook at all — `/webhooks/sms/status` structurally refuses every request forever.
- Twilio fully removed: `TwilioSmsGateway.cs`, `TwilioOptions.cs`, `TwilioWebhookSignatureValidator.cs` deleted; the `Twilio` NuGet package reference dropped from `SafePath.Infrastructure.csproj`; DI, the webhook controller, and every doc comment across `backend/src` updated to reference TextBee (or nothing provider-specific) instead.
- `SmsFanOutTests.cs` gained two new tests (`TextBeeWebhookSignatureValidator_IsAlwaysFalse`, `TextBeeSmsGateway_SendsTheExpectedRequestShapeAndExtractsTheProviderMessageId`) alongside the six pre-existing webhook-handler tests, which were left behaviorally untouched per the plan's explicit non-goal.
- `docs/EXTERNAL-SETUP.md` gained a "TextBee Device Registration" section (companion Android app install, device registration, API key/device id retrieval) and `.planning/STATE.md`'s SMS-provisioning blocker now describes TextBee, not Twilio.

## Task Commits

Each task was committed atomically:

1. **Task 1: Build the TextBee gateway, options, and webhook validator** - `2bc4367` (feat)
2. **Task 2: Remove Twilio and wire TextBee into DI, the csproj, and the webhook controller** - `b3f5ebe` (feat)
3. **Task 3: Update tests, docs, and STATE.md; run backend tests** - `047b1b1` (test+docs)

_Note: Task 2's commit also includes doc-comment-only fixes to four files outside its stated file list (see Deviations below), required to satisfy the plan's own zero-Twilio-references success criterion._

## Files Created/Modified
- `backend/src/SafePath.Infrastructure/Sms/TextBeeSmsGateway.cs` - New `ISmsGateway` implementation calling TextBee's send-sms REST API
- `backend/src/SafePath.Infrastructure/Sms/TextBeeOptions.cs` - Configuration binding + `IsConfigured` gate
- `backend/src/SafePath.Infrastructure/Sms/TextBeeWebhookSignatureValidator.cs` - Permanent always-false `ISmsWebhookSignatureValidator`
- `backend/src/SafePath.Infrastructure/Sms/TwilioSmsGateway.cs`, `TwilioOptions.cs`, `TwilioWebhookSignatureValidator.cs` - Deleted
- `backend/src/SafePath.Infrastructure/DependencyInjection.cs` - TextBee options construction/registration replaces Twilio's; typed-`HttpClient` registration replaces the `ITwilioRestClient` singleton
- `backend/src/SafePath.Infrastructure/SafePath.Infrastructure.csproj` - Removed the `Twilio` package reference
- `backend/src/SafePath.Api/Controllers/SmsWebhookController.cs` - No longer depends on `TwilioOptions`; builds the callback URL from the inbound request directly
- `backend/src/SafePath.Application/Common/Interfaces/ISmsGateway.cs`, `ISmsWebhookSignatureValidator.cs` - Doc comments reference TextBee instead of Twilio (member signatures unchanged)
- `backend/src/SafePath.Application/Sos/SosLiveWindowOptions.cs`, `backend/src/SafePath.Infrastructure/Push/FirebaseOptions.cs` - Doc-comment sibling-pattern reference renamed
- `backend/src/SafePath.Infrastructure/Sms/LoggingSmsGateway.cs`, `backend/src/SafePath.Application/Sos/SosAlertDispatcher.cs`, `backend/src/SafePath.Application/Sos/RecordSmsDeliveryStatusCommand.cs`, `backend/src/SafePath.Application/DependencyInjection.cs` - Doc-comment-only Twilio-reference cleanup (deviation, see below)
- `backend/tests/SafePath.Application.Tests/Sos/SmsFanOutTests.cs` - Two new TextBee-specific tests; `FakeSignatureValidator` doc comment updated
- `docs/EXTERNAL-SETUP.md` - Twilio provisioning section replaced with TextBee device registration; config keys table, prerequisites table, "Still Outstanding" row updated
- `.planning/STATE.md` - SMS-provisioning blocker rewritten for TextBee; Decisions log and "Carried forward from research" list left untouched

## Decisions Made
- Kept `ISmsGateway`/`ISmsWebhookSignatureValidator` member signatures completely locked, as required — only Infrastructure implementations and doc comments changed.
- `TextBeeSmsGateway` parses the response body defensively (`data._id`/`id`/`smsId`/`messageId`, checked in that order) since TextBee's exact response schema was not independently verified this session; any parse failure falls back to a synthetic `textbee-{guid}` id rather than failing the send.
- Renamed the vestigial `X-Twilio-Signature` header read in `SmsWebhookController` to `X-Sms-Provider-Signature` — functionally inert either way since `TextBeeWebhookSignatureValidator.IsValid` ignores its value unconditionally, but the old name was a literal "Twilio" string match that the plan's verification explicitly requires to be zero.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Removed residual "Twilio" doc-comment references from four files outside the plan's stated `files_modified` list**
- **Found during:** Task 2, while confirming `grep -ric twilio backend/src` returns 0 per the plan's own verification command and success criteria ("Zero Twilio references remain in backend source... every Twilio reference — package, types, config keys, docs — is removed").
- **Issue:** `LoggingSmsGateway.cs`, `SosAlertDispatcher.cs`, `RecordSmsDeliveryStatusCommand.cs`, and `SafePath.Application/DependencyInjection.cs` each carried a doc-comment sentence naming "Twilio" (e.g. "registered whenever Twilio credentials are absent", "the Twilio status webhook added in plan 03-05"). None of these four files were in the plan's Task 2 `<files>` list, but leaving them unchanged would make the plan's own stated verification command fail.
- **Fix:** Reworded each doc comment to remove the literal string "Twilio" while preserving its meaning (e.g. "the SMS provider status webhook added in plan 03-05 (migrated to TextBee in quick task 260810-vcf)"). No logic in any of these four files was touched — comment text only.
- **Files modified:** `backend/src/SafePath.Infrastructure/Sms/LoggingSmsGateway.cs`, `backend/src/SafePath.Application/Sos/SosAlertDispatcher.cs`, `backend/src/SafePath.Application/Sos/RecordSmsDeliveryStatusCommand.cs`, `backend/src/SafePath.Application/DependencyInjection.cs`
- **Verification:** `grep -ric twilio backend/src backend/tests` returns 0; `dotnet build`/`dotnet test` both green afterward.
- **Committed in:** `b3f5ebe` (Task 2 commit)
- **Note on tension with verification item 5:** The plan's top-level `<verification>` step 5 asks to confirm `SosAlertDispatcher.cs` is "byte-for-byte unchanged" via `git diff --stat`. That file *was* touched by this fix, but only its doc comment — no method body, call site, or control flow in `SosAlertDispatcher.cs` changed (confirmed via `git show b3f5ebe -- .../SosAlertDispatcher.cs`, a pure comment diff). `TriggerSosCommandHandler.cs`, the other file named in that verification step, remains completely untouched across all three commits. The SOS-01 non-negotiable (fast path logic/behavior never modified) holds; only the literal "byte-for-byte" wording of the automated check does not, because satisfying it would have left a residual "Twilio" string that the plan's own success criteria explicitly forbids. Flagging this explicitly rather than silently picking one requirement over the other.

---

**Total deviations:** 1 auto-fixed (Rule 3 - blocking, to satisfy the plan's own explicit success criteria)
**Impact on plan:** No behavioral or logic change in any file; comment-text-only edits required to make the plan's own "zero Twilio references" verification pass. No scope creep.

## Issues Encountered
- `backend/.env.example` remained permission-denied to read in this execution environment, exactly as it was during planning. Per the plan's instruction, this is documented here as an unverified follow-up rather than guessed at: if that file contains a Twilio config section, it still needs manual renaming to `TextBee__*` by whoever has filesystem access to it.
- `docs/EXTERNAL-SETUP.md` retains two prose mentions of "Twilio" for explicit historical/comparative context ("no account approval process like Twilio's trial-number verification", "unlike the old Twilio-backed flow") — both phrasings were directly specified by the plan's own Task 3 action text. The plan's automated verification command (`grep -ric twilio backend/src backend/tests`) does not cover `docs/`, so this does not fail any automated check, though it is in slight tension with the success-criteria bullet's broader wording ("Zero Twilio references remain in... docs/EXTERNAL-SETUP.md"). Left as the plan's action text explicitly instructed.

## User Setup Required

None required to build, test, or demo. To exercise a real SMS send, see `docs/EXTERNAL-SETUP.md`'s new "TextBee Device Registration" section — install the TextBee companion Android app, register a gateway device, and set `TextBee__ApiKey`/`TextBee__DeviceId`. This is explicitly deferred per `.planning/STATE.md`'s Blockers/Concerns entry; the code path is complete and unblocking is entirely the user's call.

## Next Phase Readiness
- The SMS channel is fully code-complete on TextBee and ready to provision whenever the user chooses; `LoggingSmsGateway` continues to be the zero-cost default with no account required.
- No impact on Phase 4 (Geofencing), which does not touch the SMS channel.
- `backend/.env.example`'s Twilio-key-renaming status remains genuinely unverified — flag for whoever next has permission to read that file.

---
*Phase: quick-260810-vcf*
*Completed: 2026-08-10*

## Self-Check: PASSED

All created files exist on disk (`TextBeeSmsGateway.cs`, `TextBeeOptions.cs`, `TextBeeWebhookSignatureValidator.cs`, `docs/EXTERNAL-SETUP.md`, `.planning/STATE.md`, `SmsFanOutTests.cs`); Twilio implementation files are confirmed deleted (`TwilioSmsGateway.cs` no longer exists); all three task commits (`2bc4367`, `b3f5ebe`, `047b1b1`) are present in `git log --oneline --all`.
