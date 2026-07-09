# Deferred Items — Phase 01 (backend-auth-foundation)

Out-of-scope discoveries logged during plan execution, not fixed inline per the
executor's scope-boundary rule (only auto-fix issues directly caused by the
current task's changes).

## Missing 01-07-SUMMARY.md

- **Found during:** 01-08 execution, running `roadmap update-plan-progress` (state-update step)
- **Issue:** `01-07-PLAN.md` (family-circle screens: Create/Invite/Accept/Permissions +
  landing member list) was executed and committed (`bd9288f`, `132dd85`) but no
  `01-07-SUMMARY.md` was ever written. `roadmap.update-plan-progress` reports
  `plan_count: 8, summary_count: 7` for this reason — phase 01 shows as "In Progress"
  rather than complete even though all 8 plans have landed code.
- **Impact:** Cosmetic/tracking only — 01-07's actual code is committed and tested (see
  `bd9288f`/`132dd85` in git log). No functional gap.
- **Status:** Deferred — out of scope for 01-08 execution (pre-existing, unrelated to
  Google Sign-In). Should be backfilled (or the plan-count logic reconciled) before
  Phase 01 is formally transitioned/closed.
