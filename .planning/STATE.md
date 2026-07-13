---
gsd_state_version: 1.0
milestone: v1.0
milestone_name: milestone
current_phase: 02
current_phase_name: real-time-location-history-privacy
status: planned
stopped_at: Completed 02-14-PLAN.md
last_updated: "2026-07-13T15:56:50.091Z"
last_activity: 2026-07-13
last_activity_desc: Completed 02-14 backend profile endpoints and SignalR profile propagation
progress:
  total_phases: 8
  completed_phases: 2
  total_plans: 32
  completed_plans: 30
  percent: 94
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-07-06)

**Core value:** The SOS system must always work — a single tap or covert Silent/Duress trigger reliably delivers an immediate alert with live location to a user's designated guardians within seconds, bypassing every routine and AI pipeline.
**Current focus:** v1.0 milestone closeout

## Current Position

Phase: 02 (real-time-location-history-privacy) — IN PROGRESS (additive User Profile & Map Identity wave)
Plan: /gsd-execute-phase 02 next (resume with 02-15-PLAN.md; do not redo 02-14)
Status: 14/16 plans shipped. 02-14 completed backend profile endpoints, signed profileImageUrl projection on /me and live-locations, and ProfileUpdated SignalR propagation. Remaining: 02-15 mobile profile UI and 02-16 map avatar markers.
Last activity: 2026-07-13 — Completed 02-14 backend profile endpoints and SignalR profile propagation

Progress: [█████████░] 94%

## Performance Metrics

**Velocity:**

- Total plans completed: 0
- Average duration: - min
- Total execution time: 0 hours

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| - | - | - | - |

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

### Pending Todos

None for Phase 01 closeout.

### Blockers/Concerns

Carried forward from research (see .planning/research/SUMMARY.md "Research Flags" and "Gaps to Address"):

- Phase 3 (SOS): SMS-fallback provider choice (e.g. Twilio) needs a concrete decision during planning.
- Phase 4 (Geofencing): exact dwell-time/hysteresis parameters and Android's April 2026 background-location policy wording need re-verification at build time.
- Phase 5 (AI): cold-start fallback design (two-tier prediction, synthetic history seeding) needs concrete design during planning.
- Phase 6 (Duress): security-under-coercion threat modeling for the Silent/Duress secret storage is domain-specific and underspecified beyond the general pattern.
- Phase 2 (User Profile & Map Identity, 02-15..02-16): continue with mobile profile UI and map identity work. The private Supabase Storage bucket is `avatar` (singular) and `backend/.env` contains `Supabase__ServiceRoleKey`; ImageSharp 4.0.0 builds require local Six Labors license material that must not be committed.

## Deferred Items

Items acknowledged and carried forward from previous milestone close:

| Category | Item | Status | Deferred At |
|----------|------|--------|-------------|
| Family Groups | FAM-06: Companion/Kiosk Mode for non-smartphone family members | Deferred to v2 | Requirements definition (2026-07-06) |

## Session Continuity

Last session: 2026-07-13T15:56:49.813Z
Stopped at: Completed 02-14-PLAN.md
Resume file: None
