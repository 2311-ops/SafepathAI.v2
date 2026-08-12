---
phase: quick-260812-wgl
plan: 01
subsystem: backend
tags: [sos, sms, whatsapp, webhook, hmac, delivery-status, clean-architecture]

requires:
  - phase: 03-sos-fast-path
    provides: ISmsGateway seam, SosAlertDispatcher SMS arm, SmsWebhookController/RecordSmsDeliveryStatusCommand seam (from the Twilio->TextBee migration, quick task 260810-vcf)
provides:
  - WhatsAppOptions/WhatsAppSmsGateway sending a Utility-category template message via the WhatsApp Business Cloud API, behind the unchanged ISmsGateway seam
  - A genuine HMAC-SHA256 (X-Hub-Signature-256) delivery-status webhook + GET subscription handshake, replacing the permanently-inert TextBee webhook
  - ISmsDeliveryStatusParser Application seam + WhatsAppDeliveryStatusParser
  - Complete removal of TextBee from backend/src and backend/tests
affects: [phase-03-sos-fast-path, docs-external-setup]

tech-stack:
  added: []
  patterns:
    - "Provider-agnostic ISmsGateway/ISmsWebhookSignatureValidator/ISmsDeliveryStatusParser seams keep every WhatsApp-specific type (HttpClient calls, HMAC computation, JSON payload shape) confined to Infrastructure"
    - "Raw-body signature validation: RecordSmsDeliveryStatusCommand carries the exact request bytes (not form-decoded/pre-parsed) so HMAC verification happens inside the handler before any DbContext mutation"

key-files:
  created:
    - backend/src/SafePath.Infrastructure/Sms/WhatsAppOptions.cs
    - backend/src/SafePath.Infrastructure/Sms/WhatsAppSmsGateway.cs
    - backend/src/SafePath.Infrastructure/Sms/WhatsAppWebhookSignatureValidator.cs
    - backend/src/SafePath.Infrastructure/Sms/WhatsAppDeliveryStatusParser.cs
    - backend/src/SafePath.Application/Common/Interfaces/ISmsDeliveryStatusParser.cs
  modified:
    - backend/src/SafePath.Application/Common/Interfaces/ISmsGateway.cs
    - backend/src/SafePath.Application/Common/Interfaces/ISmsWebhookSignatureValidator.cs
    - backend/src/SafePath.Application/Sos/RecordSmsDeliveryStatusCommand.cs
    - backend/src/SafePath.Infrastructure/DependencyInjection.cs
    - backend/src/SafePath.Infrastructure/Sms/LoggingSmsGateway.cs
    - backend/src/SafePath.Api/Controllers/SmsWebhookController.cs
    - backend/tests/SafePath.Application.Tests/Sos/SmsFanOutTests.cs
    - backend/src/SafePath.Application/Sos/SosAlertDispatcher.cs (doc comments only)
    - backend/src/SafePath.Application/Sos/SosLiveWindowOptions.cs (doc comments only)
    - backend/src/SafePath.Application/DependencyInjection.cs (doc comment only)
    - backend/src/SafePath.Infrastructure/Push/FirebaseOptions.cs (doc comment only)
    - docs/EXTERNAL-SETUP.md

key-decisions:
  - "Migrated the SOS emergency-contact SMS fallback from TextBee to the WhatsApp Business Cloud API, fully behind the unchanged ISmsGateway seam"
  - "RecordSmsDeliveryStatusCommand and ISmsWebhookSignatureValidator moved from form-encoded (Twilio/TextBee-era) parameters to a raw-body shape, since the WhatsApp callback is JSON and its HMAC is computed over the exact bytes"
  - "WhatsAppOptions.IsConfigured gates only on AccessToken + PhoneNumberId (send capability); AppSecret/WebhookVerifyToken gate the inbound webhook independently so an operator who configured sending but not yet the webhook can still send"
  - "WebFetch/WebSearch tools were unavailable in the executor's session; the orchestrator performed the deferred live-docs verification afterward, confirmed the request/response/webhook shapes as implemented, and corrected a stale Graph API version default (v22.0 -> v26.0) found in the process (see Deviations)"

requirements-completed: [SOS-02, NOTIF-03]

coverage:
  - id: D1
    description: "WhatsAppSmsGateway.SendAsync posts a template message to the Cloud API messages endpoint with the correct URL, bearer auth, JSON body shape, and E.164-digits-no-plus recipient"
    requirement: "SOS-02"
    verification:
      - kind: unit
        ref: "backend/tests/SafePath.Application.Tests/Sos/SmsFanOutTests.cs#WhatsAppSmsGateway_SendsATemplateMessageAndExtractsTheMessageId"
        status: pass
    human_judgment: false
  - id: D2
    description: "Template parameter text is normalized (newlines/tabs/multi-space runs collapsed) before sending, since Meta rejects those characters in template parameters"
    requirement: "SOS-02"
    verification:
      - kind: unit
        ref: "backend/tests/SafePath.Application.Tests/Sos/SmsFanOutTests.cs#WhatsAppSmsGateway_NormalizesWhitespaceInTheTemplateParameter"
        status: pass
    human_judgment: false
  - id: D3
    description: "WhatsAppWebhookSignatureValidator validates a correctly-computed X-Hub-Signature-256 HMAC, rejects a tampered body, and refuses everything when no app secret is configured"
    requirement: "NOTIF-03"
    verification:
      - kind: unit
        ref: "backend/tests/SafePath.Application.Tests/Sos/SmsFanOutTests.cs#WhatsAppWebhookSignatureValidator_ValidatesACorrectlyComputedSignature"
        status: pass
      - kind: unit
        ref: "backend/tests/SafePath.Application.Tests/Sos/SmsFanOutTests.cs#WhatsAppWebhookSignatureValidator_RejectsATamperedBody"
        status: pass
      - kind: unit
        ref: "backend/tests/SafePath.Application.Tests/Sos/SmsFanOutTests.cs#WhatsAppWebhookSignatureValidator_RefusesACorrectlySignedBodyWhenNoAppSecretIsConfigured"
        status: pass
    human_judgment: false
  - id: D4
    description: "WhatsAppDeliveryStatusParser maps delivered/read to Delivered, failed to Failed with an error reason, sent to no update, and malformed input to an empty list without throwing"
    requirement: "NOTIF-03"
    verification:
      - kind: unit
        ref: "backend/tests/SafePath.Application.Tests/Sos/SmsFanOutTests.cs#WhatsAppDeliveryStatusParser_ParsesADeliveredStatus"
        status: pass
      - kind: unit
        ref: "backend/tests/SafePath.Application.Tests/Sos/SmsFanOutTests.cs#WhatsAppDeliveryStatusParser_ParsesAReadStatusAsDelivered"
        status: pass
      - kind: unit
        ref: "backend/tests/SafePath.Application.Tests/Sos/SmsFanOutTests.cs#WhatsAppDeliveryStatusParser_ParsesAFailedStatusWithAnErrorCode"
        status: pass
      - kind: unit
        ref: "backend/tests/SafePath.Application.Tests/Sos/SmsFanOutTests.cs#WhatsAppDeliveryStatusParser_YieldsNoUpdateForASentStatus"
        status: pass
      - kind: unit
        ref: "backend/tests/SafePath.Application.Tests/Sos/SmsFanOutTests.cs#WhatsAppDeliveryStatusParser_ReturnsAnEmptyListForMalformedInput"
        status: pass
    human_judgment: false
  - id: D5
    description: "RecordSmsDeliveryStatusCommandHandler validates signature before any mutation, marks the matching SosDeliveryAttempt Delivered/Failed, ignores unknown provider message ids, and broadcasts DeliveryStatusChanged to the sender"
    requirement: "NOTIF-03"
    verification:
      - kind: unit
        ref: "backend/tests/SafePath.Application.Tests/Sos/SmsFanOutTests.cs#Webhook_MarksTheMatchingRowDeliveredOnADeliveredStatus"
        status: pass
      - kind: unit
        ref: "backend/tests/SafePath.Application.Tests/Sos/SmsFanOutTests.cs#Webhook_MarksTheMatchingRowFailedOnAFailedStatus"
        status: pass
      - kind: unit
        ref: "backend/tests/SafePath.Application.Tests/Sos/SmsFanOutTests.cs#Webhook_IgnoresAnUnknownProviderMessageId"
        status: pass
      - kind: unit
        ref: "backend/tests/SafePath.Application.Tests/Sos/SmsFanOutTests.cs#Webhook_RejectsAnInvalidSignature"
        status: pass
      - kind: unit
        ref: "backend/tests/SafePath.Application.Tests/Sos/SmsFanOutTests.cs#Webhook_BroadcastsTheStatusChangeToTheSender"
        status: pass
    human_judgment: false
  - id: D6
    description: "SosAlertDispatcher/TriggerSosCommandHandler behavior is provably unchanged (SOS-01) - only doc comments differ"
    verification:
      - kind: other
        ref: "git diff backend/src/SafePath.Application/Sos/SosAlertDispatcher.cs shows only comment-line changes; git diff on TriggerSosCommandHandler.cs is empty"
        status: pass
    human_judgment: false
  - id: D7
    description: "A real, live end-to-end WhatsApp send + delivery-status webhook round trip (populated backend/.env, ngrok-exposed webhook, one real SOS to a WhatsApp-enabled emergency contact)"
    human_judgment: true
    rationale: "Requires real operator credentials (access token, app secret, approved template) and a real WhatsApp-enabled recipient device; cannot be automated in this session. Deferred per the plan's <human-check> block - see 'User Setup Required' below."

duration: ~55min
completed: 2026-08-12
status: complete
---

# Quick Task 260812-wgl: Migrate SOS Fallback Channel from TextBee to WhatsApp Business Cloud API Summary

**SOS emergency-contact SMS fallback now sends WhatsApp Utility-template messages via the Meta Graph API, with a real HMAC-signed delivery-status webhook replacing TextBee's permanently-inert one.**

## Performance

- **Duration:** ~55 min
- **Completed:** 2026-08-12
- **Tasks:** 3
- **Files modified:** 20 (5 created, 15 modified/deleted across backend + docs)

## WhatsApp Cloud API Shapes Confirmed

**Executor-session gap, closed by the orchestrator post-execution.** WebFetch/WebSearch tools were
not available in the executor subagent's session, so the live Graph API contract could not be
re-verified against `developers.facebook.com/docs/whatsapp/cloud-api/...` at implementation time.
The orchestrator performed that verification afterward, with WebFetch/WebSearch against Meta's
live docs plus `developers.facebook.com/docs/graph-api/changelog` and
`developers.facebook.com/docs/graph-api/guides/versioning`:

- **Request/response/webhook shapes: confirmed correct as implemented.** The template-message
  request shape (`messaging_product`/`to`/`type`/`template.name`/`template.language.code`/
  `template.components[].parameters[].text`), the success-response `messages[0].id` path, the
  webhook payload nesting (`entry[].changes[].value.statuses[]`, each with `id`/`status`), and the
  `to` field taking E.164 digits with no leading `+` all match Meta's current documentation. No
  code change was needed for any of these.
- **Graph API version: was stale, now fixed.** The implementation had defaulted to `v22.0` (copied
  from the source todo, written 2026-08-10). Meta's changelog confirms the current stable version
  is **`v26.0`** (released 2026-07-29) — four versions newer. Each version stays callable for a
  minimum of two years after its *successor* ships (not after the latest version ships), so
  `v22.0` was very likely still functional, not a hard breakage — but it was not "current stable"
  as the plan required. Corrected the default in `WhatsAppOptions.ApiVersion`,
  `DependencyInjection.cs`'s `configuration["WhatsApp:ApiVersion"] ?? "..."` fallback, and the two
  hardcoded test values in `SmsFanOutTests.cs` from `v22.0` to `v26.0`. Rebuilt
  (`dotnet build backend/SafePath.sln`, 0 warnings/errors) and reran `SmsFanOutTests` (22/22 pass)
  after the change.

No other deviation from the plan's described shapes was found. The implementation is now verified
against Meta's live documentation as of 2026-08-12, not just standing knowledge. The operator's
first real send (see "User Setup Required" below) remains the final end-to-end confirmation, since
no automated check can exercise a real access token/template/recipient.

## Accomplishments

- `WhatsAppOptions`/`WhatsAppSmsGateway` send a Utility-category template message through the
  Cloud API, behind the unchanged `ISmsGateway` seam; `LoggingSmsGateway` remains the zero-cost
  default for a fresh clone (D-07)
- A genuine, HMAC-SHA256 (`X-Hub-Signature-256`) delivery-status webhook plus the GET
  `hub.mode`/`hub.verify_token`/`hub.challenge` subscription handshake are wired into the existing
  `SmsWebhookController`/`RecordSmsDeliveryStatusCommand` seam — the SMS channel can now genuinely
  reach `Delivered`, closing the observability gap that motivated the migration
  (TextBee had no delivery-status webhook at all)
- New `ISmsDeliveryStatusParser` Application seam + `WhatsAppDeliveryStatusParser` keep the
  provider's JSON payload shape out of the Application layer
- All `TextBee*` classes and references removed from `backend/src` and `backend/tests`
  (`TextBeeSmsGateway`, `TextBeeOptions`, `TextBeeWebhookSignatureValidator` deleted)
- `SosAlertDispatcher`/`TriggerSosCommandHandler` changed only in doc-comment prose — no control
  flow, ordering, or dependency changes (SOS-01 held, verified via `git diff`)
- `docs/EXTERNAL-SETUP.md` refreshed with a full "WhatsApp Business Platform Setup" section
  (System User token, Phone Number ID/WABA ID lookup, Utility template approval, webhook
  subscription, Authentication-template warning, recipient-side caveats)

## Task Commits

Each task was committed atomically:

1. **Task 1: WhatsApp send path behind the unchanged ISmsGateway seam** - `cd23241` (feat)
2. **Task 2: Signed delivery-status callback + subscription handshake** - `76103c8` (feat)
3. **Task 3: Zero-reference sweep, docs, and state** - `82e25f8` (docs, code/docs portion only)

_Note: `.planning/STATE.md` and the todo file move are left uncommitted per this execution's
constraints — the orchestrator commits `.planning/` docs artifacts separately._

## Files Created/Modified

- `backend/src/SafePath.Infrastructure/Sms/WhatsAppOptions.cs` - WhatsApp config binding + `IsConfigured` gate
- `backend/src/SafePath.Infrastructure/Sms/WhatsAppSmsGateway.cs` - `ISmsGateway` impl posting a template message
- `backend/src/SafePath.Infrastructure/Sms/WhatsAppWebhookSignatureValidator.cs` - raw-body HMAC-SHA256 validator + verify-token check
- `backend/src/SafePath.Infrastructure/Sms/WhatsAppDeliveryStatusParser.cs` - JSON status-payload parser
- `backend/src/SafePath.Application/Common/Interfaces/ISmsDeliveryStatusParser.cs` - new Application seam
- `backend/src/SafePath.Application/Common/Interfaces/ISmsGateway.cs` - doc comment only
- `backend/src/SafePath.Application/Common/Interfaces/ISmsWebhookSignatureValidator.cs` - rewritten contract (raw body + verify-token)
- `backend/src/SafePath.Application/Sos/RecordSmsDeliveryStatusCommand.cs` - rewritten command shape + handler
- `backend/src/SafePath.Infrastructure/DependencyInjection.cs` - WhatsApp DI registration
- `backend/src/SafePath.Infrastructure/Sms/LoggingSmsGateway.cs` - doc comment only
- `backend/src/SafePath.Api/Controllers/SmsWebhookController.cs` - raw-body POST + new GET handshake action
- `backend/tests/SafePath.Application.Tests/Sos/SmsFanOutTests.cs` - gateway/validator/parser/handler tests
- `backend/src/SafePath.Application/Sos/SosAlertDispatcher.cs` - doc comment only (SOS-01)
- `backend/src/SafePath.Application/Sos/SosLiveWindowOptions.cs` - doc comment only
- `backend/src/SafePath.Application/DependencyInjection.cs` - doc comment only
- `backend/src/SafePath.Infrastructure/Push/FirebaseOptions.cs` - doc comment only
- `docs/EXTERNAL-SETUP.md` - WhatsApp Business Platform Setup section, cost table, config keys, "Still Outstanding"
- `.planning/STATE.md` - blocker replaced, decision logged, quick-task row added (uncommitted, deferred to orchestrator)
- `.planning/todos/done/2026-08-10-evaluate-an-alternate-sms-provider-besides-textbee.md` - moved from pending with resolution note (uncommitted, deferred to orchestrator)

## Decisions Made

- Migrated the SOS emergency-contact SMS fallback from TextBee to the WhatsApp Business Cloud API,
  fully behind the unchanged `ISmsGateway` seam
- `RecordSmsDeliveryStatusCommand`/`ISmsWebhookSignatureValidator` moved from form-encoded
  (Twilio/TextBee-era) parameters to a raw-body shape, since the WhatsApp callback is JSON and its
  HMAC is computed over the exact bytes
- `WhatsAppOptions.IsConfigured` gates only on `AccessToken` + `PhoneNumberId` (send capability);
  `AppSecret`/`WebhookVerifyToken` gate the inbound webhook independently, so an operator who has
  configured sending but not yet the webhook can still send
- Pinned Graph API version default is `v26.0` (corrected post-execution after live-docs
  verification confirmed it as Meta's current stable version; the executor's session had used
  `v22.0` from the source todo, unable to re-check live docs)

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] WebFetch/WebSearch tools unavailable for live Meta docs confirmation**
- **Found during:** Task 1 (before writing `WhatsAppSmsGateway`)
- **Issue:** The plan's action explicitly requires confirming the live Graph API contract via
  WebFetch/WebSearch before implementing (current API version, exact request JSON keys, `to`
  format, success-response id path). Neither tool was available in the executor's session.
- **Fix:** Implemented from the already-confirmed shape recorded in the source todo plus standing
  knowledge of the stable, long-documented WhatsApp Cloud API contract, flagged clearly rather than
  silently proceeding as if the docs had been checked. The orchestrator then performed the deferred
  live-docs verification post-execution (WebFetch/WebSearch against Meta's live docs): the
  request/response/webhook shapes were confirmed correct as implemented, but the pinned Graph API
  version (`v22.0`) was four versions stale against the confirmed current stable `v26.0`. Corrected
  in `WhatsAppOptions.cs`, `DependencyInjection.cs`, and `SmsFanOutTests.cs`; rebuilt and reran
  `SmsFanOutTests` (22/22 pass) after the fix. See "WhatsApp Cloud API Shapes Confirmed" above for
  detail.
- **Files modified:** `WhatsAppSmsGateway.cs`, `WhatsAppDeliveryStatusParser.cs` (executor session);
  `WhatsAppOptions.cs`, `DependencyInjection.cs`, `SmsFanOutTests.cs` (orchestrator post-execution
  version fix)
- **Verification:** All gateway/parser/webhook unit tests pass; request/response/webhook shapes
  confirmed against Meta's live docs; API version corrected and reverified. Only the real
  end-to-end send with live credentials remains deferred to the operator (see "User Setup
  Required").
- **Committed in:** `cd23241` (Task 1), `76103c8` (Task 2), plus one orchestrator follow-up commit
  for the API version correction

---

**Total deviations:** 1 auto-fixed (tool unavailability during execution), fully closed out by a
post-execution live-docs verification pass that found and fixed one real staleness bug (API
version) and confirmed everything else matched.
**Impact on plan:** No scope change. The implemented shapes match Meta's live documentation as
verified. The API version fix is the only code change beyond the plan's original scope.

## Issues Encountered

None beyond the tool-availability deviation above. All three tasks' `dotnet build`/`dotnet test`
verification commands passed on the first attempt after implementation; no build breaks, no
flaky tests, no multi-attempt fix loops.

## User Setup Required

**External WhatsApp Business Platform configuration requires manual setup — code is complete but
unprovisioned.** Per the plan's `user_setup` block and the `<human-check>` deferred to a follow-up
session with live credentials:

1. Populate `backend/.env` with `WhatsApp__AccessToken`, `WhatsApp__PhoneNumberId`,
   `WhatsApp__WabaId`, `WhatsApp__AppSecret`, `WhatsApp__WebhookVerifyToken`,
   `WhatsApp__TemplateName` (see `docs/EXTERNAL-SETUP.md`, "WhatsApp Business Platform Setup").
   Restart the API and confirm the startup log names `WhatsAppSmsGateway`, not the logging
   fallback.
2. Expose the API over a public https origin (e.g. ngrok) and subscribe that origin +
   `/webhooks/sms/status` as the Meta webhook callback URL; confirm the GET handshake succeeds
   (Meta's dashboard accepts the URL) and that the WABA is subscribed to the `messages` field.
3. Trigger one real SOS with a WhatsApp-enabled emergency contact; confirm the template message
   arrives and that `GET /sos/{id}` shows the SMS-channel row progressing Queued -> Delivered.

Phone Number ID (`1190449597495068`) and WABA ID (`1605779661263531`) are already known per the
plan's `user_setup` block — no real secret value was committed anywhere in this session
(`git check-ignore -v backend/.env` confirmed gitignored; no staged `backend/.env`).

## Next Phase Readiness

- The SOS SMS fallback channel is code-complete and ready for operator provisioning; no further
  backend code changes are anticipated unless the live docs re-check in step 3 above surfaces a
  request-shape mismatch.
- Phase 04 (Geofencing) work is unaffected — this quick task touched only the SOS backend SMS
  channel and its documentation.

---
*Phase: quick-260812-wgl*
*Completed: 2026-08-12*

## Self-Check: PASSED

All created files verified present on disk (WhatsAppOptions.cs, WhatsAppSmsGateway.cs,
WhatsAppWebhookSignatureValidator.cs, WhatsAppDeliveryStatusParser.cs, ISmsDeliveryStatusParser.cs,
docs/EXTERNAL-SETUP.md, the moved todo file, this SUMMARY.md); TextBeeSmsGateway.cs confirmed
deleted. All three task commit hashes (cd23241, 76103c8, 82e25f8) confirmed present in `git log`.
