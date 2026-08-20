# Deferred Items — Quick Task 260820-5xp

Out-of-scope discoveries found during execution, logged per the Scope Boundary rule
(not fixed, not part of this plan's `files_modified`).

## Pre-existing failing test: `renders the battery percent when known`

- **File:** `mobile/test/features/location/live_member_marker_test.dart` (line ~181-207)
- **Symptom:** `expect(find.text('72%'), findsOneWidget)` fails — 0 widgets found.
- **Root cause:** `LiveMemberMarker` (in `live_map_screen.dart`) does not render any battery
  text/UI at all — it only builds an avatar pin + name label. `location.batteryPercent` is read
  elsewhere (passed into `MemberDetail` for the detail sheet on tap) but never displayed directly
  on the marker itself.
- **Verified pre-existing:** Reproduced this failure independently of every change in this quick
  task — it fails identically with the original unmodified `_PresenceDot` (`StatelessWidget`,
  `AppColors.bodySecondary`) restored, i.e. before any Task 1/2/3 edit. Most likely orphaned by
  commit `5782ce6` ("revert: restore original locked design system, undo Home Map redesign"),
  which reverted the Home Map redesign that had added battery display to the marker, without also
  reverting this test assertion.
- **Action taken:** None — out of scope for 260820-5xp (LOC-02 presence-color/pulse only). Left
  unfixed per the executor's scope-boundary rule. Flagging for a future quick task or phase pass
  to either wire battery display back into `LiveMemberMarker` or remove/update this stale
  assertion.

## Pre-existing failing test: splash -> Welcome -> Login routing

- **File:** `mobile/test/features/splash/splash_redirect_gate_test.dart`
  (test: "existing routing unchanged after splash: unauthenticated -> Welcome -> Login still works")
- **Symptom:** `expect(find.text('Welcome back.'), findsOneWidget)` fails after a tap on "I already
  have an account" that a hit-test warning reports as landing outside the 800x600 test viewport
  (`Offset(400.0, 651.0)` outside `Size(800.0, 600.0)`).
- **Verified pre-existing:** Reproduced in complete isolation
  (`flutter test test/features/splash/splash_redirect_gate_test.dart`), and the file has zero
  references to `app_colors.dart`, `live_map_screen.dart`, or `member_detail_sheet.dart` — the
  three files this quick task touches. Root cause looks like a pre-existing Welcome-screen
  layout/viewport issue (unrelated feature), not caused by this task.
- **Action taken:** None — out of scope for 260820-5xp. Flagging for investigation in a future
  quick task/phase.
