---
status: resolved
trigger: "Mobile app on emulator and physical device has a problem displaying data; UI says session expired."
created: 2026-08-05
updated: 2026-08-05
---

# Debug Session: session-expired-data-display

## Symptoms

- expected_behavior: "Authenticated users should see app data on emulator and physical device."
- actual_behavior: "Data does not display; app says session expired."
- error_messages: "session expired"
- timeline: "Reported during live emulator + physical device testing on 2026-08-05."
- reproduction: "Run the mobile app on emulator and physical device, navigate to data-backed screens after sign-in/session restoration."

## Current Focus

- hypothesis: "Physical device was running against an unreachable/wrong local API setup; backend was not listening on the app's expected dev URL and Android debug builds did not explicitly allow cleartext LAN HTTP."
- test: "Start backend on LAN, rebuild APK with API_BASE_URL=http://192.168.1.3:5059, install on emulator and physical device, then verify Profile and Live Map load data."
- expecting: "Backend receives authenticated requests and both devices render data instead of the session-expired message."
- next_action: "resolved"
- reasoning_checkpoint:
- tdd_checkpoint:

## Evidence

- timestamp: 2026-08-05T18:16+03:00
  observation: "Initial physical screenshot showed Profile screen with: Your session expired. Please log in again."
  artifact: ".planning/debug/artifacts/session-expired-physical.png"
- timestamp: 2026-08-05T18:17+03:00
  observation: "No process was listening on :5059 before backend start; app default Android API URL is http://10.0.2.2:5059, which is emulator-only and not reachable from a physical phone."
- timestamp: 2026-08-05T18:18+03:00
  observation: "Started SafePath.Api with launch profile http-lan; backend listened on http://0.0.0.0:5059 and logged FirebasePushSender active."
  artifact: ".planning/debug/artifacts/safe-path-api-http-lan.out.log"
- timestamp: 2026-08-05T18:20+03:00
  observation: "Built and installed debug APK with --dart-define=API_BASE_URL=http://192.168.1.3:5059 on emulator and physical device."
- timestamp: 2026-08-05T18:21+03:00
  observation: "Backend logs show authenticated EF queries, device-token registration, profile-image signed URL request, family/member reads, and location ping inserts."
- timestamp: 2026-08-05T18:21+03:00
  observation: "Fresh screenshots show Live Map data on both devices and Profile data on both devices. The session-expired message is gone."
  artifact: ".planning/debug/artifacts/session-expired-emulator-after.png; .planning/debug/artifacts/session-expired-physical-after.png; .planning/debug/artifacts/session-expired-emulator-profile-after.png; .planning/debug/artifacts/session-expired-physical-profile-after.png"

## Eliminated

- hypothesis: "Supabase session/token was genuinely expired on the physical device."
  reason: "After backend/API URL setup, the same installed app session produced authenticated backend queries and rendered Profile data."
- hypothesis: "Backend JWT validation rejected the current Supabase access token."
  reason: "Backend accepted authenticated requests and executed protected /me/family/location paths."

## Resolution

- root_cause: "Local device testing environment mismatch: backend was not listening on the dev API port, and the physical Android build needed a LAN-reachable API_BASE_URL instead of the emulator-only default. Debug/profile manifests also lacked explicit cleartext HTTP allowance for local http:// development."
- fix: "Started backend with the http-lan profile, built the debug APK with API_BASE_URL=http://192.168.1.3:5059, installed it on emulator and physical device, and added dev-only usesCleartextTraffic=true to Android debug/profile manifests."
- verification: "flutter build apk --debug succeeded; both devices installed successfully; screenshots confirm Live Map/Profile render real data; backend logs confirm authenticated protected endpoint/database activity."
- files_changed: "mobile/android/app/src/debug/AndroidManifest.xml; mobile/android/app/src/profile/AndroidManifest.xml; .planning/debug/session-expired-data-display.md"
