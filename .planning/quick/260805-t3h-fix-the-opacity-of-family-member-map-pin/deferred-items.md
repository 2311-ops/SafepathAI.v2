# Deferred Items — Quick Task 260805-t3h

## Pre-existing failure: `member_map_pin_semantics_test.dart`

**Found during:** Task 1 verification (`flutter test test/features/location/staleness_test.dart test/features/location/live_member_marker_test.dart test/shared_widgets/member_map_pin_semantics_test.dart`)

**Symptom:** Both tests in `mobile/test/shared_widgets/member_map_pin_semantics_test.dart`
("announces the label and current-location status as one node" and "announces the label and
stale status as one node") fail with:

```
A SemanticsHandle was active at the end of the test.
All SemanticsHandle instances must be disposed by calling dispose() on the SemanticsHandle.
```

**Why this is out of scope for 260805-t3h:** This task modified only
`staleness.dart` / `staleness_test.dart`. `member_map_pin.dart` and its semantics test were not
touched. The failure reproduces identically running the semantics test file in isolation, with
no relation to opacity values — it is a `tester.ensureSemantics()` handle-disposal leak in the
test harness itself (last touched in commit `7246356`, quick task 260720-3u4). Per the executor's
Scope Boundary rule, pre-existing failures in unrelated files are not auto-fixed by this task.

**Recommendation:** File a follow-up quick task to add/fix the missing
`handle.dispose()` (or equivalent teardown) in `member_map_pin_semantics_test.dart`.
