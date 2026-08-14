# Deferred Items

## 2026-08-14 — Full mobile test suite privacy failures

- **Scope:** Out of scope for 04-16 routine notification routing.
- **Command:** `cd mobile && flutter test`
- **Failing file:** `mobile/test/features/privacy/privacy_center_screen_test.dart`
- **Failing tests:** `renders toggle matrix and duration controls`; `tapping a toggle calls the privacy controller`; `4-hour duration chip uses the selected recipient row`; `custom duration accepts user-entered hours`.
- **Reason deferred:** The affected tests render `PrivacyCenterScreen` through a local test-only router and do not import or exercise the routine push service/router composition changed by this plan. Focused routine/SOS tests pass.
