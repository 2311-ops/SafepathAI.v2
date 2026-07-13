---
status: resolved
trigger: "Fix Phase 2 bug: incorrect temporary sharing duration. When the user selects temporary location sharing for 4 hours, the UI shows an incorrect value such as 'Sharing for 4 hours - 7h 59m left' immediately after starting, instead of approximately 'Sharing for 4 hours - 4 hours left'. Do not change UI/UX, authentication, Family Circle logic, or backend contracts unless a confirmed contract bug exists. Preserve Riverpod/GoRouter/Dio/Clean Architecture."
created: 2026-07-13
updated: 2026-07-14
---

# Debug Session: Temporary Sharing Duration Incorrect

## Symptoms
- expected_behavior: Immediately after starting a 4-hour temporary sharing session in the Privacy Center screen, the UI should show a total-duration label ("Sharing for 4 hours") and a remaining-time label that is consistent with it (approximately "4 hours left", decreasing correctly over time — e.g. ~3 hours left after 1 hour elapsed, using ceiling rounding so 3h59m still reads "4 hours left").
- actual_behavior: Screenshot evidence (`image.png`, project root) shows the Privacy Center's active-sharing banner reading "Sharing for 4 hours - 7h 59m left" immediately after selecting and starting the "4 hours" option — the remaining time is roughly double the selected duration.
- error_messages: None visible in the UI; this is a silent logic/display bug, not a crash or error banner.
- timeline: Discovered 2026-07-13 during manual checkpoint verification of Phase 02 plan 02-15 (mobile profile UI). The temporary-sharing feature itself was built in an earlier Phase 02 plan (likely one of 02-11 through 02-13 — needs confirming from PLAN.md/SUMMARY.md frontmatter and git history); this is the first manual verification of its duration display.
- reproduction: Open the app as a Guardian/Member, go to Privacy > Privacy Center, select the "4 hours" temporary sharing option, start sharing, and observe the active-sharing banner's displayed remaining time immediately (within seconds) after starting.

## Current Focus
- hypothesis: The display's "total duration" label ("Sharing for 4 hours") is derived by BUCKETING the remaining time via `_durationFromNowLabel(remaining)` — there is NO startedAt in the model, so total duration cannot be computed correctly. Separately, remaining shows ~8h for a 4h pick, which requires expiresAt to be ~8h ahead (a +offset timezone mis-application, phone likely UTC+4). Need to confirm WHERE the +offset enters the round-trip (client send / .NET serialize / Npgsql read).
- test: Verify System.Text.Json deserialize Kind for a "…Z" string and serialize output; verify Npgsql timestamptz read Kind. Reproduce display math in a fake-clock Dart test.
- expecting: If server emits a no-Z (Kind=Unspecified) string, Flutter DateTime.parse(...).toUtc() mis-shifts by the phone offset. On + offset phone this UNDER-counts, on - offset OVER-counts. So confirm direction + the actual wire format.
- next_action: RESOLVED. Fix implemented, self-verified (flutter analyze clean, 185 tests pass), and human-verified on a physical Samsung A30 device (banner reads correctly — "confirmed fixed"). Changes committed and session archived.
- reasoning_checkpoint:
    hypothesis: "The banner's 'total duration' label is fabricated by `_durationFromNowLabel(remaining)`, which buckets the REMAINING time with >= thresholds. Because remaining is always slightly below the nominal total right after start, an 8h session (remaining 7h59m, inHours=7) lands in the [4h,8h) bucket and mislabels as 'Sharing for 4 hours' while the true remaining '7h 59m' is shown separately — an internally inconsistent banner. The expiry itself is correct on every path."
    confirming_evidence:
      - ".NET probe: System.Text.Json + timestamptz round-trips Kind=Utc → 'Z' string on WRITE and GET; only Kind=Unspecified drops the Z, and that under-counts on positive-offset devices — so the backend expiry is correct."
      - "Dart trace: startTemporaryShare computes expiresAtUtc = utcNow + duration (correct); display remaining = expiresAt.difference(utcNow) is instant-based and correct. Optimistic path yields exactly the selected duration."
      - "Existing widget test asserts 'Sharing for 1 hour - 3h 30m left' for a 3h30m-remaining cell — literally encoding the mislabel bug (`_durationFromNowLabel(3h30m)` returns '1 hour')."
      - "There is NO startedAt in the model, so a true total cannot be computed; the code fakes it by bucketing remaining."
    falsification_test: "A fake-clock unit test where a session with total=8h (started now, expires now+8h) is described immediately: if the fix is right, totalLabel='8 hours' and remainingLabel='8 hours' (ceil of 7h59m59s), never '4 hours'. If it still shows '4 hours', the hypothesis/fix is wrong."
    fix_rationale: "Capture startedAtUtc client-side at session start and thread it into the SharingCell (never sent to nor required from the backend — no contract change). Derive total = expiresAt - startedAt and remaining = expiresAt - now (clamped >= 0), then render BOTH through one ceiling-rounding formatter so they can never disagree. When startedAt is unknown (GET-loaded), total falls back to ceil(remaining) so the banner stays self-consistent. This removes the broken bucketing that is the direct cause of the mislabel."
    blind_spots: "Cannot run the physical device to reproduce the exact 8h-vs-4h field value; relies on the proven fact that current code cannot over-count for a genuine 4h pick, so the screenshot is an 8h session mislabeled '4 hours'. Client-captured startedAt does not survive app restart (GET has no startedAt) — mitigated by the consistent ceil(remaining) fallback; a persistent total would require an additive backend field, deliberately avoided per scope."
- tdd_checkpoint:

## Evidence
- timestamp: 2026-07-13
  checked: privacy_center_screen.dart display path (_activeShare, _durationFromNowLabel, _remainingLabel)
  found: Banner text = "Sharing for ${durationLabel} - ${remainingLabel} left". BOTH labels derived from the SAME `remaining = expiresAt.difference(now)`. `_durationFromNowLabel` buckets remaining into 8h/4h/1h/Nmin. So the "total" label is fabricated from remaining, not the selected duration. There is NO startedAt field to derive true total.
  implication: "Sharing for 4 hours" for a 7h59m remaining is `_durationFromNowLabel(7h59m)` returning "4 hours" (inHours=7, 7>=4). The total-duration label is fundamentally broken (bucketing remaining). Also remaining=7h59m means expiresAt is ~8h ahead for a 4h pick.
- timestamp: 2026-07-13
  checked: privacy_controller.startTemporaryShare + privacyNowProvider + privacy_api serialization
  found: expiresAtUtc = DateTime.now().toUtc().add(duration).toUtc(); provider = DateTime.now().toUtc(). API sends expiresAtUtc.toUtc().toIso8601String() (WITH Z). Optimistic cell uses the same UTC value. Display now = provider (UTC). All instant-based math is correct → optimistic path shows exactly 4h.
  implication: The wrong (8h) value cannot come from the optimistic client path — it appears only AFTER the server response (or a GET) replaces the optimistic value.
- timestamp: 2026-07-13
  checked: backend UpdateSharingPreferenceCommandHandler, GetSharingMatrixQuery, SharingPreference entity, migration 20260712200555, SharingPreferenceConfiguration, Program.cs JSON config
  found: Handler stores command.ExpiresAtUtc verbatim and returns the in-memory value (no DB re-read on write). Column is `timestamp with time zone` (timestamptz). Program.cs uses default System.Text.Json (only JsonStringEnumConverter added; no custom DateTime converter).
  implication: With standard System.Text.Json (Kind=Utc → 'Z') and Npgsql timestamptz (read → Kind=Utc), the round-trip SHOULD emit a Z-suffixed string and parse correctly. Static analysis says current code round-trips correctly — contradicts the screenshot, so a link must be verified empirically (or screenshot predates current code).
- timestamp: 2026-07-13
  checked: Dart parse probe (dart tz_probe.dart), machine tz
  found: Machine is UTC+3. DateTime.parse("…Z").toUtc() = correct. DateTime.parse("… no Z").toUtc() = SUBTRACTS local offset (14:00 → 11:00Z on UTC+3), giving UNDER-count (1h for 4h). "+00:00" offset parses correct.
  implication: A missing-Z server string under-counts on positive-offset devices. The observed OVER-count (7h59m ≈ 8h for 4h) equals selected + ~4h → consistent with a phone at UTC+4 where the LOCAL wall-clock is interpreted as UTC somewhere (adds offset), OR a negative-offset device with a no-Z string.

## Eliminated
- hypothesis: The optimistic client-side computation in startTemporaryShare produces the wrong (8h) expiry.
  evidence: Traced expiresAtUtc = DateTime.now().toUtc().add(4h) = correct UTC instant 4h ahead; display remaining = expiresAt.difference(utcNow) = exactly 4h. Optimistic path is provably correct.
  timestamp: 2026-07-13

## Resolution
- root_cause: |
    Client-side display bug (no backend/timezone fault). The active-sharing banner
    read "Sharing for ${totalLabel} - ${remainingLabel} left" where the "total"
    label was fabricated by `_durationFromNowLabel(remaining)` — bucketing the
    REMAINING time with >= thresholds (>=8h→"8 hours", >=4h→"4 hours", >=1h→"1
    hour", else minutes). Because remaining is always slightly below the nominal
    total right after a session starts, every session lands one bucket too low:
    an 8h session (remaining 7h59m, inHours=7) falls in the [4h,8h) bucket and is
    mislabelled "Sharing for 4 hours" while `_remainingLabel` correctly shows
    "7h 59m" — producing the internally inconsistent "Sharing for 4 hours - 7h 59m
    left" screenshot. The expiry itself round-trips correctly on every path
    (confirmed: .NET System.Text.Json + Npgsql timestamptz emit a Z-suffixed UTC
    string; the optimistic client path computes expiry = utcNow + duration
    exactly). There was also no startedAt in the model, so a true total could not
    be computed at all.
- fix: |
    Client-only, no backend contract change. (1) Added a client-captured
    `startedAtUtc` to SharingCell (never sent to nor required from the backend;
    tolerated in fromJson/toJson). (2) Threaded it through PrivacyController.toggle
    and set it in startTemporaryShare from the same clock read as the expiry, and
    re-attached it after the server response (which does not echo it). (3) Added a
    single ceiling-rounding formatter `formatShareDuration` and a single source-of-
    truth `SharingCell.describeActiveShare({now})` returning `ActiveShareView`
    (totalLabel from expiresAt-startedAt, remainingLabel from expiresAt-now clamped
    >= 0; total falls back to ceil(remaining) when startedAt is unknown so the two
    labels can never disagree; returns null when disabled/no-expiry/expired). (4)
    Replaced the screen's `_activeShare`/`_ActiveShare`/`_durationFromNowLabel`/
    `_remainingLabel` with the model helper. Banner now reads e.g. "Sharing for 8
    hours - 8 hours left".
- verification: |
    flutter analyze (whole project): No issues found.
    flutter test (whole project): All 185 tests passed, including:
      - sharing_duration_test.dart: ceiling rounding (3h59m→"4 hours", 3h00m→"3
        hours"), fresh 4h→"4 hours"/"4 hours left", REGRESSION 8h-one-minute-in→
        "8 hours" (NOT "4 hours"), countdown 4h→3h→1h, expired→no banner (clamped),
        no-startedAt fallback.
      - privacy_controller_test.dart: 4h records startedAt=10:00 + expiresAt=14:00
        (start re-attached after fake API drops it); stale 8h session fully
        replaced by a new 4h session.
      - privacy_center_screen_test.dart: banner updated from the old buggy
        "Sharing for 1 hour - 3h 30m left" to "Sharing for 4 hours - 4 hours left".
    Backend untouched (expiry proven correct via evidence) — no dotnet build/test
    needed for changed layers.
    HUMAN VERIFICATION (2026-07-14): Fix confirmed on a physical Samsung A30
    device. A freshly started 4-hour temporary share now displays a self-consistent
    banner ("Sharing for 4 hours - 4 hours left") instead of the previous
    "Sharing for 4 hours - 7h 59m left". User reported "confirmed fixed".
- files_changed:
    - mobile/lib/features/privacy/data/privacy_models.dart (startedAtUtc, ActiveShareView, formatShareDuration, describeActiveShare)
    - mobile/lib/features/privacy/application/privacy_controller.dart (thread + re-attach startedAtUtc)
    - mobile/lib/features/privacy/presentation/privacy_center_screen.dart (use single source of truth; removed buggy helpers)
    - mobile/test/features/privacy/sharing_duration_test.dart (new deterministic fake-clock tests)
    - mobile/test/features/privacy/privacy_controller_test.dart (4h expiry/start + stale-replacement tests)
    - mobile/test/features/privacy/privacy_center_screen_test.dart (updated banner assertion + spy toggle signature)
