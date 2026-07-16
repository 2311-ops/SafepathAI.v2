# Phase 2: Real-Time Location, History & Privacy - Pattern Map

**Mapped:** 2026-07-12
**Files analyzed:** ~34 new/modified files (backend Domain/Application/Infrastructure/Api + mobile location/privacy features + shared widgets + bottom-nav shell)
**Analogs found:** 30 / 34 (SignalR hub/presence/no-bottom-nav-shell files have no direct in-repo analog — flagged below)

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `backend/src/SafePath.Domain/Entities/LocationPing.cs` | model | CRUD (append-only) | `backend/src/SafePath.Domain/Entities/FamilyMember.cs` | role-match |
| `backend/src/SafePath.Domain/Entities/SharingPreference.cs` | model | CRUD | `backend/src/SafePath.Domain/Entities/FamilyMember.cs` | exact (same "per-member row" shape) |
| `backend/src/SafePath.Domain/Enums/SharedDataType.cs` | model (enum) | — | `backend/src/SafePath.Domain/Enums/PermissionLevel.cs` (referenced via `FamilyMember.Permissions`) | exact |
| `backend/src/SafePath.Infrastructure/Persistence/EntityConfigurations/LocationPingConfiguration.cs` | config | CRUD | `FamilyMemberConfiguration.cs` | exact |
| `backend/src/SafePath.Infrastructure/Persistence/EntityConfigurations/SharingPreferenceConfiguration.cs` | config | CRUD | `FamilyMemberConfiguration.cs` | exact |
| `backend/src/SafePath.Application/Location/ReportLocationCommand.cs` (+Handler) | service (command handler) | event-driven (write + broadcast) | `UpdateMemberPermissionsCommand.cs` | role-match (command shape); no broadcast-side analog exists |
| `backend/src/SafePath.Application/Location/GetLiveLocationsQuery.cs` | service (query handler) | request-response | `ListFamilyMembersQuery.cs` | exact |
| `backend/src/SafePath.Application/Location/GetLocationHistoryQuery.cs` | service (query handler) | request-response / batch read | `ListFamilyMembersQuery.cs` | role-match |
| `backend/src/SafePath.Application/Location/GetTravelStatsQuery.cs` | service (query handler) | transform/batch | `ListFamilyMembersQuery.cs` | role-match |
| `backend/src/SafePath.Application/Location/StopDetection.cs` | utility (pure function) | transform | none (novel algorithm) | no analog |
| `backend/src/SafePath.Application/Privacy/UpdateSharingPreferenceCommand.cs` | service (command handler) | CRUD | `UpdateMemberPermissionsCommand.cs` | exact |
| `backend/src/SafePath.Application/Privacy/GetSharingMatrixQuery.cs` | service (query handler) | request-response | `ListFamilyMembersQuery.cs` | exact |
| `backend/src/SafePath.Application/Privacy/ExportMyDataQuery.cs` | service (query handler) | file-I/O (JSON export) | `ListFamilyMembersQuery.cs` (query shape) | role-match |
| `backend/src/SafePath.Application/Privacy/DeleteMyDataCommand.cs` | service (command handler) | CRUD (hard delete) | `DeleteFamilyCommand.cs` | exact |
| `backend/src/SafePath.Infrastructure/RealTime/LocationHub.cs` | controller (SignalR hub) | event-driven / streaming | `FamiliesController.cs` (auth/authorization wiring pattern only) | partial — no hub exists yet in repo |
| `backend/src/SafePath.Infrastructure/RealTime/ILocationClient.cs` | interface | event-driven | none | no analog |
| `backend/src/SafePath.Infrastructure/RealTime/ILocationBroadcastService.cs` + impl | service (Infrastructure abstraction) | event-driven | `FamilyAuthorizationService.cs` (Infrastructure-impl-of-Application-interface pattern) | role-match |
| `backend/src/SafePath.Infrastructure/RealTime/PresenceTracker.cs` | service (in-memory state) | event-driven | none | no analog |
| `backend/src/SafePath.Infrastructure/RealTime/SharingPreferenceSweepService.cs` | service (`BackgroundService`) | event-driven / batch (timer sweep) | none | no analog (new pattern in this codebase) |
| `backend/src/SafePath.Api/Controllers/LocationController.cs` | controller | request-response | `FamiliesController.cs` | exact |
| `backend/src/SafePath.Api/Controllers/PrivacyController.cs` | controller | request-response | `FamiliesController.cs` | exact |
| `backend/src/SafePath.Api/Program.cs` (modified) | config | — | itself (existing `AddJwtBearer` block) | exact |
| `mobile/lib/features/location/data/location_api.dart` | service (REST client) | request-response | `mobile/lib/features/family/data/family_api.dart` | exact |
| `mobile/lib/features/location/data/location_hub_client.dart` | service (SignalR client wrapper) | streaming | `family_api.dart` (error-mapping/DI-provider convention only) | partial — no realtime client exists yet |
| `mobile/lib/features/location/application/location_controller.dart` | store/provider (Riverpod Notifier) | streaming + CRUD | `family_controller.dart` | exact |
| `mobile/lib/features/location/application/history_controller.dart` | store/provider | request-response | `family_controller.dart` | exact |
| `mobile/lib/features/location/presentation/live_map_screen.dart` | component (screen) | streaming (renders pushed state) | `mobile/lib/features/family/presentation/manage_permissions_screen.dart` (Riverpod-consuming screen shape) | role-match |
| `mobile/lib/features/location/presentation/history_timeline_screen.dart` | component (screen) | request-response | `manage_permissions_screen.dart` | role-match |
| `mobile/lib/features/location/presentation/route_stats_sheet.dart` | component (bottom sheet) | request-response | `manage_permissions_screen.dart` (list-of-cards shape) | role-match |
| `mobile/lib/features/location/presentation/permission_priming_screen.dart` | component (screen) | request-response (permission flow) | `mobile/lib/features/auth/presentation/welcome_screen.dart` (value-first framing screen) | role-match |
| `mobile/lib/features/location/presentation/battery_transparency_screen.dart` | component (screen) | request-response | `welcome_screen.dart` | role-match |
| `mobile/lib/features/privacy/data/privacy_api.dart` | service (REST client) | request-response | `family_api.dart` | exact |
| `mobile/lib/features/privacy/application/privacy_controller.dart` | store/provider | CRUD | `family_controller.dart` | exact |
| `mobile/lib/features/privacy/presentation/privacy_center_screen.dart` | component (screen) | CRUD (toggle matrix) | `manage_permissions_screen.dart` | exact (near-identical shape: per-member `SegmentedButton`/toggle rows) |
| `mobile/lib/shared_widgets/member_map_pin.dart` | component | transform (staleness render) | none | no analog (first map-rendering widget) |
| `mobile/lib/shared_widgets/stat_tile.dart` | component | — | `mobile/lib/shared_widgets/safepath_card.dart` | role-match |
| `mobile/lib/shared_widgets/toggle_row.dart` | component | — | `SegmentedButton` block inside `manage_permissions_screen.dart` | role-match |
| `mobile/lib/shared_widgets/timeline_node.dart` | component | — | `safepath_card.dart` | role-match |
| `mobile/lib/features/home/presentation/*_shell.dart` (new bottom-nav shell) | component | — | `mobile/lib/features/home/presentation/landing_stub_screen.dart` (being replaced) | partial |
| `backend/tests/SafePath.Application.Tests/Location/*Tests.cs` | test | — | `backend/tests/SafePath.Application.Tests/Families/*Tests.cs` | exact |
| `backend/tests/SafePath.Application.Tests/Privacy/*Tests.cs` | test | — | `Families/*Tests.cs` | exact |
| `mobile/test/features/location/*_test.dart` | test | — | `mobile/test/features/family/family_controller_test.dart` | exact |
| `mobile/test/features/privacy/*_test.dart` | test | — | `family_controller_test.dart` | exact |

## Pattern Assignments

### Backend command/query handlers (`ReportLocationCommand`, `UpdateSharingPreferenceCommand`, `GetLiveLocationsQuery`, `GetLocationHistoryQuery`, `GetTravelStatsQuery`, `GetSharingMatrixQuery`, `ExportMyDataQuery`, `DeleteMyDataCommand`)

**Analog:** `backend/src/SafePath.Application/Families/UpdateMemberPermissionsCommand.cs`

**Imports pattern** (lines 1-4):
```csharp
using Microsoft.EntityFrameworkCore;
using SafePath.Application.Common.Interfaces;
using SafePath.Domain.Enums;
```

**Record + handler shape** (lines 6-21):
```csharp
public record UpdateMemberPermissionsCommand(Guid CallerUserId, Guid FamilyId, Guid MemberId, PermissionLevel Permissions);
public record UpdateMemberPermissionsResult(Guid MemberId, PermissionLevel Permissions);

public class UpdateMemberPermissionsCommandHandler : ICommandHandler<UpdateMemberPermissionsCommand, UpdateMemberPermissionsResult>
{
    private readonly IApplicationDbContext _db;
    private readonly IFamilyAuthorizationService _authorization;

    public UpdateMemberPermissionsCommandHandler(IApplicationDbContext db, IFamilyAuthorizationService authorization)
    {
        _db = db;
        _authorization = authorization;
    }
```

**Auth/IDOR pattern** (lines 25-38) — this is the load-bearing pattern for every Phase 2 location/privacy handler per RESEARCH.md Pattern 7/Security Domain (both `IFamilyAuthorizationService` membership check AND, for Phase 2, an additional `SharingPreference` check):
```csharp
await _authorization.RequireRole(command.CallerUserId, command.FamilyId, Role.Guardian, cancellationToken);

// Re-scoped to command.FamilyId — never trust that MemberId alone identifies the
// correct family (IDOR prevention, locked decision D5): a memberId belonging to a
// different family is treated as "not found in this family", not silently updated.
var target = await _db.FamilyMembers.SingleOrDefaultAsync(
    m => m.Id == command.MemberId && m.FamilyId == command.FamilyId && m.IsActive,
    cancellationToken);

if (target is null)
{
    throw new FamilyAuthorizationDeniedException(
        $"FamilyMember {command.MemberId} is not an active member of family {command.FamilyId}.");
}
```
For read queries (`GetLiveLocationsQuery`/`GetLocationHistoryQuery`/`GetTravelStatsQuery`), use `RequireMembership` (not `RequireRole`) as shown in `ListFamilyMembersQuery`-style handlers (membership-only gate, no Guardian requirement) — then additionally filter results by `SharingPreference.IsEnabled` per RESEARCH.md Pattern 7. `DeleteMyDataCommand` should mirror `DeleteFamilyCommand.cs`'s "delete only what the caller owns, no cross-user deletion" shape.

**Error handling:** Throw the existing `FamilyAuthorizationDeniedException` for authorization failures (do not invent a new exception type) — the controller layer already knows how to translate it to `403 Forbid()`.

---

### `LocationController.cs` / `PrivacyController.cs`

**Analog:** `backend/src/SafePath.Api/Controllers/FamiliesController.cs`

**Imports + class shape** (lines 1-19):
```csharp
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using SafePath.Application.Common.Interfaces;
using SafePath.Application.Families;
using SafePath.Domain.Enums;

namespace SafePath.Api.Controllers;

[ApiController]
[Authorize]
public class FamiliesController : ControllerBase
```

**Current-user + error-mapping pattern per action** (lines 107-127, `UpdatePermissions` — directly reusable shape for `PrivacyController.UpdateSharingPreference` and any `LocationController` write endpoint):
```csharp
[HttpPatch("families/{familyId:guid}/members/{memberId:guid}/permissions")]
public async Task<ActionResult<UpdateMemberPermissionsResult>> UpdatePermissions(
    Guid familyId, Guid memberId, [FromBody] UpdateMemberPermissionsRequest request, CancellationToken cancellationToken)
{
    if (_currentUser.UserId is not { } userId)
    {
        return Unauthorized();
    }

    try
    {
        var result = await _updatePermissions.Handle(
            new UpdateMemberPermissionsCommand(userId, familyId, memberId, request.Permissions), cancellationToken);
        return Ok(result);
    }
    catch (FamilyAuthorizationDeniedException)
    {
        return Forbid();
    }
}
```
Note: `LocationController`'s `ReportLocation`-equivalent endpoint may not be needed as REST at all if location pings are submitted only via the SignalR hub (`ReportLocation` hub method) per RESEARCH.md's architecture diagram — REST endpoints on `LocationController` are for `GetLiveLocationsQuery`/`GetLocationHistoryQuery`/`GetTravelStatsQuery` (GET) only. Always derive `userId` from `ICurrentUserService`/`Context.UserIdentifier`, never from the request body (Security Domain: Spoofing mitigation).

---

### `LocationHub.cs` / `ILocationBroadcastService.cs` (no in-repo analog — use RESEARCH.md's sourced pattern verbatim)

**Source:** RESEARCH.md Pattern 1/2 (synthesized from `learn.microsoft.com/aspnet/core/signalr/authn-and-authz` + `.../groups`, fetched by the researcher this session) — no existing hub in this codebase to copy from, since this is the first phase to introduce SignalR.

```csharp
// SafePath.Infrastructure/RealTime/ILocationClient.cs
public interface ILocationClient
{
    Task LocationUpdated(LocationUpdateDto update);
    Task PresenceChanged(PresenceChangeDto change);
}

// SafePath.Infrastructure/RealTime/LocationHub.cs
[Authorize]
public class LocationHub : Hub<ILocationClient>
{
    private readonly IFamilyAuthorizationService _authorization;
    private readonly PresenceTracker _presence;

    public override async Task OnConnectedAsync()
    {
        var userId = Guid.Parse(Context.UserIdentifier!); // "sub" claim, per Program.cs NameClaimType config
        var familyId = await _authorization.RequireMembership(userId, GetFamilyIdFromQuery(), Context.ConnectionAborted)
            is var member ? member.FamilyId : throw new HubException("no active family");

        await Groups.AddToGroupAsync(Context.ConnectionId, $"family:{familyId}");
        _presence.AddConnection(userId, Context.ConnectionId);
        await Clients.OthersInGroup($"family:{familyId}").PresenceChanged(new(userId, IsOnline: true));
    }
}
```

**Auth wiring (Program.cs modification)** — extend the existing `AddJwtBearer` block found at `backend/src/SafePath.Api/Program.cs` lines 44-60 exactly as-is, adding only the `Events.OnMessageReceived` handler (do not touch `Authority`/`TokenValidationParameters`, which stay unchanged):
```csharp
// existing block (lines 44-60), unmodified except for adding Events below:
.AddJwtBearer(options =>
{
    options.Authority = supabaseIssuer;
    options.RequireHttpsMetadata = true;
    options.MapInboundClaims = false;
    options.TokenValidationParameters = new()
    {
        ValidateIssuer = true,
        ValidIssuer = supabaseIssuer,
        ValidateAudience = true,
        ValidAudience = supabaseAudience,
        ValidateLifetime = true,
        NameClaimType = "sub",
        RoleClaimType = "role",
        ClockSkew = TimeSpan.FromMinutes(1),
    };
    // NEW for Phase 2 — required for SignalR WebSocket auth (RESEARCH.md Pitfall 1):
    options.Events = new JwtBearerEvents
    {
        OnMessageReceived = context =>
        {
            var accessToken = context.Request.Query["access_token"];
            var path = context.HttpContext.Request.Path;
            if (!string.IsNullOrEmpty(accessToken) && path.StartsWithSegments("/hubs/location"))
            {
                context.Token = accessToken;
            }
            return Task.CompletedTask;
        }
    };
});
```

**Critical constraint:** `ILocationBroadcastService` is the Application-facing seam (defined in `SafePath.Application.Common.Interfaces`, implemented in `SafePath.Infrastructure.RealTime`) — follow the exact "Infrastructure implements an Application-defined interface" shape already used by `FamilyAuthorizationService : IFamilyAuthorizationService` (`backend/src/SafePath.Infrastructure/Identity/FamilyAuthorizationService.cs` implementing `backend/src/SafePath.Application/Common/Interfaces/IFamilyAuthorizationService.cs`). Application-layer command handlers must depend on `ILocationBroadcastService` only — never `IHubContext<LocationHub>` directly.

---

### `LocationPing.cs` / `SharingPreference.cs` entities + EF configurations

**Analog:** `backend/src/SafePath.Domain/Entities/FamilyMember.cs` + `backend/src/SafePath.Infrastructure/Persistence/EntityConfigurations/FamilyMemberConfiguration.cs`

**Entity shape** (FamilyMember.cs lines 12-22):
```csharp
public class FamilyMember
{
    public Guid Id { get; set; }
    public Guid FamilyId { get; set; }
    public Guid UserId { get; set; }
    public Role Role { get; set; }
    public PermissionLevel Permissions { get; set; }
    public DateTime JoinedAt { get; set; }
    public bool IsActive { get; set; } = true;
    public DateTime? RemovedAt { get; set; }
}
```

**EF configuration shape** (FamilyMemberConfiguration.cs, full file, 32 lines):
```csharp
public class FamilyMemberConfiguration : IEntityTypeConfiguration<FamilyMember>
{
    public void Configure(EntityTypeBuilder<FamilyMember> builder)
    {
        builder.ToTable("FamilyMembers");
        builder.HasKey(m => m.Id);

        builder.Property(m => m.Role).HasConversion<string>().IsRequired();
        builder.Property(m => m.Permissions).HasConversion<string>().IsRequired();
        builder.Property(m => m.JoinedAt).IsRequired();
        builder.Property(m => m.IsActive).IsRequired();

        builder.HasOne<Family>()
            .WithMany()
            .HasForeignKey(m => m.FamilyId)
            .OnDelete(DeleteBehavior.Cascade);

        builder.HasIndex(m => new { m.FamilyId, m.UserId }).IsUnique();
        builder.HasIndex(m => m.UserId).IsUnique().HasFilter("\"IsActive\" = TRUE");
    }
}
```
Apply the same shape to `LocationPingConfiguration` (composite non-unique index `HasIndex(p => new { p.UserId, p.RecordedAtUtc })` per RESEARCH.md Pattern 5 instead of a unique index) and `SharingPreferenceConfiguration` (enum `.HasConversion<string>()` for `DataType`, matching `Permissions`' string-conversion convention — keep enum storage consistent project-wide, do not switch to int storage for the new enums).

---

### Mobile REST API clients (`location_api.dart`, `privacy_api.dart`)

**Analog:** `mobile/lib/features/family/data/family_api.dart`

**Interface + exception pattern** (lines 7-26):
```dart
enum FamilyApiIssue { forbidden, notFound, validation, network, unknown }

class FamilyApiException implements Exception {
  FamilyApiException(this.issue, {this.message});
  final FamilyApiIssue issue;
  final String? message;
}
```

**Abstract-interface-over-Dio-impl pattern** (lines 32-70, 72-100): define an abstract `LocationApi`/`PrivacyApi` class with doc-commented methods naming the exact REST route each hits, then a `DioLocationApi implements LocationApi` concrete class. Every method wraps `_dio.<verb>()` in try/`on DioException catch (error) { throw _mapError(error); }`.

**Error-mapping pattern** (lines 170-199) — copy verbatim, adjusting only the forbidden-message copy:
```dart
FamilyApiException _mapError(DioException error) {
  final status = error.response?.statusCode;
  if (status == 403) {
    return FamilyApiException(FamilyApiIssue.forbidden, message: 'Only a Guardian can do that.');
  }
  if (status == 404) {
    return FamilyApiException(FamilyApiIssue.notFound, message: 'Not found.');
  }
  if (status == 400 || status == 409) {
    final data = error.response?.data;
    final serverMessage = data is Map ? data['error'] as String? : null;
    return FamilyApiException(FamilyApiIssue.validation, message: serverMessage ?? 'That request could not be completed.');
  }
  if (error.type == DioExceptionType.connectionError || error.type == DioExceptionType.connectionTimeout ||
      error.type == DioExceptionType.receiveTimeout || error.type == DioExceptionType.sendTimeout) {
    return FamilyApiException(FamilyApiIssue.network, message: "Couldn't connect. Check your connection and try again.");
  }
  return FamilyApiException(FamilyApiIssue.unknown, message: error.message);
}
```
Note: this maps directly onto UI-SPEC's locked copy — "Couldn't save that setting. Check your connection and try again." for the toggle-save failure state, "Couldn't prepare your export. Try again in a moment." for export failure — thread those exact strings through `_mapError`'s override points or per-call catch blocks in `privacy_controller.dart`.

**Provider wiring** (line 202-204):
```dart
final familyApiProvider = Provider<FamilyApi>((ref) => DioFamilyApi(ref.watch(dioProvider)));
```

---

### `location_hub_client.dart` (SignalR client wrapper — no in-repo analog)

**Source:** RESEARCH.md Code Examples §2 (`pub.dev/documentation/signalr_netcore/latest`, fetched by researcher) — first realtime client in this codebase, follow `family_api.dart`'s *shape conventions* (abstract interface + Riverpod provider + typed exception) but the transport itself is new:
```dart
final httpOptions = HttpConnectionOptions(
  accessTokenFactory: () async => (await supabase.auth.currentSession)?.accessToken ?? '',
  logging: (level, message) => debugPrint(message),
);

final hubConnection = HubConnectionBuilder()
    .withUrl('$apiBaseUrl/hubs/location?familyId=$familyId', options: httpOptions)
    .withAutomaticReconnect(retryDelays: [2000, 5000, 10000, 20000, null])
    .build();

hubConnection.on('LocationUpdated', (args) => _handleLocationUpdate(args));
hubConnection.on('PresenceChanged', (args) => _handlePresenceChange(args));
await hubConnection.start();
```
Wrap this in an abstract `LocationHubClient` interface (mirroring `FamilyApi`'s abstract-class-over-concrete-impl shape) so `location_controller.dart` can be unit-tested against a `FakeLocationHubClient`, per the mobile test convention below. Package `signalr_netcore` is flagged `[SUS]` in RESEARCH.md's Package Legitimacy Audit — a `checkpoint:human-verify` spike task is mandatory before building real feature logic on top of it.

---

### `location_controller.dart` / `history_controller.dart` / `privacy_controller.dart`

**Analog:** `mobile/lib/features/family/application/family_controller.dart`

**State class + `copyWith` pattern** (lines 16-57):
```dart
class FamilyState {
  const FamilyState({this.family, this.members = const [], ..., this.isLoading = false});
  final Family? family;
  final List<FamilyMemberView> members;
  final String? error;
  final bool isLoading;

  FamilyState copyWith({..., bool clearError = false, ...}) {
    return FamilyState(
      family: family ?? this.family,
      error: clearError ? null : (error ?? this.error),
      isLoading: isLoading ?? this.isLoading,
    );
  }
}
```

**`AsyncNotifier` + auth-reactive bootstrap pattern** (lines 65-119) — reuse for `location_controller.dart`'s need to open the SignalR connection reactively on auth state, and for `privacy_controller.dart`'s initial sharing-matrix fetch:
```dart
class FamilyController extends AsyncNotifier<FamilyState> {
  @override
  FamilyState build() {
    ref.listen<AuthState>(authControllerProvider, (previous, next) {
      final wasAuthenticated = previous is AuthAuthenticated;
      if (next is AuthAuthenticated && !wasAuthenticated) {
        _bootstrap();
      } else if (next is AuthUnauthenticated) {
        state = const AsyncData(FamilyState());
      }
    });
    if (ref.read(authControllerProvider) is AuthAuthenticated) {
      Future.microtask(_bootstrap);
      return const FamilyState(isLoading: true);
    }
    return const FamilyState();
  }
}
```

**Mutation method pattern** (lines 218-239, `updatePermission` — directly reusable shape for `privacy_controller.dart`'s toggle mutation):
```dart
Future<void> updatePermission(String familyId, String memberId, PermissionLevel level) async {
  final api = ref.read(familyApiProvider);
  final current = _current;
  try {
    final updated = await api.updatePermission(familyId, memberId, level);
    final members = [for (final m in current.members) if (m.memberId == memberId) m.copyWith(permission: updated) else m];
    state = AsyncData(current.copyWith(members: members, clearError: true));
  } on FamilyApiException catch (error) {
    state = AsyncData(current.copyWith(error: error.message));
  }
}
```

**Provider declaration** (line 257-258):
```dart
final familyControllerProvider = AsyncNotifierProvider<FamilyController, FamilyState>(FamilyController.new);
```

---

### Screens (`privacy_center_screen.dart`, `live_map_screen.dart`, `history_timeline_screen.dart`, `route_stats_sheet.dart`)

**Analog:** `mobile/lib/features/family/presentation/manage_permissions_screen.dart` (best match for `privacy_center_screen.dart` specifically — near-identical "per-member toggle matrix in a `ListView` of `SafePathCard`s" shape)

**Riverpod-consuming `ConsumerWidget` shape + card-per-row pattern** (lines 16-18, 59-174): `ref.watch(familyControllerProvider).value`, guard on null state with an empty-state message, then `ListView` of `SafePathCard`-wrapped rows, each with a `SegmentedButton<PermissionLevel>` whose `onSelectionChanged` calls the controller mutation directly. For `privacy_center_screen.dart`, replace `SegmentedButton` per-row with the new `ToggleRow` shared widget (per-data-type × per-recipient matrix, D-07) but keep the same card/list/controller-call wiring.

**Destructive-confirmation dialog pattern** (lines 19-57) — reuse verbatim shape for `privacy_center_screen.dart`'s "Delete my data" confirmation (only the copy and button color change, per UI-SPEC Scope Resolution #2 — no `sosRedDeep`, use `AppColors.ink` + 700 weight instead):
```dart
Future<void> _confirmRemove(BuildContext context, WidgetRef ref, ...) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text('Remove this member from $circleName?'),
      content: const Text("..."),
      actions: [
        TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancel')),
        TextButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('Remove', style: TextStyle(color: AppColors.sosRedDeep, fontWeight: FontWeight.w700))),
      ],
    ),
  );
  if (confirmed != true) return;
  await ref.read(familyControllerProvider.notifier).removeMember(familyId, member.memberId);
}
```

`live_map_screen.dart`/`history_timeline_screen.dart`/`route_stats_sheet.dart` have no direct precedent (first map/timeline screens) — follow the same `ConsumerWidget` + `ref.watch(...).value` + empty/loading/error branching shape from `manage_permissions_screen.dart`, but the map/polyline/marker rendering itself must follow RESEARCH.md Pattern 4/`google_maps_flutter` APIs (`GoogleMap`, `Marker`, `Circle`, `Polyline` widgets), which has no in-repo analog to copy.

---

### Test files

**Analog (backend):** `backend/tests/SafePath.Application.Tests/Families/*Tests.cs` (directory not read in full this pass, but RESEARCH.md's own Wave 0 Gaps section confirms its fixture/fake conventions: EF Core Sqlite in-memory `IApplicationDbContext`, Moq for `IFamilyAuthorizationService`). Mirror this directory structure 1:1 for `Location/` and `Privacy/` test folders.

**Analog (mobile):** `mobile/test/features/family/family_controller_test.dart`

**Fake-implements-interface pattern** (lines 38-70) — this is the mandated mobile test convention (per CONTEXT.md's "Mobile test convention established in Phase 1" reusable asset) for `FakeLocationApi`/`FakeLocationHubClient`/`FakePrivacyApi`:
```dart
class _FakeAuthApi implements AuthApi {
  sb.Session? sessionOverride;
  final StreamController<dynamic> _controller = StreamController<dynamic>.broadcast();

  @override
  sb.Session? get currentSession => sessionOverride;
  @override
  Stream<dynamic> get authStateChanges => _controller.stream;

  void emitSession() {
    _controller.add(sb.AuthState(sb.AuthChangeEvent.signedIn, sb.Session(...)));
  }
  void dispose() => _controller.close();
}
```
No Mockito/mocktail — hand-written fakes implementing the real abstract interface (`FamilyApi`/`LocationApi`/`LocationHubClient`), constructed directly and driven via public mutator methods (`emitSession()`), exactly as `_FakeAuthApi` does. `ProviderContainer`-driven tests, no real network/Supabase calls (per CONTEXT.md's explicit reusable-asset note).

## Shared Patterns

### Clean Architecture layering (Api → Application → Domain ← Infrastructure)
**Source:** All of `backend/src/SafePath.Application/Families/*.cs`, `backend/src/SafePath.Infrastructure/Identity/FamilyAuthorizationService.cs`
**Apply to:** Every new backend file. Application-layer command/query handlers depend only on interfaces in `SafePath.Application.Common.Interfaces` (`IApplicationDbContext`, `IFamilyAuthorizationService`, new `ILocationBroadcastService`) — never on `SafePath.Infrastructure` or `Microsoft.AspNetCore.SignalR` types directly. This is the CLAUDE.md-mandated boundary and the single most important cross-cutting rule for this phase's SignalR work.

### Server-side membership + role re-check (IDOR prevention, D5)
**Source:** `backend/src/SafePath.Infrastructure/Identity/FamilyAuthorizationService.cs` (full file, 50 lines, reproduced above in full)
**Apply to:** Every Location/Privacy command and query handler, plus `LocationHub.OnConnectedAsync`. Phase 2 adds a *second* gate on top of this (the new `SharingPreference` check) — both must pass; never substitute one for the other.

### `ICommandHandler<TCommand, TResult>` / DI registration convention
**Source:** `UpdateMemberPermissionsCommandHandler : ICommandHandler<UpdateMemberPermissionsCommand, UpdateMemberPermissionsResult>` and its constructor-injection into `FamiliesController`
**Apply to:** All new `ReportLocationCommand`, `GetLiveLocationsQuery`, `UpdateSharingPreferenceCommand`, etc. handlers and their controller constructor wiring.

### Riverpod `AsyncNotifier` state/error/loading convention
**Source:** `mobile/lib/features/family/application/family_controller.dart` (full file, reproduced above)
**Apply to:** `location_controller.dart`, `history_controller.dart`, `privacy_controller.dart` — same `copyWith(clearError: ...)`, same `AuthState`-reactive `build()`, same try/`on <Feature>ApiException catch` mutation shape.

### Dio API-client error-mapping convention
**Source:** `mobile/lib/features/family/data/family_api.dart` `_mapError` (lines 170-199, reproduced above)
**Apply to:** `location_api.dart`, `privacy_api.dart` — reuse the exact 403/404/400-409/network/unknown branching; only the human-facing message strings change (per UI-SPEC Copywriting Contract).

### EF Core entity + configuration pairing (string-converted enums, indexed for the actual query pattern)
**Source:** `FamilyMember.cs` + `FamilyMemberConfiguration.cs` (both full files, reproduced above)
**Apply to:** `LocationPing`/`LocationPingConfiguration`, `SharingPreference`/`SharingPreferenceConfiguration`.

### Destructive-action confirmation dialog, non-red styling
**Source:** `manage_permissions_screen.dart` `_confirmRemove` (lines 19-57) — pattern only; color must change per UI-SPEC Scope Resolution #2 (Ink `#15302E`/700-weight, never `sosRedDeep`, for Phase 2's "Delete my data")
**Apply to:** `privacy_center_screen.dart`'s delete-data confirmation.

## No Analog Found

Files with no close match in the codebase (planner should use RESEARCH.md's Architecture Patterns/Code Examples sections instead, since this phase is the first to introduce SignalR, `google_maps_flutter`, and `geolocator`):

| File | Role | Data Flow | Reason |
|---|---|---|---|
| `backend/src/SafePath.Infrastructure/RealTime/LocationHub.cs` | controller (hub) | streaming | First SignalR hub in the codebase — use RESEARCH.md Pattern 1 (sourced from Microsoft Learn) verbatim |
| `backend/src/SafePath.Infrastructure/RealTime/ILocationClient.cs` | interface | streaming | No prior strongly-typed hub-client interface exists |
| `backend/src/SafePath.Infrastructure/RealTime/PresenceTracker.cs` | service (in-memory) | event-driven | No prior in-memory connection-tracking service in the codebase |
| `backend/src/SafePath.Infrastructure/RealTime/SharingPreferenceSweepService.cs` | service (`BackgroundService`) | batch (timer sweep) | First `BackgroundService`/hosted-timer pattern in this codebase |
| `backend/src/SafePath.Application/Location/StopDetection.cs` | utility (pure function) | transform | Novel dwell-time-clustering algorithm (RESEARCH.md Pattern 3) — no prior geo/clustering code exists |
| `mobile/lib/features/location/data/location_hub_client.dart` | service (realtime client) | streaming | First SignalR/`signalr_netcore` client in the mobile app — use RESEARCH.md Code Examples §2 |
| `mobile/lib/shared_widgets/member_map_pin.dart` | component | transform (render) | First `google_maps_flutter`-based widget — no prior map rendering code exists; follow UI-SPEC's Stale-Location & Accuracy Treatment table for exact opacity/radius values |
| `mobile/lib/features/location/presentation/live_map_screen.dart` (map-specific portions) | component | streaming | First screen embedding `GoogleMap` — screen-shell conventions (ConsumerWidget, empty/loading states) can reuse `manage_permissions_screen.dart`, but the map widget itself has no analog |
| Bottom-nav shell replacing `landing_stub_screen.dart` | component | — | Phase 1 explicitly shipped no bottom-nav shell (01-UI-SPEC.md Scope Resolution #2); this is the first phase building real tab-based navigation chrome |

## Metadata

**Analog search scope:** `backend/src/SafePath.Domain/Entities/`, `backend/src/SafePath.Application/Families/`, `backend/src/SafePath.Application/Common/Interfaces/`, `backend/src/SafePath.Infrastructure/Identity/`, `backend/src/SafePath.Infrastructure/Persistence/EntityConfigurations/`, `backend/src/SafePath.Api/Controllers/`, `backend/src/SafePath.Api/Program.cs`, `mobile/lib/features/family/`, `mobile/lib/features/auth/`, `mobile/lib/shared_widgets/`, `mobile/test/features/family/`
**Files scanned:** 21 read in full/targeted excerpt (FamiliesController.cs, UpdateMemberPermissionsCommand.cs, FamilyAuthorizationService.cs, FamilyMember.cs, FamilyMemberConfiguration.cs, family_controller.dart, family_api.dart, manage_permissions_screen.dart, family_controller_test.dart, Program.cs JWT block, plus directory listings of Domain/Application/Infrastructure and mobile features/tests)
**Pattern extraction date:** 2026-07-12
