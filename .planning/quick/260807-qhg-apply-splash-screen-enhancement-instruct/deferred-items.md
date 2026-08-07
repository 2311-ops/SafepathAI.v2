# Deferred Items — Quick Task 260807-qhg

Out-of-scope discoveries found during execution, not fixed per the scope
boundary rule (only issues directly caused by this task's changes are
auto-fixed).

## Pre-existing failing test: `member_map_pin_semantics_test.dart`

- **File:** `mobile/test/shared_widgets/member_map_pin_semantics_test.dart`
- **Tests:** `announces the label and current-location status as one node`,
  `announces the label and stale status as one node`
- **Symptom:** `A SemanticsHandle was active at the end of the test.` thrown
  by `WidgetTester._verifySemanticsHandlesWereDisposed`.
- **Found during:** Task 3's full-suite verification run
  (`cd mobile && flutter test`).
- **Confirmed unrelated:** Fails identically when run in isolation
  (`flutter test test/shared_widgets/member_map_pin_semantics_test.dart`),
  with zero involvement of any file this task touched
  (`animated_safepath_mark.dart`, `splash_screen.dart`,
  `splash_screen_test.dart`). Last modified in commit `7246356`
  (quick task 260720-3u4, "add semantics label to MemberMapPin"),
  unmodified since.
- **Not fixed:** Out of scope for this splash-animation task. Left as a
  pre-existing defect for a future task/session to pick up.
