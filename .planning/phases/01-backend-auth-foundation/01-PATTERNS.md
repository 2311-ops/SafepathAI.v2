# Phase 1: Backend & Auth Foundation - Pattern Map

**Mapped:** 2026-07-06
**Files analyzed:** 38 (backend: 26, mobile: 12; see File Classification)
**Analogs found:** 0 / 38 — **this repository is genuinely greenfield**

## Codebase Search Performed (for the record)

The repo currently contains no application source code of any kind — no `backend/`, `mobile/`, `src/`, `.csproj`, `.sln`, `.dart` app files, or test projects exist anywhere. `git ls-files` returns only:

- `.claude/CLAUDE.md`, `.planning/**` (planning/research docs, this phase's own RESEARCH/UI-SPEC/VALIDATION)
- `SYSTEM_DESIGN (1).md`, `SafePathAI_Master_Brief_enhanced_features.docx` — product briefs, not code
- `SafePath AI - Standalone (1).html`, `SafePath AI.dc (1).html` — static HTML/CSS design mockups (canvas boards rendering the 9 in-scope screens as absolutely-positioned `<div>`s with inline styles); useful only as **visual reference for DESIGN-01 tokens** (colors, type scale, spacing, component shapes), not as a code pattern — this is not Flutter, has no widget tree, no state, no build system
- `safepath_logo (1).svg`, `safepath_logo (1).dart` — the `.dart` file is a single generated constant (an SVG path/`CustomPainter`-style asset for the logo mark), not an application file with imports, routing, state management, or API-calling patterns. It has zero relevance as an analog for any of the files below.

`Glob` for `**/*.cs`, `**/*.csproj`, `**/*.sln` → no results. `Glob` for `**/pubspec.yaml`, `**/main.dart` (excluding the logo asset) → no results. `Grep` for `class.*Controller`, `router\.(get|post)`, `MediatR`, `IApplicationDbContext` → no results.

**Conclusion:** There is no prior codebase to mine for any of Phase 1's files. Every file below has **no analog** and must be built directly from RESEARCH.md's own Architecture Patterns / Code Examples sections (industry-standard Clean Architecture / JWT+refresh / Riverpod patterns, cross-cited against external sources in that document), not from an existing project convention.

---

## File Classification

All files are **new** (nothing is being modified — greenfield). Grouped by phase RESEARCH.md's Recommended Project Structure.

### Backend (ASP.NET Core Clean Architecture)

| New File | Role | Data Flow | Closest Analog | Match Quality |
|----------|------|-----------|-----------------|----------------|
| `backend/src/SafePath.Domain/Entities/User.cs` | model | CRUD | — none — | no analog |
| `backend/src/SafePath.Domain/Entities/Family.cs` | model | CRUD | — none — | no analog |
| `backend/src/SafePath.Domain/Entities/FamilyMember.cs` | model | CRUD | — none — | no analog |
| `backend/src/SafePath.Domain/Entities/FamilyInvitation.cs` | model | CRUD | — none — | no analog |
| `backend/src/SafePath.Domain/Entities/RefreshToken.cs` | model | CRUD | — none — | no analog |
| `backend/src/SafePath.Domain/Enums/Role.cs`, `PermissionLevel.cs`, `InvitationStatus.cs` | model | CRUD | — none — | no analog |
| `backend/src/SafePath.Application/Auth/RegisterCommand.cs` (+ handler, validator) | service | request-response | — none — | no analog |
| `backend/src/SafePath.Application/Auth/LoginCommand.cs` (+ handler, validator) | service | request-response | — none — | no analog |
| `backend/src/SafePath.Application/Auth/RefreshTokenCommand.cs` (+ handler) | service | request-response | — none — | no analog |
| `backend/src/SafePath.Application/Auth/LogoutCommand.cs` (+ handler) | service | request-response | — none — | no analog |
| `backend/src/SafePath.Application/Auth/ForgotPasswordCommand.cs` (+ handler) | service | event-driven (triggers email) | — none — | no analog |
| `backend/src/SafePath.Application/Auth/ResetPasswordCommand.cs` (+ handler, validator) | service | request-response | — none — | no analog |
| `backend/src/SafePath.Application/Families/CreateFamilyCommand.cs` (+ handler) | service | CRUD | — none — | no analog |
| `backend/src/SafePath.Application/Families/GenerateInviteCommand.cs` (+ handler) | service | CRUD | — none — | no analog |
| `backend/src/SafePath.Application/Families/RedeemInviteCommand.cs` (+ handler) | service | CRUD + event-driven (state machine transition) | — none — | no analog |
| `backend/src/SafePath.Application/Families/UpdateMemberPermissionsCommand.cs` (+ handler) | service | CRUD | — none — | no analog |
| `backend/src/SafePath.Application/Families/RemoveMemberCommand.cs` (+ handler) | service | CRUD | — none — | no analog |
| `backend/src/SafePath.Application/Common/Interfaces/IIdentityService.cs`, `ICurrentUserService.cs`, `IPasswordHasher.cs`, `IJwtTokenGenerator.cs`, `IEmailSender.cs`, `IApplicationDbContext.cs` | utility (interface/abstraction) | n/a | — none — | no analog |
| `backend/src/SafePath.Infrastructure/Persistence/ApplicationDbContext.cs` + `Migrations/` + `EntityConfigurations/` | model/config | CRUD | — none — | no analog |
| `backend/src/SafePath.Infrastructure/Identity/BCryptPasswordHasher.cs` | utility | transform | — none — | no analog |
| `backend/src/SafePath.Infrastructure/Identity/JwtTokenGenerator.cs` | utility | transform | — none — | no analog |
| `backend/src/SafePath.Infrastructure/ExternalServices/ResendEmailSender.cs` | service | request-response (external API call) | — none — | no analog |
| `backend/src/SafePath.Api/Controllers/AuthController.cs` | controller | request-response | — none — | no analog |
| `backend/src/SafePath.Api/Controllers/FamiliesController.cs` | controller | CRUD | — none — | no analog |
| `backend/src/SafePath.Api/Controllers/InvitesController.cs` | controller | CRUD | — none — | no analog |
| `backend/src/SafePath.Api/Middleware/` (JwtBearer config, global exception handler) | middleware | request-response | — none — | no analog |
| `backend/src/SafePath.Api/Program.cs` | config | n/a | — none — | no analog |
| `backend/tests/SafePath.Domain.Tests/*`, `SafePath.Application.Tests/*`, `SafePath.Api.IntegrationTests/*` | test | n/a | — none — | no analog |

### Mobile (Flutter)

| New File | Role | Data Flow | Closest Analog | Match Quality |
|----------|------|-----------|-----------------|----------------|
| `mobile/lib/core/theme/` (`ThemeData`/`ColorScheme` builder) | config | transform | Static HTML mockups (`SafePath AI - Standalone (1).html`, design-system board lines 39-134) — **visual token reference only**, not a code pattern | partial (design-token reference, not code) |
| `mobile/lib/core/router/` (routes for 9 screens) | route | n/a | — none — | no analog |
| `mobile/lib/core/network/` (dio client, auth interceptor, refresh-retry) | service | request-response | — none — | no analog |
| `mobile/lib/features/auth/` (welcome, register, login, forgot/reset password screens + Riverpod providers) | component/provider | request-response | Static HTML mockup screens F1-1 "Welcome" and F1-2 "Register" (`SafePath AI - Standalone (1).html` lines 140-185) — layout/visual reference only | partial (visual reference only) |
| `mobile/lib/features/family/` (role select, create circle, invite QR/code, accept/reject, permissions) | component/provider | CRUD | Static HTML mockup screens F1-3 through F1-7 (`SafePath AI - Standalone (1).html` lines 187-314+) — layout/visual reference only | partial (visual reference only) |
| `mobile/lib/shared_widgets/` (buttons, inputs, cards) | component | transform | Static HTML mockup component board (`SafePath AI - Standalone (1).html` lines 93-131 — button/card/status-chip styles) | partial (visual reference only) |
| `mobile/test/theme_test.dart` + at least one screen widget test | test | n/a | — none — | no analog |

**Summary:** 0 exact/role-match code analogs across 38 files. The HTML mockup files (and `safepath_logo (1).dart`) provide **design-token/visual reference only** for 6 mobile UI-related files — never a code-structure pattern (no Flutter widget tree, no Dart, no state management exists in them).

---

## Pattern Assignments

Since no codebase analog exists, every file's implementation pattern must come directly from **RESEARCH.md** itself. Below are the exact excerpts to copy from, reproduced here for the planner's convenience (all sourced from `.planning/phases/01-backend-auth-foundation/01-RESEARCH.md`).

### Backend: Identity abstraction + JWT generation

**Source:** RESEARCH.md, Architecture Patterns §1 (lines 236-265)

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
        var randomBytes = RandomNumberGenerator.GetBytes(64); // 64 bytes entropy floor
        return (Convert.ToBase64String(randomBytes), DateTime.UtcNow.AddDays(7));
    }
}
```

**Apply to:** `IJwtTokenGenerator.cs`, `JwtTokenGenerator.cs`, and as the reference shape for `IIdentityService`, `ICurrentUserService`, `IPasswordHasher`.

### Backend: Refresh token rotation with reuse detection

**Source:** RESEARCH.md, Architecture Patterns §2 (lines 268-297) — this is the concrete handler-body pattern for `RefreshTokenCommand`.

```csharp
public async Task<AuthResult> Handle(RefreshTokenCommand cmd, CancellationToken ct)
{
    var existing = await _db.RefreshTokens.SingleOrDefaultAsync(t => t.Token == cmd.RefreshToken, ct);
    if (existing is null) return AuthResult.Invalid();
    if (existing.IsRevoked)
    {
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

**Apply to:** `RefreshTokenCommand.cs` handler exactly; `LogoutCommand.cs` reuses the same "mark `IsRevoked = true`" write.

### Backend: Family invitation entity (expiring share-code state machine)

**Source:** RESEARCH.md, Architecture Patterns §3 (lines 300-319)

```csharp
public class FamilyInvitation
{
    public Guid Id { get; set; }
    public Guid FamilyId { get; set; }
    public string Code { get; set; } = default!;
    public string? InviteeLabel { get; set; }
    public string? InviteeEmail { get; set; }
    public Guid CreatedByUserId { get; set; }
    public DateTime ExpiresAt { get; set; }
    public InvitationStatus Status { get; set; }
    public Guid? AcceptedByUserId { get; set; }
}
```

**Apply to:** `FamilyInvitation.cs`, and as the model for `GenerateInviteCommand`/`RedeemInviteCommand` handlers (24h expiry, single-use, `Status` transitions Pending→Accepted/Declined/Expired/Revoked).

### Backend: Password hashing

**Source:** RESEARCH.md, Code Examples (lines 391-398)

```csharp
// SafePath.Infrastructure/Identity/BCryptPasswordHasher.cs
public class BCryptPasswordHasher : IPasswordHasher
{
    public string Hash(string password) => BCrypt.Net.BCrypt.HashPassword(password, workFactor: 12);
    public bool Verify(string password, string hash) => BCrypt.Net.BCrypt.Verify(password, hash);
}
```

**Apply to:** `BCryptPasswordHasher.cs` verbatim.

### Backend: Family creation + first-member (Guardian) transaction

**Source:** RESEARCH.md, Code Examples (lines 402-415)

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

**Apply to:** `CreateFamilyCommand.cs` handler verbatim.

### Backend: Password-reset email dispatch (no-enumeration pattern)

**Source:** RESEARCH.md, Code Examples (lines 418-433)

```csharp
public async Task Handle(ForgotPasswordCommand cmd, CancellationToken ct)
{
    var user = await _db.Users.SingleOrDefaultAsync(u => u.Email == cmd.Email, ct);
    if (user is null) return; // don't reveal whether the email exists

    var token = Convert.ToBase64String(RandomNumberGenerator.GetBytes(32));
    _db.PasswordResetTokens.Add(new PasswordResetToken {
        UserId = user.Id, TokenHash = _hasher.Hash(token), // store hashed, never the raw token
        ExpiresAt = DateTime.UtcNow.AddHours(24)
    });
    await _db.SaveChangesAsync(ct);

    var resetLink = $"{_config["App:BaseUrl"]}/reset-password?token={token}&email={user.Email}";
    await _emailSender.SendAsync(user.Email, "Reset your SafePath AI password", BuildResetEmailBody(resetLink));
}
```

**Apply to:** `ForgotPasswordCommand.cs` handler verbatim; the "hash before storing, never log the raw token" rule also applies to `ResetPasswordCommand.cs`'s verification side.

### Mobile: Design tokens (colors, type, spacing) — visual reference only, not code

**Source:** `SafePath AI - Standalone (1).html`, design-system board (lines 55-90)

Key literal tokens to port into `ThemeData`/`ColorScheme`:
- Colors: Deep Teal `#0C3A3F`, Primary `#15807C`, Safe `#2F9E6B`, Caution `#C98A2B`, SOS Red `#DE3B40` (reserved exclusively for SOS/emergency states — never routine warnings), App BG `#ECF0EF`, Ink `#15302E`, Surface `#FFFFFF`
- Type: Manrope (weights 400-800) for body/display, JetBrains Mono for mono labels/captions — matches `google_fonts` package already selected in Standard Stack
- Spacing: 4pt base scale (4/8/12/16/24/32)
- Component shapes: 14-18px border radius on buttons/cards/inputs (see lines 95-116 for exact button/card/status-chip treatments)

**Apply to:** `mobile/lib/core/theme/` `ThemeData` construction (DESIGN-01). This is a **visual/token reference**, not a Flutter code pattern — there is no Dart/widget code in the HTML file to copy structurally.

---

## Shared Patterns

### Custom identity abstraction (not ASP.NET Core Identity)
**Source:** RESEARCH.md Architecture Patterns §1, Don't Hand-Roll table
**Apply to:** All of `SafePath.Domain/Entities/User.cs`, `Application/Common/Interfaces/*`, `Infrastructure/Identity/*`, `Api/Controllers/AuthController.cs` — plain POCO `User` entity, no framework base class; auth logic lives entirely behind `IIdentityService`/`ICurrentUserService`/`IPasswordHasher`/`IJwtTokenGenerator` interfaces implemented in Infrastructure.

### Server-side authorization re-check on every family-scoped endpoint (IDOR prevention)
**Source:** RESEARCH.md, Anti-Patterns to Avoid + Security Domain (Known Threat Patterns table, "Broken access control across family boundaries")
**Apply to:** `FamiliesController.cs`, `InvitesController.cs`, and every handler in `Application/Families/` — never trust a client-supplied `familyId` or role claim; always independently verify the caller's own `FamilyMember` row and role/permission server-side. Do not rely on Postgres RLS as the primary enforcement (RESEARCH.md Pitfall 5 — this project's backend connects with a trusted service-role connection string, so RLS would not be respected if relied on alone).

### FluentValidation on all commands
**Source:** RESEARCH.md Standard Stack ("Supporting" table) + Security Domain V5
**Apply to:** `RegisterCommand`, `LoginCommand`, `ResetPasswordCommand`, `GenerateInviteCommand`/`RedeemInviteCommand` — validators live in Application layer, never inline in Controllers.

### Cryptographically secure randomness — never `Guid.NewGuid()`
**Source:** RESEARCH.md Don't Hand-Roll table, Security Domain V6
**Apply to:** `JwtTokenGenerator.GenerateRefreshToken()`, `ForgotPasswordCommand`'s reset-token generation, `GenerateInviteCommand`'s invite-code/opaque-token generation — always `RandomNumberGenerator.GetBytes()`.

### flutter_secure_storage for tokens — never SharedPreferences
**Source:** RESEARCH.md Anti-Patterns to Avoid (project-level Pitfall 7 restated)
**Apply to:** `mobile/lib/core/network/` (dio auth interceptor reads/writes access+refresh tokens exclusively via `flutter_secure_storage`).

---

## No Analog Found

Every file in this phase has no analog, per the File Classification tables above. This section is intentionally the primary finding of this document rather than an exception list: **PATTERNS.md's role for this phase is to confirm zero-analog status and redirect the planner to RESEARCH.md's own Architecture Patterns / Code Examples sections**, which are the only available reference material.

| File Group | Role | Data Flow | Reason |
|------------|------|-----------|--------|
| All 26 backend files | controller/service/model/middleware/config/test | CRUD, request-response, event-driven | No backend code exists anywhere in the repo — greenfield |
| All 12 mobile files | component/route/service/provider/test | request-response, CRUD, transform | No Flutter/Dart application code exists anywhere in the repo — greenfield (only a static-HTML visual mockup and an unrelated logo-asset `.dart` file) |

## Metadata

**Analog search scope:** entire repository (`git ls-files`, `Glob` for `*.cs`/`*.csproj`/`*.sln`/`pubspec.yaml`/`*.dart`, `Grep` for `class.*Controller`, `router\.(get|post)`, `MediatR`, `IApplicationDbContext`)
**Files scanned:** all tracked files in the repo (see `git ls-files` output — planning docs, two HTML design mockups, one SVG + one generated `.dart` logo asset, one docx brief; zero application source files)
**Pattern extraction date:** 2026-07-06
**Primary pattern source for planner:** `.planning/phases/01-backend-auth-foundation/01-RESEARCH.md` — Architecture Patterns §1-3 (lines 230-319) and Code Examples (lines 388-434) sections, reproduced above as concrete excerpts
