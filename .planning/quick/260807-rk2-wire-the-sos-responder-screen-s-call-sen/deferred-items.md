# Deferred Items — quick/260807-rk2

Out-of-scope discoveries found during execution, not fixed (per executor scope boundary).

## Pre-existing failing test: `member_map_pin_semantics_test.dart`

- **Found during:** Task 3 full mobile suite run (`flutter test`).
- **Symptom:** Both tests in `mobile/test/shared_widgets/member_map_pin_semantics_test.dart`
  ("announces the label and current-location status as one node" / "...and stale status...")
  fail with `A SemanticsHandle was active at the end of the test.`
- **Scope:** Neither `mobile/test/shared_widgets/member_map_pin_semantics_test.dart` nor
  `mobile/lib/shared_widgets/member_map_pin.dart` were touched by this quick task. Confirmed the
  failure reproduces in isolation (`flutter test test/shared_widgets/member_map_pin_semantics_test.dart`),
  and the files were last modified in unrelated commits (`555a22f`, `7246356`), not this task's diff.
- **Action taken:** None — logged only, per the executor's scope boundary (only auto-fix issues
  directly caused by the current task's changes).
