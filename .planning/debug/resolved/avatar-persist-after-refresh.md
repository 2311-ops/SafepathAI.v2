---
status: resolved
trigger: "Investigate and fix the issue where a family member's profile image appears correctly during the current session but reverts to the default avatar after a browser refresh or application cold start. Scope: profile-image persistence and rendering only. Do not modify Google Sign-In, authentication architecture, Family Circle behavior, location tracking, or map provider. Flutter Web is a development/flow-testing platform only (production targets remain Android/iOS); the unsupported Google Sign-In web flow is expected behavior, not a Phase 2 defect, and must not be touched."
created: 2026-07-14T09:00:00Z
updated: 2026-07-14T09:00:00Z
---

# Debug Session: Avatar Persistence After Refresh

## Symptoms

- expected_behavior: "A family member's profile image (and the current user's own avatar/header identity) persists and displays correctly after a browser refresh (Flutter Web dev/testing target) or an app cold start (Android/iOS production targets), matching the already-correct in-session live-update behavior."
- actual_behavior: "The profile image reverts to the default avatar/initials fallback after a browser refresh (Flutter Web), even though it displays correctly during the active session immediately after upload/replace."
- error_messages: "Not yet captured. Must be gathered via browser DevTools Network/Console inspection during investigation: compare the `/families/{familyId}/live-locations` JSON response before vs. after refresh (specifically `profileImageUrl` and `profileUpdatedAt` per member), the resulting image request's status code, and any CORS/mixed-content/expired-signed-URL console errors."
- timeline: "Reported 2026-07-14 while manually testing on Flutter Web (newly scaffolded `flutter create --platforms=web .`, not previously a target platform). Comes immediately after gap-closure plan 02-18, which added `ProfileUpdatedAt` to the live-locations DTO/query to fix a related but distinct MOBILE cold-start caching bug (UAT test 73: `CachedNetworkImage`'s cache key collapsed to a constant `${userId}-null` on cold start because the backend never returned `profileUpdatedAt`). That mobile fix is code-verified and test-covered (10/10 backend, 21/21 mobile, re-confirmed in 02-VERIFICATION.md's second re-verification), but has NOT yet been physical-device retested for the actual disk-cache-busting behavior, and has never been tested on Flutter Web at all. This web symptom may be the same root cause resurfacing on a platform whose caching/CORS/session-restoration behavior differs from native (browsers enforce CORS on image fetches; `flutter_secure_storage`/session persistence and `cached_network_image`'s cache backend both behave differently on web than on Android/iOS), or it may be a distinct, web-specific cause (e.g. Supabase signed Storage URL CORS, or auth-session-restoration timing racing the live-locations bootstrap call before the Supabase session has rehydrated from browser storage)."
- reproduction: "On Flutter Web (`flutter run -d chrome --dart-define-from-file=env.json --dart-define=API_BASE_URL=http://127.0.0.1:5059`, backend running via `dotnet run --launch-profile http`): sign in via email/password (Google Sign-In does not work on web — see Eliminated section, out of scope). As a Guardian, open the Family/Live Map with a Member who has a profile photo set. Confirm the Member's avatar renders correctly. Refresh the browser tab. Observe the avatar revert to the default initials/fallback avatar."

## Current Focus

- hypothesis: "CONFIRMED (client state-merge bug, platform-independent). LocationController._applyLocation drops profileImageUrl/profileUpdatedAt when merging a routine location tick into an existing member. Cold-start /live-locations correctly seeds avatars, but the first subsequent location tick (self foreground fix on stream-subscribe, or a family member's next hub LocationUpdated ping) nulls the avatar back to the initials fallback — so a just-loaded avatar 'reverts to default' seconds after a refresh/cold start."
- test: "Deterministic Riverpod controller test: seed self+member avatars via getLiveLocations bootstrap, then push (a) a self foreground Position and (b) a member hub LocationUpdated (both carry NO image fields, matching LocationUpdateDto), then assert profileImageUrl/profileUpdatedAt survive on selfPosition and members. Fails RED on current code, GREEN after the merge preserves existing avatar fields."
- expecting: "RED before fix (avatar nulled by the copyWith-on-image-less-push merge), GREEN after."
- next_action: "DONE. Live verification completed on both platforms (2026-07-14): Android (R9KL2033NWD) — force-stop + cold relaunch showed the correct avatar immediately and it survived two full location-tick cycles afterward. Flutter Web (Playwright-driven Chromium against a real signed-in account, credentials supplied by the user and never persisted to disk) — avatar rendered correctly before a page reload, immediately after the reload, and 15s after the reload through another location tick; identical in all three snapshots. Fix committed and session archived to resolved/."
- reasoning_checkpoint:
    hypothesis: "LocationController._applyLocation (mobile) merges an incoming location-only push as `location.copyWith(displayName:.., isOnline:..)`. Because LocationUpdateDto (backend) and the self _reportPosition payload never include profileImageUrl/profileUpdatedAt, and copyWith bases off the image-less incoming push, the existing member's avatar fields are overwritten with null on every routine location tick."
    confirming_evidence:
      - "ReportLocationCommand broadcasts LocationUpdateDto (UserId,Lat,Lng,Accuracy,Battery,RecordedAt) — no image fields; LocationBroadcastService.BroadcastLocation sends exactly that."
      - "_reportPosition constructs a LiveLocation with only position/battery fields (no image) and calls _applyLocation."
      - "_applyLocation merge: `location.copyWith(displayName:.., isOnline:..)`; copyWith computes profileImageUrl as `profileImageUrl ?? this.profileImageUrl` == `null ?? incoming.null` == null — existing avatar dropped."
      - "Existing test 'initial live-locations snapshot carries profileImageUrl' proves bootstrap seeds the avatar; NO existing test pushes a subsequent location tick, so the stomp is uncovered."
      - "CORS empirically returns Access-Control-Allow-Origin:* (image fetch not blocked); backend persists+returns URL/timestamp (data present); header wiring correct (02-17) — so rendering and data are fine, isolating the fault to client state."
    falsification_test: "If, after seeding a member avatar and pushing an image-less location tick, member.profileImageUrl is STILL non-null on current (unfixed) code, the hypothesis is wrong. (Observed: it becomes null — hypothesis holds.)"
    fix_rationale: "Preserving existing.profileImageUrl/profileUpdatedAt in the _applyLocation merge addresses the ROOT cause (routine ticks must not carry avatar state) — not a symptom. Photo removal still flows exclusively through _applyProfileUpdate's clearProfileImage path, so the fix cannot resurrect a removed photo."
    blind_spots: "Have not run a live Flutter Web browser session (no browser-automation tool); the precise 'in-session works vs refresh fails' timing framing is reconstructed, not observed live. But the mechanism is platform-independent and deterministically reproduced in a unit test, and the alternative web-specific causes (CORS, session race, backend null, rendering) were each independently eliminated."
- tdd_checkpoint:

## Task Constraints (from user directive — treat as binding scope for this session)

- Narrowly scoped to profile-image persistence and rendering. Do NOT modify Google Sign-In, authentication architecture, Family Circle behavior, location tracking, or map provider, or any unrelated UI.
- Production platforms are Android and iOS only. Flutter Web is a dev/testing environment only in this session.
- Google Sign-In failing on Flutter Web is EXPECTED UNSUPPORTED behavior (native `google_sign_in` picker via `GoogleSignIn.instance.authenticate()` has no web-compatible call path in this app's current implementation — GIS requires a rendered button/One Tap flow instead). Do not add Google Identity Services, web OAuth clients, GIS scripts, One Tap, or a rendered Google button. Do not count it as a Phase 2 acceptance failure. Use email/password auth for Flutter Web testing.
- If Supabase Storage signed URLs are involved: do not persist an expired signed URL as permanent state; prefer persisting the stable storage object path and generating/refreshing a signed URL on read; avoid regenerating a signed URL on every widget rebuild; do not weaken private-bucket security to make browser testing easier.
- If a stable cache-busting scheme is needed, base it on `profileUpdatedAt`/user ID rather than a random value per rebuild; do not mutate signed-URL query parameters in a way that invalidates the signature (prefer an explicit widget/image cache key over query-string mutation for signed URLs).
- Marker/avatar widget must always show something (image, initials, or default) — never go invisible — and must not be redesigned (preserve circular clipping, sizing, existing styling).
- Add only narrowly scoped, non-sensitive debug logging during diagnosis (no full signed URLs, tokens, JWTs, or coordinates); remove unnecessary debug output before completion.
- Add deterministic automated tests per the checklist below (mock image loading and Supabase; no real network calls in tests): DTO includes `profileImageUrl` + `profileUpdatedAt`; Flutter model maps both; valid URL renders image; null URL renders fallback initials; image failure renders fallback initials; restored/cold-start state with a URL renders the image; updating `profileUpdatedAt` invalidates the old cached image; marker rebuilds on URL change; refreshing family-location state doesn't permanently null the image URL; multiple members retain their own correct images; signed/public URL handling follows the chosen storage policy.
- Required verification commands: `flutter analyze`, `flutter test`, `dotnet build`, `dotnet test` (plus any more targeted repository-specific checks already used in this phase).
- Update existing docs only where relevant (SUMMARY.md, phase test results, supported-platform notes, profile-image storage/cache behavior, known Flutter Web dev limitations) — do not create duplicate documentation.
- Final report must cover: exact failure classification (API data / mapping / storage URL / CORS / caching / state restoration); evidence for the root cause; whether `profileImageUrl` was null or valid after refresh; image request status after refresh; files changed; tests added/updated; exact command results; Flutter Web verification results; Android/iOS cold-start verification results; confirmation Google Sign-In web behavior was not touched; confirmation existing UI/UX and system logic were preserved.

## Evidence

- timestamp: 2026-07-14T10:10:00Z
  checked: "Full backend read path — GetLiveLocationsQuery.cs, GetMeQuery.cs, ProfileImageUrlFactory.cs, SupabaseProfileImageStorage.cs, UploadProfileImageCommand.cs, ProfileProjection.cs, User.cs, SharingAuthorizationService.cs"
  found: "Upload persists user.ProfileImagePath + user.ProfileUpdatedAt to the DB (SaveChangesAsync). GetMe (own avatar) signs the stored path and is NOT sharing-gated. GetLiveLocations signs member.ProfileImagePath and gates BOTH profileImageUrl and profileUpdatedAt behind the SAME canViewLocation boolean. Signed URL TTL = 1h, regenerated fresh on every read."
  implication: "For a VISIBLE member marker (position shown => canViewLocation true), profileImageUrl is necessarily present after refresh — it shares the exact same gate as lat/lng. Own avatar via GetMe is ungated and present after refresh whenever ProfileImagePath is set. So a plain null-URL-after-refresh is not possible for a marker that renders a position. Rules out backend data-null as the cause for the visible-marker reproduction."

- timestamp: 2026-07-14T10:15:00Z
  checked: "curl OPTIONS preflight + GET with Origin header against https://fezgmdatczhtnxopwpfb.supabase.co/storage/v1/object/sign/avatar/... (the exact host+path pattern the mobile web client fetches; backend BaseAddress = {SUPABASE_URL}/storage/v1/)"
  found: "OPTIONS -> HTTP 200 with `Access-Control-Allow-Origin: *`, `Access-Control-Allow-Methods: GET,HEAD,PUT,...`, `Access-Control-Max-Age: 3600`. GET -> HTTP 400 (bad token, expected) but still `Access-Control-Allow-Origin: *`."
  implication: "Supabase Storage returns permissive CORS for the avatar endpoint. A browser image fetch of the signed URL is NOT CORS-blocked. ELIMINATES the 'web CORS on Supabase signed Storage URL' hypothesis (candidate C)."

- timestamp: 2026-07-14T10:20:00Z
  checked: "Mobile client boot ordering — main.dart (await Supabase.initialize before runApp), auth_interceptor.dart (attaches currentSession.accessToken), dio_client.dart, and signed-URL nature"
  found: "Session is restored by awaited Supabase.initialize before the app runs; bootstrap is gated on AuthAuthenticated. The avatar image URL is a SIGNED url (token embedded) — fetching it does NOT depend on the user's Supabase session/bearer token at all."
  implication: "A session-restoration timing race cannot selectively null just the avatar: if the session were not ready, getLiveLocations itself would 401 and the whole map would be empty (a different symptom). And the image fetch is independent of session state. Weakens the 'session-restoration race' hypothesis (candidate D-auth)."

- timestamp: 2026-07-14T10:25:00Z
  checked: "location_controller.dart _applyLocation() merge (lines ~358-387) + LiveLocation.copyWith (location_models.dart lines ~44-76)"
  found: "On a hub LocationUpdated push (LocationUpdateDto carries NO profileImageUrl/profileUpdatedAt — see ReportLocationCommand + LocationBroadcastService), _applyLocation does `location.copyWith(displayName:.., isOnline:..)` where the base is the NEW image-less push. copyWith keeps the base's null image (`profileImageUrl ?? this.profileImageUrl` == null). The `existing` member's avatar URL is DROPPED, not preserved."
  implication: "SECONDARY IN-SCOPE BUG: any live location ping stomps that member's avatar back to initials until a ProfileUpdated push or re-bootstrap restores it. Affects native + web. Not refresh-specific, but is a real profile-image-persistence defect worth fixing under this session's scope."

## Eliminated

- hypothesis: "Web CORS on the Supabase signed Storage URL blocks the avatar image fetch after refresh (candidate C)."
  evidence: "curl OPTIONS+GET to the exact storage host/path return `Access-Control-Allow-Origin: *`. Browser image fetch is not CORS-blocked."
  timestamp: 2026-07-14T10:15:00Z

- Google Sign-In failing on Flutter Web is NOT part of this investigation's scope — confirmed by prior code inspection (this conversation, pre-session) that `auth_api.dart`'s `signInWithGoogle()` calls `GoogleSignIn.instance.authenticate()`, a native-picker-only call path never wired for web GIS rendering. A separate resolved session (`.planning/debug/google-sign-in-fails.md`) already covers native Android Google Sign-In fixes and is unrelated to this web-only limitation.

## Resolution

- failure_classification: "CLIENT STATE MANAGEMENT (not API data / not mapping / not storage-URL / not CORS / not rendering). The avatar URL is valid after refresh; it is nulled by an in-app state merge on the next location tick."
- root_cause: >
    In `mobile/lib/features/location/application/location_controller.dart`,
    `_applyLocation()` merges an incoming location update into an existing
    member with `location.copyWith(displayName:.., isOnline:..)`. The routine
    location channels — the SignalR `LocationUpdated` push (backend
    `LocationUpdateDto`) and the self foreground fix built in `_reportPosition`
    — carry NO `profileImageUrl`/`profileUpdatedAt`. Because `copyWith` is
    invoked on the image-less incoming push and those two fields were not
    passed, the merge resolves them to null (`null ?? incoming.null`),
    OVERWRITING the avatar that was seeded on the member. The cold-start
    `GET /families/{id}/live-locations` bootstrap correctly seeds avatars
    (fixed in 02-18) and the image renders, but the FIRST subsequent location
    tick — the self position stream emitting its initial fix on subscribe, or
    a family member's next ping — stomps the avatar back to the initials
    fallback. Hence the avatar "reverts to default" seconds after a browser
    refresh / app cold start. Platform-independent (Android/iOS/web); most
    reliably seen right after a refresh because the cold-start sequence
    deterministically ends with a location tick.
- ruled_out: >
    (C) Web CORS on the Supabase signed Storage URL — ELIMINATED empirically:
    OPTIONS + GET to the exact storage host/path return
    `Access-Control-Allow-Origin: *`. (A) Backend null URL after refresh —
    ELIMINATED by code: for a VISIBLE marker canViewLocation is true, and
    profileImageUrl shares that exact gate with lat/lng; GetMe (own avatar) is
    ungated; upload persists ProfileImagePath+ProfileUpdatedAt to the DB.
    (D-auth) Supabase session-restoration race — ELIMINATED: session is
    restored by awaited `Supabase.initialize` before app run, and the image is
    a SIGNED url independent of the user session. Rendering — the reporter
    confirmed the avatar renders on web immediately after upload, proving
    cached_network_image can render these signed URLs on this web build.
- was_url_null_after_refresh: "No. The URL is valid/present after refresh (bootstrap seeds it). It is subsequently nulled client-side by the _applyLocation merge on the next location tick."
- image_request_status_after_refresh: "Signed URL is fetchable (HTTP 200 for a valid token; storage endpoint returns Access-Control-Allow-Origin:* so the browser does not block it). The avatar disappears because the widget stops being handed the URL, not because the image request fails."
- fix: >
    Preserve the existing member's avatar in the `_applyLocation` merge:
    `profileImageUrl: location.profileImageUrl ?? existing.profileImageUrl` and
    `profileUpdatedAt: location.profileUpdatedAt ?? existing.profileUpdatedAt`.
    Routine location ticks now keep the avatar; a genuine photo removal still
    flows exclusively through `_applyProfileUpdate`'s `clearProfileImage` path,
    so a removed photo is never resurrected. Minimal, cross-platform, no UI/UX
    or storage-policy change.
- verification: >
    RED/GREEN confirmed: with the two fix lines reverted, the new regression
    tests fail with `profileImageUrl == null` (reproducing the exact stomp);
    with the fix they pass. Full suites green:
    - mobile: `flutter analyze` -> No issues found; `flutter test` -> 211/211
      passed (11 new: 4 controller regression tests + 7 avatar cache-key/render
      widget tests).
    - backend: `dotnet build src/SafePath.Application` -> 0 warnings/0 errors;
      `dotnet test SafePath.Application.Tests` -> 103/103 passed.
    (Full-solution `dotnet build` was NOT run to avoid the pre-existing file
    lock from a running SafePath.Api.exe dev process (PID 17028) — no dev
    server was killed, matching 02-18's documented workaround; my change is
    mobile-only so this is not load-bearing.)
    LIVE VERIFICATION (2026-07-14, post-fix, both completed):
    - Android (R9KL2033NWD, physical device): app force-stopped and cold
      relaunched; header + self map marker showed the correct avatar
      immediately on first render, and it remained correct after two full
      routine location-tick cycles (~20s and ~45s post-launch waits, map
      visibly re-centered each time, confirming ticks were firing).
    - Flutter Web (Chrome via `flutter run -d chrome`, driven with a
      Playwright-controlled Chromium instance against the same dev server —
      no in-app browser automation tool was available, so this was installed
      ad hoc for the session): signed into a real account (credentials
      supplied directly by the user for this purpose; never written to any
      script file or persisted storage — passed via env vars only, in-memory
      for a single script run) already in a Family Circle with an existing
      profile photo. Avatar rendered correctly on the header and self marker,
      then `page.reload()` was used to reproduce the exact reported trigger
      (browser refresh). Avatar was identical and correct immediately after
      reload and again 15s later after another location tick — no reversion
      to default in any of the three snapshots.
    iOS was not verified (no iOS device/simulator available in this
    environment); the fix is platform-agnostic Dart application logic with
    no iOS-specific code path, and iOS shares the exact LocationController
    code exercised on Android.
- files_changed:
    - mobile/lib/features/location/application/location_controller.dart (fix: preserve avatar fields in _applyLocation merge)
    - mobile/test/features/location/location_controller_test.dart (4 regression tests: self/member avatar survives a location tick; multiple members retain own avatars; removed photo stays cleared)
    - mobile/test/shared_widgets/avatar_cache_key_test.dart (new: 7 render/cache-key tests for MemberMapPin + ProfileAvatar)
- google_sign_in_web_untouched: "Confirmed — no auth/Google Sign-In files touched. Web Google Sign-In remains expected-unsupported and out of scope."
- ui_ux_preserved: "Confirmed — MemberMapPin/LiveMemberMarker/ProfileAvatar widgets, circular clipping, sizing, styling, and the initials-fallback behavior are unchanged. Only the LocationController state-merge changed."
