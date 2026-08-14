---
phase: quick-260814-kyg
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - mobile/lib/features/geofencing/presentation/safe_zones_screen.dart
  - mobile/lib/features/geofencing/presentation/safe_zones_page.dart
  - mobile/test/features/geofencing/safe_zone_flow_test.dart
  - mobile/test/features/geofencing/safe_zone_router_flow_test.dart
  - .planning/todos/pending/2026-08-14-geofencing-ui-audit-sections-b-e.md
  - GEOFENCING_UI_FIXES.md
  - safe_zones_screen.dart
autonomous: true
requirements: [GEO-01, DESIGN-01]

must_haves:
  truths:
    - "The /safe-zones list leads with a zone-overview map header that renders every zone as a category-colored circle, instead of opening straight into text cards."
    - "Each zone card shows a 42px category-tinted rounded icon tile — Home safe-green, School/University primary-teal, Workplace member-violet, Custom body-secondary — instead of one generic teal pin for every zone."
    - "Each zone card shows a per-zone enable/disable switch reflecting zone.isActive; with no toggle handler supplied the switch renders disabled, so it can never imply a persisted change it is unable to make."
    - "A zone in the needsLocationPermission state shows an amber caution row instead of a switch, because that state is not user-toggleable — and it uses caution amber, never SOS red."
    - "Each card's subtitle is a single '<radius> m · <member>' line, and the category wire enum is no longer printed anywhere in the UI."
    - "Cards render as surface white with a 1px hairline border and 16px radius, with no Material elevation/shadow."
    - "Exactly one add affordance exists on the populated list — the circular header control — and the second one that overlapped the last card's View activity button is gone."
    - "The list AppBar title reads 'Places & zones'."
    - "Every pre-existing SafeZonesScreen constructor (default/.empty/.error/.loading) and callback (onAdd/onOpen/onActivity/onRetry) still exists with an unchanged signature; onToggle and mapOverride are added as new optional params only."
    - "SafeZonesPage passes mapOverride through to the list screen, so router-level widget tests drive /safe-zones with the platform-view stand-in and the new map header cannot crash the route."
    - "flutter analyze reports no issues and the full mobile test suite passes."
    - "The unactioned audit findings (sections B–E) survive as a tracked pending todo before the handoff files are deleted, so deleting the scratch doc discards no outstanding work."
    - "Both root-level handoff files are gone from the repository working tree."
    - "The SOS pipeline, geofence detection/tracer logic, and all backend code are behaviourally untouched."
  artifacts:
    - file: mobile/lib/features/geofencing/presentation/safe_zones_screen.dart
      contains: "Places & zones"
    - file: mobile/lib/features/geofencing/presentation/safe_zones_screen.dart
      contains: "_ZonesOverviewMap"
    - file: mobile/lib/features/geofencing/presentation/safe_zones_screen.dart
      contains: "_CategoryTile"
    - file: mobile/lib/features/geofencing/presentation/safe_zones_screen.dart
      contains: "onToggle"
    - file: mobile/lib/features/geofencing/presentation/safe_zones_page.dart
      contains: "mapOverride"
    - file: mobile/test/features/geofencing/safe_zone_flow_test.dart
      contains: "250 m · Maya"
    - file: .planning/todos/pending/2026-08-14-geofencing-ui-audit-sections-b-e.md
      contains: "zone_activity_screen"
  key_links:
    - from: "SafeZonesPage"
      to: "SafeZonesScreen.mapOverride"
      via: "ref.watch(safeZoneMapOverrideProvider) passed on the list-screen call site, matching the editor/review/detail wrappers in the same file"
      pattern: "mapOverride: ref.watch(safeZoneMapOverrideProvider)"
    - from: "SafeZone.category"
      to: "_CategoryTile / MapCircle colorHex"
      via: "shared _categoryColor/_categoryHex/_categoryIcon switch expressions covering all five enum values exhaustively"
      pattern: "_categoryColor"
    - from: "SafeZone.isActive"
      to: "per-zone Switch value"
      via: "activation == SafeZoneActivation.active, with needsLocationPermission diverted to the caution row instead of a switch"
      pattern: "zone.isActive"
---

<objective>
Replace the drifted `safe_zones_screen.dart` with the corrected design-system
version from the geofencing UI audit, wire the `mapOverride` test seam through
`SafeZonesPage`, update and extend the widget/router tests the new structure
breaks, preserve the audit's unactioned sections as a tracked todo, and delete
the two root-level handoff scratch files.

Purpose: Phase 4's most-drifted screen was built as generic Material defaults
rather than against the locked design system, so it reads like a different app
than Phases 1–3. This closes section A of the audit.

Output: A `/safe-zones` list matching the hi-fi mockup (map header, category
tiles, per-zone switch, hairline cards, single add affordance), green
`flutter analyze` + full mobile test suite, and a clean repo root.
</objective>

<execution_context>
@$HOME/.claude/gsd-core/workflows/execute-plan.md
@$HOME/.claude/gsd-core/templates/summary.md
</execution_context>

<context>
@.planning/STATE.md

@safe_zones_screen.dart
@GEOFENCING_UI_FIXES.md
@mobile/lib/features/geofencing/presentation/safe_zones_screen.dart
@mobile/lib/features/geofencing/presentation/safe_zones_page.dart
@mobile/test/features/geofencing/safe_zone_flow_test.dart
@mobile/test/features/geofencing/safe_zone_router_flow_test.dart
</context>

<interface_contracts>
Verified against the real codebase during planning — do NOT re-derive, and do
NOT change any of these to make the new screen compile:

- `MapPoint(double lat, double lng)` — `mobile/lib/features/location/application/map_geometry.dart`
- `MapCircle({required id, required center, required radiusMeters, required colorHex, outlineOpacity = 0.40})`
  and `VectorMap({required initialTarget, required initialZoom, controller, markers = const [], circles = const []})`
  — `mobile/lib/features/location/presentation/vector_map.dart`
- `SafeZone.isActive` => `activation == SafeZoneActivation.active`;
  `SafeZone.copyWith({SafeZoneActivation? activation})` (activation is the ONLY
  field it accepts) — `mobile/lib/features/geofencing/data/geofence_models.dart`
- `SafeZoneCategory` has exactly five values: home, school, university,
  workplace, custom — the new file's switch expressions are already exhaustive.
- Every theme token the new file uses exists: `AppColors.safe`, `.primaryTeal`,
  `.memberViolet`, `.bodySecondary`, `.hairline`, `.surface`, `.appBg`,
  `.toggleOffTrack`, `.caution`, `.cautionBg`, `.cautionBorder`, `.cautionText`;
  `AppSpacing.sm/.xsMd/.md/.lg`.
- `safeZoneMapOverrideProvider` already exists at the top of
  `safe_zones_page.dart` and is already overridden with `const SizedBox.expand()`
  inside `safe_zone_router_flow_test.dart`'s `_buildContainer`.

DEFERRED BY DECISION — `onToggle` is left unwired (null) in this plan, so the
switches render disabled. `GeofenceListController.setActive` is NOT added here.
Reason (verified in the backend during planning, recorded so nobody re-derives
it): `PUT /families/{id}/geofences/{zoneId}` cannot express activation at all —
`SafeZoneDraft.toRequest()` emits no active field, `UpdateZoneRequest`/
`UpdateZoneCommand` have no Active member, `UpdateZoneCommandHandler` never
writes `zone.IsActive`, and it filters on `item.IsActive` so an inactive zone
404s. The only deactivation path is `ZoneCommandValidation.Deactivate`, shared
verbatim by BOTH `DisableZoneCommandHandler` and `DeleteZoneCommandHandler`, and
there is no re-activate command or endpoint anywhere. A toggle wired to
`update` would therefore be a switch that lies in both directions. The audit doc
itself sanctions this deferral ("If you'd rather defer this, leave `onToggle`
null — the switches render disabled and nothing breaks").
</interface_contracts>

<tasks>

<task type="auto">
  <name>Task 1: Land the corrected screen and wire the map test seam</name>
  <files>mobile/lib/features/geofencing/presentation/safe_zones_screen.dart, mobile/lib/features/geofencing/presentation/safe_zones_page.dart</files>
  <action>
Copy the corrected implementation from the repo-root `safe_zones_screen.dart`
into `mobile/lib/features/geofencing/presentation/safe_zones_screen.dart`,
replacing the current contents entirely. Keep the implementation exactly as
provided — it is already verified against the real types listed in
`<interface_contracts>`.

One edit to the copied file: the root file opens with a ~36-line handoff header
comment whose closing lines point at the audit doc being deleted in Task 3.
Replace that whole header block with a concise 6–8 line doc comment that keeps
the design rationale (map header, category-tinted tiles, per-zone toggle
control, one-line subtitle, hairline surface cards, single add affordance) and
carries no reference to the handoff document or its step numbers, so no dangling
pointer survives the cleanup. Do not restate the removed widget names in that
comment — describe the current design, not the diff.

Preserve verbatim: all four constructors (default/.empty/.error/.loading), the
`onAdd`/`onOpen`/`onActivity`/`onRetry` callbacks, and the two new optional
params `onToggle` and `mapOverride`. Do not add, rename, or reorder any
parameter.

Then, in `safe_zones_page.dart`, add `mapOverride: ref.watch(safeZoneMapOverrideProvider)`
to the `SafeZonesScreen(...)` call inside `_SafeZonesPageState.build` (the
populated-list return, around line 76). Place it alongside the existing
`onAdd`/`onOpen`/`onActivity`/`onRetry` arguments, matching exactly how
`SafeZoneEditorPage`, `SafeZoneReviewPage`, and `SafeZoneDetailPage` already
pass the same provider in that file. This is required, not cosmetic: without it
the new map header mounts a real native platform view and throws in every
router-level widget test.

Do NOT pass `onToggle` and do NOT add `setActive` to `GeofenceListController` —
see the DEFERRED BY DECISION note in `<interface_contracts>`. Leaving it null is
the intended, safe state: the switches render disabled.
  </action>
  <verify>
    <automated>cd mobile && flutter analyze 2>&1 | tail -5</automated>
    <automated>grep -c 'Places & zones' lib/features/geofencing/presentation/safe_zones_screen.dart</automated>
    <automated>grep -c '_ZonesOverviewMap\|_CategoryTile\|onToggle\|mapOverride' lib/features/geofencing/presentation/safe_zones_screen.dart</automated>
    <automated>grep -c 'mapOverride: ref.watch(safeZoneMapOverrideProvider)' lib/features/geofencing/presentation/safe_zones_page.dart</automated>
    <automated>grep -v '^//' lib/features/geofencing/presentation/safe_zones_screen.dart | grep -c 'FloatingActionButton'</automated>
    <automated>grep -v '^//' lib/features/geofencing/presentation/safe_zones_screen.dart | grep -c 'Chip'</automated>
    <automated>grep -c 'SafeZonesScreen.empty\|SafeZonesScreen.error\|SafeZonesScreen.loading' lib/features/geofencing/presentation/safe_zones_screen.dart</automated>
  </verify>
  <done>
`flutter analyze` reports no issues. The screen file contains the title
"Places & zones", the map-header and category-tile widgets, and both new
optional params; the comment-filtered greps for the removed floating-button and
status-chip constructs both return 0. All four named constructors are still
declared. `safe_zones_page.dart` passes the map override provider to the list
screen exactly once (4 total call sites across the file's four wrappers).
  </done>
</task>

<task type="auto">
  <name>Task 2: Repair and extend the widget and router tests</name>
  <files>mobile/test/features/geofencing/safe_zone_flow_test.dart, mobile/test/features/geofencing/safe_zone_router_flow_test.dart</files>
  <action>
The new screen structure breaks specific existing assertions. Fix exactly these,
then add the new coverage. Use the middle-dot character U+00B7 (`·`) in expected
subtitle strings — it must match the separator the screen emits.

In `safe_zone_flow_test.dart`, test "safe zones list renders empty, error, and
truthful cards":
  1. The populated `SafeZonesScreen(...)` case must now pass
     `mapOverride: const SizedBox.expand()`. Without it the header mounts a real
     native map and the test throws. The `.empty()`/`.error()` cases take no
     override and stay as-is (they short-circuit before the header).
  2. `find.text('Maya')` findsNWidgets(2) and `find.text('250 m')`
     findsNWidgets(2) are both now inside one merged subtitle — replace both
     with a single `find.text('250 m · Maya')` findsNWidgets(2).
  3. `find.text('Active')` findsOneWidget no longer exists (the read-only status
     label became a control). Replace with switch assertions: `find.byType(Switch)`
     findsOneWidget — only the active zone renders one, because the
     needsLocationPermission zone renders the caution row instead — and assert
     that switch's `value` is true and its `onChanged` is null, proving the
     disabled-when-unwired contract.
  4. `find.text('Location permission needed')` is now
     `'Location permission needed to activate'`. `find.text` matches the whole
     string, so update the literal.
  5. `find.text('Home')` findsNWidgets(2) and `find.text('View activity')`
     findsNWidgets(2) are unaffected — leave them.

Then add new coverage in the same file (new `testWidgets` cases, each passing a
`mapOverride` stand-in):
  - Map header: pass `mapOverride: const SizedBox.expand(key: Key('zones-map'))`
    and assert `find.byKey(const Key('zones-map'))` findsOneWidget, so the header
    is proven to render and to route through the seam.
  - Category tiles: build a list holding one home, one school, and one workplace
    zone and assert `find.byIcon(Icons.home_outlined)`,
    `find.byIcon(Icons.school_outlined)`, and `find.byIcon(Icons.work_outline)`
    each findsOneWidget — proving zones are no longer all one generic pin.
  - Toggle wired: supply an `onToggle` that records its `(zone, enabled)`
    arguments, tap the switch of an active zone, and assert the callback fired
    once with that zone's id and `enabled == false`.
  - Single add affordance: on a populated list assert
    `find.byType(FloatingActionButton)` findsNothing and
    `find.byIcon(Icons.add)` findsOneWidget.

In `safe_zone_router_flow_test.dart`:
  6. Test "/safe-zones renders the family's zones with a real member name":
     `find.text('Distinctive Maya')` is now part of the merged subtitle. The
     seeded zone has `radiusMeters: 100`, so assert
     `find.text('100 m · Distinctive Maya')` findsOneWidget. Keep the negative
     assertion but widen it to `find.textContaining('Family member')` findsNothing
     so the fallback string cannot hide inside the merged line.
  7. Test "create journey: list -> add -> review -> save calls create once":
     `await tester.tap(find.text('Add safe zone'))` on the populated list no
     longer resolves — that text used to come from the removed second add
     control, and the header control is now an icon behind a Semantics label.
     Change that tap to `find.byIcon(Icons.add)`, which is unique on the
     populated list (category tiles and the activity button use different
     icons). Leave the later `find.text('Add safe zone')` findsWidgets assertion
     alone — that one is the editor screen's own AppBar title and is unaffected.
  8. No other router test needs changing: `safeZoneMapOverrideProvider` is
     already overridden with `const SizedBox.expand()` in `_buildContainer`, and
     Task 1 makes the list screen consume it.
  </action>
  <verify>
    <automated>cd mobile && flutter test test/features/geofencing/safe_zone_flow_test.dart test/features/geofencing/safe_zone_router_flow_test.dart</automated>
    <automated>cd mobile && grep -c '250 m · Maya\|100 m · Distinctive Maya' test/features/geofencing/safe_zone_flow_test.dart test/features/geofencing/safe_zone_router_flow_test.dart</automated>
    <automated>cd mobile && grep -c "byIcon(Icons.add)" test/features/geofencing/safe_zone_router_flow_test.dart</automated>
    <automated>cd mobile && grep -c "byType(Switch)\|zones-map\|Icons.work_outline" test/features/geofencing/safe_zone_flow_test.dart</automated>
  </verify>
  <done>
Both geofencing test files pass. The stale assertions on the bare member name,
the bare radius, the removed status label, and the truncated permission string
are gone. New cases cover the map header, per-category icon tiles, the wired
toggle callback, the disabled-when-unwired switch, and the single add
affordance. The router create-journey drives the header add control by icon.
  </done>
</task>

<task type="auto">
  <name>Task 3: Preserve the unactioned audit findings, then delete the handoff files</name>
  <files>.planning/todos/pending/2026-08-14-geofencing-ui-audit-sections-b-e.md, GEOFENCING_UI_FIXES.md, safe_zones_screen.dart</files>
  <action>
This task only runs after Tasks 1 and 2 are green.

The audit doc being deleted contains four sections of work this task does NOT
implement — section B (`zone_activity_screen.dart`: zone-scoped header, the
missing per-zone enter/exit notification toggles, member avatars, entered-green
/ left-amber color coding), section C (`safe_zone_detail_screen.dart`: grouped
bordered container instead of five stacked cards, surfacing
`SafeZoneSensitivity.description` instead of the bare wire enum, de-emphasised
destructive action), section D (`notifications_screen.dart`: severity left-border
slot, enter/exit color coding, per-member avatar color), and section E
(cross-cutting: extract a shared `AppCard`, normalise the screen gutter to
`AppSpacing.screenGutter` = 24, make the university-shares-school-styling call
deliberate). Deleting the doc without capturing these would silently discard
that backlog.

So first create `.planning/todos/pending/2026-08-14-geofencing-ui-audit-sections-b-e.md`,
following the existing todo convention in that directory (see
`2026-08-11-flutter-ui-ux-polish-pass.md`): YAML frontmatter with `created`
(ISO 8601), `title`, `area: ui`, and a `files:` list naming the affected
screens, then a `## Problem` section. Transcribe sections B, C, D, E and the
audit's "Suggested order" steps 2–5 into the body, preserving the per-item
identifiers (B1–B6, C1–C4, D1–D3, E1–E3) so the findings stay individually
addressable. Record that section A was closed by this quick task, that B2
(per-zone enter/exit notification toggles) is the one genuinely functional gap
rather than presentation-only, and that none of it blocks Phase 5.

Then delete both root-level handoff files:
  - `GEOFENCING_UI_FIXES.md`
  - `safe_zones_screen.dart` (the repo-root copy, NOT the one now under
    `mobile/lib/features/geofencing/presentation/`)

Finally run the full mobile verification suite.
  </action>
  <verify>
    <automated>test ! -f GEOFENCING_UI_FIXES.md && test ! -f safe_zones_screen.dart && echo "root handoff files removed"</automated>
    <automated>test -f mobile/lib/features/geofencing/presentation/safe_zones_screen.dart && echo "screen still in place"</automated>
    <automated>grep -c 'zone_activity_screen\|safe_zone_detail_screen\|notifications_screen\|AppCard' .planning/todos/pending/2026-08-14-geofencing-ui-audit-sections-b-e.md</automated>
    <automated>cd mobile && flutter analyze 2>&1 | tail -5</automated>
    <automated>cd mobile && flutter test</automated>
  </verify>
  <done>
Neither root-level handoff file exists; the screen survives at its real path
under `mobile/lib`. A pending todo captures audit sections B–E with their
original item identifiers and flags B2 as the functional gap. `flutter analyze`
reports no issues and the entire mobile test suite passes.
  </done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| server JSON → SafeZone.fromJson | Untrusted zone payload (name, category, radius, coordinates) crosses into presentation |
| user tap → zone activation | A control implying a persisted state change to a safety feature |

## STRIDE Threat Register

| Threat ID | Category | Component | Severity | Disposition | Mitigation Plan |
|-----------|----------|-----------|----------|-------------|-----------------|
| T-kyg-01 | Tampering | Per-zone enable/disable switch | high | mitigate | `onToggle` is left null so switches render disabled. A switch wired to `PUT .../geofences/{id}` would not change `IsActive` server-side, so a guardian could believe a zone was muted (or re-enabled) when it was not — a safety-relevant false belief. Deferred until a real activation endpoint exists (see `<interface_contracts>`). |
| T-kyg-02 | Information disclosure | Zone-overview map header | low | accept | The header renders only zones the caller already fetched via `ListZonesQuery`, which is Guardian-gated server-side by `RequireRole`. No new data reaches the client. |
| T-kyg-03 | Denial of service | `_ZonesOverviewMap` mean-center reduce | low | accept | `reduce` is only reached from the non-empty branch (`zones.isEmpty` returns the empty state first), so the empty-list crash is structurally unreachable. Zone count is server-capped at 20 per family. |
| T-kyg-04 | Spoofing | Category-derived styling | low | accept | Category comes from an exhaustive five-value enum parsed by `_enumFromWire`, which throws on unknown values rather than silently defaulting — an unexpected wire value cannot masquerade as another category's color. |
| T-kyg-SC | Tampering | npm/pip/cargo installs | n/a | n/a | No package installs in this plan — no dependency is added, removed, or upgraded. |
</threat_model>

<verification>
- `cd mobile && flutter analyze` → no issues.
- `cd mobile && flutter test` → full suite green.
- `/safe-zones` renders: map header, per-category icon tiles, one-line
  "<radius> m · <member>" subtitles, hairline cards, one add control, and the
  title "Places & zones".
- Switches render disabled (no toggle handler wired) and the
  needsLocationPermission zone shows the amber caution row instead of a switch.
- `git status` shows the two root-level handoff files deleted and no stray copy
  of the screen left at the repo root.
- No file under `backend/`, `mobile/lib/features/sos/`, or the geofence
  detection/tracer path appears in the diff.
</verification>

<success_criteria>
- Section A of the geofencing UI audit is fully closed on `/safe-zones`.
- Every pre-existing `SafeZonesScreen` constructor and callback signature is
  unchanged; only `onToggle` and `mapOverride` were added.
- `SafeZonesPage` passes `mapOverride` on all four safe-zone route wrappers.
- `flutter analyze` clean; full mobile test suite passes.
- Audit sections B–E survive as a tracked pending todo.
- Both root-level handoff files are deleted.
</success_criteria>

<output>
Create `.planning/quick/260814-kyg-apply-corrected-safe-zones-screen-dart-f/260814-kyg-SUMMARY.md` when done.
</output>
