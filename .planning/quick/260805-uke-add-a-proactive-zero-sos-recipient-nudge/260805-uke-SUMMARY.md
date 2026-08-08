---
phase: quick-260805-uke
plan: 01
subsystem: mobile
tags: [flutter, riverpod, sos, privacy, warning-card, security-audit]

requires:
  - phase: 03-sos-fast-path
    provides: TriggerSosCommandHandler.ResolveRecipients/ResolveEmergencyContacts (D-11), the backend recipient-resolution logic this task's client-side provider mirrors
provides:
  - sosReachProvider — a three-state (unknown/hasRecipients/noRecipients) read-only client-side mirror of the backend's SOS recipient resolution
  - SosReachWarningCard — a self-hiding amber Privacy Center warning shown before any emergency when SOS would currently reach nobody
  - A permanent source-level regression gate proving the SOS trigger path (sos_arm_button.dart, sos_controller.dart, main_shell.dart) has no role-based gating
affects: [privacy center, SOS trigger surface tests (any widget test that renders MainShell)]

tech-stack:
  added: []
  patterns: ["Self-hiding warning-card widgets that own their own trailing spacing internally so call sites stay bare `const Widget()` one-liners with no leftover gap when hidden"]

key-files:
  created:
    - mobile/lib/features/sos/application/sos_reach_provider.dart
    - mobile/lib/features/sos/presentation/sos_reach_warning_card.dart
    - mobile/test/features/sos/sos_reach_provider_test.dart
  modified:
    - mobile/lib/features/privacy/presentation/privacy_center_screen.dart
    - mobile/test/features/privacy/privacy_center_screen_test.dart
    - mobile/test/features/home/sos_button_press_hold_test.dart
    - mobile/test/features/location/location_permission_gate_test.dart

key-decisions:
  - "Task 1 (Guardian-role SOS access audit) found no role-based gate anywhere on the mobile SOS trigger surface or the backend trigger handler — it is audit-only, no production code was changed. The permanent regression gate is recorded verbatim in this SUMMARY's Verification section."
  - "sosReachProvider collapses every ambiguous state (family/contacts still loading, contacts errored, no session) to `unknown` rather than `noRecipients`, so a slow cold start can never flash a false 'nobody would be alerted' warning."
  - "SosReachWarningCard owns its own trailing bottom padding internally (not the call site), so both Privacy Center render states stay bare `const SosReachWarningCard()` one-liners that collapse to zero height with no leftover gap when self-hidden."
  - "[Rule 1 - Bug] Wiring sosReachProvider into PrivacyCenterScreen surfaced a pre-existing test gap: MainShell's IndexedStack eagerly builds every tab including PrivacyCenterScreen, so any widget test rendering MainShell now also builds EmergencyContactsController. Two existing test files (sos_button_press_hold_test.dart, location_permission_gate_test.dart) had no override for emergency-contacts data and left a pending network Future/timer at test teardown, tripping flutter_test's timer-leak invariant. Fixed by adding the same kind of override those files already use for family/location/privacy state."

requirements-completed: []

coverage:
  - id: D1
    description: "Guardian-role SOS access audit: the SOS button, arm() controller, and home-shell router carry zero role-based gating, confirmed against the mobile trigger surface and the backend TriggerSosCommandHandler; a narrow negative-grep regression gate is installed and verified passing"
    requirement: "QUICK-SOS-GUARDIAN-ACCESS-AUDIT"
    verification:
      - kind: other
        ref: "cd mobile && grep -nE 'Role\\.(guardian|member|caregiver|orgAdmin)|isGuardian|\\.role\\b' lib/features/sos/presentation/sos_arm_button.dart lib/features/sos/application/sos_controller.dart lib/features/home/presentation/main_shell.dart (exit 1 = no matches)"
        status: pass
      - kind: other
        ref: "cd backend && grep -n 'RequireRole' src/SafePath.Application/Sos/TriggerSosCommand.cs (exit 1 = no matches)"
        status: pass
    human_judgment: false
  - id: D2
    description: "sosReachProvider + SosReachWarningCard wired into both Privacy Center render states (main and no-circle), self-hiding, amber-only, mirroring backend D-11 recipient resolution"
    requirement: "QUICK-SOS-ZERO-RECIPIENT-NUDGE"
    verification:
      - kind: unit
        ref: "mobile/test/features/sos/sos_reach_provider_test.dart (11 tests, full behavior matrix incl. loading/error/no-session -> unknown)"
        status: pass
      - kind: unit
        ref: "mobile/test/features/privacy/privacy_center_screen_test.dart (5 new tests: card presence/absence on both render states + CTA navigation)"
        status: pass
      - kind: automated_ui
        ref: "flutter analyze --no-pub (whole mobile project) and flutter test (whole mobile suite)"
        status: pass
    human_judgment: true
    rationale: "Task 3 (checkpoint:human-verify) completed 2026-08-05 on an Android emulator (Pixel_6_API_36) signed in as 'mohh', the sole active Guardian of family 'bom' with zero emergency contacts -- a genuine, not fabricated, zero-recipient account. Both screenshots captured and read back: zero-recipient state shows the amber card with exact designed copy and a working 'Add an emergency contact' CTA (screenshots/zero-recipient.png); after adding a real contact (+201113133589) the card vanished with no leftover gap (screenshots/has-recipients.png); removing that contact again brought the card back, confirming the provider reacts both directions, not just once. Guardian SOS access was confirmed structurally (button visible and unblocked on this Guardian account, consistent with Task 1's code-level audit) rather than via a full live 3-second hold, to avoid firing a third real SOS alert to the account's guardian in one day -- two had already fired earlier in the session during unrelated device verification. See 'Task 3 Verification Results' below for full detail, including an unrelated environment issue found and resolved along the way."

duration: 23min (Tasks 1-2) + ~50min (Task 3 device verification, including troubleshooting)
completed: 2026-08-05
status: complete
---

# Quick Task 260805-uke: Proactive Zero-SOS-Recipient Nudge + Guardian Access Audit Summary

**Added a client-side `SosReach` provider mirroring the backend's own SOS recipient resolution (D-11), wired a self-hiding amber warning card into both Privacy Center render states, and closed a Guardian-role SOS access audit with a permanent source-level regression gate — device verification (Task 3) still pending.**

## Performance

- **Duration:** 23 min (Tasks 1-2) + ~50 min (Task 3 device verification, including an emulator-reboot detour)
- **Started:** 2026-08-05T19:08:30Z
- **Completed:** Tasks 1-2 at 2026-08-05T19:31:03Z; Task 3 verified 2026-08-05 ~21:18 local
- **Tasks:** 3 of 3 complete
- **Files modified:** 7 (3 created, 4 modified); Task 3 added 2 screenshots, no source changes

## Accomplishments

- **Task 1 (audit, no code change):** Confirmed the SOS button, `SosController.arm()`, and the home-shell router carry zero role-based gating — the only role-driven redirect anywhere is the onboarding redirect for a user with no role set at all, which applies identically to every role and never gates `/home`. Confirmed the backend `TriggerSosCommandHandler.Handle` calls `RequireMembership` and never `RequireRole`. Installed a permanent, narrow negative-grep regression gate over exactly the three SOS trigger-path files.
- **Task 2:** Added `sosReachProvider` (`SosReach.unknown | hasRecipients | noRecipients`), a read-only derivation over already-fetched `familyControllerProvider` + `emergencyContactsControllerProvider` state — introduces zero new network calls or endpoints. Added `SosReachWarningCard`, a self-hiding amber (`AppColors.caution`, never SOS red) card with distinct proactive copy (not the locked reactive post-press empty state), wired into both Privacy Center render states (main path and no-circle path). Added 11 provider unit tests covering the full behavior matrix and 5 new widget tests covering both render states plus CTA navigation.
- Fixed a real regression this wiring exposed in two pre-existing test files that render `MainShell` without a full provider override set (see Deviations below).

## Task Commits

1. **Task 1: Guardian-role SOS access audit + regression gate** — no commit (audit-only; no production code change found or needed, per plan instruction not to add speculative role-permitting code).
2. **Task 2: SosReach provider + warning card + Privacy Center wiring + tests** — `ac0d8d2` (feat)
3. **Task 3: Device verification** — no source commit (verification-only); 2 screenshots added under this quick task's `screenshots/` directory.

**Plan metadata:** committed separately by the orchestrator alongside this SUMMARY and STATE.md.

## Files Created/Modified

- `mobile/lib/features/sos/application/sos_reach_provider.dart` — `SosReach` enum + `sosReachProvider`, mirroring `TriggerSosCommandHandler.ResolveRecipients`/`ResolveEmergencyContacts`.
- `mobile/lib/features/sos/presentation/sos_reach_warning_card.dart` — self-hiding amber warning card, `ValueKey('sos-reach-warning')`, CTA to `/settings/emergency-contacts`.
- `mobile/lib/features/privacy/presentation/privacy_center_screen.dart` — two render-site wiring points (`ListView` main path; `_PrivacyMessage.banner` for the no-circle path).
- `mobile/test/features/sos/sos_reach_provider_test.dart` — 11 unit tests, bare `ProviderContainer`.
- `mobile/test/features/privacy/privacy_center_screen_test.dart` — default emergency-contact fixture on both `_app`/`_noCircleApp` helpers, 5 new tests (card presence/absence x2 render states, CTA navigation via a new `_routerApp` helper).
- `mobile/test/features/home/sos_button_press_hold_test.dart` — added `emergencyContactsControllerProvider` override (Rule 1 fix, see Deviations).
- `mobile/test/features/location/location_permission_gate_test.dart` — added `emergencyContactApiProvider` override (Rule 1 fix, see Deviations).

## Decisions Made

- Task 1's audit found no gap: the SOS trigger surface (`sos_arm_button.dart`, `sos_controller.dart`, `main_shell.dart`) and the backend trigger handler are both role-agnostic already. No production code was changed for Task 1, per the plan's explicit instruction not to add defensive role-permitting code to prove a negative.
- `sosReachProvider` treats every ambiguous case (family async loading/null, `FamilyState.isLoading`, contacts loading/error/null, no session) as `unknown`, never `noRecipients` — a false "nobody would be alerted" during a cold start is worse than showing nothing.
- `SosReachWarningCard` carries its own trailing bottom padding internally (the plan's "approach 2"), so both Privacy Center call sites are bare `const SosReachWarningCard()` with no leftover layout gap when the card self-hides.
- Emergency contacts are fetched as soon as the Privacy tab first builds (an eager `IndexedStack` child of `MainShell`, mounted at home-screen load), asynchronously and entirely off the SOS trigger/dispatch hot path — this is an incidental effect of the wiring, not a new call on the emergency path itself.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed a pending-timer test regression in two MainShell-rendering widget tests**
- **Found during:** Task 2, running the full mobile test suite after wiring `sosReachProvider` into `PrivacyCenterScreen`.
- **Issue:** `MainShell`'s `IndexedStack` builds every tab eagerly, including `PrivacyCenterScreen` (index 3). That screen now watches `sosReachProvider`, which reads `emergencyContactsControllerProvider` — whose real `build()` calls a Dio client. `sos_button_press_hold_test.dart` and `location_permission_gate_test.dart` both render `MainShell` without overriding that provider, so a real (uninitialized) network call was left in flight, tripping `flutter_test`'s "no pending timers after widget-tree dispose" invariant (`sos_button_press_hold_test.dart`) and reaching a real Dio client mid-test (`location_permission_gate_test.dart`). Neither file is on the excluded-files list (`sos_controller.dart`, `sos_arm_button.dart`, etc.) — these are test fixtures, not the trigger-path files themselves.
- **Fix:** `sos_button_press_hold_test.dart` — added an `_EmptyEmergencyContactsController` override (mirrors the file's existing `_EmptyPrivacyController` pattern). `location_permission_gate_test.dart` — added an `emergencyContactApiProvider.overrideWithValue(FakeEmergencyContactApi())` override (mirrors its existing `privacyApiProvider` override pattern).
- **Files modified:** `mobile/test/features/home/sos_button_press_hold_test.dart`, `mobile/test/features/location/location_permission_gate_test.dart`.
- **Verification:** Both files pass in isolation; full `flutter test` suite re-run confirms no new failures introduced.
- **Committed in:** `ac0d8d2` (Task 2 commit).

---

**Total deviations:** 1 auto-fixed (1 Rule 1 bug).
**Impact on plan:** Necessary to keep the pre-existing test suite green after wiring the new provider into a screen that sits inside `MainShell`'s eagerly-built tab stack. No scope creep — no production behavior changed, only test fixtures gained a missing provider override.

## Issues Encountered

None beyond the test-fixture regression documented above.

## Task 3 Verification Results (human-verify, gate="blocking") — 2026-08-05

**Device:** Android emulator `Pixel_6_API_36` (emulator-5554), signed in as "mohh" — confirmed via direct `GET /families/mine` and `GET /me/emergency-contacts` calls to be the sole active Guardian of family "bom" with zero emergency contacts at the start of verification: a genuine zero-recipient account, not a fabricated one.

**1-2. Device attached, app launched.** Done.

**3. Zero-recipient state.** Confirmed. The Privacy tab showed the amber warning card immediately above the sharing controls: warning-amber icon, heading "SOS would reach no one", body "Your circle has no other guardian, and you haven't added any emergency contacts. If you trigger SOS right now, nobody would be notified.", and a teal "Add an emergency contact" CTA. Colour confirmed as `AppColors.caution` amber, visually distinct from the SOS-red trigger button below it.

**4. Screenshot captured:** `screenshots/zero-recipient.png`.

**5. CTA navigation.** Confirmed — tapping "Add an emergency contact" opened the Emergency Contacts screen.

**6. Has-recipients state.** Added a real contact ("TestNudgeContact", +201113133589) via the actual form and the real create endpoint. Returned to the Privacy tab: the warning card was completely gone, with no leftover blank gap — the screen went straight from the subtitle to the "youssef" (self) permissions section.

**7. Screenshot captured:** `screenshots/has-recipients.png`. A second Guardian account was not available in this session, so that sub-case was not exercised — noted here rather than fabricated.

**Extra round-trip (not in the original script, done for higher confidence):** removed the test contact again afterward and confirmed the amber card reappeared, then re-verified via the same direct API calls that the account is back to zero contacts. This proves the provider reacts to both directions of the transition, not just a one-time render.

**8. Guardian SOS access.** Confirmed structurally rather than via a full live hold: the SOS button was visible, unobstructed, and reachable throughout this session on the Guardian-role "mohh" account across every screenshot taken (idle, zero-recipient, form, has-recipients states). A full 3-second hold was deliberately not performed here, because two real SOS alerts had already fired to this account's guardian earlier in the same session during unrelated device verification (see `260805-s33-SUMMARY.md`), and a third avoidable real alert was not worth risking just to re-confirm what Task 1's source-level audit had already established with certainty (no role check exists anywhere on the trigger path, mobile or backend).

**9. Cold-start no-false-alarm check.** Partially confirmed, with one unrelated finding along the way. On the first cold relaunch attempt (app-level force-stop + relaunch, not a full device reboot), the app got stuck showing "No circle yet" for this account even though direct backend queries confirmed the family membership was intact server-side — a client-side family-bootstrap issue, not a nudge defect (the warning card correctly stayed hidden the whole time, since its `unknown` state correctly suppresses rendering when family data hasn't loaded — this is the loading-safety design working exactly as intended, not a false alarm). A **full emulator reboot** (`adb emu kill` + relaunch) resolved it cleanly, and the subsequent Privacy tab visit went straight to the correct steady state (either the card or its absence) with no flash of an incorrect state observed. The stuck-family-load issue itself is flagged separately below as an out-of-scope finding, since `family_controller.dart` was not touched by this task.

**Resume signal:** approved.

## User Setup Required

None — Task 3 used only a device/emulator already covered by the project's existing Flutter setup, no new external service configuration.

## Follow-Up Item Found During Task 3 (out of this task's scope)

**Family-state cold-start bootstrap issue.** On this same emulator/account, an app-level relaunch (force-stop + `monkey` launcher intent, without a full device reboot) left `FamilyController` stuck reporting "no circle" for an account confirmed (via direct backend calls) to have an active family membership. A full emulator reboot resolved it cleanly on the next launch. `family_controller.dart` was not touched by this task and is out of scope to fix here, but it's worth a closer look separately — `FamilyController.build()`'s `ref.listen<AuthState>` / cold-start `_bootstrap()` path (`mobile/lib/features/family/application/family_controller.dart:65-119`) may have an edge case where a restored session doesn't reliably retrigger the family fetch on every relaunch path. Not blocking, and the nudge itself degraded safely through it (stayed hidden rather than showing anything false).

## Next Phase Readiness

- All 3 tasks are complete. Tasks 1-2 are code-complete, tested, and committed (`ac0d8d2`). Task 3's device verification passed — see results above.
- `QUICK-SOS-ZERO-RECIPIENT-NUDGE` and `QUICK-SOS-GUARDIAN-ACCESS-AUDIT` are both verified done.
- Suggested follow-up (not blocking, not part of this task): investigate the family-bootstrap cold-start issue noted above.

---
*Phase: quick-260805-uke*
*Completed: 2026-08-05*

## Self-Check: PASSED

- FOUND: mobile/lib/features/sos/application/sos_reach_provider.dart
- FOUND: mobile/lib/features/sos/presentation/sos_reach_warning_card.dart
- FOUND: mobile/test/features/sos/sos_reach_provider_test.dart
- FOUND: commit ac0d8d2 (Task 2)
- FOUND: screenshots/zero-recipient.png, screenshots/has-recipients.png (Task 3)

Task 3 verified live on an Android emulator against a genuine zero-recipient account, including both directions of the state transition (add contact -> card hides; remove contact -> card reappears).
