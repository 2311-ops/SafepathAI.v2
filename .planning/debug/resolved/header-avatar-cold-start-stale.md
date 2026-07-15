---
status: resolved
trigger: "header-avatar-cold-start-stale: Live Map header identity avatar shows the wrong (stale/incorrect) photo after closing and reopening the app, even though the in-session live-update fix (plan 02-17, UAT test 72) works correctly while the app stays open."
created: 2026-07-14T00:00:00+03:00
updated: 2026-07-16T00:00:00+03:00
---

## Current Focus

hypothesis: CONFIRMED â€” the backend's `GetLiveLocationsQuery` (`GET /families/{familyId}/live-locations`, consumed on every cold-start `_bootstrap()`) never returns a `profileUpdatedAt` field in `MemberLiveLocationDto`, so `LiveLocation.fromJson` always parses `profileUpdatedAt` as `null` for every member (including self) on cold start. Both `MemberMapPin` (header) and `LiveMemberMarker` (family markers) build their `CachedNetworkImage` with an explicit `cacheKey: '${userId}-${profileUpdatedAt?.toIso8601String()}'`. On cold start this collapses to a constant key `'{userId}-null'` every single app launch, regardless of how many times the photo has actually changed server-side. `cached_network_image`'s underlying disk cache (flutter_cache_manager) persists across app restarts and is looked up SOLELY by this custom `cacheKey` string (default 30-day stale period) â€” so once an image is cached under `'{userId}-null'` (the very first time this pin ever rendered an avatar), every later cold start reusing that identical key serves the OLD cached bytes directly, without re-fetching, even though the fresh network response's `profileImageUrl` (freshly signed URL) is current. In-session updates work because `_applyProfileUpdate` (SignalR ProfileUpdated handler) stamps a fresh local `DateTime.now().toUtc()` as `profileUpdatedAt` (comment confirms the push payload itself carries none either), producing a brand-new never-before-used cache key that forces a genuine re-fetch.
test: Static code read across mobile (location_controller.dart, location_api.dart, location_models.dart, member_map_pin.dart, live_map_screen.dart) and backend (GetLiveLocationsQuery.cs, LocationDtos.cs, User.cs, MeController.cs) â€” traced the full field lineage of profileUpdatedAt from DB column through DTOs to mobile parsing to cache-key construction.
expecting: N/A â€” root cause confirmed via direct code inspection, no further testing needed for find_root_cause_only mode.
next_action: Return ROOT CAUSE FOUND to caller. Fix direction: add `ProfileUpdatedAt` to `MemberLiveLocationDto` (backend) sourced from `User.ProfileUpdatedAt` (already exists in the domain/DB, already populated by Upload/Delete/UpdateDisplayName commands, already exposed on `/me` via `GetMeQuery` â€” just never selected in `GetLiveLocationsQueryHandler`'s projection), serialize it in the live-locations JSON response, and have the mobile `LiveLocation.fromJson` (already parses the field name correctly) receive a real, monotonically-changing timestamp on every cold-start fetch â€” this alone fixes the cache-busting for BOTH the header self-avatar and all family member markers on cold start.

## Symptoms

expected: On cold app start (closed then reopened), the Live Map header's identity avatar ("You" pin in the "Your family, live" bar) should show the current user's latest profile photo â€” the same photo that correctly displays and live-updates while the app is running (per the 02-17 fix: header MemberMapPin reads userId/profileImageUrl/profileUpdatedAt from LocationState.selfPosition).
actual: User reported (verbatim): "when i open the app it the new feature header avatar live-updates works but when closing it it bring back the wrong avatar" â€” i.e. while the app is open, uploading/replacing a profile photo correctly updates the header live. But after fully closing the app and reopening it, the header avatar reverts to showing an incorrect/stale avatar (not the latest one that was visible before closing).
errors: None reported by user â€” visual/data staleness issue, not a crash.
reproduction: Test 73 in .planning/phases/02-real-time-location-history-privacy/02-UAT.md â€” Open the app, verify header avatar is current (matches last uploaded photo). Fully close the app (not just background it). Reopen the app. Observe the header avatar again â€” it shows the wrong/stale avatar instead of the last-known-correct one.
started: Discovered during UAT test 73 (2026-07-14), immediately after plan 02-17 fixed the original in-session live-update bug (UAT test 72). This is a NEW distinct bug, not a regression of the 02-17 fix â€” the 02-17 fix's own scope (in-session reactivity) is confirmed working.

## Eliminated

(none yet)

## Evidence

- timestamp: 2026-07-14
  checked: mobile/lib/features/location/application/location_controller.dart (_bootstrap, lines 129-182 and _applyProfileUpdate, lines 398-434)
  found: >
    On cold start, `_bootstrap()` fetches `initialLocations` fresh from
    `locationApi.getLiveLocations(familyId)` (no local/SharedPreferences
    persistence of prior state exists anywhere in this controller â€” state
    always starts as `const LocationState(isLoading: true)` on `build()`).
    `selfPosition` is derived purely from that fresh network response
    (`initialMembers[currentUserId]`). Separately, `_applyProfileUpdate`
    (the live SignalR ProfileUpdated handler) explicitly stamps
    `profileUpdatedAt: DateTime.now().toUtc()` locally with a comment
    admitting "the server doesn't send profileUpdatedAt on this lightweight
    event."
  implication: >
    Two different code paths populate `LiveLocation.profileUpdatedAt`: the
    live in-session path (client-stamped, always fresh/unique) and the
    cold-start bootstrap path (parsed straight from the network JSON, with
    no client-side stamping at all). If the network JSON never contains
    `profileUpdatedAt`, the cold-start path always yields `null`.

- timestamp: 2026-07-14
  checked: mobile/lib/features/location/data/location_models.dart (LiveLocation.fromJson, lines 26-42) and location_api.dart (getLiveLocations, lines 46-61)
  found: >
    `LiveLocation.fromJson` correctly parses `json['profileUpdatedAt']` when
    present, defaulting to `null` when the key is absent
    (`profileUpdatedAtValue == null ? null : DateTime.tryParse(...)`).
    `getLiveLocations` deserializes the raw `GET /families/{familyId}/live-locations`
    response array through this same `fromJson` with no additional
    enrichment.
  implication: >
    The mobile client is fully capable of receiving and using a real
    `profileUpdatedAt` on cold start â€” it is purely a question of whether
    the backend response actually includes that field.

- timestamp: 2026-07-14
  checked: backend/src/SafePath.Application/Location/LocationDtos.cs and GetLiveLocationsQuery.cs (GetLiveLocationsQueryHandler.Handle, lines 34-79)
  found: >
    `MemberLiveLocationDto` (record, lines 17-26) has fields: UserId,
    DisplayName, Lat, Lng, AccuracyMeters, BatteryPercent, RecordedAtUtc,
    IsOnline, ProfileImageUrl. There is NO `ProfileUpdatedAt` field in this
    DTO at all. The handler's LINQ projection (`select new {
    member.UserId, user.FullName, user.DisplayName, user.ProfileImagePath }`)
    doesn't even query `user.ProfileUpdatedAt` from the DB, and the DTO
    constructor call (lines 66-75) has no slot for it.
  implication: >
    Confirmed: the `/families/{familyId}/live-locations` endpoint â€” the
    exact endpoint that powers cold-start bootstrap for both self and every
    family member â€” structurally cannot return `profileUpdatedAt`. This is
    not a serialization bug or a null-in-DB edge case; the field is entirely
    absent from the query/DTO. `LiveLocation.fromJson` will therefore
    ALWAYS parse `profileUpdatedAt` as `null` on every cold-start fetch, for
    every member, permanently (not just for the current user/session).

- timestamp: 2026-07-14
  checked: backend/src/SafePath.Domain/Entities/User.cs, ProfileCommandTests.cs, DeleteProfileImageCommand.cs, UploadProfileImageCommand.cs, UpdateDisplayNameCommand.cs, GetMeQuery.cs, MeController.cs
  found: >
    `User.ProfileUpdatedAt` (DateTime?) DOES exist in the domain entity and
    DB (migration `20260713152701_AddUserProfileFields`), and IS correctly
    stamped to `DateTime.UtcNow` by `UploadProfileImageCommand`,
    `DeleteProfileImageCommand`, and `UpdateDisplayNameCommand` on every
    profile mutation. It's also already exposed via `/me` (`GetMeQuery`  â†’
    `MeController` line 141: `profileUpdatedAt = result.ProfileUpdatedAt`).
  implication: >
    The authoritative, monotonically-updated timestamp already exists
    server-side and is already wired into one endpoint (`/me`) â€” it was
    simply never carried into `GetLiveLocationsQueryHandler`'s projection or
    `MemberLiveLocationDto`. This is a straightforward DTO/query omission,
    not a missing capability or a design gap requiring new schema.

- timestamp: 2026-07-14
  checked: mobile/lib/shared_widgets/member_map_pin.dart (CachedNetworkImage, lines 133-146) and live_map_screen.dart LiveMemberMarker (lines 251-295) and header MemberMapPin call site (lines 155-163, from the 02-17 fix)
  found: >
    Both widgets build `CachedNetworkImage` with an explicit custom
    `cacheKey: '${userId ?? label}-${profileUpdatedAt?.toIso8601String()}'`
    (MemberMapPin) / `'${location.userId}-${location.profileUpdatedAt?.toIso8601String()}'`
    (LiveMemberMarker) â€” NOT the default (URL-derived) cache key. The
    header call site (post-02-17 fix) correctly threads
    `state?.selfPosition?.profileUpdatedAt` in, exactly mirroring
    LiveMemberMarker's existing pattern â€” confirming the 02-17 fix's own
    scope was correct; this is a genuinely new/different bug one layer
    deeper (in the data feeding both call sites, not the wiring).
  implication: >
    `cached_network_image`'s underlying `flutter_cache_manager` persists its
    disk cache across full app restarts (this is its core value proposition
    vs. plain `Image.network`/in-memory `ImageCache`), and looks up cached
    files SOLELY by whatever `cacheKey` string is supplied â€” with a default
    30-day stale period during which a matching key is served straight from
    disk with no network re-validation at all. Since cold-start always
    produces the identical key `'{userId}-null'` (for self AND every family
    member, since GetLiveLocationsQuery is the single source for both),
    every cold start after the first-ever avatar render for that userId
    will keep serving whatever image bytes were cached under that constant
    key on the very first render â€” permanently â€” no matter how many times
    the actual photo is replaced server-side. The bug is therefore systemic
    (affects the header AND family member markers identically on cold
    start), not self-specific; it wasn't caught for family markers in UAT
    test 71 most likely because that test only exercised in-session photo
    changes, not "change photo, then fully close and reopen" for another
    family member.

## Resolution

root_cause: >
  `GET /families/{familyId}/live-locations` (backend `GetLiveLocationsQueryHandler`,
  `MemberLiveLocationDto` in backend/src/SafePath.Application/Location/LocationDtos.cs)
  never includes a `ProfileUpdatedAt` field â€” the handler's projection doesn't
  even select `user.ProfileUpdatedAt` from the DB, and the DTO record has no
  slot for it â€” even though `User.ProfileUpdatedAt` exists, is correctly
  maintained by every profile-mutation command, and is already exposed via
  `/me`. Because this is the exact endpoint mobile's `LocationController._bootstrap()`
  calls on every cold app start (for both `selfPosition` and all family
  `members`), `LiveLocation.fromJson` always parses `profileUpdatedAt` as
  `null` on cold start â€” for every member, permanently, not just the first
  time. Both `MemberMapPin` (header, wired correctly by the 02-17 fix) and
  `LiveMemberMarker` (family map markers) build their avatar's
  `CachedNetworkImage` with an explicit custom `cacheKey` of
  `'${userId}-${profileUpdatedAt?.toIso8601String()}'`. Since cold start
  always yields the same constant key (`'{userId}-null'`) regardless of how
  many times the photo has actually changed server-side, and
  `cached_network_image`'s disk cache (flutter_cache_manager, ~30-day
  default stale period) persists across full app restarts and is looked up
  solely by that custom key, every cold start after the very first avatar
  render under that key serves the OLD cached image bytes directly â€” never
  re-fetching the current signed `profileImageUrl` that the very same fresh
  network response actually returned. In-session updates work correctly
  because the live SignalR `ProfileUpdated` handler (`_applyProfileUpdate`)
  client-stamps a fresh, always-unique `DateTime.now().toUtc()` locally
  (since that lightweight push event also carries no `profileUpdatedAt`),
  producing a brand-new cache key that forces a genuine re-fetch â€” but this
  local stamp is lost and never persisted, so the very next cold-start
  bootstrap reverts to the stale, backend-omitted `null` value.
fix: >
  Applied by Phase 02 Plan 18: `User.ProfileUpdatedAt` was threaded through
  `MemberLiveLocationDto` and `GetLiveLocationsQueryHandler`, allowing the
  existing mobile `LiveLocation.fromJson` and avatar cache keys to receive a
  real mutation timestamp on cold start.
verification: >
  User confirmed everything works fine after the Phase 2 on-device verification
  loop. Phase 02-18 summary also records backend `GetLiveLocationsQueryTests`
  passing 10/10, `SafePath.Application` build passing, and mobile
  `location_controller_test.dart` passing 21/21.
files_changed:
  - backend/src/SafePath.Application/Location/LocationDtos.cs
  - backend/src/SafePath.Application/Location/GetLiveLocationsQuery.cs
  - backend/tests/SafePath.Application.Tests/Location/GetLiveLocationsQueryTests.cs
  - mobile/test/features/location/location_controller_test.dart
