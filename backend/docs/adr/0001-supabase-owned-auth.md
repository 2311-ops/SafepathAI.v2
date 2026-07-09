# ADR 0001: Supabase-Owned Authentication

## Status

Accepted

## Context

Phase 1 originally planned custom backend JWT authentication, including backend auth endpoints, password material, refresh-token storage, and custom token generation. The implementation pivoted to Supabase Auth: the mobile app performs email registration, login, logout, password reset, token refresh, and native Google Sign-In directly through Supabase, while the backend validates Supabase-issued JWTs as a resource server.

The migration `SyncSupabaseUsersAndDropLegacyAuthColumns` intentionally removed the old backend-owned `RefreshTokens` table and `PasswordHash` column. The backend `Users` table remains a domain mirror populated from Supabase Auth for profile and role lookup.

## Decision

Supabase owns the complete authentication lifecycle for Phase 1:

- email/password registration
- login and logout
- password reset via Supabase recovery links
- session persistence and refresh
- native Google Sign-In via Supabase `signInWithIdToken`
- email verification handled by Supabase Auth

The ASP.NET Core backend never mints, stores, or refreshes credentials. It only validates Supabase-issued JWTs using issuer, audience, lifetime, and subject validation with inbound claim mapping disabled. Domain authorization is not derived from JWT user metadata; family authorization is checked server-side against `FamilyMembers`, and `/me` resolves the domain role from the mirrored `Users` table.

## Consequences

Phase 1 auth requirements are satisfied by Supabase-issued sessions rather than backend-minted access/refresh tokens. Backend auth endpoints and custom token models are dead artifacts and must not be reintroduced unless a future ADR reverses this decision.

Local backend configuration comes from `backend/.env` or host environment variables. Real `.env` files and Google OAuth client secret JSON files remain untracked; `backend/.env.example` is the only committed template.

## Verification

The source tree should contain no custom-JWT artifacts such as `AuthController`, `RefreshToken`, `JwtTokenGenerator`, `IJwtTokenGenerator`, `PasswordResetToken`, `IEmailSender`, `ResendEmailSender`, or `AuthResult.cs` outside documentation that explains this decision.
