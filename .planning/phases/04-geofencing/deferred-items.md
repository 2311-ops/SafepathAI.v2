# Deferred Items

## 2026-09-28 - 04-05 Android tracer physical acceptance

- **Scope:** Deferred from `04-05-PLAN.md` so Phase 4 can continue through automated verification and code review without fabricating device evidence.
- **Status:** Half-finished / deferred physical checkpoint.
- **Remaining evidence:** Generation acknowledgement, process-death callback, real boundary candidate, restored-session upload, offline replay, and SOS-concurrency proof on a physical Android device.
- **Reason deferred:** The remote OPPO member device did not yet provide generation 2 acknowledgement or conclusive process-death/boundary evidence. Keeping the whole phase blocked on this checkpoint prevents forward progress, but marking it passed would be inaccurate.
- **Resume from:** `.planning/phases/04-geofencing/04-REMOTE-ANDROID-VERIFICATION.md`
- **Do not claim:** No Android/iOS physical acceptance evidence is implied by `04-05-SUMMARY.md`.

## 2026-08-14 — Full mobile test suite privacy failures

- **Scope:** Out of scope for 04-16 routine notification routing.
- **Command:** `cd mobile && flutter test`
- **Failing file:** `mobile/test/features/privacy/privacy_center_screen_test.dart`
- **Failing tests:** `renders toggle matrix and duration controls`; `tapping a toggle calls the privacy controller`; `4-hour duration chip uses the selected recipient row`; `custom duration accepts user-entered hours`.
- **Reason deferred:** The affected tests render `PrivacyCenterScreen` through a local test-only router and do not import or exercise the routine push service/router composition changed by this plan. Focused routine/SOS tests pass.
