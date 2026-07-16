---
phase: 02-real-time-location-history-privacy
plan: 13
subsystem: backend
tags: [profile, storage, supabase, imagesharp, ef-migration, security]

requires:
  - phase: 01-backend-auth-foundation
    provides: Supabase-authenticated backend current-user identity and Users table
  - phase: 02-real-time-location-history-privacy
    provides: family membership and privacy sharing gates used by later profile URL propagation
provides:
  - User profile fields for display name and avatar object path state
  - Backend-mediated Supabase Storage client for avatar upload, delete, and signed URL creation
  - Server-side image validation and JPEG re-encoding for avatar uploads
affects: [profile, live-map-identity, privacy, storage]

tech-stack:
  added: [SixLabors.ImageSharp 4.0.0]
  patterns: [Application interface with Infrastructure implementation, typed HttpClient for Supabase Storage, ImageSharp identify-before-load validation]

key-files:
  created:
    - backend/src/SafePath.Application/Common/Interfaces/IProfileImageStorage.cs
    - backend/src/SafePath.Application/Common/Interfaces/IProfileImageValidator.cs
    - backend/src/SafePath.Infrastructure/Storage/SupabaseProfileImageStorage.cs
    - backend/src/SafePath.Infrastructure/Storage/ImageSharpProfileImageValidator.cs
    - backend/tests/SafePath.Application.Tests/Profile/ImageValidationTests.cs
  modified:
    - .gitignore
    - backend/src/SafePath.Api/appsettings.json
    - backend/src/SafePath.Domain/Entities/User.cs
    - backend/src/SafePath.Infrastructure/DependencyInjection.cs
    - backend/src/SafePath.Infrastructure/Persistence/EntityConfigurations/UserConfiguration.cs
    - backend/src/SafePath.Infrastructure/Persistence/Migrations/ApplicationDbContextModelSnapshot.cs
    - backend/src/SafePath.Infrastructure/SafePath.Infrastructure.csproj

key-decisions:
  - "Used the existing Supabase Storage bucket `avatar` via configurable `Supabase:AvatarBucket`, instead of requiring a second bucket named `avatars`."
  - "Kept avatar object paths traversal-proof as `avatars/{serverGuid}/avatar.jpg`, with the bucket name separate and configurable."
  - "Used ImageSharp 4.0.0 as planned; local builds require an uncommitted Six Labors license file or `SIXLABORS_LICENSE_KEY`."

patterns-established:
  - "Profile image storage is backend-only through IProfileImageStorage; mobile never receives the service-role key."
  - "Avatar uploads must be validated by magic bytes, ImageSharp Identify dimensions, full decode, and JPEG re-encode before Storage writes."

requirements-completed: [PROFILE-01, PROFILE-02, PROFILE-03]

coverage:
  - id: D1
    description: "Users table has nullable DisplayName, ProfileImagePath, and ProfileUpdatedAt columns applied to live Supabase Postgres."
    requirement: PROFILE-01
    verification:
      - kind: integration
        ref: "dotnet ef database update --project backend/src/SafePath.Infrastructure --startup-project backend/src/SafePath.Api"
        status: pass
      - kind: other
        ref: "dotnet ef migrations list --project backend/src/SafePath.Infrastructure --startup-project backend/src/SafePath.Api | Select-String AddUserProfileFields"
        status: pass
    human_judgment: false
  - id: D2
    description: "Backend can upload, delete, and create signed avatar URLs against the private Supabase Storage bucket."
    requirement: PROFILE-01
    verification:
      - kind: integration
        ref: "live Storage smoke: upload/sign/delete disposable object in bucket avatar"
        status: pass
      - kind: other
        ref: "dotnet build backend/SafePath.sln"
        status: pass
    human_judgment: false
  - id: D3
    description: "Server rejects non-image, oversized, over-dimension, and polyglot avatar payloads, and re-encodes accepted images to JPEG."
    requirement: PROFILE-02
    verification:
      - kind: unit
        ref: "backend/tests/SafePath.Application.Tests/Profile/ImageValidationTests.cs"
        status: pass
    human_judgment: false
  - id: D4
    description: "Profile image delete support targets the same deterministic object path used by upload/replace."
    requirement: PROFILE-03
    verification:
      - kind: integration
        ref: "live Storage smoke: DELETE /storage/v1/object/avatar with deterministic object path"
        status: pass
    human_judgment: false

duration: 48min
completed: 2026-07-13
status: complete
---

# Phase 02 Plan 13: Backend Profile Storage Foundation Summary

**Backend avatar storage foundation with live user-profile schema migration, private Supabase Storage access, and ImageSharp JPEG re-encoding.**

## Performance

- **Duration:** 48 min
- **Started:** 2026-07-13T14:52:00Z
- **Completed:** 2026-07-13T15:39:03Z
- **Tasks:** 3 completed
- **Files modified:** 14

## Accomplishments

- Added nullable `DisplayName`, `ProfileImagePath`, and `ProfileUpdatedAt` fields to `User`, configured EF max lengths, generated `AddUserProfileFields`, and applied it to the live Supabase Postgres database.
- Added `IProfileImageStorage` and `SupabaseProfileImageStorage` for backend-only avatar upload/upsert, delete, and signed URL creation against the private `avatar` bucket.
- Added `IProfileImageValidator` and `ImageSharpProfileImageValidator` with 5 MB size cap, JPEG/PNG/WebP magic-byte sniffing, `Image.Identify` dimension cap, full decode, and JPEG re-encode.
- Added focused ImageValidation tests covering accepted JPEG/PNG/WebP, non-image rejection, oversize rejection, dimension-cap rejection, and polyglot trailing-byte removal.

## Task Commits

1. **Task 1: Extend User entity with profile fields and apply EF migration** - `3c88305` (feat)
2. **Task 2: Backend-mediated Supabase Storage client over raw REST** - `754c582` (feat)
3. **Task 3 RED: Image validation tests** - `1996489` (test)
4. **Task 3 GREEN: Image validation implementation** - `af5feb8` (feat)

**Plan metadata:** recorded in final docs commit for this plan.

## Files Created/Modified

- `.gitignore` - Ignores local `sixlabors.lic` license files.
- `backend/src/SafePath.Api/appsettings.json` - Adds empty `Supabase:ServiceRoleKey` placeholder and `Supabase:AvatarBucket` defaulting to `avatar`.
- `backend/src/SafePath.Application/Common/Interfaces/IProfileImageStorage.cs` - Application storage abstraction with deterministic avatar object path helper.
- `backend/src/SafePath.Application/Common/Interfaces/IProfileImageValidator.cs` - Application validator abstraction and `ValidatedImage` result record.
- `backend/src/SafePath.Domain/Entities/User.cs` - Adds nullable profile fields.
- `backend/src/SafePath.Infrastructure/DependencyInjection.cs` - Registers profile image storage typed HttpClient and validator singleton.
- `backend/src/SafePath.Infrastructure/Persistence/EntityConfigurations/UserConfiguration.cs` - Adds max lengths for display name and profile image path.
- `backend/src/SafePath.Infrastructure/Persistence/Migrations/20260713152701_AddUserProfileFields.cs` - Adds/drops the three `Users` profile columns.
- `backend/src/SafePath.Infrastructure/Persistence/Migrations/ApplicationDbContextModelSnapshot.cs` - Captures profile fields in EF model snapshot.
- `backend/src/SafePath.Infrastructure/SafePath.Infrastructure.csproj` - Adds `SixLabors.ImageSharp` 4.0.0.
- `backend/src/SafePath.Infrastructure/Storage/SupabaseProfileImageStorage.cs` - Supabase Storage REST client.
- `backend/src/SafePath.Infrastructure/Storage/ImageSharpProfileImageValidator.cs` - Image validation and JPEG re-encode implementation.
- `backend/tests/SafePath.Application.Tests/Profile/ImageValidationTests.cs` - Focused image validation test coverage.

## Decisions Made

- Used `Supabase:AvatarBucket` to avoid hardcoding bucket naming and to support the existing singular `avatar` bucket.
- Kept the object path convention as `avatars/{userId}/avatar.jpg`, with `userId` formatted from a server-side `Guid` and no client-controlled path segments.
- Used an uncommitted local Six Labors sample license file for verification because ImageSharp 4.0.0 enforces a build-time license; future CI/local builds need `sixlabors.lic` or `SIXLABORS_LICENSE_KEY`.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Used existing singular Supabase Storage bucket**
- **Found during:** Task 2
- **Issue:** The original plan required a private bucket named `avatars`, but live Supabase setup has a private bucket named `avatar`.
- **Fix:** Added configurable `Supabase:AvatarBucket` defaulting to `avatar`, and verified live upload/sign/delete against that bucket.
- **Files modified:** `backend/src/SafePath.Api/appsettings.json`, `backend/src/SafePath.Infrastructure/Storage/SupabaseProfileImageStorage.cs`
- **Verification:** Live Storage smoke passed: upload/sign/delete disposable object in bucket `avatar`.
- **Committed in:** `754c582`

**2. [Rule 3 - Blocking] Handled ImageSharp 4.0.0 build-time license enforcement**
- **Found during:** Task 3 RED
- **Issue:** ImageSharp 4.0.0 fails builds without `sixlabors.lic`, `SixLaborsLicenseFile`, or `SixLaborsLicenseKey`.
- **Fix:** Downloaded the official public sample license locally for verification and added `sixlabors.lic` to `.gitignore`; no license file or key was committed.
- **Files modified:** `.gitignore`
- **Verification:** `dotnet build backend/SafePath.sln` and ImageValidation tests pass with the local uncommitted license file present.
- **Committed in:** `1996489`

---

**Total deviations:** 2 auto-fixed (2 blocking)
**Impact on plan:** No scope creep. The backend works with the actual Supabase setup and preserves the planned private-bucket/server-mediated security posture.

## Issues Encountered

- Initial Task 1 migration scaffold was blocked by a running `SafePath.Api` process locking backend output DLLs. The process was stopped, then migration scaffolding, database update, and build succeeded.
- Supabase bucket probe for `avatars` returned `Bucket not found`; user clarified the real bucket name is `avatar`.
- ImageSharp 4.0.0 requires build-time license material. The license file is intentionally local/ignored and not part of git history.

## User Setup Required

None for Supabase Storage in this repo now: `backend/.env` already contains `Supabase__ServiceRoleKey`, and the private `avatar` bucket exists.

For ImageSharp 4.0.0 builds on another machine or CI, provide a Six Labors license via an uncommitted `sixlabors.lic` file or `SIXLABORS_LICENSE_KEY`.

## Verification

- `dotnet ef database update --project backend/src/SafePath.Infrastructure --startup-project backend/src/SafePath.Api` - passed and applied `20260713152701_AddUserProfileFields`.
- `dotnet ef migrations list --project backend/src/SafePath.Infrastructure --startup-project backend/src/SafePath.Api | Select-String AddUserProfileFields` - passed.
- Migration content inspection - passed: `AddColumn` count 3; table `Users`; fields `DisplayName`, `ProfileImagePath`, `ProfileUpdatedAt`.
- `dotnet build backend/SafePath.sln` - passed.
- `dotnet test backend/tests/SafePath.Application.Tests/SafePath.Application.Tests.csproj --filter "FullyQualifiedName~ImageValidation"` - passed, 7/7.
- Live Supabase Storage smoke against `avatar` bucket - passed: upload, signed URL creation, delete.
- Secret scan for `appsettings.json` - passed: `ServiceRoleKey` empty, no `eyJ` or `sb_secret` pattern.

## Known Stubs

None. The empty `Supabase:ServiceRoleKey` value in `appsettings.json` is an intentional env-sourced secret placeholder and does not flow to UI rendering.

## Threat Flags

None beyond the plan threat model. The new upload/storage trust boundaries were already in the plan and mitigated by deterministic server-derived object paths, private Storage, service-role backend mediation, and ImageSharp validation/re-encode.

## Self-Check: PASSED

- Created files exist.
- Task commits exist: `3c88305`, `754c582`, `1996489`, `af5feb8`.
- Verification commands passed.

## Next Phase Readiness

Ready for 02-14 to add profile endpoints and signed profile image URL propagation using these interfaces. 02-14 should consume `IProfileImageValidator` before `IProfileImageStorage.UploadAvatarAsync`, persist only `ProfileImagePath`, and continue using the existing family-membership and sharing gates before exposing signed URLs.

---
*Phase: 02-real-time-location-history-privacy*
*Completed: 2026-07-13*
