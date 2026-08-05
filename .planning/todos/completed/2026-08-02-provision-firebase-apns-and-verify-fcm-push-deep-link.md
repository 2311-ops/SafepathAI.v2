---
created: 2026-08-02T19:05:16.641Z
title: Provision Firebase/APNs and verify FCM push deep-link
area: verification
files:
  - .planning/phases/03-sos-fast-path/03-06-PLAN.md (Task 3 user_setup block)
  - backend/src/SafePath.Infrastructure/Push/FirebasePushSender.cs
  - mobile/lib/core/push/push_service.dart
---

## Problem

Phase 03-06 (FCM multi-device push with responder deep-link) has Tasks 1-2 of 3 code-complete and committed (`b887c35`, `40d5e0d`, `38733a4`) — backend multi-device token registry + FCM dispatcher arm, mobile `push_service.dart` token lifecycle/notification handling/deep-link, native Android/iOS platform wiring. Task 3 is a genuine `checkpoint:human-verify` gate that cannot be automated: it requires a real, provisioned Firebase/APNs project and physical (or emulator+real) devices to confirm a push notification actually deep-links into the responder screen from both backgrounded and terminated app states.

Nothing is provisioned in this environment yet. Backend currently falls back to `LoggingPushSender` and mobile falls back to a caught/logged `Firebase.initializeApp` failure — both degrade gracefully, but no real push has ever been sent or received. Until this is verified, plan 03-06 cannot get its SUMMARY.md, and Phase 03's Wave 5 (03-08, live-location streaming) — which depends on both 03-06 and 03-07 — stays blocked.

## Solution

Follow the 10-step verification script in `.planning/phases/03-sos-fast-path/03-06-PLAN.md`'s Task 3 `user_setup` block:

1. Create/confirm a Firebase project with Android + iOS apps registered.
2. Place `google-services.json` in `mobile/android/app/` and `GoogleService-Info.plist` in `mobile/ios/Runner/`.
3. Upload an APNs auth key to Firebase and enable the Push Notifications capability in Xcode.
4. Set `FIREBASE_PROJECT_ID`/`GOOGLE_APPLICATION_CREDENTIALS` for the backend and restart it — confirm the startup log names the Firebase push sender, not the logging one.
5. With two devices (or emulator + real device): sign in as a Guardian on device B, background/terminate it, trigger SOS from device A, confirm the heads-up notification arrives and tapping it deep-links into the Responder screen from BOTH backgrounded and terminated states, and confirm device A's delivery chip for device B moves Queued → Delivered.

Once verified (or if it fails), report back so a continuation agent can write `03-06-SUMMARY.md` and close the plan (STATE/ROADMAP/REQUIREMENTS updates).

## Resolution (2026-08-05)

Android half closed. Firebase provisioned; real FCM push confirmed delivered to a terminated
Guardian device and deep-linked into `ResponderAlertScreen`; delivery status confirmed
Queued -> Delivered -> Acknowledged via a direct `GET /sos/{id}` server read. Automated suites
(`PushFanOutTests` 9/9, `push_service_test.dart` 8/8) re-confirmed green. See
`.planning/phases/03-sos-fast-path/03-06-SUMMARY.md` for full evidence.

**Not resolved:** iOS/APNs (no Apple Developer enrollment yet) and the D-32 multi-device case
remain untested — do not treat NOTIF-03 as fully closed cross-platform.
