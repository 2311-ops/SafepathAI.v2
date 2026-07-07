---
phase: 01-backend-auth-foundation
plan: 01
subsystem: backend-auth
tags: [aspnet-core, clean-architecture, jwt, bcrypt, ef-core, npgsql, supabase, xunit]

# Dependency graph
requires: []
provides:
  - Clean Architecture backend solution (`backend/SafePath.sln` — Domain/Application/Infrastructure/Api)
  - Auth API: POST /auth/register, /auth/login, /auth/refresh, /auth/logout (JWT HS256 + refresh-token rotation)
  - EF Core `ApplicationDbContext` with `Users` + `RefreshTokens`, `InitialAuth` migration applied to Supabase
  - BCrypt (work factor 12) password hashing behind `IPasswordHasher`
  - Login rate limiting + generic 401s in Program.cs
affects: [01-03, 01-04, 01-05, 01-06, 01-07]

# Tech tracking
tech-stack:
  added: [ASP.NET Core 9 Web API, EF Core 9 + Npgsql, BCrypt.Net-Next, xUnit + WebApplicationFactory, Microsoft.EntityFrameworkCore.Sqlite (tests only)]
  patterns:
    - "Clean Architecture: Application layer owns interfaces (IApplicationDbContext, IPasswordHasher, IJwtTokenGenerator, ICurrentUserService); Infrastructure implements; Api composes via AddApplication()/AddInfrastructure()"
    - "Refresh tokens are single-use: rotation on every /auth/refresh, reuse detection revokes the whole token family"
    - "Secrets (connection string, Jwt:Key) live exclusively in dotnet user-secrets — appsettings.json ships placeholders only"
    - "Integration tests run against SQLite in-memory via CustomWebApplicationFactory — no live-DB dependency in CI"

key-files:
  created:
    - backend/SafePath.sln
    - backend/src/SafePath.Domain/Entities/User.cs
    - backend/src/SafePath.Domain/Entities/RefreshToken.cs
    - backend/src/SafePath.Domain/Enums/Role.cs
    - backend/src/SafePath.Application/Auth/RegisterCommand.cs
    - backend/src/SafePath.Application/Auth/LoginCommand.cs
    - backend/src/SafePath.Application/Auth/RefreshTokenCommand.cs
    - backend/src/SafePath.Application/Auth/LogoutCommand.cs
    - backend/src/SafePath.Infrastructure/Persistence/ApplicationDbContext.cs
    - backend/src/SafePath.Infrastructure/Persistence/Migrations/20260707083634_InitialAuth.cs
    - backend/src/SafePath.Infrastructure/Identity/BCryptPasswordHasher.cs
    - backend/src/SafePath.Infrastructure/Identity/JwtTokenGenerator.cs
    - backend/src/SafePath.Api/Controllers/AuthController.cs
    - backend/src/SafePath.Api/Program.cs
    - backend/tests/SafePath.Application.Tests/Auth/RegisterCommandTests.cs
    - backend/tests/SafePath.Api.IntegrationTests/AuthEndpointsTests.cs
  modified: []

key-decisions:
  - "Integration tests use SQLite in-memory (CustomWebApplicationFactory) instead of a live Supabase test schema — plan Task 3 left the test-DB choice to discretion; this removes network flakiness and keeps the suite runnable offline"
  - "Supabase connection goes through the Session Pooler (aws-0-eu-west-1.pooler.supabase.com:5432) — IPv4-only local network; direct connection unavailable without the IPv4 add-on (documented fallback in the stack brief)"
  - "Backend targets net9.0 (installed SDK) rather than the stack brief's .NET 10 recommendation — carried as a known deviation to revisit before Azure deployment"
  - "Post-review hardening committed as 313053b: enum-as-string JSON serialization, UserSecretsId in csproj, SQLite test factory"

patterns-established:
  - "TDD RED→GREEN commit pairs per plan (test(01-01) 3622abf → feat(01-01) 28b73aa)"
  - "No secret ever committed: verified via git log -S over full history; user-secrets holds ConnectionStrings:DefaultConnection and Jwt:Key"

requirements-completed: [AUTH-01, AUTH-02, AUTH-03, AUTH-05]

coverage:
  - id: A1
    description: "Register/login/refresh/logout command handlers behave per spec (hashing, rotation, reuse detection, generic 401)"
    requirement: "AUTH-01, AUTH-02, AUTH-03"
    verification:
      - kind: unit
        ref: "backend/tests/SafePath.Application.Tests — 7/7 pass (dotnet test, 2026-07-07)"
        status: pass
    human_judgment: false
  - id: A2
    description: "Real HTTP pipeline round-trip: register 200 + persisted user, login 200, wrong password 401"
    requirement: "AUTH-01, AUTH-02"
    verification:
      - kind: integration
        ref: "backend/tests/SafePath.Api.IntegrationTests/AuthEndpointsTests.cs — 2/2 pass against SQLite in-memory factory"
        status: pass
    human_judgment: false
  - id: A3
    description: "InitialAuth migration applied to Supabase; Users + RefreshTokens tables exist"
    requirement: "AUTH-05"
    verification:
      - kind: other
        ref: "dotnet ef migrations list (live connection) shows 20260707083634_InitialAuth applied (read from __EFMigrationsHistory, 2026-07-07)"
        status: pass
    human_judgment: false
  - id: A4
    description: "No secret committed in any tracked file"
    requirement: "AUTH-05"
    verification:
      - kind: other
        ref: "git log --all -S '<password fragment>' returns empty; appsettings.json DefaultConnection is empty, Jwt:Key is a placeholder"
        status: pass
    human_judgment: false

# Metrics
duration: ~90min (across two sessions; closed out on resume)
completed: 2026-07-07
status: complete
---

# Phase 01 Plan 01: Backend Auth Slice Summary

**Clean Architecture ASP.NET Core auth backend — register/login/refresh/logout with BCrypt-12 hashing, HS256 JWTs, single-use rotating refresh tokens with reuse detection, login rate limiting, and the `InitialAuth` EF migration applied to Supabase Postgres.**

## Accomplishments
- Scaffolded `backend/SafePath.sln` with Domain / Application / Infrastructure / Api projects plus three test projects (TDD RED commit `3622abf`, GREEN commit `28b73aa`)
- `AuthController` exposes `POST /auth/register|login|refresh|logout`; JwtBearer pinned to HS256 with issuer/audience/lifetime validation; per-IP rate limiting on login
- `ApplicationDbContext` (Users, RefreshTokens) with `InitialAuth` migration — **verified applied to the live Supabase database** via `__EFMigrationsHistory`
- Secrets hygiene: connection string + JWT signing key in `dotnet user-secrets` (UserSecretsId `6e949a47…`); full-history grep confirms no secret was ever committed
- Post-review hardening (`313053b`): SQLite in-memory `CustomWebApplicationFactory` (integration tests no longer touch the live DB), enum-as-string JSON, `UserSecretsId` in csproj

## Deviations
- **Test DB:** SQLite in-memory instead of a Supabase test schema (allowed by plan Task 3 discretion; documented above)
- **Framework:** net9.0 instead of the stack brief's .NET 10 — revisit before Azure deployment
- **Connection:** Supabase Session Pooler (IPv4) instead of direct 5432 — matches the stack brief's documented fallback

## Verification evidence (2026-07-07, on resume closeout)
- `dotnet test SafePath.sln` → 9/9 pass (7 Application unit, 2 Api integration)
- `dotnet ef migrations list` (live) → `20260707083634_InitialAuth` applied, no pending
- Working tree scrubbed: plaintext connection string removed from `appsettings.json` before it was ever committed

## Task Commits
- `3622abf` test(01-01): scaffold xUnit projects and write failing auth-command tests (RED)
- `28b73aa` feat(01-01): implement auth slice — Domain/Application/Infrastructure/Api (GREEN)
- `313053b` fix(01-01): review fixes — sqlite in-memory test factory, user-secrets id, enum-as-string json
