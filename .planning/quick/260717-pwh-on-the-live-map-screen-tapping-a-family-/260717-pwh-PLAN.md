---
phase: quick-260717-pwh
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - mobile/lib/features/location/presentation/live_map_screen.dart
  - mobile/test/features/location/live_map_screen_test.dart
autonomous: true
requirements: ["260717-pwh"]
must_haves:
  truths:
    - "Tapping a member's rail card recenters the FlutterMap camera on that member's exact LatLng (LiveLocation.lat/lng) at a fixed zoom of 17"
    - "Tapping a member's rail card no longer opens the member detail bottom sheet"
    - "Tapping a member's map marker pin (LiveMemberMarker.onTap) still opens the member detail bottom sheet — unchanged"
    - "The MapController is created in initState and disposed in dispose() with no leak"
  artifacts:
    - "mobile/lib/features/location/presentation/live_map_screen.dart (LiveMapScreen converted to ConsumerStatefulWidget holding a MapController)"
    - "mobile/test/features/location/live_map_screen_test.dart (rail-card-tap recenter + no-sheet widget test)"
  key_links:
    - "_MemberStatusRail.onMemberTap -> _mapController.move(LatLng(member.location.lat, member.location.lng), 17)"
    - "FlutterMap.mapController wired to the State-owned MapController"
    - "LiveMemberMarker.onTap -> showMemberDetailSheet (kept intact)"
---

<objective>
On the Live Map screen, redirect a tap on a family member's horizontal rail card (`_MemberStatusCard`, built by `_MemberStatusRail`) from opening the member-detail bottom sheet to panning the FlutterMap camera onto that member's exact live location. This gives two complementary interactions: marker-pin tap = details, rail-card tap = locate-on-map.

Purpose: Removes the redundant "both interactions open the same sheet" behavior and makes the rail a locate-on-map affordance.
Output: `LiveMapScreen` converted to a `ConsumerStatefulWidget` that owns a `MapController`; rail-card `onTap` recenters the map at zoom 17; a widget test proving the new behavior.
</objective>

<execution_context>
@$HOME/.claude/gsd-core/workflows/execute-plan.md
@$HOME/.claude/gsd-core/templates/summary.md
</execution_context>

<context>
@.planning/STATE.md

@mobile/lib/features/location/presentation/live_map_screen.dart
@mobile/lib/features/location/presentation/member_detail_sheet.dart
@mobile/test/features/location/live_map_screen_test.dart
@mobile/test/features/location/live_member_marker_test.dart

# Key facts for the executor:
# - flutter_map is ^8.0.0; latlong2 is ^0.9.0. NO animation helper package
#   (flutter_map_animations / flutter_map_animations-style) is a dependency.
#   Use plain `MapController.move(center, zoom)`. Do NOT add a pub dependency.
# - LiveMapScreen is currently `ConsumerWidget` with a single `build(context, ref)`.
#   The FlutterMap is built with `MapOptions(initialCenter: cameraTarget, initialZoom: 15)`
#   and currently has NO `mapController`.
# - The rail wiring lives at `_MemberStatusRail(members:..., onMemberTap: (member) => showMemberDetailSheet(...))`.
#   Each `_VisibleMember` exposes `.location` (a LiveLocation with `.lat` / `.lng`).
# - LiveMemberMarker.onTap already calls showMemberDetailSheet and MUST stay unchanged.
# - Static helpers `_memberColor` / `_memberName` are private statics on LiveMapScreen;
#   after the conversion they must still resolve (move them into the State class or
#   reference them via `LiveMapScreen._memberColor` — same-file private access is fine).
</context>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: Convert LiveMapScreen to a ConsumerStatefulWidget owning a MapController and recenter on rail-card tap</name>
  <files>mobile/lib/features/location/presentation/live_map_screen.dart</files>
  <behavior>
    - Rail card tap for a member recenters the map: MapController.move is invoked with LatLng(member.location.lat, member.location.lng) and zoom 17.
    - Rail card tap does NOT call showMemberDetailSheet.
    - Marker pin tap (LiveMemberMarker.onTap) still calls showMemberDetailSheet with unchanged MemberDetail payload.
    - MapController is created once in initState and disposed in dispose (only when the State created it).
  </behavior>
  <action>
Convert `LiveMapScreen` from `ConsumerWidget` to `ConsumerStatefulWidget` with a companion `_LiveMapScreenState extends ConsumerState<LiveMapScreen>`.

Add an optional constructor field annotated `@visibleForTesting` (import `package:flutter/foundation.dart`) named `mapController` of type `MapController?`, defaulting to null. This is a test seam so a test can own the controller and read its camera; production callers keep constructing `const LiveMapScreen()`.

In `initState`, set a `late final bool _ownsController = widget.mapController == null;` and `late final MapController _mapController = widget.mapController ?? MapController();`. In `dispose`, call `_mapController.dispose()` only when `_ownsController` is true, then `super.dispose()`. This prevents disposing a controller the test owns.

Move the entire existing `build(context, ref)` body into the State's `build(context)` verbatim, dropping the `WidgetRef ref` parameter (use the `ref` property available on `ConsumerState`). Keep the two private static helpers reachable: either move `_memberColor` and `_memberName` into `_LiveMapScreenState`, or reference them as `LiveMapScreen._memberColor` / `LiveMapScreen._memberName` — same-file private access is valid.

Wire the map to the controller: on the `FlutterMap`, add `mapController: _mapController` alongside the existing `options: MapOptions(initialCenter: cameraTarget, initialZoom: 15)`. Leave the initialZoom of 15 unchanged.

Change ONLY the rail wiring. Replace the `_MemberStatusRail`'s `onMemberTap` handler so it no longer opens the detail sheet and instead recenters the camera: `onMemberTap: (member) => _mapController.move(LatLng(member.location.lat, member.location.lng), 17)`. The fixed zoom 17 is tighter than the initial 15 so the tapped member's marker is clearly visible up close. Import for `LatLng` already exists (`package:latlong2/latlong.dart`).

Do NOT change `LiveMemberMarker`'s own `onTap` (the marker-pin path) — it must keep calling `showMemberDetailSheet` exactly as before. Do NOT add any pub dependency; use the built-in `MapController.move`.

To make the rail card individually targetable by the widget test, give each `_MemberStatusCard` a stable key. In `_MemberStatusRail.build`'s `itemBuilder`, pass `key: ValueKey('member-card-${members[index].location.userId}')` to `_MemberStatusCard`, and add `super.key` to the `_MemberStatusCard` constructor so it accepts the key.
  </action>
  <verify>
    <automated>cd mobile && flutter analyze lib/features/location/presentation/live_map_screen.dart</automated>
  </verify>
  <done>LiveMapScreen is a ConsumerStatefulWidget owning a MapController (created in initState, disposed in dispose only when State-created); FlutterMap uses that controller; the rail-card onTap calls _mapController.move(LatLng(lat,lng), 17) instead of showMemberDetailSheet; LiveMemberMarker.onTap is unchanged; each _MemberStatusCard carries a ValueKey('member-card-<userId>'); flutter analyze reports no new issues.</done>
</task>

<task type="auto">
  <name>Task 2: Add a widget test proving rail-card tap recenters the map and does not open the detail sheet</name>
  <files>mobile/test/features/location/live_map_screen_test.dart</files>
  <action>
Add one new `testWidgets` case to the existing `live_map_screen_test.dart`, reusing that file's established conventions: `_PopulatedFamilyController`, `_PopulatedLocationController` (which seeds self `self-user` at 30.0444/31.2357 and other `other-user` "Sam" at 30.0500/31.2400), `_SeededProfileController(Role.guardian)`, and the `GoogleFonts.config.allowRuntimeFetching = false` setup. Follow the existing populated-map test's pump strategy: use `await tester.pump(const Duration(milliseconds: 100))` (NOT `pumpAndSettle`, which hangs on flutter_map's unresolved network tile requests).

In the test, construct a `MapController` in the test body, register `addTearDown(controller.dispose)`, and inject it via `LiveMapScreen(mapController: controller)` inside the `MaterialApp(home: ...)`. Import `package:flutter_map/flutter_map.dart` (already imported), `package:latlong2/latlong.dart` if needed, and `package:mobile/features/location/presentation/member_detail_sheet.dart` for `MemberDetailSheet`.

Steps in the test:
1. Pump the injected-controller widget, then `pump(const Duration(milliseconds: 100))` to mount the FlutterMap.
2. Tap the other member's rail card by key: `await tester.tap(find.byKey(const ValueKey('member-card-other-user')));` then `await tester.pump();`.
3. Assert the camera recentred on Sam's exact live location at the tighter zoom, reading the injected controller's camera:
   - `expect(controller.camera.center.latitude, closeTo(30.0500, 1e-9));`
   - `expect(controller.camera.center.longitude, closeTo(31.2400, 1e-9));`
   - `expect(controller.camera.zoom, closeTo(17, 1e-9));`
4. Assert the card tap did NOT open the member detail sheet: `expect(find.byType(MemberDetailSheet), findsNothing);`.

Do not weaken or delete the existing tests. The marker-pin-still-opens-sheet guarantee is already covered by `live_member_marker_test.dart` ('tapping the marker invokes onTap'); this task only adds the rail-card behavior coverage.
  </action>
  <verify>
    <automated>cd mobile && flutter test test/features/location/live_map_screen_test.dart</automated>
  </verify>
  <done>A new test taps the 'other-user' rail card, asserts controller.camera.center is (30.0500, 31.2400) and zoom is 17 within 1e-9, and asserts no MemberDetailSheet is present; the full live_map_screen_test.dart suite passes.</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| (none new) | This change is client-side UI wiring only. No new inputs cross a trust boundary; the member LatLng already originates from the existing, authorized `LiveLocation` state rendered on the map. |

## STRIDE Threat Register

| Threat ID | Category | Component | Severity | Disposition | Mitigation Plan |
|-----------|----------|-----------|----------|-------------|-----------------|
| T-pwh-01 | Information Disclosure | Rail-card recenter revealing a member's precise location | low | accept | The exact LatLng is already displayed as the member's marker on the same screen; recentering exposes nothing not already shown to this authorized viewer. |
| T-pwh-02 | Denial of Service | Resource leak from an undisposed MapController | low | mitigate | MapController is disposed in `dispose()` (guarded by `_ownsController`), preventing a per-screen leak. No package installs (no T-pwh-SC supply-chain threat). |
</threat_model>

<verification>
- `cd mobile && flutter analyze lib/features/location/presentation/live_map_screen.dart` reports no new issues.
- `cd mobile && flutter test test/features/location/live_map_screen_test.dart` passes, including the new rail-card recenter test and all pre-existing cases.
- `cd mobile && flutter test test/features/location/live_member_marker_test.dart` still passes (marker onTap path unchanged).
</verification>

<success_criteria>
- Tapping a member's rail card pans the map to that member's exact LatLng at zoom 17 and does not open the detail bottom sheet.
- Tapping a member's marker pin still opens the member detail bottom sheet.
- MapController is created in initState and disposed in dispose (no leak), and no new pub dependency was added.
</success_criteria>

<output>
Create `.planning/quick/260717-pwh-on-the-live-map-screen-tapping-a-family-/260717-pwh-SUMMARY.md` when done
</output>
