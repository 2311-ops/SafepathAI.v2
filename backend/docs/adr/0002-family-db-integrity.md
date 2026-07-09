# ADR 0002: Family Database Integrity and Supabase Data API Posture

## Status

Accepted

## Context

Family membership and invitations were initially protected by application checks only. The review identified missing foreign keys, missing cascade behavior, and an implicit Supabase Row Level Security posture for tables in the public schema.

Supabase's Data API access is controlled in two layers: grants decide whether database roles such as `anon` and `authenticated` can reach an object, and RLS policies decide which rows are visible once access exists. The backend currently uses a trusted server-side connection and does not expose family tables directly to the mobile Supabase client.

## Decision

`FamilyMembers.FamilyId` and `FamilyInvitations.FamilyId` are foreign keys to `Families.Id` with cascade delete. The migration pre-cleans genuinely orphaned child rows before adding the constraints so it can apply to a live database that previously relied on app-only integrity.

Supabase RLS is enabled on `Families`, `FamilyMembers`, and `FamilyInvitations` as defense in depth. Public Data API access is denied by revoking table privileges from `anon` and `authenticated`; the ASP.NET Core backend remains the authoritative access path and enforces authorization through `IFamilyAuthorizationService`.

`UserId` columns are intentionally not foreign-keyed to `auth.users` because that table is owned by Supabase Auth and mirrored asynchronously into `public."Users"` by the signup trigger.

## Consequences

Deleting a family deletes its member and invitation rows at the database level, and handlers also remove child rows explicitly for deterministic tests. Direct mobile Data API reads or writes against family tables are not supported in Phase 1. If a future phase exposes these tables through Supabase clients, it must add explicit grants and row-scoped RLS policies before shipping.
