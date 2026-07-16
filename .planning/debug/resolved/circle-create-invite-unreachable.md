---
status: resolved
trigger: "another workflow error i signed in with a guardian account but the real problem is i cant create a circle with qr-code etc and also when entering a memeber account i cant enter the code to be in the circle use /gsd-debug and /gsd-verify-work phase 2"
created: 2026-07-13
updated: 2026-07-13
---

# Debug Session: Create Circle / Enter Invite Code Buttons Unreachable

## Symptoms
- expected_behavior: A Guardian with no family yet should see a "Create a circle" entry point somewhere in the authenticated app that leads to `CreateCircleScreen` (QR code + invite flow). A Member with no family yet should see an "Enter invite code" entry point leading to `AcceptInviteScreen`.
- actual_behavior: User reports "there's no create a circle button" (Guardian) and "the enter a code isn't appearing" (Member) — confirmed via direct code read: both empty-family-state widgets (`_PrivacyMessage` in `privacy_center_screen.dart`, `_HistoryMessage` in `history_timeline_screen.dart`) render icon + title + body text only, with **no CTA button** to `/circle/create` or `/invite/accept`. `LiveMapScreen` doesn't even branch on family-null at all (shows a generic "No one to show yet" regardless of family state).
- error_messages: None — no crash, no error. The buttons/entry points simply don't exist in any reachable screen.
- timeline: Reported live during physical A30 testing on 2026-07-13, immediately after logging in as Guardian post the header/logout UI fix.
- reproduction: Sign in as a Guardian (or Member) with no family yet -> land on `/home` (MainShell) -> every tab that checks `familyId == null` (Privacy, Activity) shows an empty state with no way to create/join a circle. `LiveMapScreen` doesn't even show that prompt.

## Current Focus
- hypothesis: `CreateCircleScreen` (`/circle/create`) and `AcceptInviteScreen` (`/invite/accept`) are fully implemented and routable, but nothing in the reachable UI navigates to them. The only place that used to link to them was `landing_stub_screen.dart` ("Create a circle" / "Enter invite code" CTAs, confirmed by grep), which Phase 2's `02-06` commit made unreachable when it replaced `/home`'s destination widget with `MainShell` — the CTAs were never carried over to the new empty states, and the router's redirect logic has no auto-redirect to these routes based on `familyId == null` either.
- test: Add CTA buttons ("Create a circle" for Guardian role, "Enter invite code" for Member/other roles) to the no-family empty states in `PrivacyCenterScreen`, `HistoryTimelineScreen`, and `LiveMapScreen`, routing to `/circle/create` / `/invite/accept` respectively. Add widget tests asserting the CTA appears and navigates correctly per role.
- expecting: After the fix, a family-less Guardian sees a working "Create a circle" button from any tab's empty state that opens `CreateCircleScreen` (QR code generation); a family-less Member/Caregiver sees a working "Enter invite code" button that opens `AcceptInviteScreen`'s code entry field.
- next_action: Awaiting human verification on the physical A30 — sign in as a family-less Guardian, confirm "Create a circle" is now visible on the Map/Activity/Privacy empty states and opens the QR/name-your-circle flow; sign in as a family-less Member, confirm "Enter invite code" opens the code-entry screen and joining works end-to-end against the real backend.
- reasoning_checkpoint:
    hypothesis: "Family-less Guardians/Members cannot create or join a circle because the only UI that navigated to /circle/create and /invite/accept was the dead landing_stub_screen.dart _RoleEmptyState; the reachable no-family empty states (_PrivacyMessage, _HistoryMessage) render text only and LiveMapScreen never branches on family-null, so no reachable widget calls context.push to those routes."
    confirming_evidence:
      - "Direct re-read confirms _PrivacyMessage (privacy_center_screen.dart:548) and _HistoryMessage (history_timeline_screen.dart:406) build only Icon+Text+Text — no button, no navigation."
      - "LiveMapScreen.build (live_map_screen.dart) never watches familyControllerProvider; its only empty state is locations.isEmpty ('No one to show yet'), reachable with no family."
      - "app_router.dart routes /circle/create and /invite/accept exist and work; MainShell is /home's destination (no LandingStubScreen reference in the router). grep confirms the Create/Enter CTAs live only in the unrouted landing_stub_screen.dart."
      - "Both stale test files named in Evidence #6 fail today for exactly this reason: landing_role_flow_test.dart (4) and auth_flow_navigation_test.dart (4) assert against LandingStubScreen text that MainShell no longer renders."
    falsification_test: "After adding role-aware CTAs to the three empty states, a family-less Guardian widget-test tapping 'Create a circle' should land on CreateCircleScreen ('Name your circle'); a Member tapping 'Enter invite code' should land on AcceptInviteScreen ('You've been invited'). If either fails to appear or navigate, the hypothesis (pure wiring gap) is wrong."
    fix_rationale: "Restores the exact navigation the dead _RoleEmptyState provided (context.push to /circle/create for Guardian, /invite/accept for Member/other) but places it inside the reachable empty states, so the entry point exists wherever a family-less user lands in MainShell. This addresses the root cause (no reachable navigator to those routes) rather than a symptom."
    blind_spots: "Role is read from profileControllerProvider; if a user reaches /home with a null profile role the 'else' branch shows both CTAs (safe). Live-device confirmation on the A30 (real Supabase profile + backend createFamily/redeemInvite) is still user-verified, not covered by widget tests."
- tdd_checkpoint: "tdd_mode=false for this run; using standard fix + widget-test verification rather than a strict RED/GREEN gate."

## Evidence
- timestamp: 2026-07-13
  observation: `app_router.dart` redirect logic (lines 92-168) has branches for role onboarding (`/onboarding/role`) and invite deep-links (`pendingInviteProvider`), but no branch that sends an authenticated user with `familyId == null` to `/circle/create` or `/invite/accept` — family-circle routes are reachable only via explicit in-app navigation.
- timestamp: 2026-07-13
  observation: `_PrivacyMessage` (privacy_center_screen.dart, no-family branch) renders `Icon` + `Text(title)` + `Text(body)` only — no button, no `context.go(...)` call.
- timestamp: 2026-07-13
  observation: `_HistoryMessage` (history_timeline_screen.dart, no-family branch) — identical shape, no CTA.
- timestamp: 2026-07-13
  observation: `LiveMapScreen.build` never reads `familyControllerProvider` or checks for a null family at all; its only empty state is location-count-based ("No one to show yet"), reachable even when the user has no family.
- timestamp: 2026-07-13
  observation: `grep -rn "Create your family circle|Create a circle|Join a family circle" mobile/lib` matches only in `landing_stub_screen.dart` (dead code, no route references it — confirmed during the 02-VERIFICATION re-verification pass earlier this session) and `invite_member_screen.dart` (a downstream screen, not an entry point).
- timestamp: 2026-07-13
  observation: `CreateCircleScreen` (148 lines) and `AcceptInviteScreen` (211 lines, accepts `initialCode`/`initialLinkToken` query params) both exist, are registered at `/circle/create` and `/invite/accept`, and are substantial implementations — this is a wiring/reachability gap, not a missing-feature gap.
- timestamp: 2026-07-13
  observation: This explains the stale test debt found during the earlier 02-VERIFICATION re-verification pass today (`auth_flow_navigation_test.dart`, `landing_role_flow_test.dart` expecting "Create your family circle" / "Join a family circle" text) — those tests were asserting against the dead `landing_stub_screen.dart`'s CTAs, which is the same missing functionality this bug report describes from the live-device side.
- timestamp: 2026-07-13
  checked: Re-verified every claim against current source before fixing (privacy_center_screen.dart, history_timeline_screen.dart, live_map_screen.dart, app_router.dart, main_shell.dart, create_circle_screen.dart, accept_invite_screen.dart, landing_stub_screen.dart).
  found: All confirmed. `LandingStubScreen` is dead code (only self-references via `grep`, never routed). `MainShell` (`/home`) has tabs Map/Activity/SOS/Insights/Privacy; its Map tab (`LiveMapScreen`) is the default landing and has no family-null branch. `_RoleEmptyState` in landing_stub is the exact behavior to restore: Member -> context.push('/invite/accept') 'Enter invite code'; Guardian -> context.push('/circle/create') 'Create a circle'; else -> both.
  implication: Confirmed pure reachability/wiring gap. Fix = drop the same role-aware CTAs into the reachable empty states.
- timestamp: 2026-07-13
  checked: Ran the two stale test files to establish a RED baseline before changing code.
  found: `landing_role_flow_test.dart` 4/4 fail and `auth_flow_navigation_test.dart` 4/4 of the home-landing tests fail — all because MainShell renders where the tests still expect LandingStubScreen text ("Your circle" / "Create your family circle"). `privacy_center_screen_test.dart` and `history_timeline_screen_test.dart` currently pass.
  implication: These 8 failures are the same bug from the test side and become the regression coverage to convert RED->GREEN by pointing the tests at the new reachable CTAs.

## Eliminated

## Resolution
- root_cause: Phase 2's 02-06 change made `MainShell` the destination of `/home`, orphaning `landing_stub_screen.dart` whose `_RoleEmptyState` was the ONLY reachable UI that navigated to `/circle/create` (Guardian) and `/invite/accept` (Member/other). The reachable no-family empty states in `MainShell`'s tabs (`_PrivacyMessage`, `_HistoryMessage`) render text only, and `LiveMapScreen` (the default tab) never branched on family-null — so a family-less user had no reachable entry point to create or join a circle. Not a missing feature; `CreateCircleScreen`/`AcceptInviteScreen` and their routes exist and work.
- fix: Added a shared, role-aware `NoCircleCta` (`lib/shared_widgets/no_circle_cta.dart`) that reads the profile role and renders "Create a circle" -> context.push('/circle/create') for a Guardian, "Enter invite code" -> context.push('/invite/accept') for a Member, and both for any other/unknown role (Caregiver/OrgAdmin/null). Wired it into the three reachable no-family empty states: `_PrivacyMessage` (privacy_center_screen.dart) and `_HistoryMessage` (history_timeline_screen.dart) both gained an optional `action` slot rendered below the body; `LiveMapScreen` gained the family-null branch it previously lacked (watches `familyControllerProvider`, includes family-loading in the loading gate, and returns a `_MapMessage` with the CTA before the location-based empty state). This restores exactly the navigation the dead `_RoleEmptyState` provided, but wherever a family-less user actually lands in `MainShell`.
- verification: `flutter analyze` clean (0 issues). `flutter test` = 162/162 passing. New focused widget tests assert the correct CTA per role in all three empty states (privacy, activity, map) and, in `live_map_screen_test.dart`, tap the CTA through a real GoRouter to confirm navigation lands on `CreateCircleScreen` ("Name your circle") and `AcceptInviteScreen` ("You've been invited"). The 8 stale tests that had been failing since the LandingStubScreen->MainShell swap (landing_role_flow x4, auth_flow_navigation x4) plus splash_redirect_gate x1 were re-pointed at the new reachable CTAs and now pass; the Guardian/Member landing_role_flow tests additionally tap the CTA end-to-end through the real app router. Live-device confirmation on the A30 (real Supabase profile + backend createFamily/redeemInvite round trips) is still pending user verification.
- files_changed: [lib/shared_widgets/no_circle_cta.dart (new), lib/features/privacy/presentation/privacy_center_screen.dart, lib/features/location/presentation/history_timeline_screen.dart, lib/features/location/presentation/live_map_screen.dart, test/features/privacy/privacy_center_screen_test.dart, test/features/location/history_timeline_screen_test.dart, test/features/location/live_map_screen_test.dart (new), test/features/home/landing_role_flow_test.dart, test/core/router/auth_flow_navigation_test.dart, test/features/splash/splash_redirect_gate_test.dart]
