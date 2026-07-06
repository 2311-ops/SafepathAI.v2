---
phase: 1
slug: backend-auth-foundation
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-07-06
---

# Phase 1 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | xUnit (backend, standard for .NET Clean Architecture templates) + `flutter_test` (mobile, ships with Flutter SDK) |
| **Config file** | none yet — greenfield; create `SafePath.Application.Tests/SafePath.Application.Tests.csproj` and `mobile/test/` during Wave 0 |
| **Quick run command** | `dotnet test backend/tests/SafePath.Application.Tests` (backend) / `flutter test` (mobile) |
| **Full suite command** | `dotnet test backend/SafePath.sln` (backend) / `flutter test` (mobile) |
| **Estimated runtime** | ~30-60 seconds (small Wave-0-scale suite) |

---

## Sampling Rate

- **After every task commit:** Run `dotnet test backend/tests/SafePath.Application.Tests` and/or `flutter test` (whichever layer the task touched)
- **After every plan wave:** Run `dotnet test backend/SafePath.sln` + `flutter test`
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 60 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 01-01-XX | 01 | 1 | AUTH-01 | V2/V5 | Duplicate email rejected; password hashed via BCrypt, never stored plaintext | unit + integration | `dotnet test --filter FullyQualifiedName~RegisterCommandTests` | ❌ W0 | ⬜ pending |
| 01-01-XX | 01 | 1 | AUTH-02 | V3 | Login issues valid access+refresh JWT pair; refresh rotates token (single-use) | unit | `dotnet test --filter FullyQualifiedName~RefreshTokenCommandTests` | ❌ W0 | ⬜ pending |
| 01-01-XX | 01 | 1 | AUTH-03 | V3 | Logout revokes the refresh token; subsequent refresh with it fails | unit | `dotnet test --filter FullyQualifiedName~LogoutCommandTests` | ❌ W0 | ⬜ pending |
| 01-01-XX | 01 | 1 | AUTH-04 | V6 | Forgot-password generates a hashed, expiring token and calls `IEmailSender` (Resend); raw token never logged | unit (mock `IEmailSender`) | `dotnet test --filter FullyQualifiedName~ForgotPasswordCommandTests` | ❌ W0 | ⬜ pending |
| 01-01-XX | 01 | 1 | AUTH-05 | V4 | Role is persisted and returned in JWT claims at registration | unit | `dotnet test --filter FullyQualifiedName~RegisterCommandTests` | ❌ W0 | ⬜ pending |
| 01-02-XX | 01 | 1 | FAM-01 | V4 | Creating a family also creates a Guardian membership row for the creator | unit | `dotnet test --filter FullyQualifiedName~CreateFamilyCommandTests` | ❌ W0 | ⬜ pending |
| 01-02-XX | 01 | 1 | FAM-02/FAM-03 | V4/T-invite | Invite code generation + redeem (accept/reject) round-trip; expiry + single-use + rate-limit enforced | unit + integration | `dotnet test --filter FullyQualifiedName~FamilyInvitationTests` | ❌ W0 | ⬜ pending |
| 01-02-XX | 01 | 1 | FAM-04 | V4 | Updating a member's permission level persists and is returned correctly | unit | `dotnet test --filter FullyQualifiedName~UpdateMemberPermissionsCommandTests` | ❌ W0 | ⬜ pending |
| 01-02-XX | 01 | 1 | FAM-05 | V4/IDOR | Removing a member revokes access; subsequent family-scoped requests as that user fail authorization | integration | `dotnet test --filter FullyQualifiedName~RemoveMemberCommandTests` | ❌ W0 | ⬜ pending |
| 01-03-XX | 01 | 1/2 | DESIGN-01 | — | `ThemeData` exposes the exact tokens (colors/type/spacing) `01-UI-SPEC.md` specifies | widget test | `flutter test test/theme_test.dart` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `backend/tests/SafePath.Domain.Tests/SafePath.Domain.Tests.csproj` — entity/enum unit tests
- [ ] `backend/tests/SafePath.Application.Tests/SafePath.Application.Tests.csproj` — command handler unit tests (with mocked `IApplicationDbContext`/`IEmailSender`/`IJwtTokenGenerator`)
- [ ] `backend/tests/SafePath.Api.IntegrationTests/SafePath.Api.IntegrationTests.csproj` — `WebApplicationFactory`-based endpoint tests against a test Postgres instance (or Testcontainers)
- [ ] `mobile/test/` — widget tests for the theme + at minimum one screen (e.g. Register) smoke test
- [ ] Framework install: `dotnet new xunit` scaffolding + `flutter test` already ships with the SDK — no extra install needed once SDKs are installed

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| End-to-end password-reset email delivery | AUTH-04 | Requires a real Resend API key + inbox to confirm actual delivery/deliverability, not just that `IEmailSender.SendAsync` was called | Trigger forgot-password with a real test email address, confirm the email arrives with a working reset link, complete the reset flow |
| Screen-by-screen visual fidelity vs `01-UI-SPEC.md` | DESIGN-01 | Pixel/spacing/color fidelity to a hand-authored design system isn't fully capturable by widget tests alone | Run the app, compare each of the 9 in-scope screens against `01-UI-SPEC.md` and the design mockup side-by-side |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 60s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
