---
gsd_state_version: 1.0
milestone: v1.0
milestone_name: milestone
current_phase: 4
current_phase_name: Geofencing
status: verifying
stopped_at: Phase 4 planned
last_updated: "2026-08-10T16:03:00.167Z"
last_activity: 2026-08-08
last_activity_desc: "Completed quick task 260808-51d: Add ngrok remote-contributor testing section to start_mobile.md"
progress:
  total_phases: 5
  completed_phases: 4
  total_plans: 61
  completed_plans: 44
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-07-16)

**Core value:** The SOS system must always work — a single tap or covert Silent/Duress trigger reliably delivers an immediate alert with live location to a user's designated guardians within seconds, bypassing every routine and AI pipeline.
**Current focus:** Phase 03 — sos-fast-path

## Current Position

Phase: 4 — Geofencing
Plan: Not started
Status: All plans complete — awaiting phase-level verification/closeout
Last activity: 2026-08-08 — Completed quick task 260808-51d: Add ngrok remote-contributor testing section to start_mobile.md

Progress: [██████████] 100%

## Performance Metrics

**Velocity:**

- Total plans completed: 28
- Average duration: - min
- Total execution time: 0 hours

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 02 | 19 | - | - |
| 03 | 9 | - | - |

**Recent Trend:**

- Last 5 plans: none yet
- Trend: N/A

*Updated after each plan completion*
| Phase 01-backend-auth-foundation P05 | 27min | 3 tasks | 29 files |
| Phase 01 P08 | 40min | 3 tasks | 13 files |
| Phase 01-backend-auth-foundation P09 | 25min | 2 tasks | 6 files |
| Phase 01-backend-auth-foundation P10 | 11min | 2 tasks | 10 files |
| Phase 01-backend-auth-foundation P11 | review-fix | 3 tasks | auth/env/docs |
| Phase 01-backend-auth-foundation P12 | review-fix | 2 tasks | family invariants/invites |
| Phase 01-backend-auth-foundation P13 | review-fix | 3 tasks | ownership/delete/db |
| Phase 01-backend-auth-foundation P14 | review-fix | 3 tasks | deep links/reset UX/tests |
| Phase 01.1-animated-logo-splash-screen P01 | 15min | 2 tasks | 3 files |
| Phase 01.1-animated-logo-splash-screen P02 | 35min | 4 tasks | tests/auth/splash |
| Phase 02-real-time-location-history-privacy P01 | multi-session | 4 tasks | 19 files |
| Phase 02-real-time-location-history-privacy P02 | 8min | 3 tasks | 24 files |
| Phase 02-real-time-location-history-privacy P03 | 9min | 3 tasks | 25 files |
| Phase 02-real-time-location-history-privacy P06 | 18min | 3 tasks | 22 files |
| Phase 02-real-time-location-history-privacy P04 | 7min | 3 tasks | 10 files |
| Phase 02 P07 | 12min | 3 tasks | 12 files |
| Phase 02-real-time-location-history-privacy P05 | 8min | 3 tasks | 18 files |
| Phase 02-real-time-location-history-privacy P08 | 9min | 3 tasks | 12 files |
| Phase 02-real-time-location-history-privacy P09 | 11min | 3 tasks | 12 files |
| Phase 02-real-time-location-history-privacy P10 | 17min | 2 tasks | 5 files |
| Phase 02-real-time-location-history-privacy P11 | 7min | 2 tasks | 3 files |
| Phase 02-real-time-location-history-privacy P13 | 48min | 3 tasks | 14 files |
| Phase 02 P14 | 10min | 3 tasks | 19 files |
| Phase 02 P15 | ~2h30m | 3 tasks | 12 files |
| Phase 02 P16 | ~10min | 4 tasks | 7 files |
| Phase 02 P17 | 7min | 1 tasks | 2 files |
| Phase 02-real-time-location-history-privacy P18 | 25min | 2 tasks | 4 files |
| Phase 02 P19 | 20min | 2 tasks | 3 files |
| Phase 03-sos-fast-path P01 | 10min | 3 tasks | 28 files |
| Phase 03 P02 | 25min | 3 tasks | 18 files |
| Phase 03-sos-fast-path P03 | 35min | 3 tasks | 18 files |
| Phase 03-sos-fast-path P04 | 72min | 3 tasks | 13 files |
| Phase 03 P05 | 15min | 3 tasks | 20 files |
| Phase 03-sos-fast-path P07 | 17min | 3 tasks | 17 files |
| Phase 03 P08 | 45min | 3 tasks | 20 files |
| Phase 03-sos-fast-path P09 | multi-session | 3 tasks | 12 files |

## Accumulated Context

### Decisions

Decisions are logged in PROJECT.md Key Decisions table.
Recent decisions affecting current work:

- Roadmap: Followed research/SUMMARY.md's core-value-first 8-phase structure, but folded the standalone SignalR-only phase into Phase 2 (Real-Time Location) — no v1 requirement uniquely needed a separate real-time-layer phase; SOS-02's SignalR channel is delivered within Phase 3's dedicated AlertHub instead.
- Roadmap: Cross-Modal Detection (Phase 6) is sequenced before Health & Wellness (Phase 7) per research — XMOD-02 explicitly allows seeded/synthetic health data so it doesn't hard-block on the Health module.
- Auth (2026-07-08, uncommitted at time of discovery): Pivoted from plan 01-01's locked D6 (custom JWT auth, `AuthController`, `TokenStorage`) to Supabase-managed auth (backend validates Supabase-issued JWTs via `MeController`; mobile reads tokens from Supabase's session object). Orphaned custom-JWT command handlers/identity helpers/tests removed from the codebase. See superseding note on D6 in `01-01-PLAN.md` and the addendum in `01-03-SUMMARY.md`. Any plan 01-04+ work involving auth must build against Supabase Auth, not the original custom JWT design.
- Plans 01-04/01-06 (2026-07-09): Marked complete-via-supersession, not executed as written. AUTH-04 (password reset) is satisfied entirely by Supabase Auth's native `resetPasswordForEmail`/`updateUser` flow — no `PasswordResetToken` entity, `IEmailSender`/Resend integration, or custom `/auth/forgot-password|reset-password` endpoints exist or are needed. The mobile screens (`forgot_password_screen.dart`, `reset_password_screen.dart`) were already built and tested against Supabase Auth directly. See `01-04-SUMMARY.md`/`01-06-SUMMARY.md` for detail. Remaining real Phase 1 work is family-circle only: `01-05` (backend) and `01-07` (mobile).
- Backend `Users` table sync (2026-07-08/09): Added a Postgres trigger (`handle_new_auth_user`) mirroring every Supabase `auth.users` signup into `public."Users"` (full name + role from `raw_user_meta_data`), since nothing previously wrote to that table under the Supabase Auth flow. Dropped the now-dead `PasswordHash` column and `RefreshTokens` table.
- Mobile test suite (2026-07-09): 60 tests now cover registration/login/logout, password reset, session persistence, Supabase auth-state-stream reactions, and router navigation — all against a hand-written `FakeAuthApi`, no real Supabase/network calls. Found and fixed a real defect: `AuthInterceptor` was forcing sign-out on any token-refresh failure (including transient network errors) instead of only on a genuinely dead session — see `mobile/lib/core/network/auth_interceptor.dart` and `AuthIssue.sessionInvalid`.
- [Phase 01-05]: Family-circle backend (01-05) built against the post-migration Supabase Auth current-user mechanism (JWT sub claim via ICurrentUserService) instead of the original custom-JWT assumption; IFamilyAuthorizationService.RequireMembership/RequireRole is the sole server-side authorization mechanism (D5) for every family-scoped handler operating on an existing family
- [Phase 01-05]: Added IInviteCodeGenerator as an Application-layer interface (not explicitly in the plan file list) so GenerateInviteCommand never references the concrete Infrastructure InviteCodeGenerator class, preserving the Clean Architecture boundary
- [Phase 01-05]: RemoveMemberCommand guards against removing the last active Guardian of a family; FamilyCircle EF migration applied to the live Supabase database via dotnet ef database update
- [Phase 01-08]: Reused the existing safepathai://reset-password redirect URL for Google OAuth (D-08-2) — zero new Supabase dashboard config; safepathai:// deep-link scheme (previously unregistered on Android/iOS) added as a prerequisite fix that also unblocks the pre-existing password-reset deep link. Google sign-in must reuse Supabase's Web OAuth client and avoid touching provider config the user set up separately.
- [Phase 01-08]: `AuthController.build()` guards `WidgetsBinding.instance.addObserver`/`removeObserver` with try/catch — this feature's own established test convention drives `AuthController` via a bare `ProviderContainer` in plain `test()` bodies with no Flutter binding initialized, which would otherwise crash every such test the moment a `WidgetsBindingObserver` is registered.
- [Phase 01-09]: Reversed 01-08's browser-based signInWithOAuth Google flow to google_sign_in's native GoogleSignIn.instance.authenticate() + Supabase signInWithIdToken() at the user's explicit request (no Supabase/Google URL ever shown); verified the actually-resolved google_sign_in 7.2.0 API from package source rather than assuming it, and removed AuthController's WidgetsBindingObserver-based lifecycle-resume recovery (01-08 D-08-6) as dead code since the native picker is synchronously awaitable end-to-end.
- [Phase 01-backend-auth-foundation]: [Phase 01-10] Closed a Phase-1 UAT gap: added GET /families/mine (server never caps to one family, D-10-1) and a mobile FamilyController bootstrap fetch (build()-time check + ref.listen auth transition, D-10-3) so a Guardian/Member's circle survives logout/login and cold app restarts instead of living only in session Riverpod state.
- [Phase 01-11]: Locked the architecture around Supabase-owned authentication: backend validates Supabase JWTs and reads role/profile from the `Users` table for `/me`, secrets load from local `.env` files during development, and `AuthResult` custom-JWT dead code was removed.
- [Phase 01-12]: Enforced the Phase 1 single-active-family invariant in backend command handlers and the database, returning 409 conflicts for duplicate create/join attempts and adding Guardian invite revocation.
- [Phase 01-13]: Added Guardian ownership transfer and delete-family workflows, plus FK/cascade migration and an explicit RLS/Data API deny posture for family tables.
- [Phase 01-14]: Added invite deep-link handling with pending-invite restoration after auth, distinct decline behavior, and amber expired-reset-link messaging while preserving SOS red exclusively for emergency surfaces.
- [Phase 01.1-01]: Splash providers use Notifier/NotifierProvider + set() (matching deep_link_service.dart convention) instead of legacy StateProvider, which is unavailable in this project's flutter_riverpod 3.3.2
- [Phase 02-01]: Approved and retained signalr_netcore 1.4.4 after package legitimacy review and physical-device smoke verification.
- [Phase 02-01]: SignalR hub user identity is normalized through SupabaseUserIdProvider using the JWT sub claim, matching the backend application user ID model.
- [Phase 02-01]: Temporary Task 4 smoke-only hub method and Flutter smoke entrypoint were removed before close-out; permanent verification is the integration guard plus recorded device smoke evidence.
- [Phase 02-02]: Location DTOs live under SafePath.Application.Location; Application handlers own the feature contracts while Infrastructure hub/client code consumes them.
- [Phase 02-02]: Live-location presence combines IPresenceQuery connection state with a 2-minute ping freshness window, preserving connected-but-stale rendering via RecordedAtUtc.
- [Phase 02-02]: ReportLocationCommand validates coordinates, non-future timestamps, non-negative accuracy, and battery percent 0-100 before persisting raw pings.
- [Phase 02-03]: SharingPreference is additive to FAM-04 PermissionLevel; privacy sharing consent and member permissions remain separate authorization axes.
- [Phase 02-03]: Missing sharing rows default to shared-with-family, explicit recipient rows override default rows, and expired rows are denied at authorization time.
- [Phase 02-03]: Privacy preference updates force OwnerUserId to the authenticated caller; clients cannot set another user's owner id.
- [Phase 02-03]: Temporary sharing expiry uses a hosted BackgroundService plus authorization-time expiry checks; no queue or cryptography library was added.
- [Phase 02-06]: Google Maps API keys are wired through build-time placeholders rather than hardcoded secrets; provide MAPS_API_KEY_ANDROID and MAPS_API_KEY_IOS in local/device builds.
- [Phase 02-06]: Mobile location permission prompting uses an injectable Geolocator permission service so requestPermission is strictly CTA-gated and testable.
- [Phase 02-06]: LocationController opens the hub only after authenticated auth state plus loaded family state, then tears down on sign-out.
- [Phase 02-04]: TimeAway is defined as elapsed time between first and last ping in the bounded history range, or zero with fewer than two pings.
- [Phase 02-04]: History and travel-stats reads enforce RequireMembership, target-in-family re-scope, and SharedDataType.History before any LocationPing range read.
- [Phase 02-04]: StopDetection uses DwellTimeDefaults plus averaged dwell-cluster coordinates as the representative stop point.
- [Phase 02]: [Phase 02-07]: Mobile LiveLocation now mirrors backend MemberLiveLocationDto displayName/isOnline while keeping hub PresenceChanged as an independent state signal. — Required so the member detail sheet can show names/status without collapsing presence and staleness.
- [Phase 02]: [Phase 02-07]: LowBattery is implemented as a typed mobile hub stream and caution banner ahead of the absent backend 02-05 event. — The 02-07 plan required the client surface, but 02-05-SUMMARY.md and the backend event are not present yet.
- [Phase 02-05]: LowBatteryAlertTracker is injected through an Application interface so the falling-edge tracker remains an Infrastructure singleton without breaking Clean Architecture.
- [Phase 02-05]: Low-battery alerts reuse the LiveLocation eligible-recipient filter before hub fan-out, so disabled sharing suppresses battery alerts to that recipient.
- [Phase 02-05]: Privacy export/delete endpoints derive the caller from ICurrentUserService only; export includes caller location/sharing rows and delete hard-deletes only caller LocationPings.
- [Phase 02-08]: HistoryController derives familyId from FamilyController instead of duplicating family discovery in the location feature.
- [Phase 02-08]: Mobile history routes render with google_maps_flutter Polyline inside route_stats_sheet.dart; Activity remains shell-hosted rather than adding a separate /activity route.
- [Phase 02]: [Phase 02-09]: PrivacyController derives familyId from FamilyController and uses server-backed PATCH toggles with rollback on failure.
- [Phase 02]: [Phase 02-09]: Privacy export uses existing share_plus JSON text sharing; delete uses Ink/700 confirmation friction and no SOS-red token.
- [Phase 02]: [Phase 02-10]: LOC-05 is enforced at both /home routing and LocationController bootstrap; non-granted permission reaches priming before MainShell/LiveMapScreen and before live API, SignalR, or Geolocator streaming.
- [Phase 02]: [Phase 02-11]: Temporary sharing controls are recipient-scoped inside each Privacy Center recipient row, so presets and Custom pass that row's memberId to PrivacyController.startTemporaryShare.
- [Phase 02]: [Phase 02-11]: Custom temporary sharing defaults to hours, supports minutes/hours, validates non-numeric/non-positive/greater-than-7-day values, and passes the parsed Duration.
- [Phase 02-13]: Supabase Storage bucket is `avatar` (singular), not the originally planned `avatars`; backend uses configurable `Supabase:AvatarBucket` defaulting to `avatar`, while object paths remain traversal-proof as `avatars/{serverGuid}/avatar.jpg`.
- [Phase 02-13]: ImageSharp 4.0.0 requires an uncommitted Six Labors license file or `SIXLABORS_LICENSE_KEY` at build time; `.gitignore` excludes `sixlabors.lic`, and no license material is committed.
- [Phase 02-14]: Profile writes stay `/me`-only and derive `CallerUserId` exclusively from `ICurrentUserService`; signed avatar URLs use a shared 1-hour `ProfileImageUrlFactory`; `ProfileUpdated` broadcasts only on profile changes while `LocationUpdateDto` remains lean.
- [Phase ?]: [Phase 02-16]: LiveLocation.copyWith gained an explicit clearProfileImage flag (mirroring clearError/clearLowBatteryAlert) so a removed profile photo actually clears the marker avatar instead of falling back via the usual ?? merge; LocationController._applyProfileUpdate stamps a fresh local profileUpdatedAt on avatar changes to bust the CachedNetworkImage cache key since the ProfileUpdated hub payload carries no timestamp. live_map_screen.dart's marker widget was promoted from private _LiveMemberMarker to public LiveMemberMarker so it is directly testable.
- [Phase ?]: [Phase 02-15]: Profile entry point is a single Live Map app-bar action (both normal and no-circle empty states) rather than a new bottom-nav tab; ProfileAvatar placed under shared_widgets so 02-16's map markers can reuse it.
- [Phase ?]: Header MemberMapPin reads userId/profileImageUrl/profileUpdatedAt from state?.selfPosition (not the self fallback variable), keeping label 'You' fixed — closing UAT test 72 for the Live Map header identity avatar — The header pin was a hardcoded const MemberMapPin, structurally immune to Riverpod rebuilds; family member markers (LiveMemberMarker) already read live avatar data from LiveLocation, but the header identity was left out
- [Phase ?]: [Phase 02-18]: MemberLiveLocationDto.ProfileUpdatedAt is gated identically to ProfileImageUrl behind the existing canViewLocation sharing check (no new authorization call); appended as the last positional DTO parameter to preserve the single existing construction site.
- [Phase 02]: [Phase 02-19]: Ping-derived IsOnline recency is treated as LiveLocation data and is false when canViewLocation is false. — Closes CR-01 / PRIV-02 by preventing recent location pings from contributing to IsOnline for viewers denied LiveLocation sharing.
- [Phase 02]: [Phase 02-19]: Independent IPresenceQuery.IsOnline connection presence remains visible under denied LiveLocation sharing, preserving D-03. — The plan explicitly preserves the accepted non-location connection-presence signal while gating only ping-derived recency.
- [Quick 260717-pwh]: LiveMapScreen converted from ConsumerWidget to ConsumerStatefulWidget owning a MapController; rail-card tap now recenters the map camera (zoom 17) instead of opening the member detail sheet, while marker-pin tap keeps opening it — two complementary interactions (locate-on-map vs. details).
- [Quick 260720-3u4]: MemberMapPin now exposes one clean Semantics label combining the member label with current-location or staleness status, so screen readers do not announce the initials and badge as separate fragments.
- [Quick 260802-w1e]: Added codemagic.yaml (manual-start ios-testflight + android-apk workflows, Codemagic automatic ios_signing + App Store Connect integration, no local Mac/Xcode needed) and docs/EXTERNAL-SETUP.md (Firebase/APNs/App Store Connect/Codemagic provisioning runbook, correcting 03-06's superseded FIREBASE_PROJECT_ID/GOOGLE_APPLICATION_CREDENTIALS names to the shipped Firebase:ProjectId/Firebase:CredentialsPath binding). Unblocks the pending 03-06 Task 3 FCM verification todo for provisioning purposes only; the actual two-device manual verification and all external account/key creation remain human-only follow-up.
- [Phase 03-01]: Recipient resolution (ResolveRecipients) queries active Guardians only, bypassing ISharingAuthorizationService so a privacy preference can never suppress an SOS emergency.
- [Phase 03-01]: GetSosSessionQuery/Handler added (not in original file list) plus a shared SosSessionProjection helper, so SosController.Get matches the controller-only-calls-handlers convention and both handlers never diverge on DTO shaping.
- [Phase 03-02]: SosController.arm() generates and persists a v4 session id before any network call; sosSessionId is a plain controller getter outside the sealed SosSessionState so D-13/D-14 are observable without a placeholder session
- [Phase 03-02]: Promoted uuid and url_launcher from transitive to direct dependencies (already resolved in pubspec.lock via signalr_netcore/qr_flutter and share_plus) rather than gating as new package installs, matching the plan's own shared_preferences precedent
- [Phase 03-02]: Fixed a pre-existing stray-comma syntax bug in member_map_pin.dart that had been silently breaking compilation of the whole mobile test suite; also fixed a rehydrate/arm race and a deactivated-context crash discovered in SosController/SosArmButton
- [Phase ?]: [Phase 03-03]: TriggerSosCommandHandler's fire-and-forget dispatch now resolves its own IServiceScopeFactory-created DI scope instead of reusing the request-scoped DbContext, matching SharingPreferenceSweepService's background-scope convention -- avoids a DbContext concurrency race/crash against the disposed request scope.
- [Phase ?]: [Phase 03-03]: AcknowledgeSosCommand and AlertHub.ConfirmReceipt both explicitly add the triggering user into the DeliveryStatusChanged broadcast recipient set so the sender's own session reflects live delivery/acknowledgement changes.
- [Phase ?]: [Phase 03-03]: CancelSosCommand is self-cancel-only (TriggeredByUserId), idempotent, and never mutates/deletes SosDeliveryAttempt rows -- cancellation is a parallel notice, never a retraction.
- [Phase 03-04]: SosResponderController owns sosHubClientProvider's connect/disconnect lifecycle exclusively; SosController only listens to its streams -- one HubConnection per app session.
- [Phase 03-04]: Fixed app_router.dart's authenticated-only-route guard: matchedLocation can never equal a parameterized route pattern like /sos/responder/:sessionId, so the check now uses fullPath instead.
- [Phase 03-04]: Call sender opens a blank OS dialler (no phone-number field exists yet for family members on the wire) -- documented as a Known Stub pending a future phone-field addition.
- [Phase 03-05]: PhoneNumberNormalizer lives in SafePath.Application.Sos; libphonenumber-csharp added as a direct package reference on SafePath.Application.csproj (same already-approved 9.0.35) rather than an IPhoneNumberNormalizer indirection.
- [Phase 03-05]: TriggerSosCommandHandler.ResolveRecipients widened to also resolve the caller's active EmergencyContacts as Sms-channel recipients, still bypassing ISharingAuthorizationService so a privacy preference can never suppress an emergency contact either.
- [Phase 03-05]: SosAlertDispatcher's Sms arm isolates failures per-contact (not just per-channel) so one bad phone number cannot flip a sibling contact's already-successful Queued row to Failed.
- [Phase 03-05]: Kept Twilio signature validation behind an ISmsWebhookSignatureValidator seam (Application interface, TwilioWebhookSignatureValidator implementation) instead of inline in SmsWebhookController, so RecordSmsDeliveryStatusCommandHandler is unit-testable from SafePath.Application.Tests without an HTTP host; the validator refuses every request when no Twilio auth token is configured, not just on a signature mismatch.
- [Phase 03-07]: SosController's retry loop is a single injectable SosRetryScheduler seam (schedule(Duration, callback) -> SosRetryHandle), not a bespoke backoff package -- idempotency stays server-side (03-01) as the only part that must not be improvised.
- [Phase 03-07]: sosHubClientProvider's default construction depends on an initialized Supabase client, absent in the unit-test process -- every test container reading sosControllerProvider now overrides sosHubClientProvider with FakeSosHubClient so SosController.build() actually completes (including its connectivity subscription) instead of silently failing into an unobserved AsyncError.
- [Phase 03-07]: Corrected the pre-existing generic AsyncError-state copy on the sender screen: since Task 1 routes every network failure through SosOfflineQueued instead, the AsyncError branch is now reached only for a genuine non-network rejection that will not retry automatically, so it surfaces the server's own rejection message instead of a false 'keep trying' claim.
- [Phase 03-06]: Task 3's manual FCM verification closed 2026-08-05, Android-only: physical device (sender) + Android emulator (Guardian, terminated) confirmed real push delivery, correct deep-link into ResponderAlertScreen, and Queued->Delivered->Acknowledged server-side via a direct GET /sos/{id} read. iOS/APNs and D-32 multi-device explicitly not tested -- see 03-06-SUMMARY.md.
- [Phase ?]: [Phase 03-08]: LiveWindowEndsAtUtc is stamped from TriggerSosCommandHandler's server-side ReceivedAtUtc via a new optional SosLiveWindowOptions parameter (default 15 min), never the client-supplied TriggeredAtUtc -- a skewed device clock cannot extend how long it is tracked (T-03-28).
- [Phase ?]: [Phase 03-08]: ReportSosLocationCommandHandler returns a typed outcome (Accepted/WindowClosed/SessionNotFound) instead of throwing for a closed window or missing session, so a client that keeps sending after expiry gets a normal refusal it can act on.
- [Phase ?]: [Phase 03-08]: SosLiveLocationService/backend ReportSosLocationCommand never touch LocationPings/ReportLocationCommandHandler/ISharingAuthorizationService/ILowBatteryAlertTracker -- the emergency stream stays structurally isolated from routine location tracking in both directions (SOS-01).
- [Phase ?]: [Phase 03-08]: D-33 force-kill survival needed zero custom Kotlin -- flutter_foreground_task v10.0.0's own onTaskRemoved/RestartReceiver logic already handles it once android:stopWithTask=false and the matching Dart ForegroundTaskOptions.stopWithTask=false are set.
- [Phase ?]: [Phase 03-08]: responder_alert_screen.dart's live-location card uses maplibre_gl's VectorMap (the project's actual post-260806-3zb map stack), not the plan's stale flutter_map read_first pointer.
- [Phase ?]: [Quick 260807-qhg]: Consolidated the splash lockup into a shared AnimatedSafePathMark (ring trace + staggered per-letter wordmark + halo), both SplashScreen and StartupSplashOverlay now synced to 1800ms; fixed StartupSplashOverlay's Stopwatch-based progress (untestable under flutter_test's FakeAsync clock) to tick-count accumulation on the same Timer.periodic.
- [Phase 03-09]: Cancellation is additive-only (never mutates/deletes SosDeliveryAttempt rows) and the quick_actions shortcut reuses SosController.arm() verbatim, registered only while authenticated.
- [Phase 03-09]: Fixed a real bug found during Task 3 manual verification: SosLiveLocationService now reports a best-effort one-shot GPS fix on start() so a stationary sender's live location no longer waits on movement (see 03-09-SUMMARY.md).

### Pending Todos

| Title | Area | File |
|-------|------|------|
| Investigate sender-screen delivery chip not visually updating on Device A despite correct server-side Queued->Delivered tracking (found during 03-06 Task 3 verification 2026-08-05) | investigation | see 03-06-SUMMARY.md "Issues Encountered" |
| Investigate FamilyController cold-start bootstrap issue: app relaunch showed "No circle yet" for a real family member until a full emulator reboot (found during 260805-uke Task 3 verification) | investigation | [todos/pending/2026-08-05-family-controller-cold-start-bootstrap-race.md](./todos/pending/2026-08-05-family-controller-cold-start-bootstrap-race.md) |
| Live Map family/self pin visibly "rolls"/vibrates while panning left-right (post-260806-3zb maplibre_gl migration); suspected unguarded overlapping async reprojection calls resolving out of order | investigation | [todos/pending/2026-08-06-live-map-pin-jitter-during-pan.md](./todos/pending/2026-08-06-live-map-pin-jitter-during-pan.md) |

### Blockers/Concerns

- [2026-08-05] 03-06 Task 3 (FCM push verification) is now **closed for Android**: Firebase project `safepath-ai-c11bd` provisioned, backend confirmed using `FirebasePushSender`, real push delivery + deep-link confirmed on a terminated Guardian device, delivery status confirmed Queued->Delivered->Acknowledged server-side. Apple Developer Program enrollment / APNs auth key / iOS TestFlight path has **not** been started — do not pick this up until the user explicitly decides to pursue it. The 03-07 airplane-mode offline SOS smoke test (03-07 D4) remains outstanding and can run in the same kind of session since it doesn't depend on Apple/iOS either.
- [2026-08-05] 03-08-PLAN.md (live-location streaming window, SOS-04) is missing an explicit requirement: today's `LocationController` uses a plain `Geolocator.getPositionStream()` with no foreground-service wrapper, so it does not survive backgrounding or app-kill; 03-08's own plan only commits to surviving the phone being locked/backgrounded via `flutter_foreground_task`, not the sender fully force-killing the app (Android `stopWithTask` isn't addressed). Flagged directly in the plan file — resolve (or explicitly accept as a limitation) before/during 03-08's execution.
- [2026-08-10] TextBee SMS provisioning (03-05's emergency-contact channel, migrated from Twilio in quick task 260810-vcf) is **not started**. The code side is fully built — `ISmsGateway`/`TextBeeSmsGateway`/`LoggingSmsGateway` seam, E.164 normalization, the SMS arm of `SosAlertDispatcher`, and the (permanently inert) status webhook — but no `TextBee:ApiKey`/`TextBee:DeviceId` are configured anywhere, so the backend still runs on `LoggingSmsGateway` and emergency-contact SMS is never actually sent, only logged. Explicitly deferred by the user — do not pick this up until they decide to pursue it. When it does happen: install the TextBee companion Android app on a gateway phone, register it as a device from the TextBee dashboard, and set the two config values (see `docs/EXTERNAL-SETUP.md`, "TextBee Device Registration"). Once provisioned, delivery status will permanently read `Queued` (sent, unconfirmed) rather than ever reaching `Delivered`, since TextBee has no delivery-status webhook (unlike the superseded Twilio design) — this is the intended behavior of the migration, not an outstanding gap.

Carried forward from research (see .planning/research/SUMMARY.md "Research Flags" and "Gaps to Address"):

- ~~Phase 3 (SOS): SMS-fallback provider choice (e.g. Twilio) needs a concrete decision during planning.~~ Resolved by 03-05: Twilio behind `ISmsGateway`, `LoggingSmsGateway` as the zero-cost default. Account provisioning itself is the open item above.
- Phase 4 (Geofencing): exact dwell-time/hysteresis parameters and Android's April 2026 background-location policy wording need re-verification at build time.
- Phase 5 (AI): cold-start fallback design (two-tier prediction, synthetic history seeding) needs concrete design during planning.
- Phase 6 (Duress): security-under-coercion threat modeling for the Silent/Duress secret storage is domain-specific and underspecified beyond the general pattern.

### Quick Tasks Completed

| # | Description | Date | Commit | Status | Directory |
|---|-------------|------|--------|--------|-----------|
| 260716-ue7 | Fix transparent person marker icon on live map | 2026-07-16 | 5cc9cd8 | | [260716-ue7-fix-transparent-person-marker-icon-on-li](./quick/260716-ue7-fix-transparent-person-marker-icon-on-li/) |
| 260717-oq0 | Display each family member's live battery on the Live Map | 2026-07-17 | 4701da1 | | [260717-oq0-display-each-family-member-s-live-batter](./quick/260717-oq0-display-each-family-member-s-live-batter/) |
| 260717-pwh | Rail-card tap on the Live Map recenters the map instead of opening the member sheet | 2026-07-17 | 4ddb746 | | [260717-pwh-on-the-live-map-screen-tapping-a-family-](./quick/260717-pwh-on-the-live-map-screen-tapping-a-family-/) |
| 260720-3u4 | Add Semantics labels to MemberMapPin for screen-reader support | 2026-07-24 | 7246356 | | [260720-3u4-add-semantics-labels-to-membermappin-so-](./quick/260720-3u4-add-semantics-labels-to-membermappin-so-/) |
| 260802-w1e | Codemagic CI config for iOS TestFlight/Android APK + Firebase/APNs/ASC external-setup runbook | 2026-08-02 | 92abded, 20fd982 | | [260802-w1e-codemagic-ci-config-and-firebase-apns-se](./quick/260802-w1e-codemagic-ci-config-and-firebase-apns-se/) |
| 6 | Enable core library desugaring required by flutter_local_notifications (real Android build failure found during device testing) | 2026-08-05 | 2aee4de | | — |
| 260805-s33 | Fixed SOS arm ring paint-order (was fully hidden), added press-scale animation and a live 3-2-1 countdown label | 2026-08-05 | 10cb95f | | [260805-s33-add-a-cool-smooth-press-animation-to-the](./quick/260805-s33-add-a-cool-smooth-press-animation-to-the/) |
| 260805-t3h | Raised Live Map family pin staleness opacity floor (0.7/0.45/0.3 -> 0.92/0.85/0.75) so pins stay legible over map tiles | 2026-08-05 | 880aad6 | | [260805-t3h-fix-the-opacity-of-family-member-map-pin](./quick/260805-t3h-fix-the-opacity-of-family-member-map-pin/) |
| 260805-uke | Proactive zero-SOS-recipient warning card in Privacy Center (mirrors backend D-11 recipient resolution) + Guardian-role SOS access audit (no gap found) | 2026-08-05 | ac0d8d2 | | [260805-uke-add-a-proactive-zero-sos-recipient-nudge](./quick/260805-uke-add-a-proactive-zero-sos-recipient-nudge/) |
| 260806-3zb | Migrate Live Map + route sheet from flutter_map to maplibre_gl for OpenFreeMap Liberty vector tiles (found/fixed 2 on-device rendering bugs + 1 dispose-race blocker via code review) | 2026-08-06 | 4152e22, 5be73c6, 015bc72, b5aa00b, 8c8e68a | Needs Review | [260806-3zb-migrate-map-rendering-from-flutter-map-t](./quick/260806-3zb-migrate-map-rendering-from-flutter-map-t/) |
| 260807-rk2 | Wired the SOS responder "Call sender" button to dial the sender's real number: nullable User.PhoneNumberE164 + PATCH /me/phone-number, recipient-scoped SosSessionDto exposure, profile phone-number card | 2026-08-07 | 6cc54b6, 175ca5a, d570434 | | [260807-rk2-wire-the-sos-responder-screen-s-call-sen](./quick/260807-rk2-wire-the-sos-responder-screen-s-call-sen/) |
| 260807-qhg | Consolidated the splash lockup into a shared AnimatedSafePathMark (ring trace + staggered letter reveal + halo), synced both splash surfaces to 1800ms; fixed StartupSplashOverlay's Stopwatch-based progress to be FakeAsync-testable | 2026-08-07 | d6f667e, 2bb751f, c7be6c5, 1821d39 | | [260807-qhg-apply-splash-screen-enhancement-instruct](./quick/260807-qhg-apply-splash-screen-enhancement-instruct/) |
| 260807-vqc | Added a country code picker (country_picker 2.0.28) to the profile phone-number field; composes/splits full E.164 numbers client-side, backend already normalized correctly (added regression tests only) | 2026-08-07 | b768b88, 7f7e94b, 15da58f | | [260807-vqc-add-a-country-code-picker-to-the-add-pho](./quick/260807-vqc-add-a-country-code-picker-to-the-add-pho/) |
| 260808-51d | Added a start_mobile.md section for testing over an ngrok tunnel (remote contributor, different network) | 2026-08-08 | 8b430d8, 611292e | | [260808-51d-add-a-section-to-start-mobile-md-documen](./quick/260808-51d-add-a-section-to-start-mobile-md-documen/) |

## Deferred Items

Items acknowledged and carried forward from previous milestone close:

| Category | Item | Status | Deferred At |
|----------|------|--------|-------------|
| Family Groups | FAM-06: Companion/Kiosk Mode for non-smartphone family members | Deferred to v2 | Requirements definition (2026-07-06) |

## Session Continuity

Last session: 2026-08-10T16:02:59.705Z
Stopped at: Phase 4 planned
Resume file: .planning/phases/04-geofencing/04-01-PLAN.md
