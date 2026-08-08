# Deferred Items — Phase 03 (sos-fast-path)

Items discovered during plan execution that are out of scope for the plan that found them
(pre-existing, unrelated to the plan's own file list) and are logged here rather than fixed,
per the executor's scope-boundary rule.

## 03-02: Pre-existing `member_map_pin_semantics_test.dart` failure (unrelated to SOS)

- **Found during:** 03-02 Task 3, running the full `flutter test` suite after Task 3's changes.
- **Symptom:** Both tests in `mobile/test/shared_widgets/member_map_pin_semantics_test.dart`
  ("announces the label and current-location status as one node" /  "... and stale status as
  one node") fail with `A SemanticsHandle was active at the end of the test.` even though each
  test correctly calls `addTearDown(semantics.dispose)`.
- **Why it's out of scope for 03-02:** This file has no relationship to the SOS feature — it
  exercises `MemberMapPin` (a Phase 2 shared widget) in isolation. Confirmed pre-existing and
  unrelated to any 03-02 file: running `flutter test test/shared_widgets/member_map_pin_semantics_test.dart`
  alone (no other test files loaded) reproduces the same two failures.
- **Why it was only now visible:** 03-02 Task 1 fixed an unrelated but blocking syntax bug in
  `mobile/lib/shared_widgets/member_map_pin.dart` (a stray trailing comma inside a ternary
  expression, committed in `555a22f`) that had been silently breaking compilation of *any* file
  transitively importing `member_map_pin.dart` — including this test file. Before that fix, this
  test (and the whole suite) could not compile at all, so this SemanticsHandle regression was
  never actually exercised or caught by CI/previous phase closeouts.
- **Suspected cause:** A Flutter-SDK-version-related change in `ensureSemantics()`/`addTearDown`
  ordering (project is on Flutter 3.44.5 stable) rather than an application bug — the test's own
  teardown code follows the standard, widely-used pattern.
- **Recommendation:** Investigate in a future quick task or the next phase touching
  `member_map_pin.dart`/its tests; not required for any 03-02 acceptance criterion (SOS-01,
  DESIGN-02, SOS-03) and does not affect the SOS fast path.
