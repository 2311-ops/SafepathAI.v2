---
gsd_state_version: 1.0
milestone: v1.0
milestone_name: milestone
current_phase: 02
current_phase_name: real-time-location-history-privacy
status: executing
stopped_at: Phase 01.1 UI-SPEC approved
last_updated: "2026-07-10T22:05:42.550Z"
last_activity: 2026-07-10
last_activity_desc: Completed Phase 01 after production UI review and closeout
progress:
  total_phases: 8
  completed_phases: 1
  total_plans: 14
  completed_plans: 14
  percent: 13
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-07-06)

**Core value:** The SOS system must always work — a single tap or covert Silent/Duress trigger reliably delivers an immediate alert with live location to a user's designated guardians within seconds, bypassing every routine and AI pipeline.
**Current focus:** Phase 02 - real-time-location-history-privacy

## Current Position

Phase: 02 (real-time-location-history-privacy) - READY TO PLAN
Plan: TBD
Status: Ready to execute
Last activity: 2026-07-10 - Completed Phase 01 after production UI review and closeout

Progress: [#---------] 14%

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

### Pending Todos

None for Phase 01 closeout.

### Blockers/Concerns

Carried forward from research (see .planning/research/SUMMARY.md "Research Flags" and "Gaps to Address"):

- Phase 3 (SOS): SMS-fallback provider choice (e.g. Twilio) needs a concrete decision during planning.
- Phase 4 (Geofencing): exact dwell-time/hysteresis parameters and Android's April 2026 background-location policy wording need re-verification at build time.
- Phase 5 (AI): cold-start fallback design (two-tier prediction, synthetic history seeding) needs concrete design during planning.
- Phase 6 (Duress): security-under-coercion threat modeling for the Silent/Duress secret storage is domain-specific and underspecified beyond the general pattern.

## Deferred Items

Items acknowledged and carried forward from previous milestone close:

| Category | Item | Status | Deferred At |
|----------|------|--------|-------------|
| Family Groups | FAM-06: Companion/Kiosk Mode for non-smartphone family members | Deferred to v2 | Requirements definition (2026-07-06) |

## Session Continuity

Last session: 2026-07-10T21:22:37.095Z
Stopped at: Phase 01.1 UI-SPEC approved
Resume file: .planning/phases/01.1-animated-logo-splash-screen/01.1-UI-SPEC.md
