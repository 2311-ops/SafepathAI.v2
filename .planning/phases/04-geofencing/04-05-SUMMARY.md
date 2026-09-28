---
phase: 04-geofencing
plan: 05
subsystem: android-geofencing
tags: [android, geofencing, workmanager, supabase, physical-verification, deferred]
requires:
  - phase: 04-geofencing
    provides: native registration and authenticated candidate-upload tracer evidence
provides:
  - Documented backend/native tracer implementation state
  - Explicit deferred physical-evidence checklist for Android process-death and offline replay
  - Guardrail that no Android/iOS acceptance evidence is claimed until a later physical test session
affects: [geofence-registration, geofence-candidate-upload, phase-04-acceptance]
actuals:
  tokens: 0
  tasks: 1
  commits: 0
tech-stack:
  added: []
  patterns: [deferred-physical-acceptance, evidence-preserving-summary]
key-files:
  created: []
  modified:
    - .planning/phases/04-geofencing/04-REMOTE-ANDROID-VERIFICATION.md
    - .planning/phases/04-geofencing/04-DEVICE-VERIFICATION.md
key-decisions:
  - "The Android process-death tracer checkpoint is intentionally carried forward as deferred physical evidence instead of blocking all later phase movement."
  - "No generation-2 acknowledgement, process-death callback, authenticated candidate upload, offline replay, or SOS-concurrency pass is claimed by this summary."
  - "The remaining physical checklist stays tracked in deferred-items.md and phase verification as human-needed acceptance debt."
requirements-completed: []
requirements-deferred: [GEO-01, GEO-02]
coverage:
  - id: D1
    description: "Android process-death registration, headless authenticated upload, offline replay, and SOS concurrency require real-device evidence."
    requirement: GEO-02
    verification:
      - kind: human
        ref: ".planning/phases/04-geofencing/04-REMOTE-ANDROID-VERIFICATION.md"
        status: deferred
        rationale: "Generation 2 acknowledgement and physical boundary evidence were not available at the time the phase was moved forward."
    human_judgment: true
duration: deferred
completed: 2026-09-28
status: deferred-partial
---

# Phase 04 Plan 05: Android Tracer Checkpoint Deferred Summary

**The Android tracer checkpoint is half-finished and intentionally deferred; the project is moving forward without fabricating physical acceptance evidence.**

## What Is Done

- The backend, native Android registration path, durable native outbox, WorkManager bridge, and authenticated Dart candidate drain were implemented in earlier Phase 4 work.
- The current remote Android run created and recentered a 100 m test zone, and the project has retained the exact outstanding evidence requirements in `04-REMOTE-ANDROID-VERIFICATION.md`.
- Automated checks recorded in `04-DEVICE-VERIFICATION.md` were green as of the latest verification run, including backend tests, Flutter tests, analyzer, native worker test, migration checks, Android build/launch, and structural SOS isolation checks.

## What Is Not Done

- The OPPO member device has not supplied the required generation 2 registration acknowledgement.
- Process-death callback evidence is inconclusive; prior attempts did not prove the app process was absent before the boundary event.
- No real boundary candidate, headless upload, offline replay, push/feed/activity result, or concurrent SOS proof is claimed here.
- Signed iPhone/macOS/Xcode/APNs physical acceptance remains outside this checkpoint and is still required by Phase 4 verification.

## Deferred Acceptance

The following remains required before Phase 4 can be called fully accepted:

- Android generation acknowledgement for the current or recreated 100 m zone.
- Verified process-death or reboot recovery without using force-stop.
- Real enter/exit candidate persisted natively, uploaded with restored Supabase auth, and acknowledged only after accepted or duplicate response.
- Offline replay that persists exactly once and drains after network return/cold launch.
- Concurrent SOS while routine geofence work is pending, with SOS remaining immediate and independent.

## Decision

This plan is counted as a deferred partial checkpoint so later Phase 4 verification and review can proceed. It does not close the physical evidence debt. The evidence debt is tracked in `deferred-items.md` and `04-DEVICE-VERIFICATION.md`.

## Next Phase Readiness

Ready for automated verification, code review, and 04-17 closeout of the current shippable state. Final phase shipping remains gated by GSD verification status.
