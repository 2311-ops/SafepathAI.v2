# Generation 2 Registration: 2026-09-27

Status: code defect repaired; actual OPPO registration remains unverified pending rebuild.

## Evidence

- Zone `e8c005b1-4bd9-43ec-a845-9bf2acd56e45` is active at generation 2; its acknowledgement remains absent.
- The remote GET `/geofences/registration` at 18:32:05 UTC returned HTTP 200 with generation 2. No generation-2 acknowledgement request followed in the retained tunnel capture.
- User supplied OPPO diagnostics: fine/background location granted, secure location_mode=3, FINE_LOCATION app-op allowed, RUN_ANY_IN_BACKGROUND default allowed.
- No matching Geofencer error lines were supplied. The old native implementation did not log its failure callbacks; Dart stored errors in provider state without diagnostic output. Therefore the missing lines do not prove success.

## Patch

- Replaced immutable geofence PendingIntent with mutable behavior on Android 11 and explicit FLAG_MUTABLE on Android 12+. The broadcast still targets an explicit, non-exported receiver.
- Remove the legacy immutable PendingIntent registration before replacing the canonical set. Cancel its old token only after successful removal. Do not silently swallow removal failures or leave duplicate generations registered.
- Added SafePathGeofence native logs for remove/add success/failure, counts and numeric Google API status. No exception messages, coordinates, tokens, or stack traces are logged by this instrumentation.
- Added debug-only GeofenceRegistration stage/generation logs in Flutter. Errors log only type/platform code, not message/details.
- Moved capability checks into the existing exception handler so a platform failure becomes NeedsSync instead of an uncaught Future error. Acknowledgement is still gated on successful native replacement.

Google requires mutable geofencing callbacks: [GeofencingClient](https://developers.google.com/android/reference/com/google/android/gms/location/GeofencingClient). Numeric errors are defined by [GeofenceStatusCodes](https://developers.google.com/android/reference/com/google/android/gms/location/GeofenceStatusCodes). The immutable flag is a confirmed contract defect, but it has not been proven to be the sole cause of the OPPO acknowledgement stall.

## Verification

- Flutter geofencing + SOS suite: 168 passed.
- Focused registration/gateway suite: 11 passed.
- Android :app:testDebugUnitTest: BUILD SUCCESSFUL; XML reports 2 PendingIntent flag tests + 1 upload-worker test, zero failures/errors.
- Flutter analyze --no-pub: no issues after correcting three brace-style findings.
- Flutter debug APK with the current HTTPS tunnel and local env.json: built successfully. Existing plugin Kotlin/Gradle warnings remain non-blocking.
- Diagnostic regression tests check capability, native-replace and acknowledgement failures, no false successful acknowledgement, and absence of private exception details/coordinates/zone ID in diagnostic output.
- Native unit coverage checks flag policy, not real Play Services legacy-token migration. That path still requires device confirmation.

## Next

User approved push for friend rebuild. Stop the previous flutter run session if one exists, pull branch phase/04-geofencing and run a fresh debug build with the existing private env.json and current API URL. Native edits require reinstall/relaunch, not hot reload. This launch is setup, not process-death evidence.

Keep the friend at the generation-2 starting spot. Obtain the dedicated logs using the command in the remote checklist, then recheck exact-generation acknowledgement before attempting movement. Do not repeat permission changes without new evidence. Process-death, real transition, replay, SOS concurrency and signed iPhone checks remain open.
