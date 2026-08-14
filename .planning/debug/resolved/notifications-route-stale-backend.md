---
status: resolved
trigger: "Notifications screen said it could not load/check connection while the device was connected to the local backend."
created: 2026-08-14
updated: 2026-08-14
---

# Debug Session: Notifications Route Stale Backend

## Current Focus
- hypothesis: The phone was correctly forwarded to port 5059, but the API process serving that port was stale and did not include the current `/notifications` route.
- test: Probe `http://127.0.0.1:5059/notifications` without auth.
- expecting: Current backend returns 401 for an authenticated route; stale backend returns 404.
- next_action: Completed.

## Evidence
- timestamp: 2026-08-14T16:10:00+03:00
  observation: `Invoke-WebRequest http://127.0.0.1:5059/notifications` returned 404 while the app showed the notification connection error.
- timestamp: 2026-08-14T16:11:00+03:00
  observation: Port 5059 was owned by `SafePath.Api` process 24396, started 2026-08-13 23:01:22.
- timestamp: 2026-08-14T16:13:00+03:00
  observation: After stopping process 24396 and launching the backend from the current source, the same unauthenticated probe returned 401.

## Eliminated
- hypothesis: USB forwarding was missing.
  reason: `adb reverse --list` showed `tcp:5059 tcp:5059`.
- hypothesis: The route is absent from source.
  reason: `NotificationsController` defines `GET /notifications`, `POST /notifications/{id}/read`, and quiet-hours endpoints.

## Resolution
- root_cause: The connected phone was hitting an old backend executable on port 5059; that build did not serve `/notifications`, so the app collapsed the 404 into generic connection copy.
- fix: Restarted the backend from current source and improved mobile notification error mapping so a 404 says the running backend is stale/unavailable instead of blaming connectivity.
- verification: `/notifications` now returns 401 unauthenticated; on-device Notifications screen loads to the empty state instead of the connection error.
- files_changed:
  - mobile/lib/features/geofencing/application/routine_notifications_controller.dart
  - mobile/lib/features/geofencing/presentation/notifications_screen.dart
  - mobile/lib/features/location/presentation/live_map_screen.dart
  - mobile/lib/features/geofencing/presentation/safe_zones_screen.dart
