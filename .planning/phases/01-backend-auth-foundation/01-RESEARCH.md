# Phase 1: Backend & Auth Foundation - Research

**Researched:** 2026-07-06
**Domain:** ASP.NET Core Clean Architecture auth walking-skeleton (JWT + refresh tokens, RBAC) + family-circle domain model + Supabase Postgres provisioning + Flutter app scaffold wired to the SafePath design system
**Confidence:** MEDIUM (architecture/pattern guidance is well-established industry practice, cross-checked across 2+ independent sources per topic; exact package versions/licensing terms verified directly against NuGet/pub.dev registries this session; no Context7/Exa/Tavily/Brave providers were enabled for this project — `config.json` has all of `exa_search`/`brave_search`/`firecrawl`/`tavily_search`/`ref_search`/`perplexity`/`jina` set to `false` — so all research used the built-in `WebSearch`/`WebFetch` tools against primary registries and official docs)

**No CONTEXT.md exists for this phase** (a `/gsd-discuss-phase` session was interrupted before completion) — there are no locked user decisions to reproduce verbatim. Several judgment calls below are genuine open decisions the planner/discuss-phase should surface to the user, not settled facts; each is flagged explicitly in **Open Questions** and the **Assumptions Log**.

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| AUTH-01 | User can register with email and password | Custom `Users` table + BCrypt.Net-Next hashing (not ASP.NET Core Identity) — see Standard Stack, Architecture Patterns §1 |
| AUTH-02 | User can log in via JWT (access + refresh tokens) and stay logged in across sessions | JWT bearer + refresh-token-rotation pattern — see Architecture Patterns §2, Code Examples, Pitfall 1 |
| AUTH-03 | User can log out | Refresh-token revocation on logout — see Architecture Patterns §2 |
| AUTH-04 | User can reset their password via a one-time, expiring emailed link | Requires an external transactional-email provider (gap in project-level STACK.md) — see Standard Stack "Email Delivery", Pitfall 3, Open Questions §1 |
| AUTH-05 | User is assigned a role (Guardian, Member, Caregiver, or org-level e.g. School Admin) during setup | Fixed `Role` enum column, not ASP.NET Core Identity's many-to-many roles — see Architecture Patterns §1, Don't Hand-Roll |
| FAM-01 | User can create a family circle | `Families` + `FamilyMembers` tables — see Architecture Patterns §3 |
| FAM-02 | User can invite a family member by email | UI-SPEC resolved this as share-code/QR, not an email field — see Open Questions §2 (technical soundness sanity-check), Architecture Patterns §3 |
| FAM-03 | Invited user can accept or reject an invitation | `FamilyInvitations` state machine — see Architecture Patterns §3 |
| FAM-04 | Guardian can manage per-member permissions | `FamilyMembers.Permissions` (view-only/full-location/notification-only) — see Architecture Patterns §3 |
| FAM-05 | Guardian can remove a member from the circle | Soft-delete/revoke on `FamilyMembers` — see Architecture Patterns §3, Security Domain (IDOR checks) |
| DESIGN-01 | Every screen matches the SafePath design system (Flutter widgets/`ThemeData`) | `google_fonts` + custom `ThemeData`/`ColorScheme` per `01-UI-SPEC.md` tokens — see Standard Stack (Flutter), Architecture Patterns §5 |

</phase_requirements>

## Project Constraints (from CLAUDE.md)

`./.claude/CLAUDE.md` is generated from `PROJECT.md`/`STACK.md` and carries the same fixed-stack constraints already reflected throughout this document: Flutter/Dart mobile, ASP.NET Core Web API (Clean Architecture, Repository Pattern, DI, SOLID), Supabase/Postgres via Npgsql/EF Core, Azure hosting. It also enforces a **GSD workflow gate** ("Do not make direct repo edits outside a GSD workflow unless the user explicitly asks to bypass it") — the planner should route all Phase 1 implementation through `/gsd-execute-phase`, not ad hoc edits. No additional phase-specific directives are present beyond what's already in PROJECT.md/STACK.md/ARCHITECTURE.md (already incorporated below).

---

## Summary

Phase 1 is the walking skeleton every later phase depends on: an ASP.NET Core 10 Clean Architecture solution (Domain/Application/Infrastructure/API) backed by a freshly-provisioned Supabase Postgres database, custom (not `Microsoft.AspNetCore.Identity`) JWT auth with rotating refresh tokens, a fixed-enum role model (Guardian/Member/Caregiver/org-role), and a family-circle domain (create/invite-by-code/accept/permissions/remove) — plus a Flutter app scaffold with the SafePath design tokens wired into `ThemeData` for the 9 screens `01-UI-SPEC.md` specifies (7 mockup screens + Login + Forgot/Reset Password, extended from the same tokens).

Three findings materially affect planning. **First**, `MediatR` — the de-facto CQRS-mediator package this project's own `STACK.md` recommends — went commercial with v13+ (Nov 2025); it remains **free for individuals/companies under $5M revenue** via a Community license key registered at mediatr.io, but this is a new external-account dependency that didn't exist when `STACK.md` was researched. The open-source, source-generator-based `Mediator` (martinothamar, MIT, NativeAOT-ready) is a viable zero-friction alternative, or a hand-rolled `ICommandHandler<T>`/DI pattern avoids the dependency entirely — recommended given this project's single-developer, no-budget context. **Second**, the project has no email-sending mechanism decided anywhere in prior research, yet AUTH-04 hard-requires one (a one-time expiring emailed link) — this is a genuine gap this document closes with a concrete recommendation (Resend, official .NET SDK, free tier). **Third**, the local dev environment currently has **.NET 9 SDKs only** (`9.0.201`, `9.0.205`) — not the .NET 10 SDK `STACK.md` recommends — and neither the Flutter SDK nor the Supabase CLI are installed; these are addressed in Environment Availability below and should become Wave-0 setup tasks in the plan.

**Primary recommendation:** Build a fully custom JWT+refresh-token auth stack (BCrypt.Net-Next + `System.IdentityModel.Tokens.Jwt`/`Microsoft.AspNetCore.Authentication.JwtBearer`) behind an `IIdentityService`/`ICurrentUserService` abstraction in Application (Jason Taylor Clean Architecture template pattern), not `Microsoft.AspNetCore.Identity` — the brief's schema uses a small, fixed role set and custom table names that don't map cleanly onto Identity's flexible-but-heavier `AspNetUsers`/`AspNetRoles` model. Implement family invites as expiring, single-use share codes (matching the UI-SPEC mockup) with a nullable `InviteeEmail`/`InviteeLabel` column, not a required-email invite record.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| User registration / login form | Browser/Client (Flutter) | API/Backend | Flutter collects/validates input client-side for UX; all real validation, hashing, and persistence happens server-side — never trust client-side checks alone |
| Password hashing & credential storage | API/Backend | Database | BCrypt hashing happens in Infrastructure; only the hash is persisted, never the plaintext password |
| JWT issuance, verification, refresh-token rotation | API/Backend | Database (refresh-token table) | Access tokens are stateless (verified via signature); refresh tokens are server-side state so they can be revoked — this requires a DB round-trip on every refresh |
| Password-reset email dispatch | API/Backend | External service (transactional email provider) | Backend generates the token and calls an external email API; no email-sending capability exists in Flutter or Postgres itself |
| Auth token storage on-device | Browser/Client (Flutter, `flutter_secure_storage`) | — | Platform Keystore/Keychain-backed secure storage; this is exclusively a client concern, the backend never sees where tokens are cached |
| Family circle CRUD, invite-code generation/redemption, permission management | API/Backend | Database | All business rules and authorization (who can invite/remove/change roles) are enforced server-side; Flutter only renders backend-returned state |
| QR code rendering / native share sheet for invite codes | Browser/Client (Flutter) | — | Purely a client-side rendering/OS-integration concern (`qr_flutter`, `share_plus`); the backend only needs to produce and validate the underlying code string |
| Role/permission enforcement on every family-scoped query | API/Backend | — | Must never be enforced only in the UI — every endpoint must independently verify the caller belongs to the family/has the required role (see Security Domain, IDOR) |
| Design system / `ThemeData` / widget styling | Browser/Client (Flutter) | — | Purely presentational; DESIGN-01 has zero backend surface |
| Database schema / EF Core migrations | Database (Supabase Postgres) | API/Backend (EF Core owns migrations) | Per ARCHITECTURE.md: EF Core migrations, not Supabase's own tooling, are the source of truth for schema |

---

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| .NET / ASP.NET Core SDK | **10.0.x** (project-level pin per `STACK.md`; **not currently installed** — see Environment Availability) | Backend runtime + Web API host | LTS through Nov 2028; confirmed no other .NET 10-vs-EF-Core-10 compatibility issue exists for this phase's scope (auth + family CRUD, no advanced EF features) |
| EF Core + `Npgsql.EntityFrameworkCore.PostgreSQL` | **10.0.x** (must match `Microsoft.EntityFrameworkCore >= 10.0.4, < 11.0.0` per `STACK.md`) | ORM + Postgres provider, owns migrations | Already verified project-wide in `STACK.md`; re-verify exact patch at install time (`dotnet add package Npgsql.EntityFrameworkCore.PostgreSQL`, no version pin needed if SDK-managed) |
| `BCrypt.Net-Next` | **4.2.0** [VERIFIED: nuget.org — 54.4M total downloads, ~22K/day, last published 2026-05-11, targets .NET 10.0/.NET Standard 2.0/.NET Framework 4.6.2] | Password hashing | Adaptive, GPU-attack-resistant hash (bcrypt); the current community consensus over PBKDF2 for new .NET projects — see Pitfall/State-of-the-Art notes below [CITED: scottbrady.io, medium.com/asp-dotnet comparison] |
| `Microsoft.AspNetCore.Authentication.JwtBearer` | ships with ASP.NET Core 10 SDK (no separate NuGet install needed for the SDK-referenced version) | JWT bearer token validation middleware | Official Microsoft package, the standard way to validate incoming `Authorization: Bearer` JWTs in ASP.NET Core |
| Flutter SDK | **3.44.x** (project-level pin; **not currently installed locally** — see Environment Availability) | Mobile app framework | Already verified in `STACK.md` |
| `google_fonts` | **8.1.0** [VERIFIED: pub.dev — 6.46k likes, 2.7M downloads, published by verified publisher flutter.dev, "Flutter Favorite", 2 months old] | Manrope + JetBrains Mono fonts for `ThemeData` | Required by DESIGN-01/UI-SPEC; already listed in `STACK.md`'s implied pubspec |
| `flutter_secure_storage` | **10.3.1** [VERIFIED: pub.dev — 4.4k likes, 3.08M weekly downloads, verified publisher steenbakker.dev, published 40 days ago] | Access/refresh token storage (Android Keystore / iOS Keychain) | Non-negotiable per Pitfall 7 (project-level PITFALLS.md) — never use `shared_preferences` for tokens |
| `flutter_riverpod` | **3.3.2** [VERIFIED: pub.dev — 2.89k likes, 2.39M downloads, verified publisher dash-overflow.net, "Flutter Favorite", published 26 days ago] | State management | Not previously decided anywhere in project-level research (ARCHITECTURE.md lists "Riverpod/Bloc" as an either/or). For 2026, Riverpod is the broadly-recommended default for new projects (compile-time safety, no `BuildContext` dependency, `AsyncValue` for loading/data/error, less boilerplate) [CITED: multiple 2026 comparison articles — medium.com/@pragneshpalsana, samioda.com, asoasis.tech — cross-checked across 3+ independent sources] — **recommend for this phase unless the user has a standing preference for Bloc; flag as an open decision, not a locked one** |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `Mediator` (martinothamar, source-generator based) | **3.0.2** [VERIFIED: nuget.org (package id `Mediator.SourceGenerator`) — 6.6M total downloads, 1.3M current-version downloads, published 2026-03-22, MIT-licensed] | CQRS-lite command/query dispatch for Application-layer use cases | **Recommended over `MediatR`** for this project specifically — see Summary/Pitfall notes on MediatR's commercial licensing change. Drop-in-similar API, no license key/account registration needed, NativeAOT-compatible [CITED: github.com/martinothamar/Mediator] |
| `MediatR` | 14.2.0, but **requires a free Community license key** (register at mediatr.io) for v13+ if this path is preferred instead | Alternative to the above | Only if the planner/user prefers MediatR's exact API/ecosystem familiarity over the newer alternative — solo-dev, non-commercial-scale use qualifies for the free Community tier, but this adds an external registration step [CITED: luckypennysoftware.com/faq, jimmybogard.com licensing posts] |
| `FluentValidation` | **12.1.1** [VERIFIED: nuget.org — 33.5M+ downloads on current version, published 2025-12-03, targets .NET 8.0+] | Request/DTO validation (register, invite-code redemption, etc.) in Application layer | Standard Clean-Architecture companion; keep validators out of Controllers |
| `Resend` (official .NET SDK) | **0.5.1** [VERIFIED: nuget.org, github.com/resend/resend-dotnet — official first-party SDK, announced in Resend's own changelog] | Transactional email (password-reset link) | Free tier: 3,000 emails/month (100/day cap) — sufficient for a graduation-project demo. Official REST-API-backed SDK, simple `dotnet add package Resend` + API key, no SMTP server to operate [CITED: resend.com/docs/send-with-dotnet] |
| `qr_flutter` | **4.1.0** [VERIFIED: pub.dev — 2,330 likes, 1.42M downloads, verified publisher theyakka.com, BSD-3-Clause] — **note: last published ~3 years ago**, no recent release but still the most-used Flutter QR-rendering package | Render the invite QR code on the Invite screen | Straightforward client-side QR rendering from a string (the invite code/link) — no server-side QR generation needed |
| `share_plus` | **13.2.0** [VERIFIED: pub.dev — 4,010 likes, 2.94M downloads, verified publisher fluttercommunity.dev, published 10 days ago] | Native share-sheet integration ("Share" button on Invite screen) | This is the mechanism UI-SPEC identifies as satisfying FAM-02's "invite by email" at the transport layer — the OS share sheet includes Mail as one of many channels |
| `dio` (or `http`) | current stable | HTTP client for Flutter → ASP.NET Core API calls | `dio` is the de-facto standard for interceptor-based auth-header injection and refresh-token retry logic; `http` (Dart's own package) is a lighter alternative if interceptor plumbing is hand-rolled |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Custom `Users`/`Role`-enum identity model | `Microsoft.AspNetCore.Identity` + EF Core Identity stores | Identity brings in lockout/2FA/email-confirmation/many-to-many-roles machinery this phase's fixed 4-role model doesn't need, and its default `AspNetUsers`/`AspNetRoles` schema conflicts with the brief's own named tables (`Users`, `Families`, etc.) — only worth it if AUTH later needs true dynamic/many-to-many roles or built-in 2FA |
| `Mediator` (martinothamar) | Hand-rolled `ICommandHandler<TCommand,TResult>` + DI, no mediator package at all | Zero dependency, but you lose auto-discovery/registration and any pipeline-behavior conveniences (logging/validation behaviors) MediatR-style libraries give for free — reasonable for a project this size given only Phase 1's handlers exist so far |
| Resend | Postmark (100 free emails/month, no expiry, .NET SDK, industry-leading deliverability) | Postmark's free tier is smaller (100/mo vs Resend's 3,000/mo) but has a longer track record specifically for transactional/password-reset email deliverability; either is a reasonable pick — **flag as an open decision for the user**, not mandated |
| `flutter_riverpod` | `flutter_bloc` | Bloc's stricter event→state discipline is valuable for audit-trail-heavy domains (financial/healthcare) or 10+-developer teams; overkill machinery for a solo-dev project at this stage [CITED: 2026 comparison articles] |

**Installation (backend):**
```bash
dotnet --version    # must show 10.0.x — install if only 9.x is present (see Environment Availability)
dotnet new sln -n SafePath
dotnet add package Npgsql.EntityFrameworkCore.PostgreSQL
dotnet add package Microsoft.EntityFrameworkCore.Design
dotnet add package Microsoft.AspNetCore.Authentication.JwtBearer
dotnet add package BCrypt.Net-Next --version 4.2.0
dotnet add package FluentValidation.AspNetCore
dotnet add package Mediator.SourceGenerator --version 3.0.2   # or MediatR, if the license-key path is preferred
dotnet add package Resend --version 0.5.1
```

**Installation (Flutter):**
```bash
flutter --version   # must show 3.44.x — currently NOT installed on this machine, see Environment Availability
flutter pub add flutter_riverpod google_fonts flutter_secure_storage qr_flutter share_plus dio
```

**Version verification note:** All versions above were confirmed live against nuget.org/pub.dev on 2026-07-06 via direct `WebFetch`, not training-data recall. Re-confirm at actual install time since this ecosystem moves quickly (MediatR's licensing model itself is a mid-2025→2026 change that training data alone would have missed).

## Package Legitimacy Audit

> The automated `package-legitimacy check` seam only supports `npm|pypi|crates` ecosystems — this project's Phase 1 dependencies are NuGet (.NET) and pub.dev (Dart), neither of which the seam covers. The table below is manually verified via direct WebFetch against nuget.org/pub.dev/GitHub for every package (age, downloads, verified-publisher status, source-repo presence), applying the same signals the seam would check.

| Package | Registry | Age | Downloads | Source Repo | Verdict | Disposition |
|---------|----------|-----|-----------|--------------|---------|--------------|
| `BCrypt.Net-Next` | NuGet | long-established (widely used since .NET Core era) | 54.4M total | github.com/BcryptNet/bcrypt.net | OK | Approved |
| `FluentValidation` | NuGet | long-established | 33.5M+ (current version) | github.com/FluentValidation/FluentValidation | OK | Approved |
| `Mediator.SourceGenerator` | NuGet | ~4 years, actively maintained (published 2026-03-22) | 6.6M total | github.com/martinothamar/Mediator | OK | Approved |
| `MediatR` | NuGet | long-established, now commercially licensed | very high (historically) | github.com/LuckyPennySoftware/MediatR | OK (legit, but licensing terms changed — not a security concern, a cost/compliance one) | Approved with note — see Summary |
| `Resend` | NuGet | newer (official SDK, actively released) | not independently benchmarked this session | github.com/resend/resend-dotnet | OK (official first-party SDK, verified via vendor's own changelog + GitHub org) | Approved |
| `qr_flutter` | pub.dev | ~3 years since last publish, but 1.42M downloads/2,330 likes, verified publisher | 1.42M | github.com/theyakka/qr.flutter | OK (mature, stable, unmaintained-but-stable — not abandoned/suspicious, just feature-complete) | Approved, note staleness |
| `share_plus` | pub.dev | actively maintained (published 10 days ago) | 2.94M | github.com/fluttercommunity/plus_plugins | OK | Approved |
| `flutter_riverpod` | pub.dev | actively maintained (published 26 days ago), Flutter Favorite | 2.39M | github.com/rrousselGit/riverpod | OK | Approved |
| `flutter_secure_storage` | pub.dev | actively maintained (published 40 days ago) | 3.08M/week | github.com/mogol/flutter_secure_storage | OK | Approved |
| `google_fonts` | pub.dev | actively maintained (published 2 months ago), Flutter Favorite, published by flutter.dev | 2.7M | github.com/material-foundation/flutter-packages | OK | Approved |

**Packages removed due to [SLOP] verdict:** none
**Packages flagged as suspicious [SUS]:** none. `qr_flutter`'s ~3-year publish gap is noted for staleness awareness (still functional, widely used, BSD-3-Clause, verified publisher) — not flagged SUS, but the planner may want a `checkpoint:human-verify` before locking it in if pixel-perfect QR styling requirements emerge later.

*All package names above were discovered via direct WebFetch against the registry/vendor's own pages (nuget.org, pub.dev, official GitHub orgs) in this session — these are `[VERIFIED]`, not `[ASSUMED]`, per the provenance rule (authoritative source + registry confirmation both present).*

---

## Architecture Patterns

### System Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│  FLUTTER APP                                                     │
│  ┌────────────┐   ┌──────────────┐   ┌─────────────────────┐    │
│  │ Welcome /  │   │ Register /   │   │ Create circle /      │    │
│  │ Login /    │──▶│ Role select  │──▶│ Invite (QR/code) /   │    │
│  │ Forgot pwd │   │              │   │ Accept / Permissions │    │
│  └────────────┘   └──────────────┘   └─────────────────────┘    │
│         │  dio (HTTP client, attaches JWT, retries on 401)        │
└─────────┼─────────────────────────────────────────────────────────┘
          │  REST: POST /auth/register, /auth/login, /auth/refresh,
          │        /auth/forgot-password, /auth/reset-password,
          │        /families, /families/{id}/invites,
          │        /invites/{code}/accept, /families/{id}/members/{id}
          ▼
┌─────────────────────────────────────────────────────────────────┐
│  ASP.NET CORE API (Clean Architecture)                           │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │ API layer: Controllers, JwtBearer middleware, FluentVal    │  │
│  │  filters, [Authorize(Roles=...)] / policy-based checks      │  │
│  ├───────────────────────────────────────────────────────────┤  │
│  │ Application: RegisterCommand, LoginCommand, RefreshCommand,│  │
│  │  CreateFamilyCommand, GenerateInviteCommand,                │  │
│  │  RedeemInviteCommand, UpdatePermissionsCommand,             │  │
│  │  RemoveMemberCommand — each a Mediator handler              │  │
│  │  Interfaces: IIdentityService, ICurrentUserService,         │  │
│  │  IPasswordHasher, IJwtTokenGenerator, IEmailSender           │  │
│  ├───────────────────────────────────────────────────────────┤  │
│  │ Domain: User, Family, FamilyMember, FamilyInvitation,       │  │
│  │  RefreshToken entities + Role enum — zero external deps     │  │
│  ├───────────────────────────────────────────────────────────┤  │
│  │ Infrastructure: EF Core DbContext + migrations, BCrypt      │  │
│  │  hasher impl, JWT generator impl, Resend email sender impl  │  │
│  └───────────────────────────────────────────────────────────┘  │
└──────────────┬────────────────────────────────────────────────────┘
               │ Npgsql / EF Core                    │ HTTPS
               ▼                                      ▼
   ┌───────────────────────┐              ┌───────────────────────┐
   │ SUPABASE / POSTGRES    │              │ RESEND (transactional  │
   │ Users, RefreshTokens,  │              │ email API)             │
   │ Families, FamilyMembers│              │ — password-reset link  │
   │ FamilyInvitations      │              │   delivery only        │
   └───────────────────────┘              └───────────────────────┘
```

A reader can trace both primary flows end-to-end: registration/login (Flutter form → API validates+hashes/verifies → Postgres → JWT+refresh pair returned → `flutter_secure_storage`) and the invite flow (Guardian generates code via API → Postgres row with expiry → code shared via QR/share-sheet, Flutter-side only → Invitee redeems code via API → Postgres membership row created → both parties' UI reflects updated `FamilyMembers`).

### Recommended Project Structure

Matches `ARCHITECTURE.md`'s project-wide layout; Phase 1 populates these specific folders (others remain stubs/empty until later phases):

```
backend/src/
├── SafePath.Domain/
│   ├── Entities/           # User.cs, Family.cs, FamilyMember.cs, FamilyInvitation.cs, RefreshToken.cs
│   ├── Enums/              # Role.cs (Guardian, Member, Caregiver, OrgAdmin), PermissionLevel.cs, InvitationStatus.cs
│   └── Common/             # base entity, domain events (unused yet, stub for later phases)
├── SafePath.Application/
│   ├── Auth/               # RegisterCommand, LoginCommand, RefreshTokenCommand, LogoutCommand,
│   │                       # ForgotPasswordCommand, ResetPasswordCommand + validators
│   ├── Families/           # CreateFamilyCommand, GenerateInviteCommand, RedeemInviteCommand,
│   │                       # UpdateMemberPermissionsCommand, RemoveMemberCommand + validators
│   ├── Common/Interfaces/  # IIdentityService, ICurrentUserService, IPasswordHasher,
│   │                       # IJwtTokenGenerator, IEmailSender, IApplicationDbContext
├── SafePath.Infrastructure/
│   ├── Persistence/        # ApplicationDbContext, EF Core Migrations/, EntityConfigurations/
│   ├── Identity/           # BCryptPasswordHasher, JwtTokenGenerator
│   └── ExternalServices/   # ResendEmailSender
└── SafePath.Api/
    ├── Controllers/        # AuthController.cs, FamiliesController.cs, InvitesController.cs
    ├── Middleware/         # JWT bearer config, global exception handler
    └── Program.cs          # DI wiring, JwtBearer options, EF Core connection string

mobile/lib/
├── core/
│   ├── theme/              # ThemeData/ColorScheme built from SYSTEM_DESIGN tokens
│   ├── router/             # go_router or Navigator 2.0 routes for the 9 in-scope screens
│   └── network/            # dio client + auth-header interceptor + refresh-retry logic
├── features/
│   ├── auth/                # welcome, register, login, forgot/reset password screens + Riverpod providers
│   └── family/              # role select, create circle, invite (QR/code), accept/reject, manage permissions
└── shared_widgets/          # design-system primitives (buttons, inputs, cards) shared across both features
```

### Pattern 1: Custom Identity Behind an Abstraction (not `Microsoft.AspNetCore.Identity`)

**What:** Domain defines a plain `User` entity (no framework base class). Application defines `IIdentityService`/`ICurrentUserService`/`IPasswordHasher`/`IJwtTokenGenerator` interfaces. Infrastructure implements them using BCrypt + `System.IdentityModel.Tokens.Jwt`. This is the well-documented Jason Taylor Clean Architecture template pattern, adapted to skip ASP.NET Core Identity's EF Core stores entirely since the brief's schema and fixed 4-role model don't need Identity's dynamic-role/2FA/lockout machinery.
**When to use:** Any Clean Architecture ASP.NET Core project with a small, fixed role set and a custom, brief-mandated DB schema (as this project has).
**Trade-offs:** You forgo Identity's built-in email-confirmation/lockout/2FA scaffolding (none of which is in Phase 1's requirements anyway) in exchange for full control over table names/columns matching the brief's schema, and a lighter dependency footprint.

```csharp
// SafePath.Application/Common/Interfaces/IJwtTokenGenerator.cs
public interface IJwtTokenGenerator
{
    string GenerateAccessToken(User user);              // short-lived, 15-30 min
    (string token, DateTime expiresAt) GenerateRefreshToken(); // cryptographically random, 7-day default
}

// SafePath.Infrastructure/Identity/JwtTokenGenerator.cs
public class JwtTokenGenerator : IJwtTokenGenerator
{
    public string GenerateAccessToken(User user)
    {
        var claims = new[] {
            new Claim(JwtRegisteredClaimNames.Sub, user.Id.ToString()),
            new Claim(ClaimTypes.Role, user.Role.ToString()),
        };
        var creds = new SigningCredentials(_signingKey, SecurityAlgorithms.HmacSha256);
        var token = new JwtSecurityToken(issuer: _issuer, audience: _audience,
            claims: claims, expires: DateTime.UtcNow.AddMinutes(20), signingCredentials: creds);
        return new JwtSecurityTokenHandler().WriteToken(token);
    }

    public (string, DateTime) GenerateRefreshToken()
    {
        var randomBytes = RandomNumberGenerator.GetBytes(64); // 64 bytes entropy floor, per source guidance
        return (Convert.ToBase64String(randomBytes), DateTime.UtcNow.AddDays(7));
    }
}
```
*Source pattern: [CITED: codewithmukesh.com/blog/refresh-tokens-in-aspnet-core, code-maze.com, antondevtips.com — cross-checked across 3 independent .NET-10-era guides]*

### Pattern 2: Refresh Token Rotation with Reuse Detection

**What:** Every refresh-token use is single-use: on `/auth/refresh`, the presented token is validated against the DB, immediately revoked, and a brand-new refresh token is issued and stored. If a *revoked* token is ever presented again, the system treats it as a signal the token was stolen and revokes every active refresh token for that user, forcing re-login everywhere.
**When to use:** Every JWT+refresh implementation in this project — this is the concrete mechanism that closes Pitfall 7 (project-level PITFALLS.md) and directly satisfies AUTH-02/AUTH-03.
**Trade-offs:** Requires a `RefreshTokens` table with `IsRevoked`/`ReplacedByToken` columns and a DB write on every refresh — negligible cost at this project's scale.

```csharp
public async Task<AuthResult> Handle(RefreshTokenCommand cmd, CancellationToken ct)
{
    var existing = await _db.RefreshTokens.SingleOrDefaultAsync(t => t.Token == cmd.RefreshToken, ct);
    if (existing is null) return AuthResult.Invalid();
    if (existing.IsRevoked)
    {
        // reuse of a revoked token — assume compromise, nuke every active token for this user
        await _db.RefreshTokens
            .Where(t => t.UserId == existing.UserId && !t.IsRevoked)
            .ExecuteUpdateAsync(s => s.SetProperty(t => t.IsRevoked, true), ct);
        return AuthResult.Invalid();
    }
    if (existing.ExpiresAt < DateTime.UtcNow) return AuthResult.Invalid();

    existing.IsRevoked = true;
    var (newToken, expiresAt) = _jwt.GenerateRefreshToken();
    _db.RefreshTokens.Add(new RefreshToken { UserId = existing.UserId, Token = newToken, ExpiresAt = expiresAt, ReplacedFrom = existing.Id });
    await _db.SaveChangesAsync(ct);

    var user = await _db.Users.FindAsync([existing.UserId], ct);
    return AuthResult.Success(_jwt.GenerateAccessToken(user!), newToken);
}
```
*Source pattern: [CITED: antondevtips.com/blog/how-to-implement-refresh-tokens-and-token-revocation-in-aspnetcore, steve-bang.com/blog/refresh-token-rotation-aspnet-core — cross-checked]*

### Pattern 3: Family Invitation as an Expiring, Single-Use Share Code (not an email-required record)

**What:** `FamilyInvitations` row: `Id`, `FamilyId`, `Code` (unique, indexed, e.g. `SP-4K9X`-style — recommend backing this with a cryptographically random code, not a naive sequential/short alphanumeric generator, to resist guessing), `InviteeLabel` (nullable free-text, for the guardian's own "Pending: Jordan (Teen)" list display — see Open Questions §2), `InviteeEmail` (nullable — kept for an optional future "also send a programmatic email" belt-and-braces channel, never required by the UI), `CreatedByUserId`, `ExpiresAt` (`CreatedAt + 24h`, matching UI-SPEC copy), `Status` (Pending/Accepted/Declined/Expired/Revoked), `AcceptedByUserId` (nullable).
**When to use:** Satisfies FAM-01 through FAM-05 per the UI-SPEC's resolved share-code/QR flow. `share_plus`'s native share sheet (which includes Mail as one of several channels) is what actually satisfies FAM-02's literal "invite by email" wording at the transport layer — the invite record itself is not email-keyed.
**Trade-offs:** A bearer-style code is weaker access control than an email-bound invite (anyone possessing the code can redeem it) — mitigate with: (1) short expiry (24h), (2) single-use (mark `Accepted`/consumed immediately, code can't be reused), (3) sufficient code entropy (don't rely on a 6-character human-friendly code alone for the *actual* security boundary — consider a longer opaque token in the shareable *link* itself, with the short human-readable code as a secondary/display-only affordance for the QR/manual-entry case), (4) require the redeeming user to be authenticated (so the invite is tied to a real account, not anonymous), (5) rate-limit the redeem endpoint against brute-force code guessing.

```csharp
public class FamilyInvitation
{
    public Guid Id { get; set; }
    public Guid FamilyId { get; set; }
    public string Code { get; set; } = default!;        // e.g. cryptographically random, base32-ish for QR/manual entry
    public string? InviteeLabel { get; set; }            // optional, guardian-entered display name only
    public string? InviteeEmail { get; set; }             // optional, never required by UI
    public Guid CreatedByUserId { get; set; }
    public DateTime ExpiresAt { get; set; }
    public InvitationStatus Status { get; set; }          // Pending, Accepted, Declined, Expired, Revoked
    public Guid? AcceptedByUserId { get; set; }
}
```

### Anti-Patterns to Avoid

- **Using `Microsoft.AspNetCore.Identity`'s default schema for this project's fixed 4-role model:** brings unnecessary ceremony (lockout, 2FA scaffolding, many-to-many role tables) that fights the brief's own named-table schema. Use the custom abstraction pattern above instead.
- **Treating the family-invite code as sufficient authorization on its own, with no expiry/single-use enforcement:** turns a convenience feature into an open door — always expire (24h) and mark consumed on accept.
- **Enforcing role/family-membership checks only in Flutter UI (hiding buttons) without server-side re-checks:** the API must independently verify on every request that the caller belongs to the family being queried/mutated and holds the required role — this is the IDOR prevention discussed in Security Domain below.
- **Storing tokens in `SharedPreferences`:** already flagged project-wide in PITFALLS.md Pitfall 7 — use `flutter_secure_storage` exclusively.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|--------------|-----|
| Password hashing | A custom SHA-256+salt scheme | `BCrypt.Net-Next` | Adaptive, slow-by-design hashing is a solved problem with well-audited libraries; hand-rolled schemes are the single most common auth vulnerability in student/solo projects |
| Refresh-token random generation | `Guid.NewGuid()` or a weak PRNG | `RandomNumberGenerator.GetBytes(64)` | GUIDs are not designed to be unguessable secrets (they leak generation-time/machine info in some implementations and have far less entropy than a CSPRNG); use a cryptographically secure random generator explicitly |
| JWT signing/parsing | Manual JSON+HMAC construction | `System.IdentityModel.Tokens.Jwt` / `Microsoft.AspNetCore.Authentication.JwtBearer` | Token format edge cases (algorithm confusion attacks, clock-skew handling, claim validation) are exactly the kind of subtle security surface a well-audited library handles correctly |
| Transactional email delivery | A custom SMTP client hand-rolled against a personal Gmail account | `Resend` (or `Postmark`) official SDK | Personal-account SMTP is unreliable (rate limits, spam-folder placement, no delivery tracking) and is explicitly the kind of shortcut that silently fails exactly when AUTH-04's password-reset flow needs to work |
| CQRS/use-case dispatch boilerplate | A hand-rolled `switch` over command types with reflection | `Mediator` (source-generator) or a small typed `ICommandHandler<T>` interface + DI | Compile-time-checked dispatch avoids a common class of "forgot to register this handler" runtime bugs; but see Standard Stack — hand-rolling a minimal interface is also acceptable here given the small handler count in Phase 1 |
| QR code rendering | A custom QR encoder | `qr_flutter` | QR encoding (Reed-Solomon error correction, module layout) is a well-defined spec with mature, free implementations; there's no reason to reimplement it |

**Key insight:** Every "don't hand-roll" item above maps to either a well-known security vulnerability class (password/token handling) or a well-specified format (JWT, QR) — the risk of a subtle bug in a hand-rolled version is disproportionate to the (near-zero) benefit of avoiding a small, well-audited dependency.

---

## Common Pitfalls

### Pitfall 1: Refresh tokens implemented without rotation or reuse detection (project-level Pitfall 7, phase-specific mechanics)

**What goes wrong:** A single, long-lived refresh token is issued at login and reused indefinitely across every subsequent `/refresh` call — if it's ever intercepted (stolen device, logged accidentally, leaked via a misconfigured client), the attacker has standing access until the token's long expiry, with no way to detect the theft.
**Why it happens:** Rotation is the part of "implement refresh tokens" that's easy to skip because the happy-path (legitimate user refreshing normally) works identically whether or not rotation/reuse-detection exists — the gap only shows up when something goes wrong.
**How to avoid:** Implement Pattern 2 above exactly: single-use tokens, immediate revocation on use, reuse-of-revoked-token triggers a full session wipe for that user.
**Warning signs:** A `RefreshTokens` table (or equivalent) with no `IsRevoked`/`ReplacedByToken` column; a `/refresh` endpoint that doesn't write to the DB on every call.

### Pitfall 2: MediatR's commercial licensing change breaks the build or CI silently

**What goes wrong:** Following older tutorials/templates (including some Clean Architecture boilerplate) that reference `MediatR` versions ≥13 without setting a license key produces console warnings at runtime (not a hard failure per current enforcement, but this is a stated, deliberate compliance step vendors can tighten later) — and any commercial-tier confusion (accidentally exceeding the $5M-revenue Community-tier threshold, which won't apply here but is worth understanding) could require a paid license.
**Why it happens:** `STACK.md` (researched before this specific licensing change was verified this session) lists MediatR as "optional but common" without flagging the Nov 2025 licensing shift.
**How to avoid:** Use `Mediator` (martinothamar, MIT, no license key) instead, or explicitly register for MediatR's free Community license at mediatr.io and set the `MEDIATR_LICENSE_KEY` env var if the team prefers MediatR's API surface.
**Warning signs:** Console warnings about a missing/invalid MediatR license key at app startup.

### Pitfall 3: AUTH-04 (password reset email) has no chosen email provider anywhere in prior research — silent scope gap

**What goes wrong:** The phase gets planned/built with a stubbed or "TODO: send email" placeholder for the reset-link delivery, and AUTH-04 quietly ships broken or manual-only, since no project document (PROJECT.md, STACK.md, ARCHITECTURE.md) picked a transactional email provider.
**Why it happens:** Project-level research focused on the fixed 4-pillar stack (Flutter/ASP.NET/Supabase/Python) and didn't surface email delivery as its own decision, since it's a small, easy-to-overlook integration relative to the AI/location/SOS features that dominated research attention.
**How to avoid:** Treat email-provider selection as an explicit Phase 1 task (see Standard Stack recommendation: Resend, official .NET SDK, free tier) — get an API key provisioned during Wave 0, not discovered as a gap mid-implementation.
**Warning signs:** No `IEmailSender` interface/implementation appears anywhere in the plan; "forgot password" tested only by reading the token directly from the database instead of an actual email.

### Pitfall 4: Family invite code has insufficient entropy or no rate-limiting on the redeem endpoint

**What goes wrong:** A short, human-typeable code (e.g. 6 alphanumeric characters, matching the mockup's `SP-4K9X` display) is brute-forceable if the redeem endpoint has no rate limiting — an attacker could script through the code space and join family circles they weren't invited to.
**Why it happens:** The mockup's visual code is optimized for human readability/typing, not cryptographic strength, and it's easy to use that same short string as the actual security-bearing secret rather than treating it as a display label over a longer underlying token.
**How to avoid:** Rate-limit `/invites/{code}/accept` (e.g., per-IP and per-family limits), and consider using a longer opaque token in the shareable *link*/QR payload itself (the QR can encode a much longer string than what's shown as a human-readable code), reserving the short 6-character form as a fallback for manual entry only, accepted with stricter rate limits.
**Warning signs:** No rate-limiting middleware on the invite-redeem endpoint; the same short code string used as both the QR payload and the manual-entry fallback with no separate long-token option.

### Pitfall 5: Postgres RLS designed as "the" authorization layer, contradicting the backend-mediates-everything architecture

**What goes wrong:** Following project-level PITFALLS.md's generic advice to "explicitly design and test Postgres RLS policies for Guardian/Member/Caregiver/org-role visibility," a plan could end up trying to enforce family/role scoping via Postgres Row-Level Security *and* backend authorization checks — doubling the enforcement surface, or worse, relying on RLS alone while the backend connects with a role that bypasses it (common when using a single service-role/superuser-style Npgsql connection string, which is the normal pattern for a persistent backend process per ARCHITECTURE.md's Anti-Pattern 3).
**Why it happens:** PITFALLS.md's advice is generically correct for Supabase-as-BaaS projects (where the client SDK talks to Postgres directly, so RLS *is* the auth layer) — but this project's ARCHITECTURE.md explicitly rejects that shape (Flutter never holds a Supabase key; only the backend talks to Postgres). The two project-level docs are in tension and the planner should resolve this explicitly, not silently pick one.
**How to avoid:** For Phase 1, enforce all Guardian/Member/Caregiver/family-scoping authorization in the Application layer (backend code, e.g., a `FamilyAuthorizationHandler` checked on every family-scoped command/query) — this matches ARCHITECTURE.md's Anti-Pattern 3 guidance. Treat Postgres RLS as optional defense-in-depth to revisit later if the backend's DB connection is ever downgraded from a trusted service role, not as this phase's primary authorization mechanism.
**Warning signs:** A plan that includes writing SQL `CREATE POLICY` statements as a Phase 1 deliverable without also specifying how the backend's own Npgsql connection would even respect them (it typically wouldn't, using a standard connection string).

### Pitfall 6: JWT/refresh-token handling mistakes (see project-level PITFALLS.md Pitfall 7 for the full writeup — restated here as the phase-owning pitfall)

**Phase to address:** This phase, explicitly — it is the "Auth/backend core phase" PITFALLS.md's Pitfall-to-Phase Mapping table already assigns this to. See Patterns 1-2 above for the concrete mechanics; see Security Domain below for the ASVS mapping.

---

## Code Examples

### Password Hashing (registration)
```csharp
// SafePath.Infrastructure/Identity/BCryptPasswordHasher.cs
public class BCryptPasswordHasher : IPasswordHasher
{
    public string Hash(string password) => BCrypt.Net.BCrypt.HashPassword(password, workFactor: 12);
    public bool Verify(string password, string hash) => BCrypt.Net.BCrypt.Verify(password, hash);
}
```
*Source: [CITED: NuGet package docs for BCrypt.Net-Next; work factor 12 is the commonly-recommended 2026 default balancing cost vs. login latency]*

### Family Creation + First Member (Guardian)
```csharp
public async Task<Guid> Handle(CreateFamilyCommand cmd, CancellationToken ct)
{
    var family = new Family { Id = Guid.NewGuid(), Name = cmd.Name, CreatedByUserId = cmd.UserId };
    var membership = new FamilyMember {
        FamilyId = family.Id, UserId = cmd.UserId, Role = Role.Guardian,
        Permissions = PermissionLevel.FullLocation, JoinedAt = DateTime.UtcNow
    };
    _db.Families.Add(family);
    _db.FamilyMembers.Add(membership);
    await _db.SaveChangesAsync(ct);
    return family.Id;
}
```

### Password Reset Email Dispatch
```csharp
public async Task Handle(ForgotPasswordCommand cmd, CancellationToken ct)
{
    var user = await _db.Users.SingleOrDefaultAsync(u => u.Email == cmd.Email, ct);
    if (user is null) return; // don't reveal whether the email exists — copy per UI-SPEC already avoids this leak

    var token = Convert.ToBase64String(RandomNumberGenerator.GetBytes(32));
    _db.PasswordResetTokens.Add(new PasswordResetToken {
        UserId = user.Id, TokenHash = _hasher.Hash(token), // store hashed, never the raw token
        ExpiresAt = DateTime.UtcNow.AddHours(24)            // matches UI-SPEC copy: "expires in 24 hours"
    });
    await _db.SaveChangesAsync(ct);

    var resetLink = $"{_config["App:BaseUrl"]}/reset-password?token={token}&email={user.Email}";
    await _emailSender.SendAsync(user.Email, "Reset your SafePath AI password", BuildResetEmailBody(resetLink));
}
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|---------------|--------|
| PBKDF2 (ASP.NET Core Identity's default `PasswordHasher`, 10,000 iterations) | BCrypt/Argon2 with adaptive work factors | Ongoing community shift, accelerated by GPU-cracking advances; PBKDF2 remains NIST-recommended/FIPS-compliant but needs far higher iteration counts (~310,000+) to stay comparably strong | For a new (not migrating-legacy) project, start with BCrypt directly rather than PBKDF2-with-low-default-iterations |
| MediatR as a free, MIT-licensed default choice in Clean Architecture templates/tutorials | MediatR v13+ (Nov 2025) requires a license key (free for individuals/companies <$5M revenue, paid above that) | Nov 2025 — Jimmy Bogard/Lucky Penny Software commercial licensing launch | Older tutorials/templates referencing MediatR without a license key will show warnings on current versions; open-source alternatives (`Mediator`, `Cortex.Mediator`, `Concordia`) have emerged in response |
| Manual foreground-service GPS polling for geofencing (irrelevant to Phase 1, noted for completeness) | Native `GeofencingClient`/`CLCircularRegion` APIs mandated by Google Play's April 2026 policy | April 15, 2026 | Not this phase's concern (Phase 4), but confirms the project-level STACK.md finding is current |

**Deprecated/outdated:** ASP.NET Core Identity's default `PasswordHasher<TUser>` iteration count (10,000) as a standalone recommendation for new projects — either use a custom higher-iteration PBKDF2 config or switch to BCrypt/Argon2 as this document recommends.

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Custom identity model (not `Microsoft.AspNetCore.Identity`) is the better fit given the brief's fixed 4-role schema | Architecture Patterns §1, Standard Stack | If the user actually wants Identity's built-in 2FA/lockout/email-confirmation machinery for a future phase, retrofitting onto a custom model is a larger refactor than starting with Identity — confirm with user/discuss-phase before locking in |
| A2 | `flutter_riverpod` over `flutter_bloc` for state management | Standard Stack | No prior project decision exists either way; if the user has Bloc experience/preference, switching later means redoing all provider/state wiring — flag for discuss-phase |
| A3 | `Resend` over `Postmark` (or another provider) for password-reset email | Standard Stack, Pitfall 3 | Low switching cost (both are thin `IEmailSender` implementations behind the same interface) but still an unconfirmed external-service choice requiring an account/API key the user needs to provision |
| A4 | Family invite codes should carry a longer opaque token in the QR/link payload distinct from the short human-readable display code | Architecture Patterns §3, Pitfall 4 | If under-engineered (short code = the actual secret), brute-force risk is real but low-severity for a graduation-project demo scope; still worth a deliberate decision, not a default |
| A5 | Postgres RLS should NOT be the primary authorization mechanism for Phase 1 (backend-layer checks instead) | Pitfall 5 | This directly contradicts project-level PITFALLS.md's generic RLS advice — if the user actually wants defense-in-depth RLS from day one, that's additional Phase 1 scope not currently planned |
| A6 | A guardian-entered free-text `InviteeLabel` (not email) explains the mockup's named "Pending" list entries | Architecture Patterns §3, Open Questions §2 | If the actual intended behavior is different (e.g., the label appears only after acceptance, from the invitee's own profile name, not entered by the guardian at invite-creation time), the invite-creation UI/API contract needs an extra field or a different data flow — this is explicitly unresolved, see Open Questions |

**If this table is empty:** N/A — see entries above; several genuine open decisions exist and should reach the user via discuss-phase or explicit plan-time flagging, not be silently assumed by the planner.

---

## Open Questions

1. **Is the share-code/QR invite flow (as UI-SPEC resolved it) technically sound, and how does it reconcile with the brief's `FamilyInvitations.InviteeEmail` schema column?**
   - What we know: Share-code/QR invites are a common, technically sound pattern (used by countless consumer apps) as long as expiry + single-use + rate-limiting are enforced (see Architecture Patterns §3, Pitfall 4). `share_plus`'s native share sheet including Mail as a channel is a reasonable way to satisfy "invite by email" at the transport layer without a dedicated email-collection field.
   - What's unclear: Whether the brief's schema truly requires `InviteeEmail` to be populated (implying the original design intent was an email-targeted invite, with the mockup being a later, UI-team decision that never got reconciled back into the schema/requirements), and whether the UI-SPEC's "Pending: Jordan (Teen) / Invited 2h ago" list implies a guardian-entered name field that isn't documented as an actual input field anywhere.
   - Recommendation: Keep `InviteeEmail` nullable (optional programmatic-email-send channel, not required), add a nullable `InviteeLabel` free-text field for the guardian's own bookkeeping, and surface this exact reconciliation to the user via discuss-phase before planning locks it in — it's a real product-intent question (was "invite by email" meant literally, with the mockup simply not having caught up?), not just a technical implementation detail.

2. **Are Login and Forgot-Password screens (specified by extension, not in the 36-screen mockup) low-risk to build without live-user validation?**
   - What we know: UI-SPEC built them using the exact same tokens/shell as the Register screen (same background, header style, input styling, CTA pattern) — internally consistent, no new visual system introduced.
   - What's unclear: Nothing technical — this is a low-risk, standard extension pattern (every app needs a login screen; building one from the same design tokens as an existing, validated screen is safe).
   - Recommendation: No further research needed here; proceed as UI-SPEC specifies. Confirmed low-risk.

3. **.NET 10 SDK is not installed locally — does the plan need an explicit SDK-install task?**
   - What we know: Only .NET 9 SDKs (9.0.201, 9.0.205) are present on this machine; `dotnet --list-sdks` confirms no 10.x SDK.
   - What's unclear: Whether the user will install .NET 10 before execution begins, or whether the plan should include an explicit install step (or, alternatively, target .NET 9 STS instead if the user prefers not to install a new SDK — though this contradicts `STACK.md`'s LTS-longevity rationale).
   - Recommendation: Add a Wave 0 environment-setup task (install .NET 10 SDK) rather than silently assuming it will appear; see Environment Availability.

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|--------------|-----------|---------|----------|
| .NET SDK | Backend build/run (all of Phase 1) | ✗ (only 9.x present) | 9.0.201, 9.0.205 installed; 10.0.x required | Install .NET 10 SDK before Wave 0 backend work begins; no code-level fallback — targeting .NET 9 (STS) instead is possible but contradicts `STACK.md`'s explicit LTS-longevity recommendation, flag as a user decision if they decline to upgrade |
| Flutter SDK | Mobile app scaffold (all of Phase 1 Flutter work) | ✗ (not found via `where flutter`) | required: 3.44.x | Install Flutter SDK before Wave 0 mobile work begins; no fallback — Flutter is fixed by the brief |
| Supabase CLI | Supabase project provisioning / local dev stack | ✗ (not found via `where supabase`, no global npm install) | none installed | Provisioning can be done entirely through the Supabase web dashboard (create project, get connection string) without the CLI for Phase 1's scope — CLI is a nice-to-have for local dev/migrations-preview, not a hard blocker |
| Node.js | Tooling (e.g., if any npm-based dev tooling is used) | ✓ | v22.14.0 | — |
| git | Version control | ✓ | 2.48.1.windows.1 | — |
| Python | Not required by Phase 1 (AI service is Phase 6) | ✓ (present, not relevant here) | 3.13.1 | — |

**Missing dependencies with no fallback:**
- .NET 10 SDK — must be installed before backend work begins (or an explicit, documented decision to target .NET 9 instead, accepting the LTS-longevity tradeoff `STACK.md` already flagged)
- Flutter SDK — must be installed before mobile scaffold work begins

**Missing dependencies with fallback:**
- Supabase CLI — dashboard-based provisioning is a viable substitute for this phase's scope

---

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | xUnit (backend, standard for .NET Clean Architecture templates) + `flutter_test` (mobile, ships with Flutter SDK) |
| Config file | none yet — greenfield; create `SafePath.Application.Tests/SafePath.Application.Tests.csproj` and `mobile/test/` during Wave 0 |
| Quick run command | `dotnet test backend/tests/SafePath.Application.Tests` (backend) / `flutter test` (mobile) |
| Full suite command | `dotnet test backend/SafePath.sln` (backend) / `flutter test` (mobile, same command — no separate "full" tier exists yet at this project size) |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|---------------------|--------------|
| AUTH-01 | Register with valid email/password succeeds; duplicate email rejected | unit + integration | `dotnet test --filter FullyQualifiedName~RegisterCommandTests` | ❌ Wave 0 |
| AUTH-02 | Login issues valid access+refresh JWT pair; refresh rotates token | unit | `dotnet test --filter FullyQualifiedName~RefreshTokenCommandTests` | ❌ Wave 0 |
| AUTH-03 | Logout revokes the refresh token (subsequent refresh with it fails) | unit | `dotnet test --filter FullyQualifiedName~LogoutCommandTests` | ❌ Wave 0 |
| AUTH-04 | Forgot-password generates a hashed, expiring token and calls `IEmailSender` | unit (mock `IEmailSender`) | `dotnet test --filter FullyQualifiedName~ForgotPasswordCommandTests` | ❌ Wave 0 |
| AUTH-05 | Role is persisted and returned in JWT claims at registration | unit | `dotnet test --filter FullyQualifiedName~RegisterCommandTests` | ❌ Wave 0 |
| FAM-01 | Creating a family also creates a Guardian membership row for the creator | unit | `dotnet test --filter FullyQualifiedName~CreateFamilyCommandTests` | ❌ Wave 0 |
| FAM-02/FAM-03 | Invite code generation + redeem (accept/reject) round-trip, expiry enforced | unit + integration | `dotnet test --filter FullyQualifiedName~FamilyInvitationTests` | ❌ Wave 0 |
| FAM-04 | Updating a member's permission level persists and is returned correctly | unit | `dotnet test --filter FullyQualifiedName~UpdateMemberPermissionsCommandTests` | ❌ Wave 0 |
| FAM-05 | Removing a member revokes their access (subsequent family-scoped requests as that user fail authorization) | integration | `dotnet test --filter FullyQualifiedName~RemoveMemberCommandTests` | ❌ Wave 0 |
| DESIGN-01 | `ThemeData` exposes the exact tokens (colors/type/spacing) `01-UI-SPEC.md` specifies | widget test | `flutter test test/theme_test.dart` | ❌ Wave 0 |

### Sampling Rate
- **Per task commit:** `dotnet test backend/tests/SafePath.Application.Tests` and/or `flutter test` (whichever layer the task touched)
- **Per wave merge:** full suite (`dotnet test backend/SafePath.sln` + `flutter test`)
- **Phase gate:** Full suite green before `/gsd-verify-work`

### Wave 0 Gaps
- [ ] `backend/tests/SafePath.Domain.Tests/SafePath.Domain.Tests.csproj` — entity/enum unit tests
- [ ] `backend/tests/SafePath.Application.Tests/SafePath.Application.Tests.csproj` — command handler unit tests (with mocked `IApplicationDbContext`/`IEmailSender`/`IJwtTokenGenerator`)
- [ ] `backend/tests/SafePath.Api.IntegrationTests/SafePath.Api.IntegrationTests.csproj` — `WebApplicationFactory`-based endpoint tests against a test Postgres instance (or Testcontainers)
- [ ] `mobile/test/` — widget tests for the theme + at minimum one screen (e.g. Register) smoke test
- [ ] Framework install: `dotnet new xunit` scaffolding + `flutter test` already ships with the SDK — no extra install needed once the SDKs themselves are installed (see Environment Availability)

---

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|----------------|---------|--------------------|
| V2 Authentication | yes | BCrypt password hashing (work factor ≥12), no plaintext/reversible storage, account-enumeration-safe error copy (UI-SPEC's "Incorrect email or password" already avoids revealing which field was wrong) |
| V3 Session Management | yes | Short-lived JWT access tokens (15-30 min) + rotating, single-use, DB-revocable refresh tokens (Pattern 2); reuse-detection triggers full session wipe |
| V4 Access Control | yes | Every family-scoped endpoint independently re-verifies the caller's `FamilyMember` row and role/permission — never trust a client-supplied family ID or role claim alone (see Pitfall 5, IDOR below) |
| V5 Input Validation | yes | `FluentValidation` on all commands (register email format, password complexity, invite-code format) |
| V6 Cryptography | yes | `RandomNumberGenerator.GetBytes()` for refresh tokens and password-reset tokens (never `Guid.NewGuid()` or `Random`); JWT signed with `HmacSha256` and a secret stored in configuration/secret manager, never hardcoded — never hand-roll |

### Known Threat Patterns for this stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|------------------------|
| Credential stuffing / brute-force login | Spoofing | Rate-limit `/auth/login` (per-IP and per-account), generic error copy that doesn't reveal which field was wrong (already specified in UI-SPEC) |
| Stolen/leaked refresh token reused after rotation | Spoofing / Elevation of Privilege | Reuse detection → revoke all tokens for that user (Pattern 2) |
| Broken access control across family boundaries (a Member querying another family's data via a crafted request) | Tampering / Elevation of Privilege | Server-side re-verification of family membership + role on every request — never rely on client-supplied `familyId` alone without checking the caller's own membership row |
| Invite-code brute-forcing | Spoofing | Rate-limit `/invites/{code}/accept`, sufficient code/token entropy, 24h expiry, single-use (Pitfall 4) |
| Password-reset token leakage via logs or URL referrer headers | Information Disclosure | Store only a hash of the reset token server-side (never the raw token), short expiry (24h per UI-SPEC copy), single-use, never log the raw token or full reset URL |
| JWT algorithm-confusion / tampering | Tampering | Use a well-audited JWT library (`Microsoft.AspNetCore.Authentication.JwtBearer`), explicitly pin the expected signing algorithm server-side, never accept `alg: none` |

---

## Sources

### Primary (HIGH confidence)
- Direct WebFetch against nuget.org: `BCrypt.Net-Next` 4.2.0, `FluentValidation` 12.1.1, `MediatR` 14.2.0, `Mediator.SourceGenerator` 3.0.2, `Resend` 0.5.1 — package existence, version, download counts, publish dates confirmed live against the registry
- Direct WebFetch against pub.dev: `qr_flutter` 4.1.0, `share_plus` 13.2.0, `flutter_riverpod` 3.3.2, `flutter_secure_storage` 10.3.1, `google_fonts` 8.1.0 — same, confirmed live
- `dotnet --list-sdks`, `where flutter`, `where supabase` — direct local environment probes (this session)
- Project-level `.planning/research/ARCHITECTURE.md`, `.planning/research/STACK.md`, `.planning/research/PITFALLS.md`, `.planning/research/FEATURES.md`, `.planning/research/SUMMARY.md` — already-verified project research, treated as authoritative project context

### Secondary (MEDIUM confidence)
- [Refresh Tokens in ASP.NET Core - A Complete .NET 10 Guide — codewithmukesh](https://codewithmukesh.com/blog/refresh-tokens-in-aspnet-core/)
- [How to Implement Refresh Tokens and Token Revocation in ASP.NET Core — antondevtips](https://antondevtips.com/blog/how-to-implement-refresh-tokens-and-token-revocation-in-aspnetcore)
- [Refresh Token Rotation with ASP.NET Core Auth — Steve Bang](https://www.steve-bang.com/blog/refresh-token-rotation-aspnet-core)
- [Better Password Hashing in ASP.NET Core — Scott Brady](https://www.scottbrady.io/aspnet-identity/improving-the-aspnet-core-identity-password-hasher)
- [The Best Practices for Password Hashing: Comparing .NET Identity and BCrypt.Net — Medium/ASP DOTNET](https://medium.com/asp-dotnet/the-best-practices-for-password-hashing-comparing-net-identity-and-bcrypt-net-38d4301dd785)
- [Hash passwords in ASP.NET Core — Microsoft Learn](https://learn.microsoft.com/en-us/aspnet/core/security/data-protection/consumer-apis/password-hashing?view=aspnetcore-10.0)
- [Licensing FAQ — Lucky Penny Software](https://luckypennysoftware.com/faq)
- [AutoMapper and MediatR Licensing Update — Jimmy Bogard](https://www.jimmybogard.com/automapper-and-mediatr-licensing-update/)
- [GitHub — martinothamar/Mediator](https://github.com/martinothamar/Mediator)
- [Send emails with .NET — Resend docs](https://resend.com/docs/send-with-dotnet)
- [Announcing the .NET SDK — Resend changelog](https://resend.com/changelog/announcing-the-dotnet-sdk)
- [The 25 Best Transactional Email Services in 2026 — Sequenzy](https://www.sequenzy.com/blog/best-transactional-email-services)
- [QR Code Security Guide — Duke Information Security](https://security.duke.edu/security-guides/qr-code-security-guide/)
- [Best practices for QR codes and hyperlinks — UTMB](https://www.utmb.edu/social/post/updates/2024/09/05/best-practices-for-qr-codes-and-hyperlinks)
- [Manage invite links — SafetyCulture Help Center](https://help.safetyculture.com/en-US/004253/)
- [Flutter Riverpod vs Bloc in 2026 — Medium/Pragnesh Palsana](https://medium.com/@pragneshpalsana/flutter-riverpod-vs-bloc-in-2026-a-real-developers-honest-take-6c0dbcdc1e3c)
- [Flutter State Management in 2026: Riverpod vs Bloc vs Provider — Samioda](https://samioda.com/en/blog/flutter-state-management-2026)
- [Flutter State Management in 2026: BLoC vs Riverpod — ASOasis](https://asoasis.tech/articles/2026-04-17-2054-flutter-bloc-vs-riverpod-comparison-2026/)
- Layers in Clean Architecture Asp.net Core — [Microsoft Q&A](https://learn.microsoft.com/en-us/answers/questions/643072/layers-in-clean-architecture-asp-net-core-5)
- [ASP.NET Core Identity in a Clean Architecture — GitHub reference implementation](https://github.com/iamdlm/aspnet-core-identity-clean-architecture)

### Tertiary (LOW confidence)
- General WebSearch aggregation on "family invite share code vs email" security framing (no single canonical source; cross-checked across 3+ independent articles on QR/quishing and invite-link expiry practices)

---

## Metadata

**Confidence breakdown:**
- Standard stack: MEDIUM-HIGH — every package version/download/publish-date claim verified live against nuget.org/pub.dev this session; architectural recommendation (custom identity vs ASP.NET Identity) is MEDIUM, cross-checked across multiple reference implementations but not a single canonical Microsoft guidance page
- Architecture: MEDIUM — patterns (refresh rotation, invite-as-share-code) are well-established industry practice cross-checked across 2+ independent sources each; project-specific schema/entity shapes are this document's own synthesis, not directly sourced
- Pitfalls: MEDIUM-HIGH — MediatR licensing change and missing-email-provider gap were both directly discovered/verified this session (not carried over unverified from training data); RLS-vs-backend-authorization tension is this document's own analysis reconciling two project-level docs

**Research date:** 2026-07-06
**Valid until:** ~30 days for architecture/pattern guidance (stable); ~7-14 days for exact package versions and MediatR licensing terms specifically (this ecosystem area is actively shifting)

---
*Research for: SafePath AI, Phase 1 — Backend & Auth Foundation*
*Researched: 2026-07-06*
