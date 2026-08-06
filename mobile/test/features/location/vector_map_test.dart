import 'dart:math' show Point;

import 'package:flutter_test/flutter_test.dart';

import 'package:mobile/features/location/presentation/vector_map.dart';

void main() {
  group('physicalToLogicalOffset', () {
    test(
      'divides a physical-pixel screen-projection point by devicePixelRatio',
      () {
        // Regression case: on-device testing found toScreenLocationBatch
        // returns PHYSICAL pixels (e.g. exactly half of a 1080x2400
        // physical-pixel screen), which must be converted to LOGICAL pixels
        // before feeding a Positioned/Offset - otherwise every marker lands
        // roughly devicePixelRatio times further right/down than correct,
        // typically off-screen entirely.
        const devicePixelRatio = 2.625;
        final offset = physicalToLogicalOffset(
          const Point(540.75, 1200.9375),
          devicePixelRatio,
        );

        expect(offset.dx, closeTo(206.0, 1e-9));
        expect(offset.dy, closeTo(457.5, 1e-9));
      },
    );

    test('is a no-op at devicePixelRatio 1.0', () {
      final offset = physicalToLogicalOffset(const Point(123.0, 456.0), 1.0);

      expect(offset.dx, 123.0);
      expect(offset.dy, 456.0);
    });

    test('handles integer-valued Point coordinates', () {
      final offset = physicalToLogicalOffset(const Point(100, 200), 2.0);

      expect(offset.dx, 50.0);
      expect(offset.dy, 100.0);
    });
  });
}
