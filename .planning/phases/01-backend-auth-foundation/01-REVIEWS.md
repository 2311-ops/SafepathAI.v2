---
phase: 1
reviewers: [codex]
failed_reviewers: [opencode]
reviewed_at: 2026-07-09T15:25:00Z
plans_reviewed: [01-01-PLAN.md, 01-02-PLAN.md, 01-03-PLAN.md, 01-04-PLAN.md, 01-05-PLAN.md, 01-06-PLAN.md, 01-07-PLAN.md, 01-08-PLAN.md, 01-09-PLAN.md, 01-10-PLAN.md]
scope: comprehensive pre-Family-Circle review (architecture, code, auth logic, family-circle design, workflows, UI, database, Supabase)
---

# Cross-AI Plan Review — Phase 1

## Codex Review

**Summary**
The codebase is strong on Clean Architecture boundaries, server-side family authorization, and the Flutter onboarding flow, but it has drifted from the planned backend-auth shape. Auth is now effectively owned by Supabase from the mobile app, the backend only validates JWTs, and there are still important gaps in family-circle UX and policy enforcement, especially QR/deep-link redemption and single-family membership.

**Strengths**
- Clean Architecture is real here: Application depends on interfaces like [IApplicationDbContext](D:/Projects/safepathai_V2/backend/src/SafePath.Application/Common/Interfaces/IApplicationDbContext.cs#L9), [ICurrentUserService](D:/Projects/safepathai_V2/backend/src/SafePath.Application/Common/Interfaces/ICurrentUserService.cs#L3), and [IFamilyAuthorizationService](D:/Projects/safepathai_V2/backend/src/SafePath.Application/Common/Interfaces/IFamilyAuthorizationService.cs#L25), while Infrastructure supplies the implementations via DI ([DependencyInjection.cs](D:/Projects/safepathai_V2/backend/src/SafePath.Infrastructure/DependencyInjection.cs#L12)).
- Family-scoped authorization is enforced server-side, not just in the UI. The guard/service checks active membership and role ([FamilyAuthorizationService.cs](D:/Projects/safepathai_V2/backend/src/SafePath.Infrastructure/Identity/FamilyAuthorizationService.cs#L23)), and controllers convert failures into 403s ([FamiliesController.cs](D:/Projects/safepathai_V2/backend/src/SafePath.Api/Controllers/FamiliesController.cs#L75), [InvitesController.cs](D:/Projects/safepathai_V2/backend/src/SafePath.Api/Controllers/InvitesController.cs#L31)).
- Invite generation is well structured: CSPRNG-backed display code and opaque link token ([InviteCodeGenerator.cs](D:/Projects/safepathai_V2/backend/src/SafePath.Infrastructure/Identity/InviteCodeGenerator.cs#L17)), 24-hour expiry and single-use semantics in the handler ([GenerateInviteCommand.cs](D:/Projects/safepathai_V2/backend/src/SafePath.Application/Families/GenerateInviteCommand.cs#L31)), plus rate limiting on redemption ([Program.cs](D:/Projects/safepathai_V2/backend/src/SafePath.Api/Program.cs#L51)).
- The Flutter auth flow is coherent and heavily tested: session restore, recovery state, register draft persistence, Google sign-in, logout, and redirect guards all have explicit coverage ([AuthController.cs](D:/Projects/safepathai_V2/mobile/lib/features/auth/application/auth_controller.dart#L21), [app_router.dart](D:/Projects/safepathai_V2/mobile/lib/core/router/app_router.dart#L64), [auth_flow_navigation_test.dart](D:/Projects/safepathai_V2/mobile/test/core/router/auth_flow_navigation_test.dart#L77), [auth_interceptor_test.dart](D:/Projects/safepathai_V2/mobile/test/core/network/auth_interceptor_test.dart#L95)).
- The design system is centralized instead of hand-rolled per screen. Theme tokens, typography, spacing, and shared widgets all source the same values ([app_theme.dart](D:/Projects/safepathai_V2/mobile/lib/core/theme/app_theme.dart#L9), [app_colors.dart](D:/Projects/safepathai_V2/mobile/lib/core/theme/app_colors.dart#L12), [app_typography.dart](D:/Projects/safepathai_V2/mobile/lib/core/theme/app_typography.dart#L11), [primary_button.dart](D:/Projects/safepathai_V2/mobile/lib/shared_widgets/primary_button.dart#L12)), and the theme test asserts the core tokens ([theme_test.dart](D:/Projects/safepathai_V2/mobile/test/theme_test.dart#L73)).
- The invite UI matches the locked QR/share-code spec and intentionally omits an email field, which is verified in tests ([invite_member_screen.dart](D:/Projects/safepathai_V2/mobile/lib/features/family/presentation/invite_member_screen.dart#L15), [invite_member_screen_test.dart](D:/Projects/safepathai_V2/mobile/test/features/family/invite_member_screen_test.dart#L95)).
- The family bootstrap path is not ad hoc in the UI. It lives in the controller, restores on auth transitions, and is covered for initial session and fresh-login cases ([family_controller.dart](D:/Projects/safepathai_V2/mobile/lib/features/family/application/family_controller.dart#L67), [family_controller_test.dart](D:/Projects/safepathai_V2/mobile/test/features/family/family_controller_test.dart#L376)).

**Concerns**
- `HIGH` Backend auth ownership has drifted. The backend only validates Supabase JWTs and exposes `/me` plus family endpoints ([Program.cs](D:/Projects/safepathai_V2/backend/src/SafePath.Api/Program.cs#L23), [MeController.cs](D:/Projects/safepathai_V2/backend/src/SafePath.Api/Controllers/MeController.cs#L20), [FamiliesController.cs](D:/Projects/safepathai_V2/backend/src/SafePath.Api/Controllers/FamiliesController.cs#L15)), while the mobile app performs register, login, logout, password reset, Google sign-in, and refresh directly against Supabase ([auth_api.dart](D:/Projects/safepathai_V2/mobile/lib/features/auth/data/auth_api.dart#L101), [auth_api.dart](D:/Projects/safepathai_V2/mobile/lib/features/auth/data/auth_api.dart#L151), [auth_api.dart](D:/Projects/safepathai_V2/mobile/lib/features/auth/data/auth_api.dart#L192)). The latest migration even drops the backend `RefreshTokens` table and `PasswordHash` column ([SyncSupabaseUsersAndDropLegacyAuthColumns.cs](D:/Projects/safepathai_V2/backend/src/SafePath.Infrastructure/Persistence/Migrations/20260708234008_SyncSupabaseUsersAndDropLegacyAuthColumns.cs#L14)). If the remaining Phase 1 work is supposed to be backend-owned auth, that is not implemented.
- `HIGH` Plaintext secrets are committed in `backend/.env`, and the file is not wired into startup. `DefaultConnection` is still blank in appsettings, while DI expects it at boot ([backend/.env](D:/Projects/safepathai_V2/backend/.env#L1), [appsettings.json](D:/Projects/safepathai_V2/backend/src/SafePath.Api/appsettings.json#L13), [DependencyInjection.cs](D:/Projects/safepathai_V2/backend/src/SafePath.Infrastructure/DependencyInjection.cs#L14)). This is both a security issue and a deployability issue.
- `HIGH` QR/share-link redemption is not actually wired end-to-end. The invite screen generates `safepathai://invite?token=...` ([invite_member_screen.dart](D:/Projects/safepathai_V2/mobile/lib/features/family/presentation/invite_member_screen.dart#L39)), but the router and accept screen only handle a `code` query param ([app_router.dart](D:/Projects/safepathai_V2/mobile/lib/core/router/app_router.dart#L137), [accept_invite_screen.dart](D:/Projects/safepathai_V2/mobile/lib/features/family/presentation/accept_invite_screen.dart#L21)). The backend accepts `linkToken`, but the UI path never consumes it ([family_api.dart](D:/Projects/safepathai_V2/mobile/lib/features/family/data/family_api.dart#L51)). QR scans and copied links will not complete a join flow as written.
- `HIGH` The current data model allows multiple active families, but the requested member workflow includes rejecting "already in another family". `ListMyFamiliesQuery` returns all active memberships and the mobile bootstrap picks only the first one ([ListMyFamiliesQuery.cs](D:/Projects/safepathai_V2/backend/src/SafePath.Application/Families/ListMyFamiliesQuery.cs#L28), [family_controller.dart](D:/Projects/safepathai_V2/mobile/lib/features/family/application/family_controller.dart#L88)). `RedeemInviteCommand` also adds a new membership without checking other active memberships ([RedeemInviteCommand.cs](D:/Projects/safepathai_V2/backend/src/SafePath.Application/Families/RedeemInviteCommand.cs#L54)). If the product is meant to be single-circle, that invariant is missing. The controller surface also stops at create, list, invite, redeem, update, and remove, so transfer ownership and delete family are absent ([FamiliesController.cs](D:/Projects/safepathai_V2/backend/src/SafePath.Api/Controllers/FamiliesController.cs#L42), [InvitesController.cs](D:/Projects/safepathai_V2/backend/src/SafePath.Api/Controllers/InvitesController.cs#L31)).
- `MEDIUM` The database schema has no foreign keys, cascade rules, or RLS policies in the checked-in migration/configuration. The family migration creates plain tables with PKs and unique indexes only ([FamilyCircle.cs](D:/Projects/safepathai_V2/backend/src/SafePath.Infrastructure/Persistence/Migrations/20260709082519_FamilyCircle.cs#L14)), and the entity configs define no relationships or delete behavior ([FamilyMemberConfiguration.cs](D:/Projects/safepathai_V2/backend/src/SafePath.Infrastructure/Persistence/EntityConfigurations/FamilyMemberConfiguration.cs#L11), [FamilyInvitationConfiguration.cs](D:/Projects/safepathai_V2/backend/src/SafePath.Infrastructure/Persistence/EntityConfigurations/FamilyInvitationConfiguration.cs#L11)). Cleanup and referential integrity are entirely application-enforced right now.
- `MEDIUM` Current user role resolution is inconsistent with the JWT mapping. The backend JWT bearer pipeline uses raw `role` claims with inbound claim mapping disabled ([Program.cs](D:/Projects/safepathai_V2/backend/src/SafePath.Api/Program.cs#L29)), but `CurrentUserService` only looks for `app_role`, `user_role`, or `ClaimTypes.Role` ([CurrentUserService.cs](D:/Projects/safepathai_V2/backend/src/SafePath.Infrastructure/Identity/CurrentUserService.cs#L33)). `/me` will likely report a null role for a stock Supabase token unless an out-of-repo claim hook exists.
- `MEDIUM` The forgot/reset-password screens drift from the design contract. They render async errors in `Colors.red` instead of the caution amber tokens reserved for non-SOS errors ([forgot_password_screen.dart](D:/Projects/safepathai_V2/mobile/lib/features/auth/presentation/forgot_password_screen.dart#L107), [reset_password_screen.dart](D:/Projects/safepathai_V2/mobile/lib/features/auth/presentation/reset_password_screen.dart#L101), [app_colors.dart](D:/Projects/safepathai_V2/mobile/lib/core/theme/app_colors.dart#L27)). `AuthController` also has no explicit expired-link branch, so the requested expired-reset UX is not covered ([auth_controller.dart](D:/Projects/safepathai_V2/mobile/lib/features/auth/application/auth_controller.dart#L167)).
- `MEDIUM` The invite decline flow is under-specified in UI behavior. `AcceptInviteScreen` always routes to `/home` after a non-error result, even for decline ([accept_invite_screen.dart](D:/Projects/safepathai_V2/mobile/lib/features/family/presentation/accept_invite_screen.dart#L45)), so "cancel join" is not a clearly separate outcome in the UI.

**Suggestions**
- Separate auth ownership first. If Supabase owns auth for Phase 1, update the roadmap and remove dead backend auth artifacts. If backend-owned auth is still required, reintroduce explicit auth endpoints, token storage, and password reset handling before adding more family work.
- Lock the membership policy explicitly. Decide single-family or multi-family, then enforce it in `RedeemInviteCommand`, `CreateFamilyCommand`, and the mobile bootstrap logic.
- Wire invite deep-link redemption end-to-end. Accept `token=` in the router, parse it in the accept screen, and add a real deep-link path for the QR payload.
- Add database integrity safeguards. At minimum, define FKs and delete behavior for family, member, and invitation records, and decide whether backend checks alone are enough or whether RLS should be added too.
- Fix the remaining UX drift. Replace red async error text on reset screens with amber, add explicit expired-link messaging, and make decline/cancel join behavior unambiguous.
- Expand tests around the gaps you actually have now: cross-family invite rejection, deep-link join, family deletion or transfer ownership, expired reset links, and decline navigation.

**Risk Assessment**
Overall risk is **HIGH**. The core auth and family scaffolding is workable, but there is a material architecture drift away from the planned backend-auth shape, a checked-in secrets file, and a broken QR/share-link join path. Those are not cosmetic issues. They affect security, onboarding, and the ability to complete the remaining Family Circle feature set safely.

**Recommended implementation order**
1. Decide auth ownership and secrets handling, then fix `backend/.env` and the connection-string/bootstrap path.
2. Choose and enforce the family membership policy, including the "already in another family" rule.
3. Wire QR and share-link redemption all the way through the router and accept screen.
4. Add the remaining guardian/member lifecycle endpoints, especially transfer ownership, delete family, and invite revoke or expire.
5. Add DB constraints and, if desired, RLS or a documented rationale for not using it.
6. Finish UI polish and edge cases, especially reset-password expired-link handling and decline navigation.

---

## OpenCode Review

OpenCode review failed on both attempts: the CLI crashed during its own internal state-database
migration ("Failed to run the query 'CREATE TABLE `project` ...'") before processing the prompt.
This is a local OpenCode installation issue, not a prompt/model failure. To fix, clear or repair
`C:\Users\LOQ\.local\share\opencode\` (see its log directory for details) and re-run
`/gsd-review 1 --opencode`.

---

## Consensus Summary

Only one external reviewer (Codex) completed successfully, so this is a single-reviewer review
rather than a true multi-model consensus. Gemini/Qwen/Cursor/Antigravity/CodeRabbit are not
installed; Claude was skipped for independence (this session runs inside Claude Code); OpenCode
failed locally. Treat the findings below as one strong, source-grounded opinion.

### Key Strengths (evidence-cited)
- Clean Architecture boundaries are genuinely enforced (Application depends only on interfaces; Infrastructure wires implementations via DI).
- Family-scoped authorization is server-side (FamilyAuthorizationService + 403 mapping in controllers), with rate-limited, CSPRNG-backed single-use invites.
- Flutter auth flow (session restore, Google sign-in, redirect guards, register draft) is coherent and heavily tested; design tokens are centralized.

### Key Concerns (highest priority)
1. **HIGH — Auth ownership drift**: mobile talks to Supabase auth directly while the backend only validates JWTs; latest migration drops backend RefreshTokens/PasswordHash. Decide and document the auth ownership model before more Family Circle work.
2. **HIGH — Committed secrets / broken bootstrap**: plaintext secrets in `backend/.env` (checked in), `DefaultConnection` blank in appsettings and `.env` not wired into startup.
3. **HIGH — QR/deep-link join is not wired end-to-end**: invite screen emits `safepathai://invite?token=...` but router/accept screen only handle `code`; `linkToken` path never consumed.
4. **HIGH — Single-family invariant missing**: RedeemInviteCommand allows multiple active memberships; transfer-ownership and delete-family endpoints absent.
5. **MEDIUM — No FKs/cascades/RLS** in the family migration; integrity is application-enforced only.
6. **MEDIUM — Role claim mismatch** (`CurrentUserService` reads `app_role`/`user_role` but JWT pipeline uses raw `role`), red-vs-amber error color drift on reset screens, ambiguous decline/cancel-join navigation.

### Recommended Implementation Order (from review)
1. Decide auth ownership + fix secrets handling (`backend/.env`, connection-string bootstrap).
2. Enforce the family membership policy (single vs multi family, "already in another family" rejection).
3. Wire QR/share-link redemption through router and accept screen.
4. Add remaining lifecycle endpoints: transfer ownership, delete family, invite revoke/expire.
5. Add DB FKs/cascades and an RLS decision (or documented rationale).
6. UI polish: expired reset-link UX, amber error tokens, decline navigation.
