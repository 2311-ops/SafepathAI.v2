---
phase: quick-260811-5oo
plan: 01
subsystem: ui
tags: [flutter, riverpod, family, privacy]

requires: []
provides:
  - "ManagePermissionsScreen member cards titled by the person's real name"
  - "PrivacyCenterScreen collapsed to a single shared sharing-controls card"
affects: [family, privacy]

tech-stack:
  added: []
  patterns:
    - "Multi-recipient UI actions loop over recipients calling the existing single-recipient PrivacyController API (toggle/startTemporaryShare) rather than adding batch endpoints/methods"

key-files:
  created: []
  modified:
    - mobile/lib/features/family/presentation/manage_permissions_screen.dart
    - mobile/lib/features/privacy/presentation/privacy_center_screen.dart

key-decisions:
  - "Privacy Center's per-recipient _RecipientMatrix widget was renamed to _SharedSharingControls, taking the full recipients list instead of one recipient; each toggle reflects true only when every current recipient has that data type enabled."
  - "_TemporarySharingSection's recipientId parameter (used only to build widget ValueKeys, not for sharing logic) is passed the fixed literal 'shared' now that the control block is no longer per-recipient."

requirements-completed: [QUICK-MEMBER-NAME-DISPLAY, QUICK-PRIVACY-COLLAPSE]

coverage:
  - id: D1
    description: "Manage Permissions member cards show each person's actual name (member.displayName) as the title, falling back to the role word only when no name is set"
    requirement: QUICK-MEMBER-NAME-DISPLAY
    verification:
      - kind: other
        ref: "flutter analyze lib/features/family/presentation/manage_permissions_screen.dart"
        status: pass
    human_judgment: true
    rationale: "No automated test exercises this screen's rendered text; visual correctness of the name-vs-role fallback needs a human glance at a real family circle."
  - id: D2
    description: "Privacy Center renders exactly one shared sharing-controls card instead of one card per recipient, with toggles/presets/active-share banner derived from the full recipient list via the existing per-recipient PrivacyController API"
    requirement: QUICK-PRIVACY-COLLAPSE
    verification:
      - kind: other
        ref: "flutter analyze lib/features/privacy/presentation/privacy_center_screen.dart"
        status: pass
    human_judgment: true
    rationale: "No automated test exercises this screen; verifying the single shared card behaves correctly across multiple recipients (toggle every()-semantics, fire-and-forget loops) needs a human check with a multi-member family circle."

duration: 12min
completed: 2026-08-11
status: complete
---

# Quick Task 260811-5oo: Show Member Names Instead of Role Labels Summary

**ManagePermissionsScreen titles member cards by name (`member.displayName`, role fallback); PrivacyCenterScreen collapses its one-card-per-recipient sharing matrix into a single `_SharedSharingControls` card wired to the existing per-recipient `PrivacyController` API via loops.**

## Performance

- **Duration:** 12 min
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments
- Manage Permissions member-card title now reads `member.displayName` when non-null/non-empty, falling back to `member.role.wireValue` otherwise
- Privacy Center's per-recipient sharing matrix (`_RecipientMatrix`, one card per family member) replaced with a single `_SharedSharingControls` card titled "Your family", built once regardless of family size
- Shared toggles reflect `true` only when every current recipient has that data type enabled; toggling loops `PrivacyController.toggle` once per recipient
- Temporary-sharing presets (1h/4h/8h/Custom) start a share for every current recipient in one tap via a loop over `PrivacyController.startTemporaryShare`
- Active-share banner shows the first recipient with an active live-location temporary share, if any

## Task Commits

1. **Task 1: Show member names instead of role labels on Manage Permissions** — `c3f3005` (fix, combined with Task 2)
2. **Task 2: Collapse Privacy Center per-recipient matrix to one shared control** — `c3f3005` (fix, combined with Task 1)

_Note: both tasks were small, tightly scoped UI changes touching one file each — committed together in a single atomic commit per the plan's execution constraints._

## Files Created/Modified
- `mobile/lib/features/family/presentation/manage_permissions_screen.dart` - Member-card title now prefers `member.displayName`, falling back to `member.role.wireValue`
- `mobile/lib/features/privacy/presentation/privacy_center_screen.dart` - Replaced the per-recipient `for` loop rendering one `_RecipientMatrix` card per recipient with a single `_SharedSharingControls` widget; updated `_activeShare` and `_startCustomTemporaryShare` to operate over the full `recipients` list; renamed `_RecipientMatrix` to `_SharedSharingControls` and removed the now-dead `_recipientLabel` helper

## Decisions Made
- Kept `_TemporarySharingSection` unchanged internally, passing it a fixed literal `'shared'` `recipientId` (used only for widget `ValueKey`s, not sharing logic) instead of a real member id, since the control block is no longer tied to one recipient.
- No controller, model, backend, or theme/token changes — both fixes are screen-level UI/interaction changes built entirely on the existing per-recipient `PrivacyController.toggle`/`startTemporaryShare` API called in loops.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

Both fixes are self-contained UI changes with no downstream dependencies. `flutter analyze` is clean on both changed files. No blockers for subsequent work.

---
*Phase: quick-260811-5oo*
*Completed: 2026-08-11*

## Self-Check: PASSED

- FOUND: mobile/lib/features/family/presentation/manage_permissions_screen.dart
- FOUND: mobile/lib/features/privacy/presentation/privacy_center_screen.dart
- FOUND: c3f3005 (git log)
