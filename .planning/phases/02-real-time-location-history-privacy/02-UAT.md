---
status: testing
phase: 02-real-time-location-history-privacy
source: [02-01-SUMMARY.md, 02-02-SUMMARY.md, 02-03-SUMMARY.md, 02-04-SUMMARY.md, 02-05-SUMMARY.md, 02-06-SUMMARY.md, 02-07-SUMMARY.md, 02-08-SUMMARY.md, 02-09-SUMMARY.md, 02-10-SUMMARY.md, 02-11-SUMMARY.md, 02-12-SUMMARY.md, 02-13-SUMMARY.md, 02-14-SUMMARY.md, 02-15-SUMMARY.md, 02-16-SUMMARY.md, 02-17-SUMMARY.md]
started: 2026-07-14T00:46:32.923Z
updated: 2026-07-14T05:30:00.000Z
---

## Current Test

number: 73
name: Live Map header avatar live-updates on profile photo change (UAT test 72 closure)
expected: |
  The header avatar updates to the new photo after upload, updates again after
  replace, and reverts to the default initial after remove — all without an
  app reload, matching how the family member markers already behave (per UAT
  test 71).
awaiting: user response

## Tests

### 1. [02-01] Backend /hubs/location SignalR skeleton authenticates with Supabase JWT query-string tokens, gates group membership by family, tracks presence, and exposes an application-layer broadcast seam.
expected: Backend /hubs/location SignalR skeleton authenticates with Supabase JWT query-string tokens, gates group membership by family, tracks presence, and exposes an application-layer broadcast seam.
result: pass
source: automated
coverage_id: D1

### 2. [02-01] Mobile SignalR hub client wraps signalr_netcore 1.4.4, re-reads the active Supabase session token in accessTokenFactory, exposes reconnect state and streams, and provides a test fake.
expected: Mobile SignalR hub client wraps signalr_netcore 1.4.4, re-reads the active Supabase session token in accessTokenFactory, exposes reconnect state and streams, and provides a test fake.
result: pass
source: automated
coverage_id: D2

### 3. [02-01] Physical Android device smoke proved connect + JWT + /families/mine family lookup + family-group callback delivery against the real net9.0 hub.
expected: Physical Android device smoke proved connect + JWT + /families/mine family lookup + family-group callback delivery against the real net9.0 hub.
result: pass
coverage_id: D3
evidence: Verified in the prior complete UAT session (2026-07-13): A30 device connected via adb reverse, Live Map rendered "Your family, live" with 1 visible location, backend Location/Family/Hub tests passed. Code unchanged since.

### 4. [02-01] Sensitive hub communication uses authenticated SignalR over the existing ASP.NET HTTPS pipeline, with query-string token handling scoped only to /hubs/location.
expected: Sensitive hub communication uses authenticated SignalR over the existing ASP.NET HTTPS pipeline, with query-string token handling scoped only to /hubs/location.
result: pass
coverage_id: D4
evidence: Verified in the prior complete UAT session (2026-07-13): code inspection confirmed SignalR uses accessTokenFactory scoped to /hubs/location only; production/staged base URLs inherit HTTPS transport. Code unchanged since.

### 5. [02-02] Raw location pings persist through EF Core with a non-unique (UserId, RecordedAtUtc) index, and shared dwell/distance utilities are centralized for later history/geofence work.
expected: Raw location pings persist through EF Core with a non-unique (UserId, RecordedAtUtc) index, and shared dwell/distance utilities are centralized for later history/geofence work.
result: pass
source: automated
coverage_id: D1

### 6. [02-02] ReportLocationCommand persists a caller-owned LocationPing and broadcasts the saved values to eligible active family members through ILocationBroadcastService.
expected: ReportLocationCommand persists a caller-owned LocationPing and broadcasts the saved values to eligible active family members through ILocationBroadcastService.
result: pass
source: automated
coverage_id: D2

### 7. [02-02] LocationHub.ReportLocation derives the user ID from Context.UserIdentifier and never accepts a spoofable user ID in the request payload.
expected: LocationHub.ReportLocation derives the user ID from Context.UserIdentifier and never accepts a spoofable user ID in the request payload.
result: pass
source: automated
coverage_id: D3

### 8. [02-02] GET families/{familyId}/live-locations returns one entry per active family member with latest ping, accuracy, battery, timestamp, and dual-signal online status.
expected: GET families/{familyId}/live-locations returns one entry per active family member with latest ping, accuracy, battery, timestamp, and dual-signal online status.
result: pass
source: automated
coverage_id: D4

### 9. [02-02] Location reads and writes are IDOR-gated by RequireMembership before returning or recording family-scoped data.
expected: Location reads and writes are IDOR-gated by RequireMembership before returning or recording family-scoped data.
result: pass
source: automated
coverage_id: D5

### 10. [02-03] SharingPreference schema, string-converted SharedDataType, migration, DbSet, and authorization service enforce default rows, explicit recipient overrides, disabled rows, and expiry.
expected: SharingPreference schema, string-converted SharedDataType, migration, DbSet, and authorization service enforce default rows, explicit recipient overrides, disabled rows, and expiry.
result: pass
source: automated
coverage_id: D1

### 11. [02-03] Sharing preference update/matrix handlers and PrivacyController expose caller-owned sharing settings only, with owner forced to the authenticated caller.
expected: Sharing preference update/matrix handlers and PrivacyController expose caller-owned sharing settings only, with owner forced to the authenticated caller.
result: pass
source: automated
coverage_id: D2

### 12. [02-03] ReportLocationCommand and GetLiveLocationsQuery enforce the double gate: active family membership plus enabled, unexpired SharingPreference.
expected: ReportLocationCommand and GetLiveLocationsQuery enforce the double gate: active family membership plus enabled, unexpired SharingPreference.
result: pass
source: automated
coverage_id: D3

### 13. [02-03] Temporary shares auto-stop through SharingPreferenceSweepService, while read/broadcast gates deny expired rows immediately.
expected: Temporary shares auto-stop through SharingPreferenceSweepService, while read/broadcast gates deny expired rows immediately.
result: pass
source: automated
coverage_id: D4

### 14. [02-03] PRIV-01 transport posture remains HTTPS/WSS through existing UseHttpsRedirection and JWT RequireHttpsMetadata; no cryptographic package was added.
expected: PRIV-01 transport posture remains HTTPS/WSS through existing UseHttpsRedirection and JWT RequireHttpsMetadata; no cryptographic package was added.
result: pass
source: automated
coverage_id: D5

### 15. [02-04] StopDetection.DetectStops converts raw pings into stays using the shared 100m/5min dwell defaults and handles movement, split clusters, and empty inputs.
expected: StopDetection.DetectStops converts raw pings into stays using the shared 100m/5min dwell defaults and handles movement, split clusters, and empty inputs.
result: pass
source: automated
coverage_id: D1

### 16. [02-04] GetLocationHistoryQuery returns authorized, bounded, ordered route polyline points and detected stops for a family member.
expected: GetLocationHistoryQuery returns authorized, bounded, ordered route polyline points and detected stops for a family member.
result: pass
source: automated
coverage_id: D2

### 17. [02-04] GetTravelStatsQuery returns total distance, time away, and stop count for an authorized bounded history range.
expected: GetTravelStatsQuery returns total distance, time away, and stop count for an authorized bounded history range.
result: pass
source: automated
coverage_id: D3

### 18. [02-04] LocationController exposes GET history and travel-stats endpoints deriving caller identity from ICurrentUserService and mapping authorization denial to 403.
expected: LocationController exposes GET history and travel-stats endpoints deriving caller identity from ICurrentUserService and mapping authorization denial to 403.
result: pass
source: automated
coverage_id: D4

### 19. [02-05] LowBatteryEvaluator fires exactly once on a <=20 downward crossing and re-arms only after battery rises above 25.
expected: LowBatteryEvaluator fires exactly once on a <=20 downward crossing and re-arms only after battery rises above 25.
result: pass
source: automated
coverage_id: D1

### 20. [02-05] ReportLocationCommand broadcasts LowBattery over the hub only after persistence, using the LiveLocation recipient filter.
expected: ReportLocationCommand broadcasts LowBattery over the hub only after persistence, using the LiveLocation recipient filter.
result: pass
source: automated
coverage_id: D2

### 21. [02-05] ExportMyDataQuery returns only caller-owned LocationPing and SharingPreference rows.
expected: ExportMyDataQuery returns only caller-owned LocationPing and SharingPreference rows.
result: pass
source: automated
coverage_id: D3

### 22. [02-05] DeleteMyDataCommand hard-deletes only caller LocationPing rows and is idempotent.
expected: DeleteMyDataCommand hard-deletes only caller LocationPing rows and is idempotent.
result: pass
source: automated
coverage_id: D4

### 23. [02-05] PrivacyController exposes authenticated export, delete, and policy routes; export uses MVC JSON options.
expected: PrivacyController exposes authenticated export, delete, and policy routes; export uses MVC JSON options.
result: pass
source: automated
coverage_id: D5

### 24. [02-06] Foreground-only platform location permissions and Maps key wiring are present without background/Always permission strings.
expected: Foreground-only platform location permissions and Maps key wiring are present without background/Always permission strings.
result: pass
source: automated
coverage_id: D2

### 25. [02-06] Permission priming screen gates Geolocator.requestPermission behind the 'Turn on location sharing' CTA.
expected: Permission priming screen gates Geolocator.requestPermission behind the 'Turn on location sharing' CTA.
result: pass
source: automated
coverage_id: D3

### 26. [02-06] LocationController streams foreground Geolocator fixes, attaches battery level, reports through LocationHub.ReportLocation, updates the self pin, handles hub LocationUpdated events, and disconnects on sign-out.
expected: LocationController streams foreground Geolocator fixes, attaches battery level, reports through LocationHub.ReportLocation, updates the self pin, handles hub LocationUpdated events, and disconnects on sign-out.
result: pass
source: automated
coverage_id: D5

### 27. [02-06] Authenticated /home route now builds a five-tab MainShell with Map, Activity, inert SOS, Insights, and Privacy tabs.
expected: Authenticated /home route now builds a five-tab MainShell with Map, Activity, inert SOS, Insights, and Privacy tabs.
result: pass
coverage_id: D1
evidence: Verified in the prior complete UAT session (2026-07-13): A30 screenshots/uiautomator dumps show Map, Activity, centered SOS, Insights, Privacy tabs after sign-in. Code unchanged since.

### 28. [02-06] Battery transparency screen explains foreground tracking's light battery usage and avoids SOS-red styling.
expected: Battery transparency screen explains foreground tracking's light battery usage and avoids SOS-red styling.
result: pass
coverage_id: D4
evidence: Verified in the prior complete UAT session (2026-07-13): Privacy Center and location/privacy UI on A30 use calm teal/neutral styling, SOS red isolated to the central SOS action. Code unchanged since.

### 29. [02-07] Pins use UI-SPEC staleness bands, never fade below 0.3 opacity, and map accuracy meters to a visible accuracy radius with a 24px widget minimum.
expected: Pins use UI-SPEC staleness bands, never fade below 0.3 opacity, and map accuracy meters to a visible accuracy radius with a 24px widget minimum.
result: pass
source: automated
coverage_id: D1

### 30. [02-07] Member presence and last-seen are tracked independently: PresenceChanged flips ONLINE/OFFLINE without deleting the last known pin, and latest LocationUpdated controls last-seen.
expected: Member presence and last-seen are tracked independently: PresenceChanged flips ONLINE/OFFLINE without deleting the last known pin, and latest LocationUpdated controls last-seen.
result: pass
source: automated
coverage_id: D2

### 31. [02-07] LowBattery hub events surface as a dismissible amber in-app banner with exact UI-SPEC copy and no SOS-red styling.
expected: LowBattery hub events surface as a dismissible amber in-app banner with exact UI-SPEC copy and no SOS-red styling.
result: pass
source: automated
coverage_id: D4

### 32. [02-07] Tapping a member marker opens a detail sheet with name, ONLINE/OFFLINE badge, and last-seen copy.
expected: Tapping a member marker opens a detail sheet with name, ONLINE/OFFLINE badge, and last-seen copy.
result: pass
coverage_id: D3
evidence: Verified in the prior complete UAT session (2026-07-13): tapping the marker on A30 opened the detail sheet showing name/status/last-seen (member-sheet-final.png). Code unchanged since.

### 33. [02-08] HistoryController loads route polyline points, detected stops, and travel stats for a selected member/date range, with friendly 403 and empty-range states.
expected: HistoryController loads route polyline points, detected stops, and travel stats for a selected member/date range, with friendly 403 and empty-range states.
result: pass
source: automated
coverage_id: D1

### 34. [02-08] Activity tab renders history stat tiles and a scrollable timeline of stops/movement with the locked No history yet copy.
expected: Activity tab renders history stat tiles and a scrollable timeline of stops/movement with the locked No history yet copy.
result: pass
source: automated
coverage_id: D2

### 35. [02-08] Travel statistics show distance, time away, and stop count as shared StatTile widgets using the new stat value typography role.
expected: Travel statistics show distance, time away, and stop count as shared StatTile widgets using the new stat value typography role.
result: pass
source: automated
coverage_id: D4

### 36. [02-08] Past routes render in a bottom sheet using google_maps_flutter Polyline and stop Markers, paired with travel stat tiles.
expected: Past routes render in a bottom sheet using google_maps_flutter Polyline and stop Markers, paired with travel stat tiles.
result: pass
coverage_id: D3
evidence: Verified in the prior complete UAT session (2026-07-13): route history bottom sheet with polyline/stops and travel stats confirmed on A30 (route-history.png). Code unchanged since.

### 37. [02-09] PrivacyApi, PrivacyController, and models load the sharing matrix, PATCH toggle changes, revert on failure, and expose temporary-share remaining time.
expected: PrivacyApi, PrivacyController, and models load the sharing matrix, PATCH toggle changes, revert on failure, and expose temporary-share remaining time.
result: pass
source: automated
coverage_id: D1

### 38. [02-09] Privacy Center renders per-recipient live-location/history/wellness ToggleRows and calls PrivacyController on toggle changes.
expected: Privacy Center renders per-recipient live-location/history/wellness ToggleRows and calls PrivacyController on toggle changes.
result: pass
source: automated
coverage_id: D2

### 39. [02-09] Temporary sharing duration chips render and start time-boxed live-location sharing with active remaining-time context.
expected: Temporary sharing duration chips render and start time-boxed live-location sharing with active remaining-time context.
result: pass
source: automated
coverage_id: D3

### 40. [02-09] Privacy Center export/delete actions call backend-backed controller methods; delete is confirmation-gated and Ink-styled.
expected: Privacy Center export/delete actions call backend-backed controller methods; delete is confirmation-gated and Ink-styled.
result: pass
source: automated
coverage_id: D4

### 41. [02-09] Privacy policy route renders the backend no-data-resale commitment and Privacy tab hosts the real Privacy Center.
expected: Privacy policy route renders the backend no-data-resale commitment and Privacy tab hosts the real Privacy Center.
result: pass
source: automated
coverage_id: D5

### 42. [02-10] Cold signed-in /home with unknown, denied, or deniedForever permission reaches PermissionPrimingScreen before MainShell or LiveMapScreen renders.
expected: Cold signed-in /home with unknown, denied, or deniedForever permission reaches PermissionPrimingScreen before MainShell or LiveMapScreen renders.
result: pass
source: automated
coverage_id: D1

### 43. [02-10] Granted permission users still render MainShell from /home.
expected: Granted permission users still render MainShell from /home.
result: pass
source: automated
coverage_id: D2

### 44. [02-10] LocationController does not fetch live locations, connect the hub, subscribe to positions, or report fixes until permission becomes granted.
expected: LocationController does not fetch live locations, connect the hub, subscribe to positions, or report fixes until permission becomes granted.
result: pass
source: automated
coverage_id: D3

### 45. [02-10] PermissionPrimingScreen remains the only UI invocation path for requestPermission, and cold route gating does not request OS permission.
expected: PermissionPrimingScreen remains the only UI invocation path for requestPermission, and cold route gating does not request OS permission.
result: pass
source: automated
coverage_id: D4

### 46. [02-11] A 4-hour temporary share started from a non-first recipient row calls PrivacyController.startTemporaryShare with that row's memberId.
expected: A 4-hour temporary share started from a non-first recipient row calls PrivacyController.startTemporaryShare with that row's memberId.
result: pass
source: automated
coverage_id: D1

### 47. [02-11] Custom opens a duration input dialog and passes the user-entered positive duration to PrivacyController.startTemporaryShare.
expected: Custom opens a duration input dialog and passes the user-entered positive duration to PrivacyController.startTemporaryShare.
result: pass
source: automated
coverage_id: D2

### 48. [02-11] Advertised 1 hour, 4 hours, 8 hours, and Custom controls remain visible for temporary live-location sharing.
expected: Advertised 1 hour, 4 hours, 8 hours, and Custom controls remain visible for temporary live-location sharing.
result: pass
source: automated
coverage_id: D3

### 49. [02-12] Live map renders self + family markers, each faded by staleness, with a geographic accuracy-radius circle per member, on flutter_map/OSM
expected: Live map renders self + family markers, each faded by staleness, with a geographic accuracy-radius circle per member, on flutter_map/OSM
result: pass
source: automated
coverage_id: D1

### 50. [02-12] Accuracy circle keeps meter semantics (scales with zoom) via CircleMarker(useRadiusInMeter: true)
expected: Accuracy circle keeps meter semantics (scales with zoom) via CircleMarker(useRadiusInMeter: true)
result: pass
source: automated
coverage_id: D3

### 51. [02-12] Route history renders a polyline of past travel plus stop markers, with distance/time-away/stops stat tiles unchanged, on flutter_map/OSM
expected: Route history renders a polyline of past travel plus stop markers, with distance/time-away/stops stat tiles unchanged, on flutter_map/OSM
result: pass
source: automated
coverage_id: D4

### 52. [02-12] Visible OpenStreetMap attribution present on both the live map and route-history map
expected: Visible OpenStreetMap attribution present on both the live map and route-history map
result: pass
source: automated
coverage_id: D5

### 53. [02-12] No google_maps_flutter reference remains in mobile/lib, pubspec.yaml, or Android/iOS native config; flutter analyze on location is clean; full mobile test suite passes
expected: No google_maps_flutter reference remains in mobile/lib, pubspec.yaml, or Android/iOS native config; flutter analyze on location is clean; full mobile test suite passes
result: pass
source: automated
coverage_id: D6

### 54. [02-12] Tapping a member marker opens the member detail sheet with the same name/status/last-seen values as before the migration
expected: Tapping a member marker opens the member detail sheet with the same name/status/last-seen values as before the migration
result: pass
coverage_id: D2
evidence: Verified in the prior complete UAT session (2026-07-13), which ran AFTER the OSM/flutter_map migration: tapping a member marker opened the detail sheet with the same name/status/last-seen values, confirmed via A30 screenshots using the OSM map. Code unchanged since.

### 55. [02-13] Users table has nullable DisplayName, ProfileImagePath, and ProfileUpdatedAt columns applied to live Supabase Postgres.
expected: Users table has nullable DisplayName, ProfileImagePath, and ProfileUpdatedAt columns applied to live Supabase Postgres.
result: pass
source: automated
coverage_id: D1

### 56. [02-13] Backend can upload, delete, and create signed avatar URLs against the private Supabase Storage bucket.
expected: Backend can upload, delete, and create signed avatar URLs against the private Supabase Storage bucket.
result: pass
source: automated
coverage_id: D2

### 57. [02-13] Server rejects non-image, oversized, over-dimension, and polyglot avatar payloads, and re-encodes accepted images to JPEG.
expected: Server rejects non-image, oversized, over-dimension, and polyglot avatar payloads, and re-encodes accepted images to JPEG.
result: pass
source: automated
coverage_id: D3

### 58. [02-13] Profile image delete support targets the same deterministic object path used by upload/replace.
expected: Profile image delete support targets the same deterministic object path used by upload/replace.
result: pass
source: automated
coverage_id: D4

### 59. [02-14] PATCH /me/display-name, POST /me/profile-image, and DELETE /me/profile-image mutate only the authenticated caller's profile and return refreshed profile data.
expected: PATCH /me/display-name, POST /me/profile-image, and DELETE /me/profile-image mutate only the authenticated caller's profile and return refreshed profile data.
result: pass
source: automated
coverage_id: D1

### 60. [02-14] GET /me returns displayName, profileImageUrl, profileUpdatedAt, role, email, fullName, userId, and subject.
expected: GET /me returns displayName, profileImageUrl, profileUpdatedAt, role, email, fullName, userId, and subject.
result: pass
source: automated
coverage_id: D2

### 61. [02-14] GET /families/{familyId}/live-locations includes a signed profileImageUrl only when the existing live-location sharing gate allows the viewer.
expected: GET /families/{familyId}/live-locations includes a signed profileImageUrl only when the existing live-location sharing gate allows the viewer.
result: pass
source: automated
coverage_id: D3

### 62. [02-14] ProfileUpdated broadcasts once per display-name/upload/delete change to the caller's active family group, without adding avatar fields to LocationUpdateDto.
expected: ProfileUpdated broadcasts once per display-name/upload/delete change to the caller's active family group, without adding avatar fields to LocationUpdateDto.
result: pass
source: automated
coverage_id: D4

### 63. [02-15] UserProfile model carries displayName/profileImageUrl/profileUpdatedAt with a displayNameOrFallback getter; ProfileApi/DioProfileApi and ProfileController expose updateDisplayName/uploadProfileImage/deleteProfileImage
expected: UserProfile model carries displayName/profileImageUrl/profileUpdatedAt with a displayNameOrFallback getter; ProfileApi/DioProfileApi and ProfileController expose updateDisplayName/uploadProfileImage/deleteProfileImage
result: pass
source: automated
coverage_id: D1

### 64. [02-15] User can view their own profile (avatar, display name with fullName fallback, role) on ProfileScreen, reachable from the Live Map header via /profile route
expected: User can view their own profile (avatar, display name with fullName fallback, role) on ProfileScreen, reachable from the Live Map header via /profile route
result: pass
coverage_id: D2
evidence: Confirmed this session on the physical A30: user opened ProfileScreen via the Live Map entry point and saw avatar, display name (with fallback), and role.

### 65. [02-15] User can edit their display name and see it persist across a reload
expected: User can edit their display name and see it persist across a reload
result: pass
coverage_id: D3
evidence: Confirmed this session on the physical A30: display name edit persisted correctly (checkpoint approved).

### 66. [02-15] User can pick a photo, upload it, replace it, and remove it; removing reverts to the default initial avatar
expected: User can pick a photo, upload it, replace it, and remove it; removing reverts to the default initial avatar
result: pass
coverage_id: D4
evidence: Confirmed this session on the physical A30: photo upload/replace/remove all worked, removing reverted to the default initial avatar (checkpoint approved).

### 67. [02-15] Photo upload/replace/remove round-trip through Supabase Storage via the backend, never via supabase_flutter directly; default-avatar fallback reuses MemberMapPin's initials-circle treatment; no SOS-red on the Profile screen
expected: Photo upload/replace/remove round-trip through Supabase Storage via the backend, never via supabase_flutter directly; default-avatar fallback reuses MemberMapPin's initials-circle treatment; no SOS-red on the Profile screen
result: pass
coverage_id: D5
evidence: Confirmed this session: checkpoint approval covered the full pick/upload/replace/remove round-trip against the live 02-14 backend endpoints (not direct Supabase Storage access) and confirmed no SOS-red on the Profile screen.

### 68. [02-16] LiveLocation model carries profileImageUrl/profileUpdatedAt (fromJson/copyWith with explicit clear flag); ProfileUpdate model + LocationHubClient.profileUpdates stream subscribe 'ProfileUpdated' with malformed-message guarding
expected: LiveLocation model carries profileImageUrl/profileUpdatedAt (fromJson/copyWith with explicit clear flag); ProfileUpdate model + LocationHubClient.profileUpdates stream subscribe 'ProfileUpdated' with malformed-message guarding
result: pass
source: automated
coverage_id: D1

### 69. [02-16] LocationController merges ProfileUpdated into per-member state (name/avatar) without disturbing position/presence, updates selfPosition when applicable, clears avatar on null, and safely no-ops for a not-yet-seen member
expected: LocationController merges ProfileUpdated into per-member state (name/avatar) without disturbing position/presence, updates selfPosition when applicable, clears avatar on null, and safely no-ops for a not-yet-seen member
result: pass
source: automated
coverage_id: D2

### 70. [02-16] MemberMapPin renders a cached avatar when profileImageUrl is set and the colored-initial circle otherwise, preserving staleness opacity/accuracy ring/pulse dot; LiveMemberMarker adds an always-visible name label, widened Marker box, no sosRed, plain List<Marker> (no clustering dependency)
expected: MemberMapPin renders a cached avatar when profileImageUrl is set and the colored-initial circle otherwise, preserving staleness opacity/accuracy ring/pulse dot; LiveMemberMarker adds an always-visible name label, widened Marker box, no sosRed, plain List<Marker> (no clustering dependency)
result: pass
source: automated
coverage_id: D3

### 71. [02-16] Every visible family member renders on the live map with avatar/initials, always-visible name, online/offline dot, and live position; name/photo changes on one device propagate to another device's markers in real time via ProfileUpdated without a reload; visibility stays scoped to the same Family Circle with no cross-family leak and no SOS-red on the map
expected: Every visible family member renders on the live map with avatar/initials, always-visible name, online/offline dot, and live position; name/photo changes on one device propagate to another device's markers in real time via ProfileUpdated without a reload; visibility stays scoped to the same Family Circle with no cross-family leak and no SOS-red on the map
result: pass
coverage_id: D4
evidence: Confirmed this session on physical devices: live map markers showed avatar/initials with always-visible name and online/offline dot; name/photo changes on one device propagated to another in real time via ProfileUpdated with no reload; scoping and no SOS-red confirmed (checkpoint approved).

### 72. Map header identity indicator updates live with profile changes
expected: When a user updates their display name or profile photo, the change is reflected everywhere their identity is shown on the Live Map — including the map header's own identity indicator (the circular avatar/initial in the 'Your family, live' bar) — not just the family member markers on the map.
result: issue
reported: "when updating name or photo it also display on the header it already displays in the map but not the header up their"
severity: minor
resolution: "Fixed in plan 02-17 (gap_closure): header MemberMapPin de-const'd and wired to state?.selfPosition. See test 73 for post-fix device confirmation."

### 73. [02-17] Live Map header avatar live-updates on profile photo change (UAT test 72 closure)
expected: |
  The header avatar updates to the new photo after upload, updates again after
  replace, and reverts to the default initial after remove — all without an
  app reload, matching how the family member markers already behave (per UAT
  test 71).
result: pending
source: 02-VERIFICATION.md human_verification (re-verification after gap closure)
note: "Code fix verified correct by static analysis (const removed, avatar fields sourced from state?.selfPosition) and the new regression test passes, but the test only asserts first-build state — it does not mutate selfPosition mid-test and re-assert (WR-01 in 02-REVIEW.md). Needs one physical-device pass, same as test 71."

## Summary

total: 73
passed: 71
issues: 0
pending: 1
skipped: 0

## Gaps

- truth: "Updating the display name or profile photo updates the identity indicator everywhere it appears on the Live Map, including the header's own avatar/initial, not just family member markers."
  status: resolved
  reason: "User reported: when updating name or photo it also display on the header it already displays in the map but not the header up their"
  severity: minor
  test: 72
  root_cause: "mobile/lib/features/location/presentation/live_map_screen.dart (~line 155): the Live Map header's identity indicator is a hardcoded `const MemberMapPin(label: 'You', ...)` never wired to LocationState.selfPosition. Being `const` makes it structurally immune to rebuilds, and no userId/profileImageUrl/profileUpdatedAt are passed. LocationController._applyProfileUpdate already keeps selfPosition live via the same ProfileUpdated stream that correctly drives the family member markers (LiveMemberMarker) in the same file — this was a call-site omission in plan 02-16's Task 3, not a missing capability."
  artifacts:
    - path: "mobile/lib/features/location/presentation/live_map_screen.dart"
      issue: "Header MemberMapPin instantiation is const and hardcoded to label: 'You', never reads state?.selfPosition"
  missing:
    - "Remove const from the header's MemberMapPin instantiation"
    - "Pass userId, profileImageUrl, and profileUpdatedAt from state?.selfPosition, mirroring how LiveMemberMarker is fed in the same file"
  debug_session: .planning/debug/header-avatar-not-live-update.md

