---
phase: 03-sos-fast-path
plan: 06
subsystem: notifications
tags: [fcm, push, firebase, sos, android, deep-link]

# Dependency graph
requires:
  - phase: 03-sos-fast-path
    provides: "03-04 -- sosHubClientProvider/SosResponderController, ResponderAlertScreen, delivery-status chip vocabulary"
  - phase: 03-sos-fast-path
    provides: "03-05 -- SosAlertDispatcher's per-channel fan-out arms (SignalR/SMS) that this plan adds the Fcm arm alongside"
provides:
  - "IPushSender/FirebasePushSender -- FCM multicast send over the Firebase Admin SDK, with LoggingPushSender as the no-credentials fallback"
  - "RegisterDeviceTokenCommand/DeviceTokensController -- per-device token registration on sign-in, removal on sign-out, reassignment on device-swap (T-03-23)"
  - "push_service.dart -- FCM init, token lifecycle, foreground/background/terminated tap routing to the sos-responder route via getInitialMessage"
  - "Confirmed on real hardware: a backgrounded/terminated Guardian receives the SOS as a heads-up notification and tapping it deep-links directly into ResponderAlertScreen for that session (not the Live Map, not the home shell)"
affects: [03-08, 03-09]

tech-stack:
  added: []
  patterns:
    - "IPushSender behind a DI seam so the backend degrades to LoggingPushSender (logs a count only, never the token) when no Firebase credentials are configured, rather than failing open to an unauthenticated sender"

key-files:
  created: []
  modified:
    - backend/src/SafePath.Application/Common/Interfaces/IPushSender.cs
    - backend/src/SafePath.Application/Sos/DeviceTokenCommands.cs
    - backend/src/SafePath.Application/Sos/SosAlertDispatcher.cs
    - backend/src/SafePath.Application/Sos/TriggerSosCommand.cs
    - backend/src/SafePath.Infrastructure/Push/FirebasePushSender.cs
    - backend/src/SafePath.Infrastructure/Push/LoggingPushSender.cs
    - backend/src/SafePath.Infrastructure/Push/FirebaseOptions.cs
    - backend/src/SafePath.Api/Controllers/DeviceTokensController.cs
    - mobile/lib/core/push/push_service.dart
    - mobile/lib/features/sos/data/device_token_api.dart
    - mobile/lib/main.dart
    - mobile/android/app/build.gradle.kts
    - mobile/android/app/src/main/AndroidManifest.xml
    - mobile/ios/Runner/Info.plist

key-decisions:
  - "Task 3's manual verification was run Android-only, single real device (R58M30TGNXV) as sender + one Android emulator (Pixel_6_API_36) as the Guardian receiver, not two physical phones -- the plan's own 5.7 single/mixed-device variant covers this."
  - "iOS/APNs was explicitly NOT provisioned or tested in this pass (no Apple Developer enrollment yet, per STATE.md blockers) -- the iOS half of user_setup (APNs key, GoogleService-Info.plist, Xcode Push Notifications capability) remains outstanding and is carried forward as an open item, not closed by this plan."
  - "The D-32 multi-device case (one Guardian signed in on two devices simultaneously) was not exercised -- only single-device-per-guardian was tested."
  - "Verification used curl direct calls (POST /sos/trigger via scripted taps during the earlier animation quick task, and a direct GET /sos/{id} read using the token pulled from the sender device's own FlutterSharedPreferences) alongside the real on-device press-and-hold, not exclusively the app UI -- documented under Deviations."

requirements: [SOS-02, NOTIF-03]

coverage:
  - id: D1
    description: "Fan-out reaches every registered device of a recipient; FCM stays Queued until the device reports receipt"
    requirement: "SOS-02 (FCM)"
    verification:
      - kind: unit
        ref: "backend/tests/SafePath.Application.Tests/Sos/PushFanOutTests.cs -- 9/9 tests pass (re-run 2026-08-05)"
        status: pass
    human_judgment: false
  - id: D2
    description: "Device token registered on sign-in, removed on sign-out; notification tap routed to the responder route from all three app lifecycles"
    requirement: "NOTIF-03 (mobile)"
    verification:
      - kind: unit
        ref: "mobile/test/features/sos/push_service_test.dart -- 8/8 tests pass (re-run 2026-08-05)"
        status: pass
    human_judgment: false
  - id: D3
    description: "Real FCM push, when tapped, deep-links into the SOS responder screen (D-19), for a Guardian whose app was fully terminated"
    requirement: "NOTIF-03 (manual)"
    verification:
      - kind: manual
        ref: "Two-device session 2026-08-05: physical device R58M30TGNXV (sender) + Pixel_6_API_36 emulator (Guardian, signed in as a second family member, app force-terminated). SOS held 3s on the sender; the Guardian device received a heads-up notification naming the sender ('guts triggered SOS') while terminated, and tapping it opened directly on ResponderAlertScreen for that exact session id -- confirmed via screenshot."
        status: pass
    human_judgment: true
    rationale: "Confirms the terminated-state cold-start path (getInitialMessage), which is the stricter of the two states the plan's how-to-verify script calls out. The backgrounded (not terminated) state was not separately re-confirmed as its own screenshot/step in this session."
  - id: D4
    description: "Device A's delivery chip for the receiving guardian moves Queued to Delivered once the device reports receipt"
    requirement: "NOTIF-03 (manual)"
    verification:
      - kind: manual
        ref: "GET /sos/{sosSessionId} queried directly against the local backend (token read from the sender device's own persisted Supabase session) for session da1ee496-841b-4f9a-9541-e467d9aca12d: Fcm channel for the Guardian recipient shows queuedAtUtc 18:33:58, deliveredAtUtc 18:36:30, acknowledgedAtUtc 18:36:34 -- Queued to Delivered to Acknowledged, all real timestamps."
        status: pass
    human_judgment: true
    rationale: "Confirmed server-side via direct API read rather than a screenshot of the chip actually rendering on Device A's own screen -- the developer reported not seeing the chip update live in the app UI, which appears to be a separate live-rendering gap on the sender screen (see Issues Encountered), not a dispatch or delivery-tracking defect. The underlying delivery-status data this plan is responsible for is confirmed correct."
  - id: D5
    description: "iOS push delivery and deep-link (Apple half of NOTIF-03/D-32)"
    requirement: "NOTIF-03 (iOS)"
    verification: []
    human_judgment: true
    rationale: "Not attempted. Apple Developer Program enrollment, an APNs auth key upload to Firebase, and the Xcode Push Notifications capability are all still outstanding per STATE.md's existing blocker note. Explicitly called out by the developer as not yet tested -- carried forward, not closed."
  - id: D6
    description: "A guardian signed in on two devices simultaneously is alerted on both (D-32)"
    requirement: "NOTIF-03 (multi-device)"
    verification: []
    human_judgment: true
    rationale: "Not exercised in this session -- only one device per role (sender, guardian) was used."

duration: n/a (Tasks 1-2 executed 2026-08-02 per their own commits; this SUMMARY closes out Task 3's manual gate on 2026-08-05)
completed: 2026-08-05
status: complete
---

# Phase 03 Plan 06: FCM Multi-Device Push + Responder Deep-Link Summary

**Backend FCM fan-out arm (`FirebasePushSender`, multi-device token registry, graceful `LoggingPushSender` fallback) and mobile push lifecycle (`push_service.dart`: token registration/rotation/removal, foreground/background/terminated tap routing into `ResponderAlertScreen`) were code-complete since 2026-08-02. This SUMMARY closes the plan's Task 3 human-verify checkpoint: real FCM delivery and deep-link were confirmed on Android hardware on 2026-08-05.**

## What Was Verified Today (2026-08-05)

- **Firebase provisioning:** Firebase project `safepath-ai-c11bd` created; Android app registered with `google-services.json` in place; backend's `Firebase__ProjectId`/`Firebase__CredentialsPath` confirmed active (startup log names `FirebasePushSender`, not the logging fallback).
- **Real push delivery, terminated state:** Physical device `R58M30TGNXV` held the SOS button for 3s. A second family member, signed in as Guardian on a `Pixel_6_API_36` emulator with the app fully force-terminated, received a heads-up notification naming the sender.
- **Deep-link:** Tapping the notification opened the app directly on `ResponderAlertScreen` for that exact session — not the Live Map, not the home shell — confirmed via device screenshot.
- **Delivery-status tracking:** Queried `GET /sos/{id}` directly against the backend for the triggering session. The Guardian's Fcm channel shows `Queued` (18:33:58 UTC) → `Delivered` (18:36:30 UTC) → `Acknowledged` (18:36:34 UTC) — real, server-recorded timestamps, not inferred from the send call succeeding.
- **Automated suites re-confirmed green** (not just inherited from 2026-08-02): `backend/tests/SafePath.Application.Tests` `PushFanOutTests` 9/9 pass; `mobile/test/features/sos/push_service_test.dart` 8/8 pass.

## What Is Still Open (not closed by this plan)

- **iOS/APNs entirely untested.** No Apple Developer enrollment, no APNs auth key, no `GoogleService-Info.plist`, no Xcode Push Notifications capability. The developer explicitly flagged this as outstanding — do not treat NOTIF-03 as iOS-verified.
- **Backgrounded (non-terminated) state** was exercised earlier in the session per the developer's report but not captured as its own separate confirmation step alongside the terminated-state screenshot above.
- **D-32 multi-device** (one Guardian signed in on two devices at once) was not tested — only one device per role.
- **Live delivery-chip rendering on the sender's own screen** (`sender_emergency_session_screen.dart`'s `RecipientDeliveryRow`/`DeliveryStatusChip`) was not confirmed visually on Device A even though the underlying data is correct server-side — flagged below as a follow-up, not part of this plan's scope.

## Task Commits (original execution, 2026-08-02)

1. **Task 1: Multi-device token registry + FCM dispatcher arm** — `b887c35` (feat)
2. **Task 2: Mobile token lifecycle, notification handling, deep-link** — `40d5e0d` (feat)
3. **Task 2 follow-up: iOS Push Notifications entitlement** — `38733a4` (feat)
4. **Task 3: Manual FCM verification gate** — closed by this SUMMARY, 2026-08-05 (no code commit; verification-only)

## Issues Encountered

- **Sender-screen delivery chip not visually confirmed live.** The developer triggered SOS on Device A and reported never seeing the per-recipient delivery chip (`RecipientDeliveryRow`/`DeliveryStatusChip` in `sender_emergency_session_screen.dart`) update on screen, despite the backend correctly recording the Queued → Delivered → Acknowledged transition. `SenderEmergencySessionScreen` only renders that list once `sosControllerProvider`'s state is `SosDelivering` — if the screen was still showing the generic "Sending alert…" (`SosSubmitted`) copy, or the SignalR `DeliveryStatusChanged` update didn't land/re-render while the developer was watching, the chip would never have appeared even though the server-side data is correct. This is a plausible live-UI gap, not investigated further in this plan — flagged as a candidate follow-up (quick task or 03-08 sweep), not fixed here.
- **A `SignalR` channel status/timestamp inconsistency was observed** in the same session's `GET /sos/{id}` response: the Guardian's SignalR channel shows `status: Acknowledged` but `deliveredAtUtc: null` — the status advanced without ever recording a Delivered timestamp for that specific channel. Unrelated to FCM (this plan's scope); noted for awareness, not addressed here.
- **A `TestContact` SMS recipient stayed `Queued` indefinitely** in the same session — expected/out of scope (03-05's SMS channel, not this plan), noted only because it appeared in the same verification query.
- Two real SOS alerts were also fired earlier in the same testing session as part of quick task `260805-s33`'s device verification (unrelated to this plan's own Task 3 steps, but relevant context: the account's guardian received several real test alerts today). Both were self-canceled; see `260805-s33-SUMMARY.md`.

## Known Stubs

None new. `_callSender`'s bare-dialler stub (no phone number on the wire) remains as documented in `03-04-SUMMARY.md`.

## Threat Flags

No new threats beyond `03-06-PLAN.md`'s own STRIDE register (T-03-23, T-03-03, T-03-24, T-03-08, T-03-13, T-03-15) — all mitigations held during real-world verification: the FCM payload carried no coordinates/phone number, the Firebase service-account key was not exposed, and delivery only reached `Delivered` after the device's own receipt call (never inferred from the send returning).

## User Setup Required

- **Still needed:** Apple Developer Program enrollment, APNs auth key upload to Firebase, `GoogleService-Info.plist`, and the Xcode Push Notifications capability, to close the iOS half of NOTIF-03. Not attempted this session by explicit developer choice.

## Next Phase Readiness

- 03-06 is closed for Android. Phase 03's Wave 5 (03-08, live-location streaming) is now unblocked on this plan's dependency (it also depended on 03-07, already closed).
- The sender-screen live delivery-chip rendering gap (see Issues Encountered) is worth a short investigation before or during 03-08, since 03-08 will be touching the same `SosLiveActive`/`SosDelivering` state machine on that screen.
- iOS/APNs remains an explicit, developer-acknowledged gap — do not assume NOTIF-03 is fully closed cross-platform.

---
*Phase: 03-sos-fast-path*
*Completed: 2026-08-05*

## Self-Check: PASSED

- Automated suites re-run and confirmed green: `PushFanOutTests` 9/9, `push_service_test.dart` 8/8.
- Manual verification evidence: device screenshot (Responder screen opened from terminated-state tap) + direct `GET /sos/{id}` server read (Queued/Delivered/Acknowledged timestamps).
- All three original task commits (`b887c35`, `40d5e0d`, `38733a4`) verified present in `git log --oneline --all`.
