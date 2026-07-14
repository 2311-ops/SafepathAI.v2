---
phase: 02-real-time-location-history-privacy
reviewed: 2026-07-14T00:00:00Z
depth: standard
files_reviewed: 2
files_reviewed_list:
  - mobile/lib/features/location/presentation/live_map_screen.dart
  - mobile/test/features/location/live_map_screen_test.dart
findings:
  critical: 0
  warning: 1
  info: 2
  total: 3
status: issues_found
---

# Phase 02: Code Review Report (Gap Closure — Plan 02-17)

**Reviewed:** 2026-07-14T00:00:00Z
**Depth:** standard
**Files Reviewed:** 2
**Status:** issues_found (warnings/info only — no blockers)

## Summary

Scoped review of plan 02-17's single call-site fix: the Live Map header's
`MemberMapPin` was changed from a `const` instantiation to a dynamic one wired
to `state?.selfPosition?.userId` / `profileImageUrl` / `profileUpdatedAt`, plus
a new TDD regression widget test. This is a narrow, targeted follow-up to the
already-resolved full-file reviews (`02-REVIEW.md`/`02-REVIEW-2.md` from the
prior pass); only these two files and this specific diff were re-reviewed.

The wiring itself is correct:
- All three new fields use the `?.` null-safe chain through `state` →
  `selfPosition`, so a `null` `LocationState` or a `null` `selfPosition` (e.g.
  before the user's own location has ever been reported) degrades cleanly to
  `MemberMapPin`'s existing initials fallback (`_hasAvatar` is `false` when
  `profileImageUrl` is `null`/blank) rather than throwing.
- The fix mirrors the exact `LiveMemberMarker` pattern already used for other
  family members' pins in the same file (same field names, same null-coalescing
  shape), which is what the plan asked for.
- Traced into `LocationController` (`_applyLocation`, `_applyProfileUpdate` in
  `location_controller.dart`): `selfPosition` is correctly kept in sync
  whenever a location or profile-update event arrives for the current user's
  `userId`, so the header will genuinely live-update at runtime, not just at
  first build — the fix is wired to a data source that actually changes.
- Confirmed `LiveLocation.profileImageUrl` / `profileUpdatedAt` are
  nullable (`String?` / `DateTime?`) in `location_models.dart`, matching the
  types `MemberMapPin` expects — no type mismatch.
- Confirmed via `git diff b59b567~1..HEAD` that the diff is exactly the 4-line
  addition described (no other call sites or logic touched), so the
  already-reviewed broader file was not re-litigated here.

The new regression test is a real, TDD-authored (fails-before-fix per commit
`c522e4c`, then fixed in `b59b567`) lock on the specific bug (hardcoded/const
pin), and correctly disambiguates against the map's own per-member pins by
asserting `findsOneWidget` for `MemberMapPin` (map markers use the sibling
`LiveMemberMarker` widget, not `MemberMapPin`) — this is a sound assertion,
not an incidental one.

Two minor gaps below (a test-coverage completeness gap and a formatting nit)
are worth fixing but neither is a shippable-blocking issue.

## Warnings

### WR-01: Regression test only checks the initial build, not an in-flight live update

**File:** `mobile/test/features/location/live_map_screen_test.dart:250-291`
**Issue:** The test name is "header identity pin live-updates from
LocationState.selfPosition (UAT 72)," and the bug being fixed was specifically
that the header never *reflected changes* to the current user's profile
photo. However, the test only asserts that `MemberMapPin`'s props are correct
on the widget's first build from a state that is seeded with the avatar
already present — it never mutates `selfPosition` mid-test (e.g., by pumping
a second frame after the notifier applies a simulated `_applyProfileUpdate`/
`_applyLocation` event with a *different* `profileImageUrl`) and re-asserting
the pin picked up the new value. As written, the test would pass equally well
for an implementation that captured `selfPosition` once and never rebuilt —
it happens to also prove the actual fix (removing `const`) because a `const`
widget's fields are fixed to null regardless of state, but it doesn't
independently prove the "live" (reactive-to-change) half of the bug
description.
**Fix:** Add a second phase to the test that mutates the seeded state after
the first `pump` (e.g., expose a settable field on
`_SeededSelfAvatarLocationController` or drive its notifier directly) to
change `profileImageUrl`, then re-`pump` and re-assert the `MemberMapPin`'s
`profileImageUrl` reflects the new value:
```dart
controller.simulateProfileChange(imageUrl: 'https://example.com/new.jpg');
await tester.pump(const Duration(milliseconds: 100));
final updatedPin = tester.widget<MemberMapPin>(find.byType(MemberMapPin));
expect(updatedPin.profileImageUrl, 'https://example.com/new.jpg');
```

## Info

### IN-01: `profileUpdatedAt` assertion is looser than the other two new fields

**File:** `mobile/test/features/location/live_map_screen_test.dart:289`
**Issue:** `expect(headerPin.profileUpdatedAt, isNotNull);` only checks
non-null, whereas the sibling assertions for `userId` and `profileImageUrl`
(lines 284-288) check exact values. Since `_SeededSelfAvatarLocationController`
seeds a specific `now` value for `profileUpdatedAt`, the test could pin the
exact `DateTime` and catch a wiring mistake (e.g., accidentally passing a
freshly-created `DateTime.now()` instead of
`state.selfPosition.profileUpdatedAt`) that `isNotNull` would miss.
**Fix:**
```dart
expect(headerPin.profileUpdatedAt, self.profileUpdatedAt);
```

### IN-02: New lines exceed the file's 80-column formatting convention

**File:** `mobile/lib/features/location/presentation/live_map_screen.dart:161-162`
**Issue:** The two new lines are 82 and 84 characters respectively:
```dart
                            profileImageUrl: state?.selfPosition?.profileImageUrl,
                            profileUpdatedAt: state?.selfPosition?.profileUpdatedAt,
```
Every other line in this file's `Row`/`Column` block (and the vast majority of
the file) wraps at or under 80 columns per standard `dart format` output,
suggesting these two lines weren't run through `dart format` after editing.
Not a lint failure under this project's `analysis_options.yaml` (no
`lines_longer_than_80_chars` rule enabled), but inconsistent with the
surrounding style.
**Fix:** Run `dart format mobile/lib/features/location/presentation/live_map_screen.dart`
so these two lines wrap consistently with the rest of the constructor call,
e.g.:
```dart
MemberMapPin(
  label: 'You',
  identityColor: AppColors.primaryTeal,
  isSelf: true,
  size: 36,
  userId: state?.selfPosition?.userId,
  profileImageUrl:
      state?.selfPosition?.profileImageUrl,
  profileUpdatedAt:
      state?.selfPosition?.profileUpdatedAt,
),
```

---

_Reviewed: 2026-07-14T00:00:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
