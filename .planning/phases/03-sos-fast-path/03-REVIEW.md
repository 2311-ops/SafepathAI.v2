---
phase: 03-sos-fast-path
reviewed: 2026-08-08T00:00:00Z
depth: standard
files_reviewed: 110
files_reviewed_list:
  - backend/src/SafePath.Api/Controllers/DeviceTokensController.cs
  - backend/src/SafePath.Api/Controllers/EmergencyContactsController.cs
  - backend/src/SafePath.Api/Controllers/SmsWebhookController.cs
  - backend/src/SafePath.Api/Controllers/SosController.cs
  - backend/src/SafePath.Api/Program.cs
  - backend/src/SafePath.Application/Common/Interfaces/IAlertBroadcastService.cs
  - backend/src/SafePath.Application/Common/Interfaces/IApplicationDbContext.cs
  - backend/src/SafePath.Application/Common/Interfaces/IPushSender.cs
  - backend/src/SafePath.Application/Common/Interfaces/ISmsGateway.cs
  - backend/src/SafePath.Application/Common/Interfaces/ISmsWebhookSignatureValidator.cs
  - backend/src/SafePath.Application/Common/Interfaces/ISosAlertDispatcher.cs
  - backend/src/SafePath.Application/DependencyInjection.cs
  - backend/src/SafePath.Application/SafePath.Application.csproj
  - backend/src/SafePath.Application/Sos/AcknowledgeSosCommand.cs
  - backend/src/SafePath.Application/Sos/CancelSosCommand.cs
  - backend/src/SafePath.Application/Sos/DeviceTokenCommands.cs
  - backend/src/SafePath.Application/Sos/EmergencyContactCommands.cs
  - backend/src/SafePath.Application/Sos/GetSosSessionQuery.cs
  - backend/src/SafePath.Application/Sos/PhoneNumberNormalizer.cs
  - backend/src/SafePath.Application/Sos/RecordSmsDeliveryStatusCommand.cs
  - backend/src/SafePath.Application/Sos/ReportSosLocationCommand.cs
  - backend/src/SafePath.Application/Sos/SosAlertDispatcher.cs
  - backend/src/SafePath.Application/Sos/SosDtos.cs
  - backend/src/SafePath.Application/Sos/SosLiveWindowOptions.cs
  - backend/src/SafePath.Application/Sos/SosSessionProjection.cs
  - backend/src/SafePath.Application/Sos/TriggerSosCommand.cs
  - backend/src/SafePath.Domain/Entities/EmergencyContact.cs
  - backend/src/SafePath.Domain/Entities/SosDeliveryAttempt.cs
  - backend/src/SafePath.Domain/Entities/SosSession.cs
  - backend/src/SafePath.Domain/Entities/UserDeviceToken.cs
  - backend/src/SafePath.Domain/Enums/AlertChannel.cs
  - backend/src/SafePath.Domain/Enums/DevicePlatform.cs
  - backend/src/SafePath.Domain/Enums/SosDeliveryStatus.cs
  - backend/src/SafePath.Domain/Enums/SosKind.cs
  - backend/src/SafePath.Domain/Enums/SosSessionStatus.cs
  - backend/src/SafePath.Infrastructure/DependencyInjection.cs
  - backend/src/SafePath.Infrastructure/Persistence/ApplicationDbContext.cs
  - backend/src/SafePath.Infrastructure/Persistence/EntityConfigurations/EmergencyContactConfiguration.cs
  - backend/src/SafePath.Infrastructure/Persistence/EntityConfigurations/SosDeliveryAttemptConfiguration.cs
  - backend/src/SafePath.Infrastructure/Persistence/EntityConfigurations/SosSessionConfiguration.cs
  - backend/src/SafePath.Infrastructure/Persistence/EntityConfigurations/UserDeviceTokenConfiguration.cs
  - backend/src/SafePath.Infrastructure/Persistence/Migrations/20260801200953_AddSosFastPath.cs
  - backend/src/SafePath.Infrastructure/Push/FirebaseOptions.cs
  - backend/src/SafePath.Infrastructure/Push/FirebasePushSender.cs
  - backend/src/SafePath.Infrastructure/Push/LoggingPushSender.cs
  - backend/src/SafePath.Infrastructure/RealTime/AlertBroadcastService.cs
  - backend/src/SafePath.Infrastructure/RealTime/AlertHub.cs
  - backend/src/SafePath.Infrastructure/RealTime/IAlertClient.cs
  - backend/src/SafePath.Infrastructure/SafePath.Infrastructure.csproj
  - backend/src/SafePath.Infrastructure/Sms/LoggingSmsGateway.cs
  - backend/src/SafePath.Infrastructure/Sms/TwilioOptions.cs
  - backend/src/SafePath.Infrastructure/Sms/TwilioSmsGateway.cs
  - backend/src/SafePath.Infrastructure/Sms/TwilioWebhookSignatureValidator.cs
  - backend/tests/SafePath.Api.IntegrationTests/AlertHubSmokeTests.cs
  - backend/tests/SafePath.Api.IntegrationTests/SosControllerTests.cs
  - backend/tests/SafePath.Application.Tests/Sos/AlertFanOutTests.cs
  - backend/tests/SafePath.Application.Tests/Sos/CancelSosCommandTests.cs
  - backend/tests/SafePath.Application.Tests/Sos/EmergencyContactCommandTests.cs
  - backend/tests/SafePath.Application.Tests/Sos/SmsFanOutTests.cs
  - backend/tests/SafePath.Application.Tests/Sos/SosLiveWindowTests.cs
  - backend/tests/SafePath.Application.Tests/Sos/SosSchemaTests.cs
  - backend/tests/SafePath.Application.Tests/Sos/TriggerSosCommandHandlerTests.cs
  - mobile/android/app/build.gradle.kts
  - mobile/android/app/src/main/AndroidManifest.xml
  - mobile/ios/Runner/Info.plist
  - mobile/lib/core/network/connectivity_service.dart
  - mobile/lib/core/os_shortcuts/quick_actions_service.dart
  - mobile/lib/core/push/push_service.dart
  - mobile/lib/core/router/app_router.dart
  - mobile/lib/core/theme/app_typography.dart
  - mobile/lib/features/home/presentation/main_shell.dart
  - mobile/lib/features/privacy/presentation/privacy_center_screen.dart
  - mobile/lib/features/sos/application/emergency_contacts_controller.dart
  - mobile/lib/features/sos/application/sos_controller.dart
  - mobile/lib/features/sos/application/sos_live_location_service.dart
  - mobile/lib/features/sos/application/sos_responder_controller.dart
  - mobile/lib/features/sos/application/sos_session_state.dart
  - mobile/lib/features/sos/data/device_token_api.dart
  - mobile/lib/features/sos/data/emergency_contact_api.dart
  - mobile/lib/features/sos/data/sos_api.dart
  - mobile/lib/features/sos/data/sos_hub_client.dart
  - mobile/lib/features/sos/data/sos_local_store.dart
  - mobile/lib/features/sos/data/sos_models.dart
  - mobile/lib/features/sos/presentation/delivery_status_chip.dart
  - mobile/lib/features/sos/presentation/emergency_contacts_screen.dart
  - mobile/lib/features/sos/presentation/responder_alert_screen.dart
  - mobile/lib/features/sos/presentation/sender_emergency_session_screen.dart
  - mobile/lib/features/sos/presentation/sos_arm_button.dart
  - mobile/lib/features/sos/presentation/sos_arm_ring_painter.dart
  - mobile/lib/features/sos/presentation/sos_countdown.dart
  - mobile/lib/features/sos/presentation/sos_hold_to_cancel_button.dart
  - mobile/lib/main.dart
  - mobile/lib/shared_widgets/member_map_pin.dart
  - mobile/pubspec.lock
  - mobile/pubspec.yaml
  - mobile/test/features/home/sos_button_press_hold_test.dart
  - mobile/test/features/privacy/privacy_center_screen_test.dart
  - mobile/test/features/sos/emergency_contacts_screen_test.dart
  - mobile/test/features/sos/quick_actions_service_test.dart
  - mobile/test/features/sos/responder_alert_screen_test.dart
  - mobile/test/features/sos/sos_cancel_test.dart
  - mobile/test/features/sos/sos_controller_test.dart
  - mobile/test/features/sos/sos_delivery_status_test.dart
  - mobile/test/features/sos/sos_live_window_test.dart
  - mobile/test/features/sos/sos_offline_retry_test.dart
  - mobile/test/helpers/fake_connectivity_service.dart
  - mobile/test/helpers/fake_emergency_contact_api.dart
  - mobile/test/helpers/fake_sos_api.dart
  - mobile/test/helpers/fake_sos_hub_client.dart
  - mobile/test/helpers/fake_sos_local_store.dart
findings:
  critical: 1
  warning: 4
  info: 1
  total: 6
status: issues_found
---

# Phase 03: Code Review Report

**Reviewed:** 2026-08-08T00:00:00Z
**Depth:** standard
**Files Reviewed:** 110
**Status:** issues_found

## Summary

This phase implements the SOS fast path end-to-end: trigger/cancel/acknowledge/live-location
endpoints, multi-channel fan-out (SignalR, FCM, SMS), a Twilio delivery-status webhook, device
token registration, emergency contacts, and the full mobile sender/responder UI plus offline
retry/foreground-service handling. The code is unusually well-documented, with inline comments
tracing almost every decision back to a specific threat id (`T-03-xx`) or design decision
(`D-xx`), and the authorization/idempotency/isolation invariants are enforced consistently
almost everywhere.

The one significant exception is `TriggerSosCommandHandler`'s idempotent-replay branch, which
returns a full session payload (delivery history, recipient names, family id, sender user id)
to *any* authenticated caller who supplies a known `SosSessionId`, without the family-membership
check every sibling handler (`GetSosSessionQueryHandler`, `CancelSosCommandHandler`,
`AcknowledgeSosCommandHandler`) performs first. This directly contradicts the rule the codebase's
own comments state elsewhere ("an SOS session id is not itself proof of authorization to view
it") and is unprotected by any test. It is classified Critical below.

The remaining findings are lower-severity robustness/correctness gaps: a mobile UI label that
misrepresents a terminal `Failed` delivery status as actively retrying (no such retry exists
server-side), a webhook signature-validation URL that is likely to break behind a reverse proxy
in production, a client-side race that can send an empty `familyId` on SOS trigger, and a DB
unique constraint that doesn't actually hold for the SMS delivery-attempt rows it was meant to
cover.

## Critical Issues

### CR-01: `TriggerSosCommandHandler`'s idempotent-replay branch leaks SOS session data to non-members (broken access control)

**File:** `backend/src/SafePath.Application/Sos/TriggerSosCommand.cs:48-57`
**Issue:**
```csharp
public async Task<TriggerSosResult> Handle(TriggerSosCommand command, CancellationToken cancellationToken = default)
{
    var existing = await _db.SosSessions
        .SingleOrDefaultAsync(s => s.Id == command.SosSessionId, cancellationToken);

    if (existing is not null)
    {
        var existingDto = await SosSessionProjection.ProjectAsync(_db, existing, command.CallerUserId, cancellationToken);
        return new TriggerSosResult(existingDto, WasExistingSession: true);
    }

    await _authorization.RequireMembership(command.CallerUserId, command.FamilyId, cancellationToken);
    Validate(command);
    ...
```
`RequireMembership` is only called on the *fresh-session* path, after the `existing is not null`
early return. Any authenticated user (`[Authorize]` on `SosController`, no further scoping) who
supplies a `SosSessionId` belonging to a session they were never a party to gets back a full
`SosSessionDto` — `FamilyId`, `TriggeredByUserId`, `Status`, all timestamps, and the complete
`Recipients` list (display names + per-channel delivery/acknowledgement status for every
guardian and emergency contact), regardless of the `FamilyId` supplied in the request body (it is
silently ignored once `existing` is found). Only the sender's own phone number is gated (via
`ProjectAsync`'s `recipientIds.Contains(callerUserId)` check) — everything else is unconditionally
returned.

This is inconsistent with every sibling handler in the same file/feature:
- `GetSosSessionQueryHandler.Handle` (`GetSosSessionQuery.cs:26-40`) explicitly calls
  `RequireMembership` before returning any session, with a doc comment stating "an SOS session id
  is not itself proof of authorization to view it (threat T-03-04)".
- `CancelSosCommandHandler.Handle` and `AcknowledgeSosCommandHandler.Handle` both call
  `RequireMembership` unconditionally, before their own idempotent/no-op branches.

`TriggerSosCommandHandlerTests.Handle_IsIdempotentForRepeatedSessionId` and
`SosControllerTests.Trigger_ReturnsForbiddenForNonMemberFamily` only exercise the case where the
caller is consistent across the replay, or where the session doesn't exist yet — there is no test
covering "caller B replays caller A's already-created `SosSessionId`", so this gap is currently
unguarded by the test suite as well.

Exploitability requires knowing another user's client-generated `SosSessionId` GUID (e.g. leaked
via a screenshot, shared link, log line, or captured push-notification payload before delivery
completes) — but the entire point of an authorization check on a resource-by-id endpoint is to
not rely on the id being secret. This is a genuine IDOR / broken-access-control bug on the most
safety-critical endpoint in the app.

**Fix:** Move the membership check ahead of the idempotency short-circuit (and re-verify the
resolved session's *actual* `FamilyId`, not the caller-supplied one, since a replay could pass a
mismatched `FamilyId` for an existing session):
```csharp
var existing = await _db.SosSessions
    .SingleOrDefaultAsync(s => s.Id == command.SosSessionId, cancellationToken);

if (existing is not null)
{
    await _authorization.RequireMembership(command.CallerUserId, existing.FamilyId, cancellationToken);
    var existingDto = await SosSessionProjection.ProjectAsync(_db, existing, command.CallerUserId, cancellationToken);
    return new TriggerSosResult(existingDto, WasExistingSession: true);
}

await _authorization.RequireMembership(command.CallerUserId, command.FamilyId, cancellationToken);
Validate(command);
```
Add a regression test mirroring `Trigger_ReturnsForbiddenForNonMemberFamily` but against an
*already-created* session id, asserting the same 403.

## Warnings

### WR-01: `DeliveryStatusChip` labels a permanently `Failed` delivery as "Retrying", but nothing retries it

**File:** `mobile/lib/features/sos/presentation/delivery_status_chip.dart:55-62`
**Issue:**
```dart
case SosDeliveryStatus.failed:
  // A failure is an amber attention state, never a second red tone —
  // red stays reserved for the emergency itself.
  return const _StatusSpec(
    icon: Icons.schedule,
    color: AppColors.caution,
    label: 'Retrying',
  );
```
Server-side, `SosDeliveryStatus.Failed` is a terminal state written by
`SosAlertDispatcher.MarkChannelFailed`/`DispatchFcm`/`DispatchSms`/
`RecordSmsDeliveryStatusCommandHandler` and is never subsequently re-dispatched — there is no
retry loop, scheduled job, or re-attempt path anywhere in `SosAlertDispatcher` or its callers for
an individual `SosDeliveryAttempt` row once it is `Failed` (e.g. a missing FCM token, an invalid
phone number, or a provider rejection). Rendering the label "Retrying" tells the sender/guardian
that the system is actively working to reach that recipient when, in fact, that channel has
permanently given up for this session. On a safety-critical delivery-status screen (whose whole
purpose per D-09/D-10 is to be an honest, never-misleading vocabulary), this is a materially
misleading state that could cause a sender to believe backup contact has been reached when it has
not.
**Fix:** Either give `Failed` its own honest label/copy (e.g. "Not delivered" / "Couldn't reach"),
or implement an actual retry path server-side and only show "Retrying" once one exists. At
minimum, don't reuse the copy "Retrying" for a state that is final:
```dart
case SosDeliveryStatus.failed:
  return const _StatusSpec(
    icon: Icons.error_outline,
    color: AppColors.caution,
    label: 'Not delivered',
  );
```

### WR-02: SMS webhook signature validation reconstructs the request URL from `Request.Scheme`/`Request.Host`, which is unreliable behind a reverse proxy

**File:** `backend/src/SafePath.Api/Controllers/SmsWebhookController.cs:32`,
`backend/src/SafePath.Infrastructure/Sms/TwilioWebhookSignatureValidator.cs:19-28`
**Issue:** `Status()` builds the URL Twilio's `RequestValidator` recomputes the HMAC over as
`$"{Request.Scheme}://{Request.Host}{Request.Path}{Request.QueryString}"`. Twilio signs the
*public* URL it called (e.g. `https://api.safepathai.example.com/webhooks/sms/status`). When the
API is deployed behind a TLS-terminating reverse proxy or load balancer (Azure App Service's
front end, a container ingress, etc.) without `app.UseForwardedHeaders()` configured in
`Program.cs`, `Request.Scheme` typically reports `http` and/or `Request.Host` reports an internal
hostname/port rather than the externally-visible `https://` host Twilio actually signed — causing
every legitimate delivery-status callback to fail signature validation permanently. The practical
effect is that `SosDeliveryStatus.Delivered` (and `Failed` via the webhook) would never be written
for the SMS channel in a typical production deployment, silently degrading D-10's delivery
truthfulness for the one channel (SMS to non-app emergency contacts) that has no other delivery
confirmation signal.
**Fix:** Add `app.UseForwardedHeaders(...)` (configured for the actual proxy in front of the API)
before `app.UseHttpsRedirection()`/routing in `Program.cs`, and/or build the validated URL from
`TwilioOptions.StatusCallbackUrl` (already known and configured) plus the incoming query string,
rather than trusting `HttpContext.Request.Scheme`/`Host` directly.

### WR-03: `SosController._composeRequest` can silently trigger with an empty `familyId`

**File:** `mobile/lib/features/sos/application/sos_controller.dart:358-373`
**Issue:**
```dart
SosTriggerRequest _composeRequest(String sessionId) {
  final familyId = ref.read(familyControllerProvider).value?.family?.id;
  ...
  return SosTriggerRequest(
    sosSessionId: sessionId,
    familyId: familyId ?? '',
    ...
```
If `arm()` runs before `FamilyController` has resolved the user's family (e.g. a cold start where
`familyControllerProvider` is still loading, or briefly during a state transition), `familyId`
falls back to an empty string, which is sent to `POST /sos/trigger` as `FamilyId`. Server-side,
`TriggerSosRequest.FamilyId` is a `Guid`; an empty string fails ASP.NET Core model binding for a
non-nullable `Guid` route/body parameter, which typically surfaces as a 400 with a
`ProblemDetails`-shaped body rather than the `{ "error": "..." }` shape `_mapError` expects,
degrading to a generic "That request could not be completed" message — and, more importantly, the
alert is never sent, silently defeating the Core Value ("SOS must always work") for a plausible
real-world race (app launched cold, SOS armed within the first second before family data has
loaded).
**Fix:** Guard `arm()`/`_composeRequest` against a not-yet-loaded family (e.g. block arming until
`familyControllerProvider` has a value, or fall back to a cached last-known family id persisted
alongside the session id) rather than sending a value the server can never accept.

### WR-04: `SosDeliveryAttempts`' unique index does not actually enforce "one row per (session, recipient, channel)" for SMS rows

**File:**
`backend/src/SafePath.Infrastructure/Persistence/EntityConfigurations/SosDeliveryAttemptConfiguration.cs:25-26`
**Issue:**
```csharp
builder.HasIndex(a => new { a.SosSessionId, a.RecipientUserId, a.EmergencyContactId, a.Channel })
    .IsUnique();
```
For SMS delivery rows, `RecipientUserId` is always `NULL` (only `EmergencyContactId` is set). In
PostgreSQL (and standard SQL), a `NULL` in one of a composite unique index's columns makes that
row's uniqueness untracked against every other row that also has `NULL` there — two SMS delivery
rows for the same `(SosSessionId, EmergencyContactId, Channel)` are *not* rejected by this index,
because `RecipientUserId IS NULL` is never considered equal to another `RecipientUserId IS NULL`.
The doc comment on `SosDeliveryAttempt` states "Exactly one of `RecipientUserId` /
`EmergencyContactId` is set" as an invariant, and the index is presumably meant to back that up —
but it currently only does so for the guardian (`RecipientUserId`-populated) rows. In practice
`TriggerSosCommandHandler`'s idempotency check prevents duplicate inserts today, but the DB is not
actually the backstop the code comments imply, so any future code path that re-runs the SMS
fan-out insert (e.g. a retry/backfill job) could silently create duplicate SMS sends with no
constraint violation to catch it.
**Fix:** Add a partial unique index (or a computed/generated non-null surrogate key) so the SMS
rows are actually constrained, e.g. (Npgsql/EF Core filtered index):
```csharp
builder.HasIndex(a => new { a.SosSessionId, a.RecipientUserId, a.Channel })
    .IsUnique()
    .HasFilter("\"RecipientUserId\" IS NOT NULL");
builder.HasIndex(a => new { a.SosSessionId, a.EmergencyContactId, a.Channel })
    .IsUnique()
    .HasFilter("\"EmergencyContactId\" IS NOT NULL");
```

## Info

### IN-01: CORS policy in `Program.cs` allows any RFC1918 private-IP origin on any port/scheme

**File:** `backend/src/SafePath.Api/Program.cs:81-116`
**Issue:** `SetIsOriginAllowed` accepts any origin whose host is `localhost`/`127.0.0.1` or falls
in `10.0.0.0/8`, `172.16.0.0/12`, or `192.168.0.0/16` — with no scheme or port restriction. This is
broader than a typical dev-only CORS allowlist (e.g. it would accept `http://` origins, and any
host on the developer's LAN, not just the dev machine itself). This is likely intentional for LAN
device testing during development, but is worth confirming it is not the policy also active in a
production `ASPNETCORE_ENVIRONMENT`, since a private-IP-range check is not itself an environment
check.
**Fix:** Scope this policy to `IsDevelopment()` explicitly (or a config flag), and use a distinct,
narrower policy for production origins.

---

_Reviewed: 2026-08-08T00:00:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
