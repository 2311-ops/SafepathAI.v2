---
phase: 01-backend-auth-foundation
plan: 14
subsystem: mobile-ui
tags: [flutter, riverpod, deep-links, invite-workflow, reset-password, material-3]

requires:
  - phase: 01-backend-auth-foundation
    provides: Supabase Auth mobile flow, family invite acceptance UI
provides:
  - "Invite QR/deep-link route handling with pending invite restoration after auth"
  - "Distinct invite decline behavior that does not redeem/join"
  - "Expired reset-link messaging using amber warning styling instead of SOS red"
  - "Google Sign-In configuration errors surfaced as configuration errors"
affects: [02-real-time-location]

key-files:
  created:
    - mobile/lib/core/deep_link/deep_link_service.dart
    - mobile/test/core/router/pending_invite_redirect_test.dart
    - mobile/test/features/family/accept_invite_screen_test.dart
  modified:
    - mobile/lib/app.dart
    - mobile/lib/core/router/app_router.dart
    - mobile/lib/features/auth/data/auth_api.dart
    - mobile/lib/features/auth/presentation/forgot_password_screen.dart
    - mobile/lib/features/auth/presentation/reset_password_screen.dart
    - mobile/lib/features/family/data/family_api.dart
    - mobile/lib/features/family/presentation/accept_invite_screen.dart
    - mobile/pubspec.yaml
    - mobile/pubspec.lock
    - mobile/test/features/auth/forgot_password_screen_test.dart
    - mobile/test/features/auth/reset_password_screen_test.dart
    - mobile/test/features/family/family_controller_test.dart

requirements-completed: [AUTH-03, AUTH-04, AUTH-06, FAM-02, FAM-03, DESIGN-01]
completed: 2026-07-10
status: complete
---

# Phase 01 Plan 14: Invite Deep Links and Reset UX Summary

## Accomplishments

- Added an app-level deep-link service using `app_links` for `safepathai://invite` and reset-password error redirects.
- Implemented pending invite restoration: unauthenticated users who open an invite link are sent through auth and then returned to the invite acceptance screen without losing the token/code.
- Updated invite acceptance so link-token invites do not require manual code entry, and declining an invite shows a distinct decline path without redeeming or joining.
- Added amber warning banners for expired reset links, preserving SafePath's red for SOS/emergency contexts.
- Fixed Google Sign-In configuration error mapping so missing configuration remains a configuration/auth error instead of being mislabeled as a network failure.
- Added deterministic widget/router tests with no real network or Supabase authentication.

## Verification

- `flutter analyze`
- Targeted widget/router tests during implementation; full `flutter test` tracked in the final audit-fix run.

## Remaining Notes

QR generation uses the existing invite URL/code flow; no Phase 2 location or notification functionality was introduced.
