---
phase: 01-backend-auth-foundation
plan: 12
subsystem: family
tags: [family-circle, invites, authorization, integrity]

requires:
  - phase: 01-backend-auth-foundation
    provides: CreateFamilyCommand, RedeemInviteCommand, Guardian authorization
provides:
  - "Single-active-family invariant enforced in create and redeem workflows"
  - "409 conflict behavior for already-in-family create/join attempts"
  - "Guardian invite revocation endpoint and command"
affects: [02-real-time-location]

key-files:
  created:
    - backend/src/SafePath.Application/Families/AlreadyInAnotherFamilyException.cs
    - backend/src/SafePath.Application/Families/RevokeInviteCommand.cs
    - backend/tests/SafePath.Application.Tests/Families/RevokeInviteCommandTests.cs
    - backend/tests/SafePath.Application.Tests/Families/SingleFamilyInvariantTests.cs
  modified:
    - backend/src/SafePath.Api/Controllers/FamiliesController.cs
    - backend/src/SafePath.Api/Controllers/InvitesController.cs
    - backend/src/SafePath.Application/DependencyInjection.cs
    - backend/src/SafePath.Application/Families/CreateFamilyCommand.cs
    - backend/src/SafePath.Application/Families/RedeemInviteCommand.cs
    - backend/tests/SafePath.Application.Tests/Families/CreateFamilyCommandTests.cs
    - backend/tests/SafePath.Application.Tests/Families/ListMyFamiliesQueryTests.cs
    - mobile/lib/features/family/data/family_api.dart

requirements-completed: [FAM-01, FAM-02, FAM-03, FAM-04]
completed: 2026-07-10
status: complete
---

# Phase 01 Plan 12: Family Invariant and Invite Revocation Summary

## Accomplishments

- Enforced the Phase 1 rule that a user has at most one active family membership. Creating a second family or redeeming an invite while already active in a family now returns a conflict instead of producing ambiguous app state.
- Updated invite redemption to reactivate a historical inactive membership for the same family/user instead of creating duplicates.
- Added Guardian-only invite revocation through a backend command and route.
- Updated mobile family error mapping so backend 409 validation conflicts surface as user-readable workflow errors.
- Added deterministic command tests for duplicate-family prevention and invite revocation.

## Verification

- `dotnet test tests\SafePath.Application.Tests\SafePath.Application.Tests.csproj`
- Full repository verification tracked in the final audit-fix run.

## Remaining Notes

Multi-family switching remains intentionally out of Phase 1 scope. The invariant protects the current single-family UI until a later phase explicitly designs switching.
