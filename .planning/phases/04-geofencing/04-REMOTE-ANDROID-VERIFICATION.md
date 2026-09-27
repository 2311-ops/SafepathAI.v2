# Remote Android Verification

Status: membership confirmed; 100m zone created; phone registration acknowledgement and movement pending. Applies to 04-05 and the Android portion of 04-17. A successful app launch or API request is not a boundary-crossing pass.

Latest setup at 17:56 UTC: existing zone `e8c005b1-4bd9-43ec-a845-9bf2acd56e45`, generation 1, assigned Member `f4026a11-435d-4eb6-8a74-c70ccb3caacc`. Center came from stationary Member's 17:52:16 UTC fix (16.5m accuracy, 250 seconds old). Requested cold reopen to fetch registration. Wait for exact-generation acknowledgement before process death or walking. Do not create a duplicate zone.

2026-09-27: Youssef Ghallab joined as Member; user reports OPPO A52 / Android 11. The friend is waiting before walking. Reopen the map, grant background location, and wait for a fresh accurate fix and server registration acknowledgement before movement. ADB availability and API level still need device evidence. Do not use the Guardian Samsung serial for the friend's commands.

## Join And Register

1. Install the current debug APK or build branch `phase/04-geofencing` using `start_mobile.md` section 6 and the current tunnel URL. Keep the backend PC awake and the tunnel running.
2. Sign in with the friend's own account, choose Member, and accept the test-circle invitation shared privately. Old-project accounts must register again or use Google.
3. Report the Member display name, Android model/version, and whether ADB is available on the friend's computer. The operator verifies membership in family `40bdffff-c601-47a1-9a8b-7394813dde56`.
4. The Guardian creates a 100 m zone assigned to that Member at their current test location. Record zone ID and registration generation. Grant precise and background location on the Member phone; leave notifications enabled for routine push acceptance.
5. Wait for the Member to fetch the registration and the backend to acknowledge the same generation. Do not start movement with a pending/inactive registration. Record the build commit, device/API, zone ID, generation, and acknowledgement time.

## Process-Death Run

Commands below run on the friend's computer. Replace `<device-id>` with that computer's `adb devices` result, not the Guardian's Samsung serial.

```powershell
adb devices -l
adb -s <device-id> shell getprop ro.product.model
adb -s <device-id> shell getprop ro.build.version.release
adb -s <device-id> shell getprop ro.build.version.sdk
adb -s <device-id> shell input keyevent KEYCODE_HOME
adb -s <device-id> shell am kill com.safepath.mobile
adb -s <device-id> shell pidof com.safepath.mobile
```

Record whether the PID is absent. If it remains, Android did not kill the process; do not call the run a process-death pass. Do not substitute force-stop, clear app data, remove permissions, or kill the SOS service.

Walk safely beyond the actual 100 m boundary and remain clearly outside. Avoid interpreting an ambiguous/poor-accuracy fix as a crossing. Keep the Flutter UI closed for the headless case. Correlate the event's UUID, request ID/generation, and timestamps with backend `/geofences/candidates` acceptance and persisted candidate records.

The following reads only the routine outbox; it does not read authentication preferences:

```powershell
adb -s <device-id> shell run-as com.safepath.mobile cat shared_prefs/safepath_geofence_outbox.xml
adb -s <device-id> logcat -d -v time -s GeofenceUploadWorker GeofenceBackgroundEngine WM-WorkerWrapper
```

A missing outbox file means no file is available, not a passed upload. An empty outbox alone cannot distinguish no event from an acknowledged upload. Match the same event ID in server evidence. Record worker success/failure and whether the Flutter UI was absent; do not rely on log tags that emitted no lines. Outbox data includes location, so exchange it privately and keep it out of git. Never share `FlutterSharedPreferences.xml`, bearer tokens, refresh tokens, or unrestricted device logcat.

## Offline Replay

1. With a registered zone, disable Wi-Fi and mobile data on the Member phone and cross a boundary. Keep GPS/location enabled.
2. Inspect the routine outbox and record the pending event ID. It must remain pending without network access.
3. Re-enable network and cold-launch SafePath. The operator correlates that event with authenticated Accepted/Duplicate handling and native acknowledgement.
4. Relaunch once more; verify the server has one candidate for that event ID and no duplicate activity/notification. Record times and observed outcomes.

## SOS And Remaining Android Checks

Coordinate a clearly announced test with the test Guardian before pressing SOS. While a routine candidate is pending, verify the existing SOS flow opens/responds immediately and the expected delivery path is independent. Record observed timing and session/event IDs. Do not send an unannounced emergency alert.

04-17 additionally requires clear-side dwell versus poor-accuracy suppression, one activity/feed/push, reboot recovery, permission-revoked inactive state, quiet-hours feed-now/push-later, notification tap routing, and accessibility checks. Record each as PASS, FAIL, or NOT RUN with evidence. The signed physical iPhone checklist in `04-17-PLAN.md` is separate and mandatory.
