# Phase 04 — Multi-Source Coverage Audit

SOURCE | ID | Feature / constraint | Plan(s) | Status | Notes
--- | --- | --- | --- | --- | ---
GOAL | — | Guardians receive reliable safe-zone enter/exit awareness without drift false alarms | 01-17 | COVERED | Backend/native/device/UX path is complete
REQ | GEO-01 | Guardian creates/manages radius safe zones | 01, 02, 06, 12, 13, 17 | COVERED | Production tracer then full CRUD/UI
REQ | GEO-02 | Native enter/exit with dwell/hysteresis | 01-05, 07, 11, 17 | COVERED | Early Android gate precedes expansion
REQ | GEO-03 | Per-geofence activity log | 02, 07, 08, 14, 17 | COVERED | Pairing, filters, retention, UI
REQ | NOTIF-02 | Enter/exit push plus in-app notification | 02, 07, 09, 10, 15-17 | COVERED | Durable feed, PR-03, normal push
RESEARCH | PR-01 | Normalized server-owned persistence and atomic feed/job creation | 01, 02, 07 | COVERED | Decision fixed before device work
RESEARCH | PR-02 | Native outbox -> headless Dart Supabase auth -> candidate API, cold-relaunch fallback | 03-05, 11 | COVERED | No native credential
RESEARCH | PR-03 | Recipient-owned quiet hours; feed now, push later; SOS bypass | 02, 09, 10, 15 | COVERED | Disabled default, IANA zone
RESEARCH | PR-04 | Signed physical-iPhone/Xcode/APNs acceptance | 11, 17 | COVERED | Missing evidence keeps phase open
RESEARCH | — | 20 active-zone cross-platform cap and lifecycle recovery | 03, 06, 11 | COVERED | Android/iOS recovery
RESEARCH | — | Accuracy envelope, contiguous dwell, replay/idempotency | 01, 07 | COVERED | Pure evaluator plus durable keys
RESEARCH | — | Seven-day retention and push/SOS isolation | 02, 08-10, 16-17 | COVERED | Query+worker+regressions
CONTEXT | D-01 | Map-first pin/current location | 12 | COVERED | Editor and VectorMap
CONTEXT | D-02 | Presets plus fine slider | 12 | COVERED | UI-SPEC values
CONTEXT | D-03 | Standard categories and custom names | 01, 06, 12 | COVERED | API/model/UI
CONTEXT | D-04 | Complete confirmation preview | 12 | COVERED | Separate review surface
CONTEXT | D-05 | Continuous dwell; cross-back reset | 01, 07 | COVERED | Candidate/evaluator
CONTEXT | D-06 | Accuracy-overlap waits | 01, 07 | COVERED | Clear-side envelope
CONTEXT | D-07 | Per-zone sensitivity | 06, 07, 12 | COVERED | Stored/mapped/evaluated
CONTEXT | D-08 | Configurable Guardian recipients | 01, 02, 06, 12 | COVERED | Normalized recipient rows
CONTEXT | D-09 | Guardian-controlled member notification | 01, 06, 07, 12 | COVERED | Off default; fan-out rule
CONTEXT | D-10 | Push + durable feed; push failure cannot erase activity | 02, 07, 09, 10, 15, 16 | COVERED | Persist-before-deliver
CONTEXT | D-11 | Routine quiet hours; SOS bypass/unaffected | 02, 04, 05, 09-11, 15-17 | COVERED | PR-03 and isolation gates
CONTEXT | D-12 | Member/zone/type/time/duration fields | 02, 08, 14 | COVERED | Backend projection + UI
CONTEXT | D-13 | Newest/day grouping and visit pairing | 07, 08, 14 | COVERED | Persisted pairing identity
CONTEXT | D-14 | Member/zone/type/date filters | 08, 14 | COVERED | Server/client filters
CONTEXT | D-15 | Automatic seven-day deletion | 02, 08 | COVERED | Query clamp + sweep

## Exclusions

- Deferred FamilyController cold-start todo remains outside Phase 4 as explicitly recorded in CONTEXT.md.
- Predictive geofencing, learned schedules, and AI alerts remain Phase 6 scope.

## Result

All GOAL, REQ, RESEARCH, and CONTEXT items are covered. No source item is missing and no deferred idea is planned.
