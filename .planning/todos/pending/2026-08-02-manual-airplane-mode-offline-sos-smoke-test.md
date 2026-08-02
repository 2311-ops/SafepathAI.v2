---
created: 2026-08-02T19:05:16.641Z
title: Manual airplane-mode offline SOS smoke test
area: verification
files:
  - mobile/lib/features/sos/application/sos_controller.dart
  - mobile/lib/features/sos/presentation/sender_emergency_session_screen.dart
  - .planning/phases/03-sos-fast-path/03-07-PLAN.md (verification section, D4)
---

## Problem

Phase 03-07 (offline SOS queue/retry + emergency contacts) is code-complete and merged (`0627b6d`, `459dcf3`, `8930a6b`) with full automated test coverage (`sos_offline_retry_test.dart` 10/10, `emergency_contacts_screen_test.dart` 8/8), but its own plan calls out one explicit manual verification step (D4 in `03-07-SUMMARY.md`) that requires a physical/emulator device with airplane-mode toggling and app-kill/relaunch — not available in the execution sandbox this plan ran in.

## Solution

Manual smoke test per `03-07-PLAN.md`'s `<verification>` section, step 4:

1. Put the device in airplane mode.
2. Hold the SOS button — confirm the offline/queued session appears immediately with the "Not sent yet, retrying…" copy and both local fallback actions (call contact, copy location).
3. Kill the app entirely and reopen it — confirm it resumes the *same* emergency session (same session id), still queued, not a new one.
4. Re-enable networking — confirm the queued SOS submits automatically with no user action, and confirm only one emergency session exists server-side (no duplicate from the retry loop).

Report the result back; this closes out the last open item on 03-07.
