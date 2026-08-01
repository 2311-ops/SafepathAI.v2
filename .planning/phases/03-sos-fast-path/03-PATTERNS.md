# Phase 3: SOS Fast Path - Pattern Map

**Mapped:** 2026-08-01
**Files analyzed:** 22 (new/modified files derived from CONTEXT.md + RESEARCH.md's Recommended Project Structure)
**Analogs found:** 20 / 22

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `backend/src/SafePath.Domain/Entities/SosSession.cs` | model | CRUD | `backend/src/SafePath.Domain/Entities/LocationPing.cs` (not read directly, referenced via `ReportLocationCommand`'s `LocationPing` usage) | role-match |
| `backend/src/SafePath.Domain/Entities/SosDeliveryAttempt.cs` | model | CRUD | same as above | role-match |
| `backend/src/SafePath.Domain/Entities/EmergencyContact.cs` | model | CRUD | `FamilyMember` entity shape (per RESEARCH.md Pitfall 2) | role-match |
| `backend/src/SafePath.Application/Sos/TriggerSosCommand.cs` | service (command handler) | event-driven / request-response | `backend/src/SafePath.Application/Location/ReportLocationCommand.cs` | exact |
| `backend/src/SafePath.Application/Sos/CancelSosCommand.cs` | service (command handler) | request-response | `ReportLocationCommand.cs` (handler shape only; no direct cancel analog exists) | role-match |
| `backend/src/SafePath.Application/Sos/AcknowledgeSosCommand.cs` | service (command handler) | request-response | `ReportLocationCommand.cs` | role-match |
| `backend/src/SafePath.Application/Sos/GetSosSessionQuery.cs` | service (query handler) | request-response | `GetLiveLocationsQuery` (used via `LocationController.GetLiveLocations`) | exact |
| `backend/src/SafePath.Infrastructure/RealTime/AlertHub.cs` | middleware (SignalR hub) | streaming / event-driven | `backend/src/SafePath.Infrastructure/RealTime/LocationHub.cs` | exact |
| `backend/src/SafePath.Infrastructure/RealTime/IAlertClient.cs` | interface | streaming | `ILocationClient` (referenced by `LocationHub`/`LocationBroadcastService`, not opened directly — shape inferred from usage) | exact |
| `backend/src/SafePath.Infrastructure/RealTime/AlertBroadcastService.cs` | service | event-driven / pub-sub | `backend/src/SafePath.Infrastructure/RealTime/LocationBroadcastService.cs` | exact |
| `backend/src/SafePath.Infrastructure/Sms/ISmsGateway.cs` | interface | request-response | none (first external-gateway abstraction in codebase) | no analog |
| `backend/src/SafePath.Infrastructure/Sms/TwilioSmsGateway.cs` | service (external gateway) | request-response | none | no analog |
| `backend/src/SafePath.Infrastructure/Sms/LoggingSmsGateway.cs` | service (fake/dev gateway) | request-response | none | no analog |
| `backend/src/SafePath.Api/Controllers/SosController.cs` | controller | request-response | `backend/src/SafePath.Api/Controllers/LocationController.cs` | exact |
| `mobile/lib/features/sos/application/sos_controller.dart` | provider/store (AsyncNotifier) | streaming / event-driven | `mobile/lib/features/location/application/location_controller.dart` | exact |
| `mobile/lib/features/sos/application/sos_session_state.dart` | model (state) | transform | `LocationState` class (same file as `LocationController`) | exact |
| `mobile/lib/features/sos/data/sos_api.dart` | service (Dio client) | request-response | `mobile/lib/features/location/data/location_api.dart` | exact |
| `mobile/lib/features/sos/data/sos_hub_client.dart` | service (SignalR client) | streaming | `mobile/lib/features/location/data/location_hub_client.dart` | exact |
| `mobile/lib/features/sos/data/sos_local_store.dart` | utility (local persistence) | file-I/O | none (first `shared_preferences`-direct usage in a feature `data/` folder — verify no existing wrapper before building) | no analog |
| `mobile/lib/features/sos/presentation/sender_emergency_session_screen.dart` | component (screen) | streaming / event-driven | `mobile/lib/features/location/presentation/live_map_screen.dart` (not opened; same tier as `_PlainTabPlaceholder` in `main_shell.dart`) | role-match |
| `mobile/lib/features/sos/presentation/responder_alert_screen.dart` | component (screen) | streaming / event-driven | same as above | role-match |
| `mobile/lib/core/os_shortcuts/quick_actions_service.dart` | service (platform integration) | event-driven | none (first OS-shortcut integration in codebase) | no analog |
| `mobile/lib/features/home/presentation/main_shell.dart` (MODIFIED — `_SosTabButton`) | component | event-driven | itself (existing file, in-place rewrite of `_SosTabButton`) | exact (self) |
| `mobile/lib/core/router/app_router.dart` (MODIFIED — add SOS routes) | route config | request-response | itself (existing file, additive `GoRoute` entries) | exact (self) |

## Pattern Assignments

### `backend/src/SafePath.Application/Sos/TriggerSosCommand.cs` (service, event-driven)

**Analog:** `backend/src/SafePath.Application/Location/ReportLocationCommand.cs`

**Imports pattern** (lines 1-4):
```csharp
using Microsoft.EntityFrameworkCore;
using SafePath.Application.Common.Interfaces;
using SafePath.Domain.Entities;
using SafePath.Domain.Enums;
```

**Command/handler shape** (lines 8-39):
```csharp
public record ReportLocationCommand(
    Guid CallerUserId, Guid FamilyId, double Latitude, double Longitude,
    double AccuracyMeters, int? BatteryPercent, DateTime RecordedAtUtc);

public record ReportLocationResult(Guid PingId);

public class ReportLocationCommandHandler : ICommandHandler<ReportLocationCommand, ReportLocationResult>
{
    private readonly IApplicationDbContext _db;
    private readonly IFamilyAuthorizationService _authorization;
    private readonly ILocationBroadcastService _broadcast;
    // constructor DI, no MediatR — hand-rolled ICommandHandler<TCommand,TResult>
}
```

**Core pattern — persist then broadcast, membership check first** (lines 41-70):
```csharp
public async Task<ReportLocationResult> Handle(ReportLocationCommand command, CancellationToken cancellationToken = default)
{
    await _authorization.RequireMembership(command.CallerUserId, command.FamilyId, cancellationToken);
    Validate(command);
    // ... _db.Add(...); await _db.SaveChangesAsync(cancellationToken);
    // ... resolve recipients, then _broadcast.BroadcastX(...)
}
```
**For `TriggerSosCommand`:** copy this shape exactly, but (a) add the idempotency check (`FindAsync` by `SosSessionId`) as the very first line per RESEARCH.md's Pattern 2 before `RequireMembership`, (b) do NOT call `ISharingAuthorizationService.FilterRecipients` (that gates routine location visibility, not emergency recipients — RESEARCH.md Anti-Patterns) — resolve Guardians + `EmergencyContact` rows directly, (c) fire the multi-channel fan-out (`AlertBroadcastService`) as commented in RESEARCH.md's Code Examples section (`_ = _alertFanOut.DispatchAsync(...)`, not awaited inline) so a slow SMS/FCM call never delays the DB commit the idempotency check depends on.

**Error handling / validation pattern** (lines 107-133, `Validate`):
```csharp
private static void Validate(ReportLocationCommand command)
{
    if (double.IsNaN(command.Latitude) || command.Latitude is < -90 or > 90)
        throw new ArgumentException("Latitude must be a finite number between -90 and 90.", nameof(command));
    // ... plain ArgumentException, no FluentValidation (package unused in this codebase)
}
```

---

### `backend/src/SafePath.Infrastructure/RealTime/AlertHub.cs` (middleware, streaming)

**Analog:** `backend/src/SafePath.Infrastructure/RealTime/LocationHub.cs`

**Full hub shape to mirror** (lines 1-30, 69-114):
```csharp
[Authorize]
public class LocationHub : Hub<ILocationClient>
{
    private readonly IFamilyAuthorizationService _authorization;
    private readonly PresenceTracker _presence;
    private readonly ICommandHandler<ReportLocationCommand, ReportLocationResult> _reportLocation;

    public override async Task OnConnectedAsync()
    {
        var userId = GetUserId();
        var familyId = GetFamilyIdFromQuery();
        await _authorization.RequireMembership(userId, familyId, Context.ConnectionAborted);
        var groupName = FamilyGroupName(familyId);
        await Groups.AddToGroupAsync(Context.ConnectionId, groupName, Context.ConnectionAborted);
        // presence tracking...
        await base.OnConnectedAsync();
    }

    public static string FamilyGroupName(Guid familyId) => $"family:{familyId}";

    private Guid GetUserId()
    {
        if (Guid.TryParse(Context.UserIdentifier, out var userId)) return userId;
        throw new HubException("Missing authenticated user.");
    }
}
```
**For `AlertHub`:** reuse `[Authorize]` + `Hub<IAlertClient>` + the same `GetUserId()`/`GetFamilyIdFromQuery()`/group-naming helpers verbatim (rename group prefix e.g. `alert:family:{familyId}` or reuse `family:{familyId}` if the same group should receive both location and alert traffic — RESEARCH.md recommends a **separate** hub, so prefer a distinct group scheme). Do not add a `PresenceTracker`-equivalent unless a Phase 3 requirement needs it — `AlertHub`'s job is fan-out delivery + live-location-window streaming, not presence.

**Anti-pattern (from RESEARCH.md Alternatives Considered):** do not extend `LocationHub` itself with alert methods — build `AlertHub` as a fully separate `Hub<IAlertClient>` class/route (`/hubs/alert`) so SOS traffic has zero code-path coupling to routine location hub logic.

---

### `backend/src/SafePath.Infrastructure/RealTime/AlertBroadcastService.cs` (service, pub-sub)

**Analog:** `backend/src/SafePath.Infrastructure/RealTime/LocationBroadcastService.cs`

**Full pattern to mirror** (lines 1-47):
```csharp
public class LocationBroadcastService : ILocationBroadcastService
{
    private readonly IHubContext<LocationHub, ILocationClient> _hubContext;

    public Task BroadcastLocation(Guid familyId, LocationUpdateDto update, IEnumerable<Guid> eligibleRecipientUserIds, CancellationToken cancellationToken = default)
    {
        var userIds = eligibleRecipientUserIds.Select(userId => userId.ToString());
        return _hubContext.Clients.Users(userIds).LocationUpdated(update);
    }
}
```
**For `AlertBroadcastService`:** same `IHubContext<AlertHub, IAlertClient>` constructor-injection shape; one method per `IAlertClient` event (`SosTriggered`, `DeliveryStatusChanged`, `SosCanceled`, `LiveLocationWindowUpdate`), each doing `_hubContext.Clients.Users(userIds).MethodName(dto)`. Per RESEARCH.md's Pitfall 1: this service's return value must NOT be treated as "delivered" by the caller — `TriggerSosCommandHandler`/`AlertBroadcastService` only ever mark `SosDeliveryAttempt.Status = Queued` here; `Delivered`/`Acknowledged` come from a separate explicit callback path (client ack for SignalR, FCM receipt callback, Twilio webhook).

---

### `backend/src/SafePath.Api/Controllers/SosController.cs` (controller, request-response)

**Analog:** `backend/src/SafePath.Api/Controllers/LocationController.cs`

**Full controller pattern to mirror** (lines 1-49):
```csharp
[ApiController]
[Authorize]
public class LocationController : ControllerBase
{
    private readonly ICommandHandler<GetLiveLocationsQuery, IReadOnlyList<MemberLiveLocationDto>> _getLiveLocations;
    private readonly ICurrentUserService _currentUser;

    [HttpGet("families/{familyId:guid}/live-locations")]
    public async Task<ActionResult<IReadOnlyList<MemberLiveLocationDto>>> GetLiveLocations(Guid familyId, CancellationToken cancellationToken)
    {
        if (_currentUser.UserId is not { } userId) return Unauthorized();
        try
        {
            var locations = await _getLiveLocations.Handle(new GetLiveLocationsQuery(userId, familyId), cancellationToken);
            return Ok(locations);
        }
        catch (FamilyAuthorizationDeniedException) { return Forbid(); }
    }
}
```
**For `SosController`:** same `[ApiController][Authorize]` + constructor-injected `ICommandHandler<TCommand,TResult>` fields + `_currentUser.UserId is not { } userId → Unauthorized()` guard + `try/catch (FamilyAuthorizationDeniedException) → Forbid()` pattern for `POST /sos/trigger`, `POST /sos/{id}/cancel`, `POST /sos/{id}/acknowledge`, `GET /sos/{id}`.

**Explicit anti-pattern (RESEARCH.md Pitfall 4):** do NOT apply `[EnableRateLimiting("invite-redeem")]` or any existing shared rate-limit policy to `SosController` — if any rate limiting is added at all it must be a new, generous, per-user/per-`sosSessionId`, fail-open policy, never the existing 10/min invite-redeem policy.

---

### `mobile/lib/features/sos/application/sos_controller.dart` (provider/store, streaming)

**Analog:** `mobile/lib/features/location/application/location_controller.dart`

**State class pattern** (lines 23-69):
```dart
class LocationState {
  const LocationState({this.selfPosition, this.members = const {}, ...});
  final LiveLocation? selfPosition;
  LocationState copyWith({...}) { ... }
}
```
**For `SosSessionState`:** RESEARCH.md's Recommended Project Structure specifies this as a **sealed union** (`offlineQueued | submitted | delivering | liveActive | canceled`), not a single mutable class like `LocationState` — use Dart 3 `sealed class`/pattern-matching instead of copying `LocationState`'s single-class-with-copyWith shape verbatim; only borrow the *provider wiring* pattern below.

**Controller/subscription-management pattern** (lines 84-90):
```dart
class LocationController extends AsyncNotifier<LocationState> {
  StreamSubscription<Position>? _positionSubscription;
  StreamSubscription<LiveLocation>? _locationSubscription;
  StreamSubscription<PresenceChange>? _presenceSubscription;
  LocationHubClient? _hubClient;
  // ... build() wires hub client, subscribes streams, disposes on ref.onDispose
}
```
**For `SosController`:** same `AsyncNotifier<SosSessionState>` base, same "hold hub-client reference + typed `StreamSubscription` fields, wire in `build()`" convention, subscribing to `sos_hub_client.dart`'s `deliveryStatusChanges`/`sosCanceled`/`liveLocationWindowUpdates` streams instead of `LocationHubClient`'s.

---

### `mobile/lib/features/sos/data/sos_hub_client.dart` (service, streaming)

**Analog:** `mobile/lib/features/location/data/location_hub_client.dart`

**Abstract interface + broadcast-stream pattern** (lines 19-39):
```dart
abstract class LocationHubClient {
  Future<void> connect(String familyId);
  Future<void> disconnect();
  Stream<LiveLocation> get locationUpdates;
  LocationHubConnectionState get state;
  Stream<LocationHubConnectionState> get stateChanges;
  void dispose();
}
```
**Connection lifecycle + generation-guard pattern** (lines 86-150, `connect()`):
```dart
final generation = ++_generation;
_setState(LocationHubConnectionState.connecting);
final connection = signalr.HubConnectionBuilder()
    .withUrl(_locationHubUrl(familyId), options: signalr.HttpConnectionOptions(
        accessTokenFactory: () async => _supabase.auth.currentSession?.accessToken ?? ''))
    .withAutomaticReconnect(retryDelays: [2000, 5000, 10000, 20000])
    .build();
connection.on('LocationUpdated', _handleLocationUpdated);
connection.onreconnecting(...); connection.onreconnected(...); connection.onclose(...);
if (generation != _generation) return; // stale-connection guard
```
**Malformed-payload guard** (lines 202-210):
```dart
void _handleLocationUpdated(List<Object?>? arguments) {
  final json = _firstJsonArgument(arguments);
  if (json == null) return;
  try { _locationUpdates.add(LiveLocation.fromJson(json)); }
  catch (_) { /* A malformed push must not take down the hub connection's event delivery. */ }
}
```
**For `SosAlertHubClient`:** copy this entire file's structure verbatim — abstract interface + `SignalRAlertHubClient` implementation, same generation-counter reconnect-race guard, same try/catch-per-event-handler defensive parsing, same `Provider<AlertHubClient>` factory at the bottom (`ref.onDispose(client.dispose)`). Point `_locationHubUrl` equivalent at `/hubs/alert?familyId=...` and register `on('SosTriggered', ...)`, `on('DeliveryStatusChanged', ...)`, `on('SosCanceled', ...)`, `on('LiveLocationWindowUpdate', ...)` instead of the location events.

---

### `mobile/lib/features/home/presentation/main_shell.dart` (MODIFIED — `_SosTabButton`)

**Analog:** itself (in-place rewrite; current `_SosTabButton`, lines 202-262, and its usage at lines 103-114, 90-99)

**Current (to be replaced) pattern:**
```dart
Positioned(
  top: -10,
  child: _SosTabButton(
    selected: _index == 2,
    onPressed: () {
      setState(() => _index = 2); // WRONG per D-03/UI-SPEC: SOS is an action, not a nav tab
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Coming soon')));
    },
  ),
),
```
```dart
for (var i = 0; i < _tabs.length; i++)
  Expanded(
    child: i == 2
        ? const SizedBox(width: 76) // slot stays a spacer — do not restore tap-forwarding
        : _NavItem(tab: _tabs[i], selected: _index == i, onTap: () => setState(() => _index = i)),
  ),
```
Also delete: the `_index == 2` branch in the `IndexedStack` body list (`_PlainTabPlaceholder(icon: Icons.sos, ...)`, lines 49-53) and the now-unused `_index == 2` selected-state check on `_SosTabButton`.

**What to build instead (per 03-UI-SPEC.md Geometry + Interaction sections):** `_SosTabButton` becomes a `GestureDetector`-driven press-and-hold control (`onTapDown`/`onTapUp`/`onTapCancel`, 72px total footprint = 64px circle + 4px border, `-40px` raise, `AnimationController(duration: 3000ms)` driving a `CustomPainter` ring) that never touches `_index`/`setState` for tab switching — on arm-complete it calls a callback (wired to `sos_controller.dart`) that generates `sosSessionId` and pushes the Sender Emergency Session route. Reuse `AppColors.sosRed`, `AppTypography.caption` styling, and the existing `Semantics(button: true, ...)` wrapper convention exactly as already present in `_SosTabButton`/`_NavItem`.

---

### `mobile/lib/core/router/app_router.dart` (MODIFIED — add SOS routes)

**Analog:** itself (existing `GoRoute` entries, e.g. lines 219-224, 240-244)

**Pattern to copy for new routes:**
```dart
GoRoute(
  path: '/profile',
  name: 'profile',
  builder: (context, state) => const ProfileScreen(),
),
```
**For SOS:** add `GoRoute(path: '/sos/session', name: 'sos-session', builder: (context, state) => const SenderEmergencySessionScreen())` and `GoRoute(path: '/sos/responder/:sessionId', name: 'sos-responder', builder: (context, state) => ResponderAlertScreen(sessionId: state.pathParameters['sessionId']!))`. Add both to `_authenticatedOnlyRoutes` (line 48-59 set) since SOS requires an authenticated session. For FCM deep-link-to-responder-screen (D-19), the app's existing `deep_link_service.dart` (imported at line 5) is the integration point — inspect it before wiring `quick_actions`/FCM tap-through navigation, do not duplicate deep-link plumbing ad hoc in `main.dart`.

---

## Shared Patterns

### Hand-rolled `ICommandHandler<TCommand,TResult>` (no MediatR)
**Source:** `backend/src/SafePath.Application/Common/Interfaces/ICommandHandler.cs`
**Apply to:** All new Sos command/query handlers (`TriggerSosCommand`, `CancelSosCommand`, `AcknowledgeSosCommand`, `GetSosSessionQuery`)
```csharp
public interface ICommandHandler<in TCommand, TResult>
{
    Task<TResult> Handle(TCommand command, CancellationToken cancellationToken = default);
}
```
Explicitly chosen over MediatR (doc comment cites avoiding MediatR v13+'s commercial license requirement) — do not introduce MediatR for Sos handlers even though the "pipeline isolation" framing of the SOS non-negotiable might otherwise suggest a pipeline abstraction.

### Family/membership authorization guard
**Source:** `IFamilyAuthorizationService.RequireMembership(userId, familyId, ct)` — used identically in `LocationHub.OnConnectedAsync` and `ReportLocationCommandHandler.Handle`
**Apply to:** `TriggerSosCommand`, `AlertHub.OnConnectedAsync`, and any Sos handler that needs to confirm the caller belongs to the family before acting — call this immediately after (or, for `TriggerSosCommand`, immediately after) the idempotency check, before any DB writes.
```csharp
await _authorization.RequireMembership(userId, familyId, cancellationToken);
```
Catch `FamilyAuthorizationDeniedException` in controllers → `return Forbid();` (see `LocationController` pattern above).

### Never infer "Delivered"/"Sent" from a synchronous send-call return
**Source:** RESEARCH.md Common Pitfalls #1, echoed by `LocationBroadcastService`'s fire-and-forget `SendAsync` calls (which the codebase does NOT currently treat as delivery confirmation of anything — it's used only for best-effort routine updates, a materially lower-stakes context than SOS)
**Apply to:** `AlertBroadcastService`, `TwilioSmsGateway`, all `SosDeliveryAttempt` status transitions — a channel dispatch call returning without exception may only ever set `Status = Queued`; `Delivered`/`Acknowledged` require an explicit downstream signal (SignalR client ack, FCM receipt callback, Twilio status webhook, `AcknowledgeSosCommand`).

### SignalR client generation-guard + defensive event parsing
**Source:** `mobile/lib/features/location/data/location_hub_client.dart` (`_generation` counter pattern, lines 65, 91, 128-150; try/catch-per-handler pattern, lines 202-249)
**Apply to:** `sos_hub_client.dart` — copy both patterns verbatim to avoid stale-connection races and malformed-payload crashes on the new `AlertHub` client.

### Riverpod `Provider<T>` factory + `ref.onDispose` cleanup
**Source:** `mobile/lib/features/location/data/location_hub_client.dart` lines 277-284
```dart
final locationHubClientProvider = Provider<LocationHubClient>((ref) {
  final client = SignalRLocationHubClient(supabase: ref.watch(supabaseClientProvider), apiBaseUrl: apiBaseUrl);
  ref.onDispose(client.dispose);
  return client;
});
```
**Apply to:** `sos_hub_client.dart`'s exported provider, `sos_local_store.dart`'s provider, `quick_actions_service.dart`'s provider — this is the codebase's universal pattern for any disposable service/client provider.

## No Analog Found

Files with no close match in the codebase (planner should lean on RESEARCH.md's Code Examples / Standard Stack instead):

| File | Role | Data Flow | Reason |
|---|---|---|---|
| `backend/src/SafePath.Infrastructure/Sms/ISmsGateway.cs` + `TwilioSmsGateway.cs` + `LoggingSmsGateway.cs` | service (external gateway abstraction) | request-response | First external paid-provider integration in the codebase — no prior `I*Gateway`/third-party-SDK-wrapping interface exists to mirror. RESEARCH.md's "Don't Hand-Roll" table and Standard Stack section are the primary reference; structurally this should still follow the plain-interface + DI-registered-implementation convention used everywhere else in `SafePath.Infrastructure` (e.g. `IFamilyAuthorizationService`), just with no existing external-gateway analog to copy method signatures from. |
| `mobile/lib/features/sos/data/sos_local_store.dart` | utility (local persistence) | file-I/O | No existing feature-level file directly wraps `shared_preferences` for a single string/JSON-blob value — `shared_preferences` is only transitively present per RESEARCH.md. Keep this file minimal (get/set/clear `sosSessionId` + last-known offline payload) rather than importing a heavier persistence pattern from elsewhere in the app. |
| `mobile/lib/core/os_shortcuts/quick_actions_service.dart` | service (platform integration) | event-driven | First OS-shortcut/`quick_actions` integration — no existing platform-channel-style service in the codebase to mirror. Follow the plugin's own documented `QuickActions().initialize(...)` + `setShortcutItems(...)` API (see `pub.dev/packages/quick_actions`) and wire its callback straight into the same arm-complete handler `_SosTabButton` uses (per D-27, skip the hold entirely). |

## Metadata

**Analog search scope:** `backend/src/SafePath.Domain/Entities/`, `backend/src/SafePath.Application/Location/`, `backend/src/SafePath.Application/Common/Interfaces/`, `backend/src/SafePath.Infrastructure/RealTime/`, `backend/src/SafePath.Api/Controllers/`, `mobile/lib/features/location/`, `mobile/lib/features/home/presentation/`, `mobile/lib/core/router/`
**Files scanned:** 11 read in full (LocationHub.cs, LocationBroadcastService.cs, LocationController.cs, ReportLocationCommand.cs, ICommandHandler.cs, main_shell.dart, location_hub_client.dart, app_router.dart, location_controller.dart [partial, lines 1-90]) plus 03-CONTEXT.md, 03-RESEARCH.md, 03-UI-SPEC.md
**Pattern extraction date:** 2026-08-01
