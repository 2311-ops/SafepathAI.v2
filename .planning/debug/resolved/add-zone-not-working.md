---
status: resolved
trigger: "the add zone isnt working investegate and fix"
created: 2026-08-16
updated: 2026-08-20
---

## REOPENED 2026-08-16

Human verification came back **"Still broken"**. The user ran the backend on port 5059,
`adb reverse tcp:5059 tcp:5059`, signed in as **Guardian**, opened Places & zones, tapped '+' —
nothing happened. No navigation, no error.

That is the **backend-reachable** scenario, which the applied fix (surfacing `familyState.error`)
does NOT cover. The prior Resolution section below is therefore **premature and insufficient**:
it fixed a real but different bug (silent failure when the family load errors out).

The user reached "Places & zones" at all, which means `live_map_screen.dart:112`'s guardian gate
PASSED — so `profile`/`familyRole` resolved. Investigation must now target the path where the
family loads successfully and the '+' is still inert.

Approved side-actions from the checkpoint:
- Remove the `// TEMP DIAGNOSTIC — remove before commit` print in `geofence_api.dart:_mapError`.
- Leave the genuine "no circle yet" dead '+' as-is (explicitly out of scope).

## Symptoms

- Expected behavior: Tapping the '+' / Add Zone button on the geofencing/safe-zones screen opens the add-zone screen/flow.
- Actual behavior: Silent failure — nothing happens when tapping the Add Zone entry point. No error, no crash, no new zone.
- Failure point: Can't open the add-zone screen (fails before location picker or save step).
- Error messages/logs: None seen/checked yet.
- Timeline: Worked before, broke recently.
- Reproduction: Tap '+' / Add Zone button on the geofencing/safe-zones screen.

## Relevant context

- Current branch: phase/04-geofencing
- Git status shows uncommitted modification to `mobile/lib/features/geofencing/data/geofence_api.dart`
- Recent commits on this branch (most recent first):
  - 594cf8c docs(04-05): update physical verification handoff
  - 3b7ce81 fix(04-05): expose geofence background entrypoint from main
  - 2bb8b30 fix: stabilize safe zone location editor
  - 258bfd2 docs: confirm geofence whatsapp template
  - faf684c fix(mobile): make privacy center owner-only

## Current Focus

- hypothesis: CONFIRMED (round 2) — the backend serialises `sensitivity: "Conservative"`, a wire value the mobile `SafeZoneSensitivity` enum does not have (it uses `Reliable`). `_enumFromWire` throws, the whole zone-list load fails, `SafeZonesPage` renders `SafeZonesScreen.error(...)`, and that constructor hardcodes `onAdd = null` — so the '+' is inert.
- test: Intercepted the real device's HTTP traffic through a logging proxy (`adb reverse tcp:5059 tcp:5099`). Confirmed HTTP 200 with a valid body containing `"sensitivity":"Conservative"`.
- expecting: n/a — confirmed by direct observation of the live wire payload.
- next_action: Split `wireValue` (contract) from `label` (UI copy) on `SafeZoneSensitivity`; keep '+' live in the list-error state; remove the temp diagnostic print.

### reasoning_checkpoint (round 2)

```yaml
hypothesis: "The backend's SafeZoneSensitivity enum is `Conservative|Balanced|Responsive`; the mobile enum's wireValue set is `Reliable|Balanced|Responsive`. Any persisted zone with `Conservative` makes `_enumFromWire` throw ArgumentError inside `SafeZone.fromJson`. That ArgumentError is not a DioException, so it escapes `DioGeofenceApi.list`'s `on DioException` and is swallowed by `GeofenceListController.load`'s bare `catch (_)`, which sets the generic 'Couldn't load safe zones' error. `SafeZonesPage` then renders `SafeZonesScreen.error(...)`, whose named constructor hardcodes `onAdd = null` — so the header '+' is drawn gray and its onTap is null. Tapping it does nothing."
confirming_evidence:
  - "LIVE WIRE CAPTURE via logging proxy on the device's own adb-reverse tunnel: `GET /families/a16955a1.../geofences -> 200`, `auth=Bearer(1449)`, body contains `\"sensitivity\":\"Conservative\"` for zone a51cd0a6. The request SUCCEEDS — this is not a connectivity failure."
  - "backend/src/SafePath.Domain/Enums/SafeZoneSensitivity.cs declares `Conservative, Balanced, Responsive`. mobile geofence_models.dart:23 declares `reliable('Reliable')`. 'Conservative' matches nothing."
  - "geofence_models.dart:261 — `_enumFromWire`'s orElse is `throw ArgumentError('Unknown wire value: ...')`, i.e. a hard throw, not a fallback."
  - "Live device uiautomator dump of /safe-zones shows exactly: 'Couldn't load safe zones' + 'Try again' + a gray 'Add safe zone' control — the error state, reached WITH the backend up and family loaded."
  - "The same dump proves the family DID load and the guardian gate DID pass: 'Manage safe zones' is rendered on the map screen and the page navigated successfully."
falsification_test: "If the proxied GET had returned a non-2xx status, or a body with only Balanced/Responsive sensitivities, this hypothesis would be dead — the failure would be network/authz instead. Observed: HTTP 200 with `Conservative` present."
fix_rationale: "`wireValue` was doing double duty as both the backend contract AND the UI label (edit/review/detail screens all render `sensitivity.wireValue`). 04-UI-SPEC.md mandates the user-facing word 'Reliable', so renaming the wire value alone would regress the spec'd copy. Splitting the two — `wireValue: 'Conservative'` (matches the backend enum) and `label: 'Reliable'` (matches the UI spec) — fixes the contract at its source, which is what makes the list parse, the list render, and therefore the '+' live again. Separately, keeping '+' enabled in the list-error state removes the silent-dead-button failure mode for ALL future list errors, since failing to read zones never actually prevents creating one."
blind_spots:
  - "I could not read the app's own logs (the installed build is not debuggable), so the ArgumentError itself was never seen in a stack trace — it is inferred from the wire payload plus the enum definitions. The regression test closes this by asserting the throw directly."
  - "How `Conservative` got persisted is not fully traced: mobile sends `'Reliable'`, which the backend cannot bind either, so these zones were likely written by the 04-05 device-verification tooling (their names say so) or defaulted to ordinal 0. The write path is fixed by the same change, but I did not exercise a real create against the backend."
  - "`_enumFromWire` still hard-throws on any unknown value, so future backend enum drift will break the list the same way. Left as-is deliberately (out of scope) and flagged as an open item rather than silently made lenient."
  - "`SafeZoneCategory` was checked and does match the backend (Home/School/University/Workplace/Custom), so no second mismatch of this kind is currently live."
```

## Evidence

- checked: `mobile/lib/features/geofencing/presentation/safe_zones_screen.dart`
  found: The only add affordances are the AppBar circular InkWell (`onTap: onAdd`) and the empty-state `ElevatedButton(onPressed: onAdd)`. Named constructors `.empty()`, `.error()`, `.loading()` ALL hardcode `onAdd = null` (`.empty` accepts it but SafeZonesPage never passes it).
  implication: In loading / error / no-family states the '+' is a dead, gray (`AppColors.toggleOffTrack`) circle — tapping does literally nothing, no snackbar, no error. Matches "silent failure" exactly.

- checked: `mobile/lib/features/geofencing/presentation/safe_zones_page.dart` lines 54-86
  found: `onAdd: () => context.push('/safe-zones/add')` is only wired on the fully-loaded path (family != null AND not loading AND not (error && zones empty)).
  implication: Any list-load failure or missing family disables the add entry point.

- checked: `mobile/lib/features/geofencing/presentation/safe_zones_page.dart` lines 115-143 (`SafeZoneEditorPage`)
  found: `if (family == null) return const SafeZonesPage();` — the /safe-zones/add route renders the LIST screen when family is null.
  implication: Second silent-failure path — the route push succeeds but the user sees an identical-looking list screen.

- checked: `mobile/lib/core/router/app_router.dart` lines 274-318
  found: `/safe-zones/add` (line 296) is declared BEFORE `/safe-zones/:zoneId` (line 306); go_router matches in declaration order.
  implication: Route shadowing is NOT the cause. (candidate for Eliminated pending confirmation)

- checked: `git diff mobile/lib/features/geofencing/data/geofence_api.dart`
  found: Uncommitted TEMP DIAGNOSTIC `print('GEOFENCE_DIAG ...')` inside `DioGeofenceApi._mapError`.
  implication: A prior session was already chasing a Dio failure in the geofence API — supports the "list load fails -> error state -> onAdd null" chain.

- checked: `flutter test test/features/geofencing/` (full folder, 52 tests)
  found: Exactly one failure — `safe_zone_router_flow_test.dart` "create journey: list -> add -> review -> save calls create once". The add screen DOES open; the tap on "Review zone" does not navigate.
  implication: A second, independent regression exists in the add journey (see next entry). Not necessarily the user's reported symptom.

- checked: Diagnostic widget test dumping controller state through the create journey
  found: `route=/safe-zones/add`, `draft hasExplicitCenter=false center=0.0,0.0`, `validation.location='Choose a zone location before review.'`, `route after review tap=/safe-zones/add`, `snackbars=1`.
  implication: With no known location, `startNewDraft` leaves `hasExplicitCenter=false`, so `validateForReview()` blocks. Regression introduced by commit `2bb8b30` which added the `hasExplicitCenter` gate to `isReadyForReview`/`validateForReview` but did NOT update this router test. Real but distinct — it shows a snackbar, so it is not fully silent.

- checked: `git show 2bb8b30` (geofence_controller.dart, geofence_models.dart)
  found: Added `SafeZoneDraft.hasExplicitCenter`, `SafeZoneValidation.location`, and the `draft.hasExplicitCenter` clause in `isReadyForReview` + `validateForReview`.
  implication: Confirms "worked before, broke recently" for the review-step failure.

- checked: Physical device `R58M30TGNXV` (adb) — the same device from `.planning/phases/04-geofencing/.continue-here.md`
  found: Backend is NOT listening on port 5059 (`netstat` shows nothing). App launched; `uiautomator dump` of the home screen shows: "No circle yet" / "Create or join a family circle to see everyone on the map." / "Create a circle" / "I have an invite code".
  implication: **DIRECT OBSERVATION — on the user's actual device `familyControllerProvider` currently resolves to `family == null`** because the bootstrap `GET /families/mine` failed with a connection error. `FamilyApi._mapError` maps `DioExceptionType.connectionError` to a `FamilyApiException`, which `FamilyController._bootstrap` catches and stores as `error` while leaving `family` null.

- checked: `uiautomator` dump for a safe-zones entry point on the home screen
  found: No "Manage safe zones" / "Places" affordance is rendered at all. `live_map_screen.dart:112` gates it on `(familyRole ?? profile?.role) == Role.guardian`; with both null the control is hidden.
  implication: Confirms the whole geofencing surface degrades to dead/hidden affordances when family/profile fail to load, with no error shown anywhere.

- checked: `safe_zones_page.dart` lines 54-59 against the observed device state
  found: `if (family == null) return const SafeZonesScreen.empty();` — this branch discards `familyState.error` entirely and passes no `onAdd`.
  implication: **ROOT CAUSE CANDIDATE.** In the exact state the device is in, `/safe-zones` renders the cheerful "No safe zones yet" empty state with BOTH add affordances dead (`onAdd == null`): the header '+' is drawn gray (`AppColors.toggleOffTrack`) and the CTA `ElevatedButton(onPressed: null)`. Tapping either does nothing at all — no snackbar, no error, no navigation. This is an exact match for "Silent failure — nothing happens... No error, no crash" and "Can't open the add-zone screen".

### Round 2 (after reopen — backend running)

- checked: `adb devices` + `netstat` + `adb reverse --list`
  found: Device `R58M30TGNXV` attached; backend LISTENING on 127.0.0.1:5059 with live ESTABLISHED connections; `UsbFfs tcp:5059 tcp:5059` reverse tunnel active.
  implication: The user's environment claim is accurate. The earlier "backend down / family null" observation no longer holds — all round-1 device evidence is stale.

- checked: `uiautomator` dump of the live home screen
  found: Renders "Family map", "You, current location", "View notifications" AND **"Manage safe zones"**.
  implication: `live_map_screen.dart:112`'s guardian gate PASSES and the family loaded. The guardian-role gate is NOT a second failing gate — eliminated.

- checked: Tapped "Manage zones" (733,206) on the device, then dumped the resulting screen
  found: Screen contains ONLY: "Places & zones", "Back", "Add safe zone", **"Couldn't load safe zones"**, "Couldn't load safe zones. Check your connection and try again.", "Try again".
  implication: **The page is in the ERROR state, not the empty or loaded state.** `SafeZonesScreen.error()` hardcodes `onAdd = null`, so the '+' is gray and inert. This is the exact mechanism of the user's symptom — and it is on the ZONES side, not the family side, exactly as the reopen guidance predicted.

- checked: Live HTTP interception — started a Node logging proxy on host:5099 and re-pointed the device tunnel with `adb reverse tcp:5059 tcp:5099`, then tapped "Try again"
  found: `GET /families/a16955a1-7a2b-42d5-93b8-3e1a2b31ab46/geofences -> 200`, `auth=Bearer(1449)`, `content-type: application/json`, body = a valid JSON array of zones including `"sensitivity":"Conservative"`.
  implication: **The request SUCCEEDS.** The failure is entirely client-side, AFTER a 200 response — a deserialization throw, not a network or authz problem. The displayed "Check your connection" text is a red herring: `SafeZonesScreen.error()` hardcodes that message and ignores `listState.error`.

- checked: `backend/src/SafePath.Domain/Enums/SafeZoneSensitivity.cs` vs `mobile/.../geofence_models.dart:22-35`
  found: Backend = `Conservative, Balanced, Responsive`. Mobile = `reliable('Reliable'), balanced('Balanced'), responsive('Responsive')`.
  implication: **ROOT CAUSE.** `Conservative` matches no mobile wire value, so `_enumFromWire` (geofence_models.dart:261) throws `ArgumentError`. Not a `DioException`, so it bypasses `DioGeofenceApi.list`'s handler and is swallowed by `GeofenceListController.load`'s bare `catch (_)`.

- checked: `git log -L` on the mobile enum
  found: `reliable('Reliable')` has been wrong since the enum was created in `ff4f1f1 feat(04-12): add safe-zone draft controller` — it was never correct.
  implication: Explains "worked before, broke recently" WITHOUT a code regression: the list parsed fine while the family had zero zones. The moment the 04-05 device-verification zones (named "04-05 Guardian Device Verification 012517", "04-05 100m Verification Zone") were persisted with `Conservative`, every list load began throwing. The data changed, not the code.

- checked: All `wireValue` usages in mobile
  found: `wireValue` is ALSO the rendered UI label at `edit_safe_zone_screen.dart:260`, `review_safe_zone_screen.dart:123`, `safe_zone_detail_screen.dart:67`.
  implication: `wireValue` was doing double duty as contract + copy. That conflation is the underlying design flaw — someone picked the nicer word "Reliable" for the UI and silently broke the wire contract.

- checked: `.planning/phases/04-geofencing/04-UI-SPEC.md:59` and `04-12-PLAN.md:42`
  found: The spec mandates the user-facing label **"Reliable"** (default) with description "Wait for a clearer, sustained crossing".
  implication: The fix must keep "Reliable" on screen while sending "Conservative" on the wire — so the two concerns must be split into separate fields rather than renaming `wireValue`.

- checked: `backend/src/SafePath.Domain/Enums/SafeZoneCategory.cs` vs mobile `SafeZoneCategory`
  found: Both are Home/School/University/Workplace/Custom — exact match.
  implication: No second enum mismatch is currently live. Category needs no change.

## Eliminated

- hypothesis: go_router route shadowing — `/safe-zones/:zoneId` swallowing `/safe-zones/add`
  evidence: `/safe-zones/add` is declared at app_router.dart:296, before `/safe-zones/:zoneId` at :306; go_router matches in declaration order. The router test confirms `route=/safe-zones/add` after tapping '+' when family is loaded.
  timestamp: 2026-08-16

- hypothesis: `SafeZoneEditorPage`'s `if (family == null) return const SafeZonesPage();` fallback is what the user sees (push succeeds, list re-renders, looks like nothing happened)
  evidence: Unreachable in practice — when family is null the list page never wires `onAdd`, so the push that would hit this fallback can never be triggered. The dead button fires first.
  timestamp: 2026-08-16

- hypothesis: The create-journey "Review zone" block (missing explicit center) is the reported bug
  evidence: Diagnostic run shows it renders inline validation text AND a snackbar ("Choose a zone location before review."), so it is not a silent failure. It is stale-test debt from commit 2bb8b30, which added the location guard and updated two sibling test files but missed the router-flow test.
  timestamp: 2026-08-16

- hypothesis: Regression in the uncommitted `geofence_api.dart` change
  evidence: The only uncommitted change is an added `print` in `_mapError`; it alters no control flow.
  timestamp: 2026-08-16

- hypothesis: (ROUND 2) The failed family load / `familyState.error` path is the user's symptom
  evidence: With the backend up, the live device renders "Manage safe zones" on the map and navigates to "Places & zones" successfully — the family loaded and the guardian gate passed. The page lands in the ZONES error state instead. The round-1 fix is real but addresses a different failure mode.
  timestamp: 2026-08-16

- hypothesis: (ROUND 2) Guardian-role gating at `live_map_screen.dart:112` is a second failing gate
  evidence: `uiautomator` dump shows the "Manage safe zones" button rendered on the live map screen, and tapping it navigated to /safe-zones. The gate passes.
  timestamp: 2026-08-16

- hypothesis: (ROUND 2) A loading state that never resolves leaves `onAdd` permanently null
  evidence: The device renders the ERROR state ("Couldn't load safe zones" + "Try again"), not the loading spinner. `GeofenceListController.load` resolved and set `error`.
  timestamp: 2026-08-16

- hypothesis: (ROUND 2) The zone-list request fails on the network (connection/timeout/authz)
  evidence: Live proxy capture of the device's own traffic shows `GET /families/.../geofences -> 200` with a valid Bearer token and a well-formed JSON body. The request succeeds; the failure is post-response deserialization.
  timestamp: 2026-08-16

## Resolution

- root_cause: |
    `SafeZonesPage.build()` read `familyState.family` but discarded `familyState.error`. When the
    family-circle bootstrap failed, `FamilyController._bootstrap` recorded the error and left
    `family` null, so the page fell into `return const SafeZonesScreen.empty()`. That named
    constructor hardcodes `onAdd = null`, which makes BOTH add affordances inert — the header
    '+' InkWell (`onTap: null`, drawn gray) and the empty-state CTA
    (`ElevatedButton(onPressed: null)`). The result was a cheerful "No safe zones yet" screen
    where tapping Add Zone produced no navigation, no snackbar and no error, and where the zone
    list was never even requested. A failed load was indistinguishable from "you have no zones".

- fix: |
    `mobile/lib/features/geofencing/presentation/safe_zones_page.dart` — when `family == null`,
    branch on `familyState?.error`: render the existing `SafeZonesScreen.error(onRetry:)` state
    (visible message + working "Try again") when a load error is present, and keep
    `SafeZonesScreen.empty()` only for the genuine "no circle yet" case. Added `_retryFamily()`
    which calls `familyControllerProvider.notifier.refresh()`; once that succeeds the widget
    rebuilds with a non-null family and the existing `_load` issues the zone fetch.

    Separately repaired the stale create-journey test in
    `mobile/test/features/geofencing/safe_zone_router_flow_test.dart`, which commit 2bb8b30 broke
    by adding the `hasExplicitCenter` guard without seeding a location. It now seeds a member
    location (mirroring `safe_zone_editor_test.dart`'s convention) and asserts
    `draft.hasExplicitCenter`.

- verification: |
    - New regression test "a failed circle load surfaces an error with a working retry instead of
      a silent empty state with a dead add button" fails on the old code path and passes now.
    - `flutter test test/features/geofencing/safe_zone_router_flow_test.dart` — 8/8 pass
      (was 7 pass / 1 fail).
    - `flutter analyze lib/features/geofencing test/features/geofencing` — no issues.
    - Full suite: 449 tests, 1 failure — `test/features/location/live_member_marker_test.dart:
      renders the battery percent when known`, confirmed PRE-EXISTING by re-running it with these
      changes stashed. Unrelated to geofencing.
    - NOT yet verified on the physical device: `/safe-zones` is unreachable from home while the
      backend is down (`live_map_screen.dart:112` gates the entry point on guardian role, which
      also comes from the backend). Needs human verification with the backend running.

- files_changed:
  - mobile/lib/features/geofencing/presentation/safe_zones_page.dart
  - mobile/test/features/geofencing/safe_zone_router_flow_test.dart

## Round 2 Resolution (2026-08-20)

- root_cause: |
    Confirmed by live wire capture (see Round 2 evidence above): the backend's
    `SafeZoneSensitivity` enum spells its least-sensitive option `Conservative`;
    the mobile enum's `wireValue` set was `Reliable|Balanced|Responsive`. Every
    persisted zone with `sensitivity: "Conservative"` made `_enumFromWire`
    throw `ArgumentError` inside `SafeZone.fromJson`. That throw is not a
    `DioException`, so it bypassed `DioGeofenceApi.list`'s handler and was
    swallowed by `GeofenceListController.load`'s bare `catch (_)`, which set
    the generic "Couldn't load safe zones" error. `SafeZonesScreen.error()`
    (as it existed before this round) hardcoded `onAdd = null`, so the '+' was
    gray and inert — a second, independent silent-failure path from the one
    round 1 fixed.

- fix: |
    `mobile/lib/features/geofencing/data/geofence_models.dart` — split the
    single `wireValue` field on `SafeZoneSensitivity` into `wireValue`
    (`Conservative|Balanced|Responsive`, matches the backend contract) and
    `label` (`Reliable|Balanced|Responsive`, matches 04-UI-SPEC.md's mandated
    UI copy). Updated `review_safe_zone_screen.dart` and
    `safe_zone_detail_screen.dart` to render `.label` instead of `.wireValue`
    for the sensitivity display — `wireValue` is now send/parse-only and
    should never be rendered.

    `mobile/lib/features/geofencing/presentation/safe_zones_page.dart` — the
    list-load error branch now passes `onAdd: () => context.push('/safe-zones/add')`
    to `SafeZonesScreen.error(...)` alongside the existing `onRetry`, since the
    family IS resolved at that point — only reading existing zones failed, so
    creating a new one is still valid. `SafeZonesScreen.error()` already
    accepted an `onAdd` parameter from the round-1 fix, so no widget change
    was needed there.

    Removed the uncommitted `// TEMP DIAGNOSTIC — remove before commit` print
    in `geofence_api.dart`'s `_mapError` (the file now matches HEAD).

- verification: |
    - New regression tests in `safe_zone_router_flow_test.dart`: "a failed
      circle load surfaces an error with a working retry instead of a silent
      empty state with a dead add button" and "a failed zone-list load still
      lets the guardian add a zone" — both pass.
    - New `safe_zone_wire_contract_test.dart` (159 lines) locks `wireValue`
      to the backend's exact spelling (`Conservative|Balanced|Responsive`)
      and `label` to the UI-spec copy (`Reliable|Balanced|Responsive`)
      independently, so this class of drift fails loudly instead of silently
      breaking the list again.
    - `FakeGeofenceApi` gained `throwsOnList` to simulate the list-error path
      the two new router tests exercise.
    - `flutter analyze lib/features/geofencing test/features/geofencing`:
      No issues found.
    - `flutter test test/features/geofencing/`: 62/62 pass.
    - NOT yet re-verified on the physical device — the original report came
      from a real device; this round's evidence is a live wire capture plus
      the full local test suite, not a repeat physical-device tap-through.
      Recommend a quick human confirmation next time the device is at hand.

- files_changed:
  - mobile/lib/features/geofencing/data/geofence_models.dart
  - mobile/lib/features/geofencing/presentation/review_safe_zone_screen.dart
  - mobile/lib/features/geofencing/presentation/safe_zone_detail_screen.dart
  - mobile/lib/features/geofencing/presentation/safe_zones_page.dart
  - mobile/lib/features/geofencing/data/geofence_api.dart (reverted the temp diagnostic print, no net change vs HEAD)
  - mobile/test/features/geofencing/safe_zone_router_flow_test.dart
  - mobile/test/features/geofencing/safe_zone_wire_contract_test.dart (new)
  - mobile/test/helpers/fake_geofence_api.dart

## Open items for the user

- The genuine "no circle yet" state (family null, error null) still renders the same dead '+'.
  Left unchanged deliberately — a zone cannot belong to no circle, so this is pre-existing intended
  behaviour rather than part of this regression. Say the word if you want it to route to
  "Create a circle" instead.
- `FamilyController._bootstrap` assigns `family` only after BOTH `getMyFamilies()` and
  `listMembers()` succeed, so a `listMembers` failure discards an already-fetched circle and lands
  in exactly this null-family state. Not changed here; the fix makes it visible instead of silent.
- `_enumFromWire` still hard-throws on any unknown wire value. Left as-is deliberately (a future
  backend enum addition would break the list the same way) — flagged rather than silently made
  lenient. The new wire-contract test at least ensures this specific pair of enums can't drift
  again unnoticed.
- Recommend a physical-device tap-through of "Add safe zone" next time the device is available,
  to close the loop on the original human-reported symptom with a live re-test rather than test
  suite + wire capture alone.
