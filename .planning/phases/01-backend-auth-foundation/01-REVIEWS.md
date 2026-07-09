---
phase: 1
reviewers: [codex]
reviewed_at: 2026-07-09T21:27:14Z
plans_reviewed: [01-01-PLAN.md, 01-02-PLAN.md, 01-03-PLAN.md, 01-04-PLAN.md, 01-05-PLAN.md, 01-06-PLAN.md, 01-07-PLAN.md, 01-08-PLAN.md, 01-09-PLAN.md, 01-10-PLAN.md, 01-11-PLAN.md, 01-12-PLAN.md, 01-13-PLAN.md, 01-14-PLAN.md]
scope: Codex-only cross-AI plan review generated from current working-tree Phase 1 plans and source inspection
---

# Cross-AI Plan Review - Phase 1

## Codex Review

**Summary**

I reviewed the plans against the current repo. The major pattern is: plans 01-01 through 01-03 are now historically stale because the code has pivoted to Supabase-owned auth; plans 01-04 and 01-06 correctly mark themselves superseded; plans 01-11 through 01-14 mostly target real gaps still present in the code. Highest-risk issues to fix before execution: plan 12 needs a DB-level single-active-family constraint, plan 13 should address Supabase public-schema/RLS exposure more concretely, and plan 14's tasks do not fully implement its own "logged-out invite link survives login" requirement.

I did not edit files or run tests; the environment is read-only, so this is source inspection only.

**Plan Reviews**

| Plan | Assessment |
|---|---|
| **01-01 Backend Auth** | **Risk: HIGH if executed as written, LOW as history.** The plan's custom JWT/AuthController direction conflicts with current code: backend validates Supabase JWTs in `backend/src/SafePath.Api/Program.cs:23-46`, and migration `20260708234008...` drops `RefreshTokens` and `PasswordHash` at `backend/src/SafePath.Infrastructure/Persistence/Migrations/20260708234008_SyncSupabaseUsersAndDropLegacyAuthColumns.cs:14-19`. **Strength:** strong original TDD/security shape. **Concern HIGH:** `AuthResult` remains as dead custom-auth artifact at `backend/src/SafePath.Application/Common/Models/AuthResult.cs:8-19`. **Suggestion:** treat only the superseding note as authoritative; do not revive `/auth/*`. |
| **01-02 Mobile Foundation** | **Risk: MEDIUM.** Theme/router foundation appears useful, but token storage claims are stale: there is no `mobile/lib/core/storage/token_storage.dart`, and the interceptor now reads Supabase `currentSession?.accessToken` at `mobile/lib/core/network/auth_interceptor.dart:21-23`. **Strength:** core Dio auth retry remains sensible. **Concern MEDIUM:** plan still says `flutter_secure_storage`; current `pubspec.yaml:47-56` uses `supabase_flutter`, not secure-storage. **Suggestion:** update plan summary to "Supabase session persistence," not custom token storage. |
| **01-03 Auth Screens** | **Risk: HIGH if re-executed.** Current auth API calls Supabase directly: sign-up metadata at `mobile/lib/features/auth/data/auth_api.dart:109-117`, password login at `:138-143`. **Strength:** UI flow still maps to auth requirements. **Concern HIGH:** plan's `/auth/register`, `/auth/login`, `/auth/logout` client contract is obsolete. **Suggestion:** keep the screens, but rewrite any remaining artifact text around Supabase Auth. |
| **01-04 Password Reset Backend** | **Risk: LOW if supersession respected.** The superseding note is correct: current reset flow is Supabase client-side via `resetPasswordForEmail` at `mobile/lib/features/auth/data/auth_api.dart:165-168` and `updateUser` at `:181-183`. **Strength:** avoids unnecessary Resend/token table. **Concern LOW:** historical plan still references backend reset entities that should not be rebuilt. **Suggestion:** keep as historical only. |
| **01-05 Family Backend** | **Risk: MEDIUM.** The core mechanisms exist and match the plan: server-side membership/role checks in `FamilyAuthorizationService` at `backend/src/SafePath.Infrastructure/Identity/FamilyAuthorizationService.cs:23-47`; Guardian-gated invite generation at `backend/src/SafePath.Application/Families/GenerateInviteCommand.cs:31-45`; CSPRNG invite tokens at `backend/src/SafePath.Infrastructure/Identity/InviteCodeGenerator.cs:17-35`. **Concern MEDIUM:** no revoke, no single-family guard, no FKs; current redeem always inserts a new member at `RedeemInviteCommand.cs:54-68`. **Suggestion:** execute 12/13 before calling Phase 1 complete. |
| **01-06 Reset UI** | **Risk: LOW as superseded, MEDIUM for remaining UX.** Supabase reset is implemented, but current screens still use red errors: `forgot_password_screen.dart:107-115`, `reset_password_screen.dart:101-109`. **Strength:** supersession avoids backend reset complexity. **Concern MEDIUM:** amber/expired-link UX is not done. **Suggestion:** plan 14's reset-error portion is valid. |
| **01-07 Family Mobile** | **Risk: MEDIUM.** QR/link invite UI exists: `invite_member_screen.dart:95-112`, and link payload is `safepathai://invite?token=...` at `:39-44`. **Concern HIGH:** accept screen only uses a manual code and routes both accept and decline to `/home` at `accept_invite_screen.dart:45-57`. **Strength:** plan 10 already fixed session restore via `FamilyController` bootstrap at `family_controller.dart:68-80` and `:93-109`. **Suggestion:** plan 14 is needed to finish QR/deep-link redemption and decline UX. |
| **01-08 Browser Google OAuth** | **Risk: LOW as superseded.** Platform scheme registration from this plan exists on Android `mobile/android/app/src/main/AndroidManifest.xml:32-37` and iOS `mobile/ios/Runner/Info.plist:11-17`. **Concern LOW:** browser OAuth path is obsolete because 01-09 replaced it. **Suggestion:** keep only the platform deep-link registration and docs that still apply to reset links. |
| **01-09 Native Google Sign-In** | **Risk: LOW-MEDIUM.** Native Google path is implemented: `google_sign_in` dependency at `mobile/pubspec.yaml:56`, `GOOGLE_SERVER_CLIENT_ID` at `mobile/lib/core/config/supabase_config.dart:8-13`, native picker + Supabase `signInWithIdToken` at `mobile/lib/features/auth/data/auth_api.dart:220-233`. **Concern MEDIUM:** missing `GOOGLE_SERVER_CLIENT_ID` throws `StateError` before the `try` block at `auth_api.dart:209-219`, while `AuthController` only catches `AuthApiException` at `auth_controller.dart:136-138`; this can crash instead of showing UI error. **Suggestion:** move the config check into the `try` or catch `StateError` and map to `AuthApiException`. |
| **01-10 Families Mine** | **Risk: LOW.** This plan matches a real fixed gap: backend query filters by caller membership at `ListMyFamiliesQuery.cs:28-37`; controller exposes `GET /families/mine` at `FamiliesController.cs:62-72`; mobile bootstraps on auth state at `family_controller.dart:68-80`. **Strength:** tests cover empty/removed/multiple memberships at `ListMyFamiliesQueryTests.cs:44-121`. **Concern LOW:** multiple active memberships are intentionally still possible until plan 12. **Suggestion:** keep this plan as executed and sequence 12 after it. |
| **01-11 ADR/env/me** | **Risk: MEDIUM.** The plan addresses real gaps: `/me` currently returns `_currentUser.Role` from JWT claims at `MeController.cs:23-28`, and `CurrentUserService` looks for role claims that stock Supabase tokens do not carry at `CurrentUserService.cs:37-40`. Bootstrap is also real: `appsettings.json` has blank `DefaultConnection` at `backend/src/SafePath.Api/appsettings.json:13-14`, and no `DotNetEnv` package exists in `SafePath.Api.csproj:10-18`. **Strength:** deletes real dead `AuthResult`. **Concern LOW:** there are untracked root `client_secret_*.json` files, though `.gitignore` covers them at `.gitignore:23-26`. **Suggestion:** execute; also delete local client secret files after confirming they are not needed. |
| **01-12 Single-Family + Revoke** | **Risk: MEDIUM-HIGH.** The plan targets real defects: create has no existing-membership check at `CreateFamilyCommand.cs:26-47`; accept always inserts at `RedeemInviteCommand.cs:54-68`; unique index is only `(FamilyId, UserId)` at `FamilyMemberConfiguration.cs:19-21`. **Concern HIGH:** app-level "check then insert" does not prevent concurrent double-joins across families. **Suggestion:** add a DB-level partial unique index on active `UserId` memberships, or wrap membership creation in a transaction/isolation strategy. |
| **01-13 FKs / Transfer / Delete** | **Risk: MEDIUM.** Missing FKs are real: family member config has only indexes at `FamilyMemberConfiguration.cs:19-21`; invitations likewise only code/token indexes at `FamilyInvitationConfiguration.cs:14-24`; the family migration creates tables without FKs at `20260709082519_FamilyCircle.cs:14-83`. **Strength:** orphan pre-clean before adding FK is good. **Concern MEDIUM:** documenting "RLS not primary" is not enough for Supabase public-schema exposure; the mobile app uses a Supabase publishable key at `main.dart:12-15`. **Suggestion:** explicitly decide either deny Data API access or enable restrictive RLS/GRANT posture for public tables as defense-in-depth. |
| **01-14 Deep Links / Decline / Amber Reset** | **Risk: MEDIUM-HIGH.** The plan addresses real gaps: invite links are generated at `invite_member_screen.dart:39-44`, but `SafePathApp` has no deep-link service and is only a `ConsumerWidget` at `app.dart:11-22`; router passes only `code` to accept at `app_router.dart:138-142`; unauthenticated access to `/invite/accept` redirects to `/` at `app_router.dart:36-42` and `:75-77`; decline currently routes to `/home` just like accept at `accept_invite_screen.dart:54-57`. **Concern HIGH:** plan must-haves mention stashing logged-out invite tokens, but task text does not clearly define a `pendingInviteProvider` and post-auth redirect implementation. **Suggestion:** add explicit pending-invite state and redirect tests before execution. |

**Overall Risk Assessment**

Overall risk is **MEDIUM**. The later plans are mostly aimed at real, source-confirmed gaps, but plan 12 and plan 14 need tightening before execution, and plan 13 needs a more explicit Supabase Data API/RLS security decision. The obsolete auth plans should remain historical only; re-executing them would fight the current Supabase-owned architecture.

---

## Consensus Summary

Single reviewer run (--codex), so this section summarizes the Codex findings rather than cross-reviewer agreement.

### Agreed Strengths

- Later plans 01-11 through 01-14 are aimed at real, source-confirmed Phase 1 gaps.
- Supabase-owned auth is the live architecture; obsolete custom-auth plans should remain historical rather than being re-executed.
- Family bootstrap and /families/mine appear to match the intended recovered-session behavior.

### Agreed Concerns

1. **MEDIUM-HIGH - Plan 01-12 needs DB-level single-active-family protection.** Application-level checks alone can race; add a partial unique index or transaction/isolation strategy for active UserId memberships.
2. **MEDIUM - Plan 01-13 should make the Supabase Data API/RLS posture explicit.** Documenting backend-owned authorization is not enough if public tables remain reachable through Supabase's Data API surface.
3. **MEDIUM-HIGH - Plan 01-14 needs explicit pending-invite handling across logged-out auth.** The must-have is present, but the task text should define the provider/storage and post-auth redirect tests.
4. **LOW-MEDIUM - Obsolete auth plans remain risky if treated as executable.** Plans 01-01 through 01-03 conflict with the Supabase-owned implementation and should stay historical.

### Divergent Views

No divergent reviewer views in this run because only Codex was invoked.
