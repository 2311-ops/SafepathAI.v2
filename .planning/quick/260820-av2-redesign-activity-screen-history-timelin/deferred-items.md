# Deferred Items — quick-260820-av2

Out-of-scope test failures discovered while running the full `flutter test` suite
during Task 3 verification. Neither failing test imports `SafePathCard`,
`StatTile`, `PrimaryButton`, `TimelineNode`, or `history_timeline_screen.dart` —
both are pre-existing, unrelated to this plan's changes, and were left unfixed
per the scope-boundary rule (only auto-fix issues directly caused by the
current task's changes).

| Test | File | Failure |
|------|------|---------|
| `renders the battery percent when known` | `mobile/test/features/location/live_member_marker_test.dart` | `Expected: exactly one matching candidate. Actual: Found 0 widgets with text "72%"` — imports only `live_map_screen.dart` and `location_models.dart`, no relation to this plan's touched files. |
| `existing routing unchanged after splash: unauthenticated -> Welcome -> Login still works` | `mobile/test/features/splash/splash_redirect_gate_test.dart` | Tap on "I already have an account" misses (`Offset` outside 800x600 test viewport bounds), followed by `Expected: exactly one matching candidate. Actual: Found 0 widgets with text "Welcome back."` — imports `app.dart`/`splash_screen.dart`/auth-family-profile fakes only, no relation to this plan's touched files. |

Both are candidates for a future `/gsd-debug` or quick-task investigation, not
addressed here.
