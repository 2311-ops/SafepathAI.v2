---
phase: quick-260814-aft
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - mobile/lib/features/geofencing/presentation/safe_zones_page.dart
  - mobile/test/helpers/fake_location_permission_service.dart
  - mobile/test/features/geofencing/safe_zone_router_flow_test.dart
autonomous: true
requirements: [GEO-01, GEO-03]

must_haves:
  truths:
    - "Tapping Delete zone on the safe-zone detail screen, then confirming, actually deletes the zone through the existing GeofenceListController.deleteZone and returns the user to /safe-zones with that zone gone from the list."
    - "Dismissing the delete confirmation with Keep safe zone deletes nothing and leaves the user on the detail screen."
    - "A delete that fails server-side surfaces the controller's error message to the user and does NOT navigate away, so a failed destructive action is never mistaken for a successful one."
    - "A delete attempted with no resolvable family id reports failure instead of silently no-opping and navigating as if it had succeeded."
    - "The Open Settings affordance on the location-permission card opens the OS app settings through the existing LocationPermissionService seam, rather than being a dead button."
    - "No second delete confirmation dialog is introduced — SafeZoneDetailScreen already owns the confirm gate, and the wrapper supplies only the post-confirmation handler."
    - "Router-level widget tests drive the real routerProvider through the delete-confirm, delete-cancel, and open-settings paths, so either affordance regressing back to a null callback fails the suite."
    - "The SOS pipeline, location tracking, geofence registration, and every non-geofencing router entry are behaviourally untouched."
  artifacts:
    - file: mobile/lib/features/geofencing/presentation/safe_zones_page.dart
      contains: "onDeleteConfirmed"
    - file: mobile/lib/features/geofencing/presentation/safe_zones_page.dart
      contains: "onOpenSettings"
    - file: mobile/test/helpers/fake_location_permission_service.dart
      contains: "openAppSettingsCalls"
    - file: mobile/test/features/geofencing/safe_zone_router_flow_test.dart
      contains: "deleteCalls"
  key_links:
    - from: "SafeZoneDetailScreen.onDeleteConfirmed"
      to: "GeofenceListController.deleteZone"
      via: "SafeZoneDetailPage handler invoked only after the screen's own confirm dialog resolves true"
      pattern: "deleteZone"
    - from: "SafeZoneDetailPage delete success"
      to: "/safe-zones"
      via: "GoRouter captured before the await, so no BuildContext is used across an async gap"
      pattern: "go('/safe-zones')"
    - from: "SafeZoneDetailScreen.onOpenSettings"
      to: "LocationPermissionService.openAppSettings"
      via: "locationPermissionServiceProvider, the project's existing Geolocator.openAppSettings seam"
      pattern: "locationPermissionServiceProvider"
---

<objective>
Wire the two remaining dead affordances on `SafeZoneDetailScreen` — the delete-zone action
and the Open Settings action — to real handlers in `SafeZoneDetailPage`, and cover both with
router-level tests.

Purpose: Quick task 260814-8r2 connected the Safe Zones list/add/review/edit journey but left
`onDeleteConfirmed` and `onOpenSettings` unsupplied. Both render as visible, tappable controls
that do nothing. A visibly-tappable Delete button that silently no-ops is the worse of the two:
the user believes the zone is gone while alerts keep firing.

Output: A `SafeZoneDetailPage` that supplies both callbacks, plus three new tests in the
existing router-flow suite.
</objective>

<execution_context>
@$HOME/.claude/gsd-core/workflows/execute-plan.md
@$HOME/.claude/gsd-core/templates/summary.md
</execution_context>

<context>
@.planning/STATE.md
@.claude/CLAUDE.md

@mobile/lib/features/geofencing/presentation/safe_zones_page.dart
@mobile/lib/features/geofencing/presentation/safe_zone_detail_screen.dart
@mobile/lib/features/geofencing/application/geofence_controller.dart
@mobile/lib/features/location/application/permission_controller.dart
@mobile/lib/features/family/presentation/manage_permissions_screen.dart
@mobile/test/features/geofencing/safe_zone_router_flow_test.dart
@mobile/test/helpers/fake_geofence_api.dart
@mobile/test/helpers/fake_location_permission_service.dart
</context>

<interface_contracts>
Verified by reading the source — reuse verbatim, do not reinvent:

- `SafeZoneDetailScreen({zone, assignedMemberName, mapOverride, onEdit, onActivity, onOpenSettings, onDeleteConfirmed})`.
  - `onDeleteConfirmed` is `ValueChanged<SafeZone>?`, **not** a bare `VoidCallback`.
  - `onOpenSettings` and `onEdit` are `VoidCallback?`.
- `GeofenceListController.deleteZone(SafeZone zone)` returns `Future<void>`. It:
  - early-returns doing nothing when `state.familyId == null`;
  - on success removes the zone from `state.zones` locally and clears `state.error` — so
    `/safe-zones` renders correctly afterwards with **no** refetch needed;
  - on `GeofenceApiException` sets `state.error` and leaves `state.zones` untouched. It never
    throws and never returns a success flag, so the caller must read
    `ref.read(geofenceListControllerProvider).error` to distinguish outcomes.
- `locationPermissionServiceProvider` -> `LocationPermissionService.openAppSettings()` returns
  `Future<bool>` and is implemented as `Geolocator.openAppSettings()`. This is the project's
  established, already-faked settings seam.
- `familyControllerProvider` -> `AsyncValue<FamilyState>` with `family` (`Family.id`).
- `FakeGeofenceApi` already tracks `deleteCalls` — no new counter is needed there.

## Three corrections to the task brief — read before writing code

1. **`SafeZoneDetailScreen` already owns the delete confirmation dialog.** Its bottom-bar
   Delete zone button calls a private `_confirmDelete(context)`, which shows an `AlertDialog`
   with `Keep safe zone` / `Delete zone` actions and only then invokes
   `onDeleteConfirmed?.call(zone)`. The confirm gate therefore already matches the
   `manage_permissions_screen.dart` convention (confirm-then-mutate); it simply lives in the
   screen rather than the wrapper. **Do not add a second dialog in `SafeZoneDetailPage`** —
   that would make the user confirm a destructive action twice.

2. **`onEdit` is already wired** in `SafeZoneDetailPage` (it pushes
   `/safe-zones/${zone.id}/edit` with the zone in `extra`). No work is required for the edit
   affordance; leave that line alone.

3. **`onOpenSettings` is not the edit route.** It renders only inside the card gated on
   `zone.activation == SafeZoneActivation.needsLocationPermission`, whose body copy reads
   "Open Settings and allow background location so SafePath can activate this zone." It must
   open the OS app settings via `locationPermissionServiceProvider`. Do not point it at
   `/safe-zones/:zoneId/edit`, and do not add `permission_handler` — `geolocator` is already
   the project's permission dependency.

## Explicitly out of scope

Re-syncing `GeofenceRegistrationController` when the user returns from OS settings. That needs
app-lifecycle observation and is a separate concern; this task only opens settings.
</interface_contracts>

<tasks>

<task type="auto" tdd="false">
  <name>Task 1: Supply the delete and open-settings handlers in SafeZoneDetailPage</name>
  <files>mobile/lib/features/geofencing/presentation/safe_zones_page.dart</files>
  <action>
    In `SafeZoneDetailPage` (a `ConsumerWidget`), pass two additional arguments to the
    `SafeZoneDetailScreen` it already returns, leaving the existing `zone`,
    `assignedMemberName`, `mapOverride`, `onEdit`, and `onActivity` arguments unchanged.

    Add the import for `permission_controller.dart` from the location feature so
    `locationPermissionServiceProvider` resolves.

    Supply `onOpenSettings` as a short arrow that reads `locationPermissionServiceProvider`
    off `ref` and calls its `openAppSettings()`. Returning a `Future<bool>` from a
    `VoidCallback` arrow is valid Dart void-compatibility and needs no `unawaited` wrapper.

    Supply `onDeleteConfirmed` — remembering it is a `ValueChanged<SafeZone>`, so it receives
    the zone — as an arrow delegating to a new private `Future<void>` method on the widget
    class, taking the `BuildContext`, the `WidgetRef`, and the zone.

    That private method must, in this order:
    - Capture `GoRouter.of(context)` and `ScaffoldMessenger.of(context)` into locals **before
      the first await**. The analyzer's `use_build_context_synchronously` lint will fail
      `flutter analyze` if the `BuildContext` is instead touched after an await, and this
      widget is stateless so there is no `mounted` field to guard with.
    - Resolve a family id: prefer the loaded `geofenceListControllerProvider` state's
      `familyId`, falling back to `familyControllerProvider`'s family id. When the list state
      has no family id but the fallback does, await a `load(...)` on the list controller first
      so `deleteZone` is not defeated by its own null-family early return — this is the cold
      deep-link case, where the detail screen was reached with a zone in `extra` but the list
      was never fetched.
    - When no family id can be resolved at all, show a snackbar explaining the zone could not
      be deleted and return **without navigating**. Navigating here would present a silent
      no-op as a successful delete, which for a safety product means the user believes alerts
      have stopped when they have not.
    - Await `deleteZone(zone)` on the list controller notifier.
    - Re-read `geofenceListControllerProvider` and inspect its `error`. When non-null, show
      that message via the captured messenger and return without navigating. When null,
      navigate with the captured router using `go('/safe-zones')` — matching
      `SafeZoneReviewPage.onSaved`'s existing use of `go` for this destination. No refetch is
      needed because `deleteZone` already pruned the zone from local state.

    Add a short comment above the `onDeleteConfirmed` argument recording that
    `SafeZoneDetailScreen` owns the confirmation gate and this handler runs only after the
    user has already confirmed, so no dialog belongs here.
  </action>
  <verify>
    <automated>cd mobile && flutter analyze lib/features/geofencing/presentation/safe_zones_page.dart</automated>
  </verify>
  <done>
    `SafeZoneDetailPage` passes both `onOpenSettings` and `onDeleteConfirmed` to
    `SafeZoneDetailScreen`; neither remains unsupplied. `flutter analyze` reports no issues for
    the file, in particular no `use_build_context_synchronously` diagnostic. No `showDialog`
    call was added to `safe_zones_page.dart`, and `onEdit` is byte-for-byte unchanged.
  </done>
</task>

<task type="auto" tdd="false">
  <name>Task 2: Cover delete-confirm, delete-cancel, and open-settings at the router level</name>
  <files>
    mobile/test/helpers/fake_location_permission_service.dart,
    mobile/test/features/geofencing/safe_zone_router_flow_test.dart
  </files>
  <action>
    First, in `fake_location_permission_service.dart`, add a public mutable call counter field
    for settings opens and increment it inside `openAppSettings()` before returning its
    existing value. This is purely additive — the constructor, the `status` field, and the
    other two method bodies stay as they are, so no existing test that uses this fake changes
    behaviour.

    Then, in `safe_zone_router_flow_test.dart`:

    Widen the private `_buildContainer` helper to accept an optional named
    `FakeLocationPermissionService`, defaulting to a freshly constructed one when omitted, and
    use it for the `locationPermissionServiceProvider` override. The three existing call sites
    keep working untouched.

    Add three `testWidgets` cases, each following the suite's established shape: build a
    `FakeGeofenceApi` seeded with the zone, build the container, `addTearDown(container.dispose)`,
    read the real `routerProvider`, drive it with `router.go(...)` / `router.push(...)` before
    or after `pumpWidget`, and `pumpAndSettle`.

    Reach the detail screen by first `router.go('/safe-zones')` and pumping (which loads the
    list and therefore populates the controller's `familyId`), then
    `router.push('/safe-zones/{id}', extra: zone)` and pumping again. Driving the router
    directly rather than tapping a list card keeps these cases independent of
    `SafeZonesScreen`'s internal card markup, matching how the existing edit-journey case
    navigates.

    Note a finder subtlety: the bottom-bar trigger and the dialog's confirm action carry the
    same visible label. Disambiguate by widget type — the bottom-bar trigger is a
    `TextButton.icon` (so a `TextButton`), and the dialog's confirm action is a `FilledButton`.
    Use `find.widgetWithText` with the corresponding type in each case rather than a bare
    `find.text`, which would match both and throw on an ambiguous hit.

    Case one — confirming actually deletes. Open the detail screen, tap the bottom-bar delete
    trigger, pump, tap the dialog's `FilledButton` confirm action, `pumpAndSettle`, then assert
    the fake API recorded exactly one delete call and that the app has landed back on the
    safe-zones list (assert on a list-screen-only text such as its Add affordance, and that the
    detail screen's Assigned member row is gone).

    Case two — cancelling deletes nothing. Same setup, tap the bottom-bar delete trigger, pump,
    then tap the dialog's dismiss action (`Keep safe zone`), `pumpAndSettle`, and assert the
    fake API recorded zero delete calls and the detail screen is still on screen.

    Case three — Open Settings reaches the permission seam. Construct a permission-needing
    variant of the seeded zone with `copyWith` setting activation to
    `SafeZoneActivation.needsLocationPermission`, pass it as the `extra` on the detail push so
    the permission card renders, construct an explicit `FakeLocationPermissionService` and hand
    it to `_buildContainer` so the assertion can read its counter, tap the `Open Settings`
    control, `pumpAndSettle`, and assert the counter is exactly one.
  </action>
  <verify>
    <automated>cd mobile && flutter test test/features/geofencing/safe_zone_router_flow_test.dart</automated>
  </verify>
  <done>
    The router-flow suite contains three additional passing cases covering delete-confirmed,
    delete-cancelled, and open-settings. Reverting either handler added in Task 1 back to an
    unsupplied callback makes this suite fail. The three pre-existing cases in the file still
    pass unmodified.
  </done>
</task>

<task type="auto" tdd="false">
  <name>Task 3: Full-package analyze and test gate</name>
  <files>mobile/</files>
  <action>
    Run the whole mobile package's analyzer and test suite to confirm the additive changes to
    the shared `FakeLocationPermissionService` helper and to `safe_zones_page.dart` did not
    disturb any other suite that depends on them. Fix anything that surfaces without widening
    scope beyond the three files in `files_modified`.

    Then confirm the diff is contained: the change set must touch only
    `safe_zones_page.dart`, `fake_location_permission_service.dart`, and
    `safe_zone_router_flow_test.dart`. Any change reaching SOS, location tracking, geofence
    registration, the router table, or the backend means scope drifted and must be reverted.
  </action>
  <verify>
    <automated>cd mobile && flutter analyze && flutter test</automated>
  </verify>
  <done>
    `flutter analyze` is clean across the mobile package and `flutter test` is fully green.
    `git diff --name-only` lists exactly the three files in `files_modified`.
  </done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| user gesture → destructive mutation | A single visible control initiates an irreversible zone deletion that stops safety alerts. |
| mobile client → backend geofence API | `DELETE` crosses to `GeofencesController`, the authoritative authorization point (04-06). |
| app → OS settings surface | `Geolocator.openAppSettings()` hands control to a platform-owned screen outside the app's trust domain. |

## STRIDE Threat Register

| Threat ID | Category | Component | Severity | Disposition | Mitigation Plan |
|-----------|----------|-----------|----------|-------------|-----------------|
| T-AFT-01 | Repudiation | Delete outcome shown to the user | high | mitigate | The handler reads `GeofenceListState.error` after `deleteZone` and navigates to the list only when it is null; a failed or family-id-less delete shows the error via snackbar and stays on the detail screen. A false "deleted" impression would leave a user believing alerts stopped when they had not. |
| T-AFT-02 | Tampering | Zone id used for the delete call | medium | mitigate | The deleted zone is the `SafeZone` instance the screen already resolved and rendered, passed back through `onDeleteConfirmed`; no attacker-supplied path parameter is trusted, and `GeofencesController` re-authorizes family scope server-side. |
| T-AFT-03 | Denial of service | Accidental deletion via a single tap | medium | mitigate | `SafeZoneDetailScreen`'s existing `AlertDialog` gate is preserved verbatim and asserted by the delete-cancel test; the wrapper deliberately adds no bypass path that calls `deleteZone` without confirmation. |
| T-AFT-04 | Elevation of privilege | Non-guardian deleting a zone from the detail route | low | accept | `GeofencesController` enforces guardian authority server-side on delete; duplicating that as a client-side gate would add no security, consistent with the T-8R2-04 disposition on this same surface. |
| T-AFT-05 | Information disclosure | Error text surfaced in the delete snackbar | low | accept | The message is `GeofenceApiException.message` or the controller's own copy — the same strings already rendered by `SafeZonesScreen.error`; no new server detail reaches the UI. |
| T-AFT-SC | Tampering | npm/pip/cargo installs | high | mitigate | No package installs in this task. `geolocator`, `go_router`, `flutter_riverpod`, and `flutter_test` are all already resolved in `pubspec.lock`. |
</threat_model>

<verification>
1. `cd mobile && flutter analyze` — clean, with no `use_build_context_synchronously` diagnostic
   in `safe_zones_page.dart`.
2. `cd mobile && flutter test` — full mobile suite green, including the three new router-flow
   cases.
3. Read `safe_zones_page.dart`: `SafeZoneDetailScreen` is constructed with both
   `onOpenSettings` and `onDeleteConfirmed` supplied, and `safe_zones_page.dart` contains no
   `showDialog` call (the confirm gate stays in `safe_zone_detail_screen.dart`).
4. `git diff --name-only` lists exactly the three files in `files_modified` — no SOS,
   location-tracking, geofence-registration, router-table, or backend changes.
</verification>

<success_criteria>
- Confirming Delete zone on the detail screen deletes through `GeofenceListController.deleteZone`
  and returns to `/safe-zones`; cancelling deletes nothing.
- A failed or unresolvable delete reports the failure and does not navigate.
- Open Settings opens the OS app settings through `locationPermissionServiceProvider`.
- No duplicate confirmation dialog, no new screen, no new state management, and no new package.
- Automated router-level coverage exists for all three paths.
</success_criteria>

<output>
Create `.planning/quick/260814-aft-wire-up-delete-zone-and-open-settings-af/260814-aft-SUMMARY.md` when done
</output>
