---
phase: 01-backend-auth-foundation
plan: 13
subsystem: family-database
tags: [ownership, database, ef-core, rls, authorization]

requires:
  - phase: 01-backend-auth-foundation
    provides: Family authorization service and family persistence model
provides:
  - "Guardian ownership transfer workflow"
  - "Guardian delete-family workflow"
  - "FamilyMembers/FamilyInvitations foreign keys with cascade cleanup"
  - "Filtered unique active-membership index"
  - "RLS/Data API deny posture documented for backend-owned family tables"
affects: [02-real-time-location, 03-sos-fast-path]

key-files:
  created:
    - backend/docs/adr/0002-family-db-integrity.md
    - backend/src/SafePath.Application/Families/DeleteFamilyCommand.cs
    - backend/src/SafePath.Application/Families/TransferOwnershipCommand.cs
    - backend/src/SafePath.Infrastructure/Persistence/Migrations/20260709213600_AddFamilyForeignKeys.cs
    - backend/src/SafePath.Infrastructure/Persistence/Migrations/20260709213600_AddFamilyForeignKeys.Designer.cs
    - backend/tests/SafePath.Application.Tests/Families/DeleteFamilyCommandTests.cs
    - backend/tests/SafePath.Application.Tests/Families/TransferOwnershipCommandTests.cs
  modified:
    - backend/src/SafePath.Api/Controllers/FamiliesController.cs
    - backend/src/SafePath.Application/DependencyInjection.cs
    - backend/src/SafePath.Infrastructure/Persistence/EntityConfigurations/FamilyInvitationConfiguration.cs
    - backend/src/SafePath.Infrastructure/Persistence/EntityConfigurations/FamilyMemberConfiguration.cs
    - backend/src/SafePath.Infrastructure/Persistence/Migrations/ApplicationDbContextModelSnapshot.cs

requirements-completed: [FAM-01, FAM-03, FAM-04, FAM-05]
completed: 2026-07-10
status: complete
---

# Phase 01 Plan 13: Ownership, Delete, and Database Integrity Summary

## Accomplishments

- Added Guardian-only transfer ownership workflow. The current owner can promote an active member to Guardian/Owner and demote themselves to Guardian.
- Added Guardian-only delete-family workflow using existing authorization checks and cascade-backed cleanup.
- Added database integrity hardening: family foreign keys for members/invitations, orphan cleanup in the migration, cascade delete, and a filtered unique index preventing multiple active family memberships per user.
- Documented the database integrity and RLS/Data API posture in `backend/docs/adr/0002-family-db-integrity.md`.
- Added deterministic command tests for ownership transfer and delete behavior.

## Verification

- `dotnet test tests\SafePath.Application.Tests\SafePath.Application.Tests.csproj`
- Full repository verification tracked in the final audit-fix run.

## Remaining Notes

RLS is configured as defense in depth for Phase 1 backend-owned tables. Family authorization still lives in application handlers so mobile clients do not depend on direct table access.
