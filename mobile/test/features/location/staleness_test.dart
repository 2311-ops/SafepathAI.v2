import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/location/application/staleness.dart';

void main() {
  group('stalenessFor', () {
    test('keeps live pings fully opaque with no badge before 2 minutes', () {
      final band = stalenessFor(const Duration(minutes: 1, seconds: 59));

      expect(band.opacity, 1);
      expect(band.badgeText, isNull);
      expect(band.badgeIsAmber, isFalse);
    });

    test('uses the recent stale band at the 2 minute edge', () {
      final band = stalenessFor(const Duration(minutes: 2));

      expect(band.opacity, 0.7);
      expect(band.badgeText, 'Last seen 2 min ago');
      expect(band.badgeIsAmber, isFalse);
    });

    test('uses the amber stale band at the 15 minute edge', () {
      final band = stalenessFor(const Duration(minutes: 15));

      expect(band.opacity, 0.45);
      expect(band.badgeText, 'Last seen 15 min ago');
      expect(band.badgeIsAmber, isTrue);
    });

    test('uses the oldest floor band at the 1 hour edge', () {
      final band = stalenessFor(const Duration(hours: 1));

      expect(band.opacity, 0.3);
      expect(band.badgeText, 'Last seen 1 hr ago');
      expect(band.badgeIsAmber, isTrue);
    });

    test('never fades below the 0.3 floor for very old pings', () {
      final band = stalenessFor(const Duration(days: 3));

      expect(band.opacity, 0.3);
      expect(band.badgeText, 'Last seen 3 days ago');
      expect(band.badgeIsAmber, isTrue);
    });
  });

  group('isStaleAge', () {
    test('is fresh just below kStaleThreshold', () {
      expect(
        isStaleAge(const Duration(minutes: 2, seconds: 59)),
        isFalse,
      );
    });

    test('is stale exactly at kStaleThreshold', () {
      expect(isStaleAge(const Duration(minutes: 3)), isTrue);
    });

    test('is stale above kStaleThreshold', () {
      expect(isStaleAge(const Duration(minutes: 10)), isTrue);
    });

    test('treats a negative age (clock skew) as fresh', () {
      expect(isStaleAge(const Duration(seconds: -5)), isFalse);
    });
  });

  group('accuracyCircleRadius', () {
    test('renders highly accurate fixes with a 24px minimum radius', () {
      expect(accuracyCircleRadius(8), 24);
      expect(accuracyCircleRadius(24), 24);
    });

    test('maps accuracy meters 1:1 once above the minimum radius', () {
      expect(accuracyCircleRadius(42), 42);
    });
  });
}
