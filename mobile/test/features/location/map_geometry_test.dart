import 'package:flutter_test/flutter_test.dart';

import 'package:mobile/features/location/application/map_geometry.dart';

void main() {
  group('geodesicRing', () {
    test('returns 65 points with the default 64 segments', () {
      final ring = geodesicRing(const MapPoint(30.0444, 31.2357), 100);
      expect(ring.length, 65);
    });

    test('is closed: first point equals last point', () {
      final ring = geodesicRing(const MapPoint(30.0444, 31.2357), 100);
      expect(ring.first, ring.last);
    });

    test(
      'at latitude 30, a 100m ring spans the expected lat/lng offsets',
      () {
        const center = MapPoint(30.0, 0.0);
        final ring = geodesicRing(center, 100);

        // Find the point directly north (max latitude) and directly east
        // (max longitude) of center to read off the ring's span.
        final maxLat = ring.map((p) => p.lat).reduce((a, b) => a > b ? a : b);
        final maxLng = ring.map((p) => p.lng).reduce((a, b) => a > b ? a : b);

        expect(maxLat - center.lat, closeTo(0.000898, 1e-6));
        expect(maxLng - center.lng, closeTo(0.001037, 1e-6));
      },
    );

    test('doubling the radius doubles both spans', () {
      const center = MapPoint(30.0, 0.0);
      final ring100 = geodesicRing(center, 100);
      final ring200 = geodesicRing(center, 200);

      final maxLat100 = ring100
          .map((p) => p.lat)
          .reduce((a, b) => a > b ? a : b);
      final maxLng100 = ring100
          .map((p) => p.lng)
          .reduce((a, b) => a > b ? a : b);
      final maxLat200 = ring200
          .map((p) => p.lat)
          .reduce((a, b) => a > b ? a : b);
      final maxLng200 = ring200
          .map((p) => p.lng)
          .reduce((a, b) => a > b ? a : b);

      expect(
        maxLat200 - center.lat,
        closeTo((maxLat100 - center.lat) * 2, 1e-9),
      );
      expect(
        maxLng200 - center.lng,
        closeTo((maxLng100 - center.lng) * 2, 1e-9),
      );
    });

    test('segments: 8 returns 9 points', () {
      final ring = geodesicRing(
        const MapPoint(30.0444, 31.2357),
        100,
        segments: 8,
      );
      expect(ring.length, 9);
    });

    test('a radius of 0 returns an empty list', () {
      final ring = geodesicRing(const MapPoint(30.0444, 31.2357), 0);
      expect(ring, isEmpty);
    });

    test('a negative radius returns an empty list', () {
      final ring = geodesicRing(const MapPoint(30.0444, 31.2357), -10);
      expect(ring, isEmpty);
    });

    test('a NaN radius returns an empty list', () {
      final ring = geodesicRing(const MapPoint(30.0444, 31.2357), double.nan);
      expect(ring, isEmpty);
    });

    test('an infinite radius returns an empty list', () {
      final ring = geodesicRing(
        const MapPoint(30.0444, 31.2357),
        double.infinity,
      );
      expect(ring, isEmpty);
    });

    test('a near-polar center returns an empty list (near-zero cosine)', () {
      final ring = geodesicRing(const MapPoint(90.0, 0.0), 100);
      expect(ring, isEmpty);
    });
  });

  group('MapPoint', () {
    test('has value equality', () {
      expect(const MapPoint(1.0, 2.0), const MapPoint(1.0, 2.0));
      expect(
        const MapPoint(1.0, 2.0).hashCode,
        const MapPoint(1.0, 2.0).hashCode,
      );
    });

    test('is const-constructible', () {
      const point = MapPoint(1.0, 2.0);
      expect(point.lat, 1.0);
      expect(point.lng, 2.0);
    });
  });
}
