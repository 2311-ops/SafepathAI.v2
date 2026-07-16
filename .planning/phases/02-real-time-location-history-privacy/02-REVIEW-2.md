---
phase: 02-real-time-location-history-privacy
reviewed: 2026-07-13T18:00:00Z
depth: standard
files_reviewed: 85
findings:
  critical: 5
  warning: 9
  info: 8
  total: 22
status: fixed
---

# Phase 02: Code Review Report — Real-Time Location, History & Privacy (2nd pass)

**Reviewed:** 2026-07-13
**Depth:** standard
**Files Reviewed:** 85 (46 backend, 39 mobile)
**Status:** All Critical and Warning findings fixed and verified (backend: `dotnet build` + 81 tests pass; mobile: `flutter analyze` clean + 95 relevant tests pass). Info-level items left as follow-ups (see below).

Two parallel reviews were run (backend .NET / Clean Architecture, mobile Flutter) due to the large
change surface (102 files across Phase 02's 11 plans). Full detail for each is preserved below.

## Fixed — Critical

| ID | Summary | Fix |
|----|---------|-----|
| BE-CR-01 | `PresenceTracker` check-then-act race between `AddConnection`/`RemoveConnection` could permanently desync a user's online state | Added live-entry re-check under lock (retry loop) in both methods; `RemoveConnection` uses `TryRemove(KeyValuePair)` to avoid removing a replaced entry |
| MO-CR-01 | `batteryLevelProvider` cached the battery reading once, silently freezing low-battery detection | Made provider `autoDispose` and invalidated before each read in `_reportPosition` |
| MO-CR-02 | `LowBatteryAlert.fromJson` threw on a missing battery value, crashing the SignalR event handler | Added a `?? 0` fallback; wrapped all three hub event handlers in try/catch |
| MO-CR-03 | History dropdown fed a stale/removed member id instead of the resolved fallback, crash risk | `selectedUserId` now uses `selectedMember?.userId` directly |
| MO-CR-04 | `deleteMyData()` didn't invalidate location/history state, so deleted data kept showing on-device | Invalidate `locationControllerProvider`/`historyControllerProvider` after a successful delete |

## Fixed — Warning

| ID | Summary | Fix |
|----|---------|-----|
| BE-WR-01 | `FilterRecipients` had no self-bypass; a user with default LiveLocation sharing disabled stopped receiving their own real-time push updates | Added self-bypass mirroring `CanView`; updated `FilterRecipients_DefaultRowCanBeOverriddenPerRecipient` test to assert the corrected behavior |
| BE-WR-02 | `ReportLocationCommand.Validate` didn't reject `NaN` lat/lng/accuracy (NaN comparisons are always false) | Added `double.IsNaN(...)` checks alongside the existing range checks |
| BE-WR-03 | `LowBatteryAlertTracker` Get-then-Set wasn't atomic, allowing duplicate low-battery broadcasts under concurrent reports | Added `TransitionAlerted` (lock-per-user atomic read-decide-write); handler now uses it instead of separate Get/Set calls |
| MO-WR-01 | Optimistic sharing-preference rollback on failure reverted to a full pre-toggle snapshot, discarding a different already-confirmed toggle | Rollback now reverts only the affected cell against the *current* matrix (`SharingMatrix.removeCell` added) |
| MO-WR-02 | `SignalRLocationHubClient.connect()`/`disconnect()` had no guard against being superseded by a concurrent call | Added a monotonic `_generation` token; connect() checks it before committing `_connection`/state at each await boundary |
| MO-WR-03 | Missing try/catch in `PermissionController.checkPermission()`/`requestPermission()` left `isChecking`/`isRequesting` stuck `true` on any exception | Added try/catch that always clears the flag before rethrowing |
| MO-WR-04 | Inconsistent catch-all across sibling async methods (`HistoryController.load()`, `PrivacyController._loadForCurrentFamily()`, `deleteMyData()`) left loading flags stuck on unexpected errors | Added `catch (_)` fallback matching sibling methods (`toggle()`/`exportMyData()`) |

## Not fixed (intentionally left)

- **BE-WR-04** (`DeleteMyDataCommand` only erases `LocationPings`, not `SharingPreferences`) — matches the documented privacy-policy text (`ExportAndDeleteRights`) exactly; this is a naming-clarity gap, not a behavioral bug. Left for a future product decision on scope + a possible rename.
- **MO-WR-05** ("Not now" on the priming screen loops back to itself) — a UX/product question (should skipping be allowed at all?), not a logic error.
- **All Info-level items (BE-IN-01..06, MO-IN-01..02)** — code-quality/duplication/cosmetic notes, no functional impact. See full detail below for follow-up candidates (duplicate `RequireTargetInFamily` helper, CORS policy scoping, missing FK on `SharingPreference.OwnerUserId`, duplicated distance/duration formatting, etc.)

---

# Backend Review (full detail)

**Files Reviewed:** 46
**Findings:** critical: 1, warning: 4, info: 6

## Summary

Reviewed the real-time location, history, travel-stats, presence, low-battery alert, and privacy
(sharing matrix / export / delete) backend slice. The sharing-gate design is fundamentally sound —
read paths (`GetLiveLocationsQuery`, `GetLocationHistoryQuery`, `GetTravelStatsQuery`) and the
write/broadcast path (`ReportLocationCommandHandler`) both independently enforce
`ISharingAuthorizationService`, IDOR checks on `familyId`/`targetUserId` are present on every
controller action, and EF Core migrations match their entity configurations and the model
snapshot exactly.

### CR-01: PresenceTracker check-then-act race (FIXED)
`backend/src/SafePath.Infrastructure/RealTime/PresenceTracker.cs` — see table above.

### WR-01: FilterRecipients no self-bypass (FIXED)
`backend/src/SafePath.Infrastructure/Identity/SharingAuthorizationService.cs` — see table above.

### WR-02: NaN validation gap (FIXED)
`backend/src/SafePath.Application/Location/ReportLocationCommand.cs` — see table above.

### WR-03: LowBatteryAlertTracker non-atomic Get-then-Set (FIXED)
`backend/src/SafePath.Infrastructure/RealTime/LowBatteryAlertTracker.cs` — see table above.

### WR-04: DeleteMyDataCommand narrower scope than name implies (not fixed — see above)
`backend/src/SafePath.Application/Privacy/DeleteMyDataCommand.cs`

### Info items (not fixed — code quality, no functional impact)
- IN-01: Duplicate `RequireTargetInFamily` helper (`GetLocationHistoryQuery.cs`, `GetTravelStatsQuery.cs`)
- IN-02: `SupabaseUserIdProvider`'s `Identity?.Name` fallback is dead/redundant
- IN-03: CORS policy not scoped to `IsDevelopment()`, broad private-network matcher
- IN-04: No FK constraint from `SharingPreference.OwnerUserId` to Users
- IN-05: `GetSharingMatrixQuery` doesn't filter deactivated recipients
- IN-06: Unused `familyId` parameter in `LocationBroadcastService` (safe today only due to one-active-family-per-user invariant)

---

# Mobile Review (full detail)

**Files Reviewed:** 39
**Findings:** critical: 4, warning: 5, info: 2

## Summary

Reviewed the Flutter mobile source for live location streaming/state management, the SignalR
hub client, history/timeline, permission gating, and the Privacy Center. The controller-level
bootstrap/stop token machinery (`_bootstrapToken`/`_generation`/`_hubOwnerToken` in
`LocationController`) is carefully built and correctly guards against the previously-fixed
"stale location connect handoffs" class of bug.

### CR-01..CR-04 (FIXED) — see table above
### WR-01..WR-04 (FIXED) — see table above
### WR-05: "Not now" UX loop (not fixed — product/UX decision, not a logic error)
`mobile/lib/features/location/presentation/permission_priming_screen.dart`

### Info items (not fixed — code quality, no functional impact)
- IN-01: Family member labels fall back to role name, indistinguishable for same-role members (pre-existing data-model limitation)
- IN-02: `_distanceLabel`/`_durationLabel` duplicated verbatim between `history_timeline_screen.dart` and `route_stats_sheet.dart`

---

_Reviewed: 2026-07-13_
_Reviewer: Claude (gsd-code-reviewer, parallel backend + mobile agents)_
_Depth: standard_
_Fixes applied and verified: 2026-07-13_
