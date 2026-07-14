---
phase: 02-real-time-location-history-privacy
reviewed: 2026-07-14T00:00:00Z
depth: standard
files_reviewed: 4
files_reviewed_list:
  - backend/src/SafePath.Application/Location/LocationDtos.cs
  - backend/src/SafePath.Application/Location/GetLiveLocationsQuery.cs
  - backend/tests/SafePath.Application.Tests/Location/GetLiveLocationsQueryTests.cs
  - mobile/test/features/location/location_controller_test.dart
findings:
  critical: 1
  warning: 2
  info: 2
  total: 5
status: issues_found
---

# Phase 02: Code Review Report (Gap Closure — Plan 02-18)

**Reviewed:** 2026-07-14T00:00:00Z
**Depth:** standard
**Files Reviewed:** 4
**Status:** issues_found

## Summary

This is a scoped gap-closure review for plan 02-18 (fix for UAT test 73: cold-start avatar
caching bug caused by `profileUpdatedAt` never flowing through `GET /families/{familyId}/live-locations`).

The core change itself — adding a trailing `ProfileUpdatedAt` field to `MemberLiveLocationDto` and
projecting/gating it in `GetLiveLocationsQueryHandler` — is correct: the field is appended (not
inserted) so no positional-record ordering hazard exists, the type (`DateTime?`) matches the
underlying `User.ProfileUpdatedAt` entity property, JSON serialization is name-based (not
positional) so the API contract is unaffected, and the single construction site
(`GetLiveLocationsQuery.cs:66`) is the only place that needed updating. The three new backend
tests genuinely exercise three distinct branches (visible-and-set, visible-and-unset,
gated-and-denied) rather than three copies of the happy path. The mobile test's assertion that
only `selfPosition.profileUpdatedAt` (not also `members['self-user'].profileUpdatedAt`) gets
checked is not a coverage gap — `_bootstrap()` assigns `selfPosition = initialMembers[currentUserId]`,
i.e. the exact same object reference, so the two assertions would be redundant.

However, while auditing "is the sharing gate actually complete" (the specific question this
review was asked to answer), I found that a *different* field already present in this file —
`IsOnline` — is not gated by `canViewLocation` at all, and it is computed from the same
location-ping timestamp that `ProfileUpdatedAt`/`ProfileImageUrl`/`Lat`/`Lng` are correctly gated
behind. That's a pre-existing gap in `GetLiveLocationsQuery.cs` (not introduced by this diff, but
squarely inside one of the four files in scope), and it means a viewer who has been denied
`LiveLocation` sharing can still infer "this family member's device pinged the server within the
last 2 minutes" — a location-adjacent signal leaking straight past the privacy boundary this
handler is supposed to enforce.

## Critical Issues

### CR-01: `IsOnline` leaks location-ping recency past the `LiveLocation` sharing gate

**File:** `backend/src/SafePath.Application/Location/GetLiveLocationsQuery.cs:51-65,74`
**Issue:**
`isRecent` is computed directly from `latestPing.RecordedAtUtc` *before* (and independently of)
the `canViewLocation` check, and is then OR'd into the `IsOnline` field unconditionally:

```csharp
var latestPing = await _db.LocationPings...FirstOrDefaultAsync(cancellationToken);
var canViewLocation = await _sharing.CanView(..., SharedDataType.LiveLocation, ...);
...
var isRecent = latestPing is not null && now - latestPing.RecordedAtUtc <= PingFreshnessWindow;
results.Add(new MemberLiveLocationDto(
    ...,
    canViewLocation ? latestPing?.RecordedAtUtc : null,   // <-- correctly gated
    _presence.IsOnline(member.UserId) || isRecent,        // <-- NOT gated
    profileImageUrl,
    canViewLocation ? member.ProfileUpdatedAt : null));   // <-- correctly gated (this fix)
```

Every other location-derived field on this DTO (`Lat`, `Lng`, `AccuracyMeters`, `RecordedAtUtc`,
`ProfileImageUrl`, and now `ProfileUpdatedAt`) is null when `canViewLocation` is false. `IsOnline`
is the one exception: it still reflects whether the member pinged the server in the last two
minutes, regardless of whether the viewer is authorized to see that member's location at all. For
a family-safety app whose stated design principle is privacy-first sharing controls, "this
person's device was active moments ago" is exactly the kind of location-adjacent inference a
sharing-disabled family member would expect to be withheld — this is the same class of leak the
`ProfileUpdatedAt` fix in this same diff was written to close, just on a sibling field the fix
didn't touch. No existing test (including the pre-existing
`Handle_SignsProfileImageUrlOnlyWhenViewerCanSeeLocation` denial test) asserts `IsOnline` after a
sharing denial, so this has never been caught.

**Fix:** Gate the ping-recency contribution behind `canViewLocation`, same as the other fields
(presence/connection state from `_presence.IsOnline` is a separate, non-location signal and can
stay ungated if that's the intended product behavior — but the ping-derived half must not be):

```csharp
var isRecent = canViewLocation && latestPing is not null
    && now - latestPing.RecordedAtUtc <= PingFreshnessWindow;
results.Add(new MemberLiveLocationDto(
    ...,
    _presence.IsOnline(member.UserId) || isRecent,
    ...
```

Add a regression test mirroring `Handle_HidesProfileUpdatedAtWhenViewerCannotSeeLocation` that
seeds a recent ping, denies `LiveLocation` sharing, and asserts `IsOnline` is `false` (assuming no
independent, non-ping presence signal is active).

## Warnings

### WR-01: No test locks in the self-viewing-own-row path for `ProfileUpdatedAt`

**File:** `backend/tests/SafePath.Application.Tests/Location/GetLiveLocationsQueryTests.cs:147-181`
**Issue:** All three new tests exercise `ProfileUpdatedAt` for the *caller viewing a family
member* (`memberId`), relying on `SharingAuthorizationService.CanView`'s self-bypass
(`viewerUserId == ownerUserId`) being correct only by inference from other test files. Given the
underlying UAT bug (test 73) was specifically about the *current user's own* avatar going stale
on cold start — not just family members' avatars — a direct assertion that the caller's own row
(`result.Single(l => l.UserId == callerId)`) also carries a non-null `ProfileUpdatedAt` when set
would close the loop on the exact regression this plan was meant to fix, rather than relying on
self-bypass being exercised correctly elsewhere.
**Fix:** Add (or extend an existing test) to set `caller.ProfileUpdatedAt` and assert
`result.Single(l => l.UserId == callerId).ProfileUpdatedAt` equals it, with no `SharingPreference`
row needed (self-bypass path).

### WR-02: `ProfileUpdatedAt`/`ProfileImageUrl` visibility is coupled to the `LiveLocation` permission, not a profile-specific one

**File:** `backend/src/SafePath.Application/Location/GetLiveLocationsQuery.cs:62-76`
**Issue:** The fix intentionally mirrors the existing `ProfileImageUrl` gating pattern (per this
plan's stated rationale), but that means disabling *location* sharing for a family member also
blanks their avatar and cache-bust timestamp, even though `DisplayName` remains visible
regardless. There's no `SharedDataType.Profile`/`Identity` category — `LiveLocation` is being
overloaded as a proxy for "can this viewer see this person's current profile appearance." This
isn't a regression introduced by this diff (the same coupling already existed for
`ProfileImageUrl`), but extending it to a second field compounds the coupling rather than
resolving it, and is worth flagging before it becomes harder to unwind.
**Fix:** Not blocking for this gap-closure plan. Consider a follow-up to introduce a dedicated
`SharedDataType.Profile` (or equivalent) if avatar/profile visibility should ever need to vary
independently of live-location sharing.

## Info

### IN-01: `DateTime` equality assertions round-tripped through the SQLite test provider

**File:** `backend/tests/SafePath.Application.Tests/Location/GetLiveLocationsQueryTests.cs:153-164,190-209`
**Issue:** `Assert.Equal(profileUpdatedAt, result.Single(...).ProfileUpdatedAt)` compares a
`DateTime.UtcNow.AddMinutes(-5)` value written to and read back from an in-memory SQLite context.
This mirrors an existing established pattern in this same file (e.g. `RecordedAtUtc` equality
checks), so it's consistent with prior art and not a new risk, but any sub-tick precision loss in
the Sqlite EF Core provider's DateTime round-trip would make this assertion (and its siblings)
flaky. Not action-required given precedent, but worth knowing if these tests ever start
intermittently failing.
**Fix:** If flakiness appears, switch to `Assert.Equal(profileUpdatedAt, actual, TimeSpan.FromMilliseconds(1))` (xUnit's tolerance overload) rather than exact equality.

### IN-02: Mobile test naming slightly overstates what's being verified

**File:** `mobile/test/features/location/location_controller_test.dart:403-440`
**Issue:** The test name "cold-start bootstrap threads profileUpdatedAt into selfPosition and
family markers" only asserts `selfPosition` and `members['member-2']`, not
`members['self-user']` directly. As analyzed, this is fine because `selfPosition` and
`members['self-user']` are the same object reference in `_bootstrap()` — but a future refactor
that stops aliasing them (e.g. if `selfPosition` is ever built from a separate lookup) could
silently invalidate this test's coverage of the family-marker map for the self user without
failing.
**Fix:** Optional: add an explicit `expect(state.members['self-user']?.profileUpdatedAt, ...)`
assertion alongside the `selfPosition` one, purely as a tripwire against that future refactor
risk. Not required now.

---

_Reviewed: 2026-07-14T00:00:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
