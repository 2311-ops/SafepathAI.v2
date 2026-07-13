import 'package:flutter_test/flutter_test.dart';

import 'package:mobile/features/privacy/data/privacy_models.dart';

/// Deterministic, clock-free tests for the temporary-sharing duration display.
///
/// Every case passes an explicit `now` (or explicit start/expiry instants) — no
/// `DateTime.now()` — so results never depend on the machine's wall clock or
/// timezone. This is the regression guard for the "Sharing for 4 hours - 7h 59m
/// left" bug, where the total-duration label was fabricated by bucketing the
/// remaining time instead of being derived from startedAt/expiresAt.
void main() {
  SharingCell cell({
    DateTime? startedAtUtc,
    DateTime? expiresAtUtc,
    bool isEnabled = true,
  }) {
    return SharingCell(
      recipientId: 'mem-1',
      dataType: SharedDataType.liveLocation,
      isEnabled: isEnabled,
      startedAtUtc: startedAtUtc,
      expiresAtUtc: expiresAtUtc,
    );
  }

  group('formatShareDuration (ceiling rounding)', () {
    test('3h59m rounds up to "4 hours"', () {
      expect(
        formatShareDuration(const Duration(hours: 3, minutes: 59)),
        '4 hours',
      );
    });

    test('exactly 3h00m stays "3 hours"', () {
      expect(formatShareDuration(const Duration(hours: 3)), '3 hours');
    });

    test('exactly 4h stays "4 hours"', () {
      expect(formatShareDuration(const Duration(hours: 4)), '4 hours');
    });

    test('a few seconds under 4h still reads "4 hours"', () {
      expect(
        formatShareDuration(
          const Duration(hours: 3, minutes: 59, seconds: 59),
        ),
        '4 hours',
      );
    });

    test('exactly 1h uses the singular "1 hour"', () {
      expect(formatShareDuration(const Duration(hours: 1)), '1 hour');
    });

    test('sub-hour durations report ceiling minutes', () {
      expect(formatShareDuration(const Duration(minutes: 30)), '30 minutes');
      expect(formatShareDuration(const Duration(minutes: 1)), '1 minute');
      expect(
        formatShareDuration(const Duration(minutes: 44, seconds: 30)),
        '45 minutes',
      );
    });

    test('59m30s rolls up to "1 hour" rather than "60 minutes"', () {
      expect(
        formatShareDuration(const Duration(minutes: 59, seconds: 30)),
        '1 hour',
      );
    });

    test('zero and negative durations clamp to "0 minutes"', () {
      expect(formatShareDuration(Duration.zero), '0 minutes');
      expect(formatShareDuration(const Duration(minutes: -5)), '0 minutes');
    });
  });

  group('SharingCell.describeActiveShare', () {
    final start = DateTime.utc(2026, 7, 13, 10);

    test('a brand-new 4h session shows total and remaining both "4 hours"', () {
      final view = cell(
        startedAtUtc: start,
        expiresAtUtc: start.add(const Duration(hours: 4)),
      ).describeActiveShare(now: start.add(const Duration(seconds: 1)));

      expect(view, isNotNull);
      expect(view!.totalLabel, '4 hours');
      expect(view.remainingLabel, '4 hours');
    });

    test(
      'regression: an 8h session one minute in is NOT mislabelled "4 hours"',
      () {
        // This is the exact screenshot scenario: an 8-hour session started a
        // minute ago has 7h59m left. The old bucketing showed
        // "Sharing for 4 hours - 7h 59m left"; it must now read "8 hours".
        final view = cell(
          startedAtUtc: start,
          expiresAtUtc: start.add(const Duration(hours: 8)),
        ).describeActiveShare(now: start.add(const Duration(minutes: 1)));

        expect(view, isNotNull);
        expect(view!.totalLabel, '8 hours');
        expect(view.remainingLabel, '8 hours');
      },
    );

    test('the total stays fixed while the remaining counts down', () {
      final session = cell(
        startedAtUtc: start,
        expiresAtUtc: start.add(const Duration(hours: 4)),
      );

      // 1 hour in: 3h left exactly -> "3 hours left", total unchanged.
      final afterOneHour =
          session.describeActiveShare(now: start.add(const Duration(hours: 1)));
      expect(afterOneHour!.totalLabel, '4 hours');
      expect(afterOneHour.remainingLabel, '3 hours');

      // 1s past the 1-hour mark: 2h59m59s left -> ceil -> "3 hours left".
      final justPast = session.describeActiveShare(
        now: start.add(const Duration(hours: 1, seconds: 1)),
      );
      expect(justPast!.totalLabel, '4 hours');
      expect(justPast.remainingLabel, '3 hours');

      // 3h in: 1h left -> "1 hour left".
      final nearEnd =
          session.describeActiveShare(now: start.add(const Duration(hours: 3)));
      expect(nearEnd!.totalLabel, '4 hours');
      expect(nearEnd.remainingLabel, '1 hour');
    });

    test('an expired session shows no banner (clamped, never negative)', () {
      final expired = cell(
        startedAtUtc: start,
        expiresAtUtc: start.add(const Duration(hours: 4)),
      );

      // Exactly at expiry.
      expect(
        expired.describeActiveShare(now: start.add(const Duration(hours: 4))),
        isNull,
      );
      // Well past expiry — must not produce a negative "remaining".
      expect(
        expired.describeActiveShare(now: start.add(const Duration(hours: 5))),
        isNull,
      );
    });

    test('disabled or expiry-less cells are never active', () {
      expect(
        cell(isEnabled: false, expiresAtUtc: start.add(const Duration(hours: 4)))
            .describeActiveShare(now: start),
        isNull,
      );
      expect(
        cell(expiresAtUtc: null).describeActiveShare(now: start),
        isNull,
      );
    });

    test(
      'without a captured start, total falls back to the ceil of remaining',
      () {
        // Server-restored session (no startedAtUtc): the total is unknown, so
        // the banner shows the remaining for both labels and stays consistent —
        // never total < remaining, never the old "4 hours vs 7h 59m" mismatch.
        final view = cell(expiresAtUtc: start.add(const Duration(hours: 8)))
            .describeActiveShare(now: start.add(const Duration(minutes: 1)));

        expect(view!.totalLabel, '8 hours');
        expect(view.remainingLabel, '8 hours');
      },
    );
  });
}
