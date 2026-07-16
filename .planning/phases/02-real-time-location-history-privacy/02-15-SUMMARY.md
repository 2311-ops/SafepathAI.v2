---
phase: 02-real-time-location-history-privacy
plan: 15
subsystem: mobile
tags: [profile, mobile, riverpod, image-picker, cached_network_image, flutter]

# Dependency graph
requires:
  - phase: 02-14
    provides: "/me display-name, profile-image upload/delete endpoints; signed profileImageUrl projection; ProfileUpdated SignalR event"
provides:
  - "Extended UserProfile model (displayName, profileImageUrl, profileUpdatedAt, displayNameOrFallback)"
  - "ProfileApi/DioProfileApi updateDisplayName / uploadProfileImage / deleteProfileImage"
  - "ProfileController mutations wired to ProfileState"
  - "ProfileScreen (view + edit) reachable from the Live Map header, /profile route"
  - "Reusable ProfileAvatar shared widget (cached avatar + initials fallback)"
affects: [02-16, profile, live-map]

# Tech tracking
tech-stack:
  added: ["image_picker 1.2.3", "cached_network_image 3.4.1"]
  patterns:
    - "ProfileAvatar shared widget: CachedNetworkImage with cacheKey = userId + profileUpdatedAt (not the signed URL), initials-circle fallback matching MemberMapPin visual language"
    - "Client-side image_picker downscale (maxWidth/maxHeight/imageQuality) is bandwidth-only; backend re-validates/re-encodes every upload (never a trust boundary)"

key-files:
  created:
    - mobile/lib/features/profile/presentation/profile_screen.dart
    - mobile/lib/shared_widgets/profile_avatar.dart
    - mobile/test/features/profile/profile_controller_test.dart
    - mobile/test/helpers/fake_profile_api.dart
  modified:
    - mobile/lib/features/profile/data/user_profile.dart
    - mobile/lib/features/profile/data/profile_api.dart
    - mobile/lib/features/profile/application/profile_controller.dart
    - mobile/lib/core/router/app_router.dart
    - mobile/lib/features/location/presentation/live_map_screen.dart
    - mobile/ios/Runner/Info.plist
    - mobile/pubspec.yaml
    - mobile/pubspec.lock

key-decisions:
  - "Single shell entry point for Profile is an avatar/person action in the Live Map app bar (including the no-circle empty-state app bar, fix commit 53515a2) — no sixth bottom-nav tab added, preserving the SOS-centered 5-tab layout."
  - "ProfileAvatar placed in shared_widgets (not the profile feature) specifically so 02-16's map markers can reuse it."

patterns-established:
  - "Profile mutations (updateDisplayName/uploadProfileImage/deleteProfileImage) follow the existing updateRole shape: set loading, call API, replace ProfileState(profile: ...) from the response, catch ProfileApiException into ProfileState.error without dropping the prior profile."

requirements-completed: [PROFILE-01, PROFILE-02, PROFILE-03, PROFILE-04, PROFILE-05]

coverage:
  - id: D1
    description: "UserProfile model carries displayName/profileImageUrl/profileUpdatedAt with a displayNameOrFallback getter; ProfileApi/DioProfileApi and ProfileController expose updateDisplayName/uploadProfileImage/deleteProfileImage"
    requirement: "PROFILE-01"
    verification:
      - kind: unit
        ref: "mobile/test/features/profile/profile_controller_test.dart"
        status: pass
    human_judgment: false
  - id: D2
    description: "User can view their own profile (avatar, display name with fullName fallback, role) on ProfileScreen, reachable from the Live Map header via /profile route"
    requirement: "PROFILE-05"
    verification:
      - kind: manual_procedural
        ref: "Human-verify checkpoint (Task 3): sign in, open profile entry point from Live Map, confirm identity display"
        status: pass
    human_judgment: true
    rationale: "Visual/navigational verification of a physical-device flow — not exercisable by unit tests alone."
  - id: D3
    description: "User can edit their display name and see it persist across a reload"
    requirement: "PROFILE-04"
    verification:
      - kind: unit
        ref: "mobile/test/features/profile/profile_controller_test.dart#updateDisplayName mutation"
        status: pass
      - kind: manual_procedural
        ref: "Human-verify checkpoint (Task 3), step 3: edit display name, save, pull-to-refresh, confirm persistence"
        status: pass
    human_judgment: true
    rationale: "End-to-end persistence against the running backend requires physical-device confirmation."
  - id: D4
    description: "User can pick a photo, upload it, replace it, and remove it; removing reverts to the default initial avatar"
    requirement: "PROFILE-02"
    verification:
      - kind: unit
        ref: "mobile/test/features/profile/profile_controller_test.dart#uploadProfileImage/deleteProfileImage mutations"
        status: pass
      - kind: manual_procedural
        ref: "Human-verify checkpoint (Task 3), steps 4-6: upload, replace, remove photo on physical device"
        status: pass
    human_judgment: true
    rationale: "Real device photo picker, upload to live backend, and default-avatar fallback rendering require human visual confirmation — approved by user 2026-07-13."
  - id: D5
    description: "Photo upload/replace/remove round-trip through Supabase Storage via the backend, never via supabase_flutter directly; default-avatar fallback reuses MemberMapPin's initials-circle treatment; no SOS-red on the Profile screen"
    requirement: "PROFILE-03"
    verification:
      - kind: manual_procedural
        ref: "Human-verify checkpoint (Task 3), step 7: confirm no SOS-red appears on the Profile screen"
        status: pass
    human_judgment: true
    rationale: "Design-token/visual compliance is a human judgment call confirmed on-device."

# Metrics
duration: ~2h30m (across two sessions; checkpoint pause for physical-device verification)
completed: 2026-07-14
status: complete
---

# Phase 02 Plan 15: Mobile Profile Screen (View/Edit + Photo Management) Summary

**Mobile Profile feature (data/API/controller/screen) letting a user view their identity, edit their display name, and upload/replace/remove their photo end-to-end against the live 02-14 backend, with a shared `ProfileAvatar` widget for map-marker reuse.**

## Performance

- **Duration:** ~2h30m (Tasks 1-2 executed 2026-07-13 19:03-21:14; checkpoint verification approved 2026-07-13/14 on physical device)
- **Started:** 2026-07-13T19:03:18+03:00 (first task commit)
- **Completed:** 2026-07-14 (checkpoint approval + finalization)
- **Tasks:** 3 (2 auto tasks + 1 human-verify checkpoint, all complete)
- **Files modified:** 12 (7 created, 5 modified, plus pubspec.lock)

## Accomplishments
- Extended `UserProfile` with `displayName`/`profileImageUrl`/`profileUpdatedAt` and a `displayNameOrFallback` getter; extended `ProfileApi`/`DioProfileApi` with `updateDisplayName` (PATCH `/me/display-name`), `uploadProfileImage` (multipart POST `/me/profile-image`), and `deleteProfileImage` (DELETE `/me/profile-image`); added matching `ProfileController` mutations, all covered by hand-written fake-API controller tests.
- Built `ProfileScreen` (view + inline display-name edit + change/remove photo) in SafePath design tokens with no SOS-red, wired into the router at `/profile` (in `_authenticatedOnlyRoutes`) and reachable from a single Live Map header entry point (including the no-circle empty-state app bar).
- Built a reusable `ProfileAvatar` shared widget: `CachedNetworkImage` keyed on `userId + profileUpdatedAt` (never the signed URL) with an initials-circle fallback matching `MemberMapPin`'s visual language — ready for 02-16 to reuse on map markers.
- Added `image_picker` 1.2.3 + `cached_network_image` 3.4.1 dependencies and the iOS `NSPhotoLibraryUsageDescription` usage string.
- Human-verify checkpoint (Task 3) approved on a physical device 2026-07-13/14: display-name edit persists across reload, photo upload/replace/remove all work end-to-end against the running backend, default-avatar fallback renders correctly on removal, and no SOS-red appears anywhere on the Profile screen.

## Task Commits

Each task was committed atomically:

1. **Task 1: Extend profile model, API, and controller; add dependencies** — TDD cycle:
   - `2725145` `test(02-15): add failing profile controller tests`
   - `7e9d108` `feat(02-15): implement profile client mutations`
2. **Task 2: ProfileScreen (view + edit) with pick/upload/replace/remove and default-avatar fallback**
   - `44bab79` `feat(02-15): add profile management screen`
   - `53515a2` `fix(02-15): keep profile reachable without a circle` (Rule 1 fix — see Deviations)
3. **Task 3 [checkpoint]: Human-verify profile edit + photo upload/replace/remove end-to-end** — approved by user on physical device, no code commit (verification-only checkpoint).

**Plan metadata:** (this commit)

_Note: Task 1 followed the TDD RED→GREEN cycle (test commit then feat commit)._

## Files Created/Modified
- `mobile/lib/features/profile/data/user_profile.dart` - adds displayName/profileImageUrl/profileUpdatedAt + displayNameOrFallback
- `mobile/lib/features/profile/data/profile_api.dart` - updateDisplayName/uploadProfileImage/deleteProfileImage (Dio impls + abstract interface)
- `mobile/lib/features/profile/application/profile_controller.dart` - three new mutations following the updateRole shape
- `mobile/lib/features/profile/presentation/profile_screen.dart` - view + edit + photo management screen
- `mobile/lib/shared_widgets/profile_avatar.dart` - reusable cached avatar + initials fallback widget
- `mobile/lib/core/router/app_router.dart` - `/profile` GoRoute + `_authenticatedOnlyRoutes` entry
- `mobile/lib/features/location/presentation/live_map_screen.dart` - Profile entry point in the Live Map app bar (both normal and no-circle empty states)
- `mobile/ios/Runner/Info.plist` - `NSPhotoLibraryUsageDescription`
- `mobile/pubspec.yaml` / `mobile/pubspec.lock` - `image_picker` + `cached_network_image` dependencies
- `mobile/test/features/profile/profile_controller_test.dart` - controller mutation/fallback coverage
- `mobile/test/helpers/fake_profile_api.dart` - hand-written `_FakeProfileApi implements ProfileApi` test double

## Decisions Made
- Single shell entry point for Profile is an avatar/person action in the Live Map app bar — no sixth bottom-nav tab, preserving the SOS-centered 5-tab layout (per plan design).
- `ProfileAvatar` placed under `shared_widgets` (not inside the profile feature) so 02-16's live-map avatar markers can reuse it directly.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Profile entry point unreachable when a user has no family circle**
- **Found during:** Task 2 (ProfileScreen shell wiring), post-implementation manual check
- **Issue:** The Live Map header renders a distinct "no circle" empty-state app bar for users without a family circle yet; the initial profile entry-point wiring only added the action to the normal app bar, leaving no way to reach `/profile` before joining/creating a family.
- **Fix:** Added the same profile action to the no-circle empty-state app bar in `live_map_screen.dart`, preserving a single logical entry point (still no new bottom-nav tab).
- **Files modified:** `mobile/lib/features/location/presentation/live_map_screen.dart`
- **Verification:** `flutter analyze` clean; manually traced both app-bar render paths.
- **Committed in:** `53515a2`

---

**Total deviations:** 1 auto-fixed (1 bug fix, Rule 1)
**Impact on plan:** Necessary correctness fix so every authenticated user (not just those with an active family circle) can reach their profile. No scope creep.

## Issues Encountered
None beyond the Rule 1 fix above.

## User Setup Required
None - no external service configuration required beyond what 02-13/02-14 already established (Supabase `avatar` bucket, `Supabase__ServiceRoleKey`).

## Next Phase Readiness
- 02-16 (live-map avatar markers + always-visible name labels) can build directly on `ProfileAvatar`, the extended `UserProfile`/`LiveLocation` fields, and the `ProfileUpdated` propagation already established here and in 02-14.
- No blockers. Human-verify checkpoint fully approved: display-name edit persistence, photo upload/replace/remove, default-avatar fallback, and no-SOS-red compliance all confirmed on a physical device.

---
*Phase: 02-real-time-location-history-privacy*
*Completed: 2026-07-14*

## Self-Check: PASSED

- FOUND: `.planning/phases/02-real-time-location-history-privacy/02-15-SUMMARY.md`
- FOUND: `2725145` (test(02-15): add failing profile controller tests)
- FOUND: `7e9d108` (feat(02-15): implement profile client mutations)
- FOUND: `44bab79` (feat(02-15): add profile management screen)
- FOUND: `53515a2` (fix(02-15): keep profile reachable without a circle)
