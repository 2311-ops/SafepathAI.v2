---
phase: quick-260810-vcf
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - backend/src/SafePath.Infrastructure/Sms/TextBeeSmsGateway.cs
  - backend/src/SafePath.Infrastructure/Sms/TextBeeOptions.cs
  - backend/src/SafePath.Infrastructure/Sms/TextBeeWebhookSignatureValidator.cs
  - backend/src/SafePath.Infrastructure/Sms/TwilioSmsGateway.cs
  - backend/src/SafePath.Infrastructure/Sms/TwilioOptions.cs
  - backend/src/SafePath.Infrastructure/Sms/TwilioWebhookSignatureValidator.cs
  - backend/src/SafePath.Infrastructure/DependencyInjection.cs
  - backend/src/SafePath.Infrastructure/SafePath.Infrastructure.csproj
  - backend/src/SafePath.Api/Controllers/SmsWebhookController.cs
  - backend/src/SafePath.Application/Common/Interfaces/ISmsGateway.cs
  - backend/src/SafePath.Application/Common/Interfaces/ISmsWebhookSignatureValidator.cs
  - backend/src/SafePath.Application/Sos/SosLiveWindowOptions.cs
  - backend/src/SafePath.Infrastructure/Push/FirebaseOptions.cs
  - backend/tests/SafePath.Application.Tests/Sos/SmsFanOutTests.cs
  - docs/EXTERNAL-SETUP.md
  - .planning/STATE.md
autonomous: true
requirements: [SOS-02, NOTIF-03]

must_haves:
  truths:
    - "A successfully-sent SMS through the configured gateway still records SosDeliveryAttempt.Status = Queued and a non-empty ProviderMessageId, exactly as it did under Twilio — SosAlertDispatcher's per-contact SMS fan-out (DispatchSms) is unaffected by the provider swap."
    - "No Twilio package reference, Twilio type, or Twilio configuration key remains anywhere in the backend source or docs."
    - "/webhooks/sms/status still exists, compiles, and structurally can never mark a row Delivered from a TextBee-originated send, because TextBeeWebhookSignatureValidator.IsValid always returns false — TextBee has no delivery-status callback to receive."
    - "A fresh clone with no TextBee credentials configured still runs the entire SOS pipeline for free via LoggingSmsGateway, unchanged from today's Twilio-absent behavior."
    - "dotnet test on SafePath.Application.Tests passes, including the updated/new SMS-channel tests."
    - "docs/EXTERNAL-SETUP.md and the relevant .planning/STATE.md blocker describe TextBee provisioning, not Twilio."
  artifacts:
    - path: "backend/src/SafePath.Infrastructure/Sms/TextBeeSmsGateway.cs"
      provides: "ISmsGateway implementation calling TextBee's send-sms REST API via IHttpClientFactory"
      contains: "ISmsGateway"
    - path: "backend/src/SafePath.Infrastructure/Sms/TextBeeOptions.cs"
      provides: "TextBee:ApiKey / TextBee:DeviceId / TextBee:BaseUrl configuration binding + IsConfigured gate"
      contains: "IsConfigured"
    - path: "backend/src/SafePath.Infrastructure/Sms/TextBeeWebhookSignatureValidator.cs"
      provides: "Documented always-false ISmsWebhookSignatureValidator implementation (TextBee has no webhook signature scheme)"
      contains: "ISmsWebhookSignatureValidator"
  key_links:
    - from: "SosAlertDispatcher.DispatchSms"
      to: "TextBeeSmsGateway.SendAsync"
      via: "ISmsGateway (unchanged interface, DI-resolved)"
      pattern: "ISmsGateway"
    - from: "Infrastructure/DependencyInjection.cs"
      to: "TextBeeSmsGateway vs LoggingSmsGateway"
      via: "TextBeeOptions.IsConfigured gate, same D-07 zero-cost-default shape as Twilio/Firebase"
      pattern: "IsConfigured"
    - from: "SmsWebhookController"
      to: "TextBeeWebhookSignatureValidator"
      via: "ISmsWebhookSignatureValidator.IsValid, unconditionally false"
      pattern: "IsValid"
---

<objective>
Migrate the emergency-contact SMS fallback channel (SOS-02/NOTIF-03) from Twilio to TextBee across the backend: a new `TextBeeSmsGateway` replaces `TwilioSmsGateway` behind the unchanged `ISmsGateway` seam, a new `TextBeeWebhookSignatureValidator` replaces `TwilioWebhookSignatureValidator` as a documented permanent no-op (TextBee has no delivery-status callback), and every Twilio reference — package, types, config keys, docs — is removed.

Purpose: Twilio SMS provisioning was never started (STATE.md "Blockers/Concerns"); the project is switching providers to TextBee (a free, self-hosted-Android-gateway SMS API) before provisioning happens. The SOS-01 non-negotiable is structural here too: this plan touches only the SMS delivery arm — `SosAlertDispatcher`'s SignalR/FCM channels, `TriggerSosCommandHandler`, and the SOS trigger fast path are never modified, so the swap cannot slow or block SOS delivery.

Output: `TextBeeSmsGateway`, `TextBeeOptions`, `TextBeeWebhookSignatureValidator` in `SafePath.Infrastructure/Sms`; Twilio's three files and its NuGet package removed; DI, the webhook controller, tests, and docs updated to match.

Explicit non-goals: no change to `ISmsGateway`'s or `ISmsWebhookSignatureValidator`'s member signatures (interface shape is locked); no change to `SosAlertDispatcher`'s call sites, `RecordSmsDeliveryStatusCommand`'s logic, or `SmsWebhookController`'s route/response shape (webhook infrastructure is kept in place structurally per product decision, even though no real TextBee callback will ever arrive); no new NuGet package (plain `HttpClient` + `System.Text.Json`, matching the existing `AddHttpClient<IProfileImageStorage, SupabaseProfileImageStorage>` typed-client convention already in `Infrastructure/DependencyInjection.cs`).
</objective>

<execution_context>
@$HOME/.claude/gsd-core/workflows/execute-plan.md
@$HOME/.claude/gsd-core/templates/summary.md
</execution_context>

<context>
@.planning/STATE.md
@.claude/CLAUDE.md
@backend/src/SafePath.Application/Common/Interfaces/ISmsGateway.cs
@backend/src/SafePath.Application/Sos/SosAlertDispatcher.cs
</context>

<facts_verified_this_session>
These were read from the repository during planning. Treat them as ground truth; do not re-derive or contradict them.

| Fact | Source |
|------|--------|
| `ISmsGateway.SendAsync(toE164, body, ct)` returns `SmsSendResult(string ProviderMessageId)` — single-recipient, non-nullable id | `backend/src/SafePath.Application/Common/Interfaces/ISmsGateway.cs` |
| `SosAlertDispatcher.DispatchSms` calls `_smsGateway.SendAsync` once per emergency contact, then unconditionally sets `attempt.Status = SosDeliveryStatus.Queued` and `attempt.ProviderMessageId = result.ProviderMessageId` on success, or `Failed` per-contact on a caught exception — this method is not touched by this plan | `backend/src/SafePath.Application/Sos/SosAlertDispatcher.cs` lines 189-235 |
| `SosDeliveryStatus` enum is exactly `NotAttempted, Queued, Delivered, Acknowledged, Failed` — no "Unverified" value exists or is being added; "unverified" (sent-but-unconfirmed) is the existing `Queued` state, which a TextBee-sent row now simply never leaves | `backend/src/SafePath.Domain/Enums/SosDeliveryStatus.cs` |
| `SosDeliveryAttempt.ProviderMessageId` is `HasMaxLength(128)` — a synthetic `textbee-{Guid:N}` fallback id (40 chars) fits comfortably | `backend/src/SafePath.Infrastructure/Persistence/EntityConfigurations/SosDeliveryAttemptConfiguration.cs` |
| `RecordSmsDeliveryStatusCommand`/Handler and `SmsWebhookController` are explicitly kept per product decision — only their Twilio-specific coupling (the `TwilioOptions` field/param in the controller) needs removal to keep compiling | `backend/src/SafePath.Application/Sos/RecordSmsDeliveryStatusCommand.cs`, `backend/src/SafePath.Api/Controllers/SmsWebhookController.cs` |
| The typed-client HttpClient DI pattern already exists in this file: `services.AddHttpClient<IProfileImageStorage, SupabaseProfileImageStorage>(...)`, and `SupabaseProfileImageStorage(HttpClient httpClient, IConfiguration configuration)` takes `HttpClient` as its first constructor parameter, with other services resolved from DI normally | `backend/src/SafePath.Infrastructure/DependencyInjection.cs`, `backend/src/SafePath.Infrastructure/Storage/SupabaseProfileImageStorage.cs` |
| No Twilio config keys exist in `appsettings.json`/`appsettings.Development.json` today — the app already runs on `LoggingSmsGateway` (confirmed in STATE.md and by grep) | `.planning/STATE.md` "Blockers/Concerns" |
| `backend/.env.example` could not be read (tool permission denies `.env*` files) — if it contains a Twilio section, it is out of scope for this plan; flag it in the SUMMARY as an unverified follow-up rather than guessing its contents | tool permission error during planning |
| `SafePath.Infrastructure.csproj` targets `net9.0`, references `Microsoft.AspNetCore.App` via `FrameworkReference` and `Microsoft.Extensions.Http` — `System.Net.Http.Json.JsonContent` and `System.Text.Json` are available with no new package | `backend/src/SafePath.Infrastructure/SafePath.Infrastructure.csproj` |
| `dotnet test backend/tests/SafePath.Application.Tests --filter FullyQualifiedName~Sos.SmsFanOutTests` and `dotnet test backend/SafePath.sln` are the established verification commands for this test class | `.planning/phases/03-sos-fast-path/03-0{1,3}-PLAN.md` |
| `SmsFanOutTests.cs` already references `SafePath.Infrastructure.Sms.LoggingSmsGateway` by fully-qualified name inline (no `using SafePath.Infrastructure.Sms;`) — the new tests should follow the same inline-qualified style | `backend/tests/SafePath.Application.Tests/Sos/SmsFanOutTests.cs` line 167-168 |
| TextBee's send API: `POST https://api.textbee.dev/api/v1/gateway/devices/{deviceId}/send-sms`, header `x-api-key: <API_KEY>`, JSON body `{ "recipients": [...], "message": "..." }`. The exact success-response JSON shape is not independently verified this session (no research phase run, per task constraints) — the implementation below parses it defensively and never fails a send over an unexpected response shape | task instructions (planner's own knowledge, explicitly authorized in lieu of research for this small integration surface) |

**Naming decision:** configuration keys are `TextBee:ApiKey`, `TextBee:DeviceId`, `TextBee:BaseUrl` (env var form `TextBee__ApiKey` etc.), mirroring the existing `Twilio:AccountSid`/`Firebase:ProjectId` double-underscore-to-colon convention in `docs/CONFIGURATION.md`.
</facts_verified_this_session>

<tasks>

<task type="auto">
  <name>Task 1: Build the TextBee gateway, options, and webhook validator</name>
  <files>backend/src/SafePath.Infrastructure/Sms/TextBeeSmsGateway.cs, backend/src/SafePath.Infrastructure/Sms/TextBeeOptions.cs, backend/src/SafePath.Infrastructure/Sms/TextBeeWebhookSignatureValidator.cs, backend/src/SafePath.Application/Common/Interfaces/ISmsGateway.cs, backend/src/SafePath.Application/Common/Interfaces/ISmsWebhookSignatureValidator.cs</files>
  <read_first>
    - backend/src/SafePath.Infrastructure/Sms/TwilioSmsGateway.cs (the try/catch-and-translate pattern to mirror: log the full exception server-side only via ILogger, then throw a generic credential-free InvalidOperationException — never let the raw HTTP exception message reach the dispatcher's FailureReason column)
    - backend/src/SafePath.Infrastructure/Sms/TwilioOptions.cs (the IsConfigured gate shape to mirror)
    - backend/src/SafePath.Infrastructure/Sms/LoggingSmsGateway.cs (the synthetic-id fallback pattern: `$"logging-{Guid.NewGuid():N}"`)
    - backend/src/SafePath.Infrastructure/Storage/SupabaseProfileImageStorage.cs (the typed-HttpClient constructor shape: `HttpClient` as the first constructor parameter, resolved by `AddHttpClient<TInterface, TImpl>`, with other dependencies resolved from DI normally)
  </read_first>
  <action>
Create `backend/src/SafePath.Infrastructure/Sms/TextBeeOptions.cs`. A plain class with `string? ApiKey`, `string? DeviceId`, and `string BaseUrl { get; set; } = "https://api.textbee.dev";`, plus `bool IsConfigured => !string.IsNullOrWhiteSpace(ApiKey) && !string.IsNullOrWhiteSpace(DeviceId);` (BaseUrl is never part of the gate — it always has a usable default). XML doc comment: binds `TextBee:ApiKey`, `TextBee:DeviceId`, `TextBee:BaseUrl` from configuration, never committed; `IsConfigured` gates which `ISmsGateway` implementation is registered exactly like `TwilioOptions.IsConfigured` did (D-07 zero-cost-default shape) — `LoggingSmsGateway` whenever either required value is missing.

Create `backend/src/SafePath.Infrastructure/Sms/TextBeeSmsGateway.cs` implementing `ISmsGateway`. Constructor takes `HttpClient httpClient, TextBeeOptions options, ILogger<TextBeeSmsGateway> logger` (typed-client pattern — `httpClient.BaseAddress` is configured by the DI registration added in Task 2, not by this class). `SendAsync(string toE164, string body, CancellationToken cancellationToken = default)`: build a relative request URI `api/v1/gateway/devices/{options.DeviceId}/send-sms` (no leading slash, so it resolves relative to `httpClient.BaseAddress`); construct a `HttpRequestMessage(HttpMethod.Post, requestUri)`; add the header via `request.Headers.TryAddWithoutValidation("x-api-key", options.ApiKey)`; set `request.Content` via `System.Net.Http.Json.JsonContent.Create` from a private/internal `record TextBeeSendSmsRequest([property: JsonPropertyName("recipients")] IReadOnlyList<string> Recipients, [property: JsonPropertyName("message")] string Message)`, passing `new[] { toE164 }` and `body`. Send with `await _httpClient.SendAsync(request, cancellationToken)`, call `response.EnsureSuccessStatusCode()` inside the try block so a non-2xx status throws and is caught by the same try/catch-and-translate pattern `TwilioSmsGateway` uses (`catch (Exception ex) when (ex is not OperationCanceledException)`: `_logger.LogError(ex, "TextBeeSmsGateway failed to send an SMS.")`, then `throw new InvalidOperationException("Failed to send SMS via the configured provider.", ex);`). On success, extract a provider message id defensively: parse the response body as `JsonDocument`, and if it has a `data` object property containing a string property named `_id`, `id`, `smsId`, or `messageId` (checked in that order), use its value; otherwise (or on any `JsonException` while parsing) fall back to a synthetic `$"textbee-{Guid.NewGuid():N}"` id, matching `LoggingSmsGateway`'s synthetic-id convention — TextBee's exact response schema is not verified this session and a send must never fail purely because the response shape did not match expectations. Return `new SmsSendResult(providerMessageId)`.

Add an XML doc comment on `TextBeeSmsGateway` explaining: a successful return means only that TextBee's gateway device accepted the message for sending, never that it was delivered; `SosAlertDispatcher` records this as `Queued` exactly as it did for Twilio (D-10, unchanged); because `TextBeeWebhookSignatureValidator` (added below) never validates any inbound callback, a TextBee-sent row stays at `Queued` — honestly "sent, unconfirmed" — forever, rather than ever progressing to `Delivered`. This is the deliberate migration design, not a regression.

Create `backend/src/SafePath.Infrastructure/Sms/TextBeeWebhookSignatureValidator.cs` implementing `ISmsWebhookSignatureValidator`. `IsValid(string requestUrl, IReadOnlyDictionary<string, string> formParameters, string? signatureHeader) => false;` unconditionally — no field, no branching. XML doc comment: TextBee has no delivery-status webhook/callback mechanism and therefore no signature scheme to validate (unlike Twilio's `X-Twilio-Signature`/`RequestValidator`); this is a permanent, documented no-op — `/webhooks/sms/status` structurally refuses every request forever, including any forged one, exactly the same refuse-by-default posture `TwilioWebhookSignatureValidator` already had whenever no auth token was configured (threat T-03-19 stays closed by construction, not by configuration).

Update the XML doc comments (only — do not touch member signatures, which are locked) on `backend/src/SafePath.Application/Common/Interfaces/ISmsGateway.cs` and `backend/src/SafePath.Application/Common/Interfaces/ISmsWebhookSignatureValidator.cs`: replace every reference to `TwilioSmsGateway`/`TwilioWebhookSignatureValidator` as the example Infrastructure implementation with `TextBeeSmsGateway`/`TextBeeWebhookSignatureValidator`, and "Twilio (or any provider)" phrasing with "TextBee (or any provider)".
  </action>
  <verify>
    <automated>cd backend &amp;&amp; dotnet build SafePath.sln 2>&amp;1 | tail -n 30</automated>
  </verify>
  <done>TextBeeSmsGateway, TextBeeOptions, and TextBeeWebhookSignatureValidator exist, implement ISmsGateway/ISmsWebhookSignatureValidator without altering either interface's members, and the solution still builds (Task 2 wires them in and removes Twilio, so a pre-existing Twilio reference elsewhere is expected to still compile at this point).</done>
</task>

<task type="auto">
  <name>Task 2: Remove Twilio and wire TextBee into DI, the csproj, and the webhook controller</name>
  <files>backend/src/SafePath.Infrastructure/Sms/TwilioSmsGateway.cs, backend/src/SafePath.Infrastructure/Sms/TwilioOptions.cs, backend/src/SafePath.Infrastructure/Sms/TwilioWebhookSignatureValidator.cs, backend/src/SafePath.Infrastructure/DependencyInjection.cs, backend/src/SafePath.Infrastructure/SafePath.Infrastructure.csproj, backend/src/SafePath.Api/Controllers/SmsWebhookController.cs, backend/src/SafePath.Application/Sos/SosLiveWindowOptions.cs, backend/src/SafePath.Infrastructure/Push/FirebaseOptions.cs</files>
  <read_first>
    - backend/src/SafePath.Infrastructure/DependencyInjection.cs (the exact Twilio block to replace: `using Twilio.Clients;` at the top; the `twilioOptions` construction, bootstrap-logger block, and conditional `ITwilioRestClient`/`TwilioSmsGateway`/`LoggingSmsGateway` registration; the trailing `services.AddScoped&lt;ISmsWebhookSignatureValidator, TwilioWebhookSignatureValidator&gt;();` line)
    - backend/src/SafePath.Api/Controllers/SmsWebhookController.cs (the `TwilioOptions _twilioOptions` field/constructor param and the `BuildValidatedUrl()` method that reads it)
  </read_first>
  <action>
Delete `backend/src/SafePath.Infrastructure/Sms/TwilioSmsGateway.cs`, `backend/src/SafePath.Infrastructure/Sms/TwilioOptions.cs`, and `backend/src/SafePath.Infrastructure/Sms/TwilioWebhookSignatureValidator.cs`.

In `backend/src/SafePath.Infrastructure/SafePath.Infrastructure.csproj`, remove the `<PackageReference Include="Twilio" Version="7.14.9" />` line. No replacement package reference is added (plain `HttpClient`).

In `backend/src/SafePath.Infrastructure/DependencyInjection.cs`, remove the `using Twilio.Clients;` line. Replace the Twilio options-construction-through-registration block with a TextBee equivalent: construct `var textBeeOptions = new TextBeeOptions { ApiKey = configuration["TextBee:ApiKey"], DeviceId = configuration["TextBee:DeviceId"], BaseUrl = configuration["TextBee:BaseUrl"] ?? "https://api.textbee.dev" };` then `services.AddSingleton(textBeeOptions);`. Keep the same bootstrap-logger-block pattern immediately after (a throwaway `LoggerFactory.Create` since the container is not built yet), logging `"SMS gateway active: TextBeeSmsGateway (TextBee credentials configured)."` when `textBeeOptions.IsConfigured`, else `"SMS gateway active: LoggingSmsGateway (no TextBee credentials configured — SMS sends are logged only, never sent)."`. Then: `if (textBeeOptions.IsConfigured) { services.AddHttpClient<ISmsGateway, TextBeeSmsGateway>(client => client.BaseAddress = new Uri(textBeeOptions.BaseUrl.TrimEnd('/') + "/")); } else { services.AddScoped<ISmsGateway, LoggingSmsGateway>(); }` — this is the same typed-client shape as the existing `AddHttpClient<IProfileImageStorage, SupabaseProfileImageStorage>` registration already in this file; do not add a separate `ITwilioRestClient`-style singleton, TextBee needs none. Change the final `services.AddScoped<ISmsWebhookSignatureValidator, TwilioWebhookSignatureValidator>();` line to `services.AddScoped<ISmsWebhookSignatureValidator, TextBeeWebhookSignatureValidator>();`.

In `backend/src/SafePath.Api/Controllers/SmsWebhookController.cs`, remove the `using SafePath.Infrastructure.Sms;` import and the `TwilioOptions _twilioOptions` field and constructor parameter, keeping only the `ICommandHandler<RecordSmsDeliveryStatusCommand, RecordSmsDeliveryStatusResult> _record` dependency. Delete the `BuildValidatedUrl()` private method entirely, and in `Status(...)` replace its call site (`var url = BuildValidatedUrl();`) with the request-derived URL built inline: `var url = $"{Request.Scheme}://{Request.Host}{Request.Path}{Request.QueryString}";` — the provider-specific public-URL-preference logic `BuildValidatedUrl()` existed for is now moot, since `ISmsWebhookSignatureValidator.IsValid` returns false unconditionally regardless of the URL passed to it. Update the class's XML doc comment to describe the route as TextBee's (or any configured provider's) delivery-status callback, kept in place structurally though no real TextBee callback will ever arrive, with authenticity enforced by delegating to `ISmsWebhookSignatureValidator` (now `TextBeeWebhookSignatureValidator`, permanently false) rather than by recomputing a Twilio-specific signature. Leave the rest of the `Status` action, the route attribute, and the no-rate-limit rationale comment unchanged.

In `backend/src/SafePath.Application/Sos/SosLiveWindowOptions.cs` and `backend/src/SafePath.Infrastructure/Push/FirebaseOptions.cs`, update the one XML doc comment reference in each that names `TwilioOptions` as a sibling-pattern example, to name `TextBeeOptions` instead — mechanical rename only, no logic change in either file.
  </action>
  <verify>
    <automated>cd backend &amp;&amp; dotnet build SafePath.sln 2>&amp;1 | tail -n 30</automated>
  </verify>
  <done>The solution builds with zero Twilio references anywhere (`grep -ric twilio backend/src` returns 0), TextBee is the sole ISmsGateway/ISmsWebhookSignatureValidator implementation registered when configured, LoggingSmsGateway remains the zero-cost default, and SmsWebhookController compiles with no TwilioOptions dependency.</done>
</task>

<task type="auto">
  <name>Task 3: Update tests, docs, and STATE.md; run backend tests</name>
  <files>backend/tests/SafePath.Application.Tests/Sos/SmsFanOutTests.cs, docs/EXTERNAL-SETUP.md, .planning/STATE.md</files>
  <read_first>
    - backend/tests/SafePath.Application.Tests/Sos/SmsFanOutTests.cs (the `FakeSignatureValidator` class and its doc comment; the `LoggingGateway_ReturnsASyntheticIdAndSendsNothing` test's inline-fully-qualified-name style to mirror for the two new tests)
    - docs/EXTERNAL-SETUP.md (the "Prerequisites and Costs" table, "Backend Configuration Keys" section, and "Still Outstanding" table — the three places naming Twilio)
    - .planning/STATE.md "Blockers/Concerns" section (the single `[2026-08-05] Twilio SMS provisioning...` paragraph to update; leave every entry under "Decisions" untouched — those are an accurate historical record, not something to retcon)
  </read_first>
  <action>
In `backend/tests/SafePath.Application.Tests/Sos/SmsFanOutTests.cs`: update `FakeSignatureValidator`'s XML doc comment — it currently says the real `TwilioWebhookSignatureValidator` wraps Twilio's own SDK-tested crypto; replace with: the real `TextBeeWebhookSignatureValidator` is a permanent no-op that always returns false, so `FakeSignatureValidator` exists specifically to let these tests exercise `RecordSmsDeliveryStatusCommandHandler`'s own Delivered/Failed/ignore branching under both a valid and an invalid signature outcome — something the real always-false validator alone could never produce. Do not change any of the six existing `Webhook_*` test method bodies or assertions (`Webhook_MarksTheMatchingRowDeliveredOnADeliveredStatus`, `Webhook_MarksTheMatchingRowFailedOnAFailedStatus`, `Webhook_IgnoresAnUnknownProviderMessageId`, `Webhook_RejectsAnInvalidSignature`, `Webhook_BroadcastsTheStatusChangeToTheSender`, and the SMS-dispatch tests) — they cover `RecordSmsDeliveryStatusCommandHandler`'s own logic, which this migration intentionally leaves unchanged per the product decision to keep the webhook infrastructure in place structurally.

Add a new `[Fact]` test method verifying `TextBeeWebhookSignatureValidator`'s always-false behavior: construct `new SafePath.Infrastructure.Sms.TextBeeWebhookSignatureValidator()` inline by fully-qualified name (matching the existing `SafePath.Infrastructure.Sms.LoggingSmsGateway` inline-qualified style a few lines above in this same file — no new `using` needed), and assert `IsValid(...)` returns `false` for at least two distinct input shapes: a plausible well-formed url/params/non-null-signature tuple, and a `null` signature header — proving the "always unverified" behavior is unconditional, not merely a stand-in for missing configuration.

Add a second new `[Fact]` test method verifying `TextBeeSmsGateway`'s HTTP request shape: define a small private `HttpMessageHandler` subclass local to this test (or the test class) that overrides `SendAsync`, captures the incoming `HttpRequestMessage`, and returns a canned `HttpResponseMessage` with status 200 and a minimal JSON success body (e.g. `{"success":true,"data":{"_id":"abc123"}}`); construct `new SafePath.Infrastructure.Sms.TextBeeSmsGateway(new HttpClient(fakeHandler) { BaseAddress = new Uri("https://api.textbee.dev/") }, new SafePath.Infrastructure.Sms.TextBeeOptions { ApiKey = "test-key", DeviceId = "test-device" }, Microsoft.Extensions.Logging.Abstractions.NullLogger<SafePath.Infrastructure.Sms.TextBeeSmsGateway>.Instance)`; call `SendAsync("+12025550182", "test body")`; assert the captured request's `Method` is `HttpMethod.Post`, its `RequestUri`'s path contains `"test-device"` and ends with `"/send-sms"`, its headers contain `x-api-key` equal to `"test-key"`, and the returned `SmsSendResult.ProviderMessageId` equals `"abc123"` (proving the defensive JSON-id extraction works for a well-formed response, complementing `LoggingGateway_ReturnsASyntheticIdAndSendsNothing`'s coverage of the zero-cost fallback gateway).

In `docs/EXTERNAL-SETUP.md`: in the "Prerequisites and Costs" table, replace the `Twilio account | Free trial, then paid | Real SMS delivery (see "Still outstanding")` row with a TextBee row (free — a self-hosted Android-app SMS gateway, no per-message cost beyond the phone's own SMS plan). Update the intro paragraph's "...Firebase or Twilio credentials are absent..." to name TextBee instead of Twilio. In "Backend Configuration Keys", replace the four `Twilio__*` table rows with `TextBee__ApiKey` (from the TextBee dashboard, after registering a gateway device), `TextBee__DeviceId` (the registered device's id, same dashboard), and `TextBee__BaseUrl` (optional; defaults to `https://api.textbee.dev` when unset). Update the "Observable success signal" paragraph's "...separately logs 'SMS gateway active: TwilioSmsGateway (Twilio credentials configured)'..." sentence to name `TextBeeSmsGateway`/TextBee credentials. Add a new "TextBee Device Registration" section (placed directly after "Backend Configuration Keys") with numbered steps: install the TextBee companion Android app (from textbee.dev) on the phone that will act as the SMS gateway; create/sign in to a TextBee account; register that device as a gateway from the TextBee dashboard; copy the generated API key and the device's id from the dashboard and set `TextBee__ApiKey`/`TextBee__DeviceId` accordingly. State plainly that the phone must stay powered on, network-connected, and running the TextBee app for sends to succeed, and that TextBee has no delivery-status webhook — every SMS sent through it will show as Queued (sent, unconfirmed) forever by design, never Delivered, unlike the old Twilio-backed flow. In "Still Outstanding", replace the `Twilio account and phone number provisioning...` row with a `TextBee device provisioning...` row (same column shape: why it is needed / when it becomes blocking / status `Outstanding (code-complete, unprovisioned)`).

In `.planning/STATE.md`, edit only the single `[2026-08-05] Twilio SMS provisioning (03-05's emergency-contact channel) is not started...` paragraph under "Blockers/Concerns": rewrite it to describe the TextBee equivalent — the code side is complete (`ISmsGateway`/`TextBeeSmsGateway`/`LoggingSmsGateway` seam, E.164 normalization, the SMS arm of `SosAlertDispatcher`), but no `TextBee:ApiKey`/`TextBee:DeviceId` are configured anywhere yet, so the backend still runs on `LoggingSmsGateway`; state that once provisioned, delivery status will permanently read `Queued` (sent, unconfirmed) rather than ever reaching `Delivered`, since TextBee has no delivery-status webhook (unlike the superseded Twilio design) — this is the intended behavior of this migration, not an outstanding gap. Do not edit any entry under "Decisions" or the "Carried forward from research" list — those are an accurate historical record of what was decided at the time and must not be rewritten to imply TextBee was the original choice.

Run the test verification below. If `backend/.env.example` is readable in this execution environment (unlike during planning, where it was permission-denied), check it for a Twilio section and rename any keys found there to the `TextBee__*` names above; if it remains unreadable, note that explicitly in the SUMMARY as an unverified follow-up rather than guessing its contents.
  </action>
  <verify>
    <automated>cd backend &amp;&amp; dotnet test tests/SafePath.Application.Tests --filter FullyQualifiedName~Sos.SmsFanOutTests 2>&amp;1 | tail -n 20 &amp;&amp; dotnet test SafePath.sln 2>&amp;1 | tail -n 30</automated>
  </verify>
  <done>SmsFanOutTests.cs has zero remaining Twilio references, includes passing tests proving TextBeeWebhookSignatureValidator is unconditionally false and TextBeeSmsGateway builds the expected TextBee request/response shape, `dotnet test backend/tests/SafePath.Application.Tests --filter FullyQualifiedName~Sos.SmsFanOutTests` is green, `dotnet test backend/SafePath.sln` is green (no regression elsewhere), docs/EXTERNAL-SETUP.md and the STATE.md blocker describe TextBee provisioning instead of Twilio, and the historical STATE.md Decisions log is untouched.</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| Backend -> TextBee cloud API | Outbound HTTPS call carrying an emergency contact's E.164 phone number, an SOS message body (sender name + optional location link), and the TextBee API key. |
| Internet -> `/webhooks/sms/status` | Unauthenticated inbound endpoint; previously validated a Twilio-signed callback, now structurally refuses every request since TextBee has no legitimate caller for this route at all. |

## STRIDE Threat Register

| Threat ID | Category | Component | Severity | Disposition | Mitigation Plan |
|-----------|----------|-----------|----------|-------------|-----------------|
| T-VCF-01 | Information Disclosure | `TextBeeOptions.ApiKey` | high | mitigate | Loaded from configuration/environment only, never committed (same posture as the superseded `TwilioOptions`, T-03-08 precedent); sent only via the `x-api-key` request header over HTTPS to `api.textbee.dev`, never logged. |
| T-VCF-02 | Spoofing | `/webhooks/sms/status` | medium | mitigate | `TextBeeWebhookSignatureValidator.IsValid` always returns `false`, so `RecordSmsDeliveryStatusCommandHandler` refuses every request unconditionally — a forged POST can never mark an `SosDeliveryAttempt` row `Delivered` (T-03-19 stays closed by construction, not by configuration, now permanently rather than only when unconfigured). |
| T-VCF-03 | Information Disclosure | `TextBeeSmsGateway` failure logs | low | accept | On failure, only the exception is logged server-side (`_logger.LogError`, no phone number or message body in the log line) before translating to a generic credential-free exception — unchanged from `TwilioSmsGateway`'s existing accepted posture. |
| T-VCF-04 | Tampering | dead webhook endpoint kept alive | low | accept | `/webhooks/sms/status` remains reachable but inert (validator always false) per the explicit product decision not to restructure `SmsWebhookController`/`RecordSmsDeliveryStatusCommand`; the only residual risk is unreachable code, not exploitable behavior, since no request — forged or genuine — can ever mutate state through it. |
</threat_model>

<verification>
1. `cd backend && dotnet build SafePath.sln` succeeds with zero warnings about missing Twilio types.
2. `grep -ric twilio backend/src backend/tests` returns 0.
3. `dotnet test backend/tests/SafePath.Application.Tests --filter FullyQualifiedName~Sos.SmsFanOutTests` — all tests pass, including the two new TextBee-specific tests.
4. `dotnet test backend/SafePath.sln` is green (no regression in any other suite).
5. Manual read-through: `SosAlertDispatcher.cs` and `TriggerSosCommandHandler.cs` are byte-for-byte unchanged (confirm via `git diff --stat` showing neither file listed) — the SOS fast path is untouched.
</verification>

<success_criteria>
- `TextBeeSmsGateway` is the sole live `ISmsGateway` implementation when `TextBee:ApiKey`/`TextBee:DeviceId` are configured; `LoggingSmsGateway` remains the free zero-config default.
- `TextBeeWebhookSignatureValidator` always returns `false`, proven by a direct unit test, so no forged or genuine TextBee callback can ever move a delivery-attempt row to `Delivered`.
- Zero Twilio references remain in backend source, tests, the csproj, or `docs/EXTERNAL-SETUP.md`.
- `docs/EXTERNAL-SETUP.md` documents how to register a TextBee gateway device and the exact `TextBee__*` configuration keys the shipped code reads.
- `.planning/STATE.md`'s SMS-provisioning blocker describes TextBee, not Twilio, while its historical Decisions log is untouched.
- `dotnet test` is green for `SafePath.Application.Tests` at minimum, and for the full `SafePath.sln` solution.
- `SosAlertDispatcher`, `TriggerSosCommandHandler`, and every other SOS fast-path file are unmodified — the SOS-01 non-negotiable holds.
</success_criteria>

<output>
Create `.planning/quick/260810-vcf-migrate-sms-gateway-from-twilio-to-textb/260810-vcf-SUMMARY.md` when done.
</output>
