import 'dart:math' as math;

import 'package:flutter/rendering.dart' show Size;
import 'package:flutter_test/flutter_test.dart';

import 'package:mobile/features/location/presentation/vector_map.dart';

/// Metres per pixel at the equator at zoom 0, for MapLibre's 512-pixel tile
/// scheme: the WGS84 equatorial circumference divided by the 512 pixels the
/// world spans at zoom 0. Stated independently of `projectToScreen` so these
/// tests anchor the projection to a physical constant rather than to itself —
/// if the implementation ever switched to the 256-pixel tile convention, every
/// distance assertion below would be out by exactly 2x.
const double _equatorCircumferenceMeters = 40075016.686;
const double _metersPerPixelAtZoom0 = _equatorCircumferenceMeters / 512.0;
const double _metersPerDegreeLngAtEquator = _equatorCircumferenceMeters / 360.0;

void main() {
  group('projectToScreen', () {
    const viewport = Size(400, 800);

    test('places a marker on the camera centre at the viewport centre', () {
      final offset = projectToScreen(
        lat: 30.0444,
        lng: 31.2357,
        cameraLat: 30.0444,
        cameraLng: 31.2357,
        zoom: 15,
        viewport: viewport,
      );

      expect(offset.dx, closeTo(200, 1e-9));
      expect(offset.dy, closeTo(400, 1e-9));
    });

    test('scales eastward metres to pixels at MapLibre 512-tile resolution', () {
      // Anchors the zoom -> pixel convention to a real-world distance: 1 km east
      // of the camera at the equator must land exactly 1 km / metres-per-pixel
      // to the right of centre.
      const zoom = 15.0;
      const eastMeters = 1000.0;
      final metersPerPixel = _metersPerPixelAtZoom0 / math.pow(2.0, zoom);
      final expectedDx = eastMeters / metersPerPixel;

      final offset = projectToScreen(
        lat: 0,
        lng: eastMeters / _metersPerDegreeLngAtEquator,
        cameraLat: 0,
        cameraLng: 0,
        zoom: zoom,
        viewport: viewport,
      );

      expect(offset.dx - viewport.width / 2, closeTo(expectedDx, 1e-6));
      expect(offset.dy, closeTo(viewport.height / 2, 1e-9));
    });

    test('doubles pixel displacement for each zoom level', () {
      double dxAtZoom(double zoom) =>
          projectToScreen(
            lat: 0,
            lng: 0.01,
            cameraLat: 0,
            cameraLng: 0,
            zoom: zoom,
            viewport: viewport,
          ).dx -
          viewport.width / 2;

      expect(dxAtZoom(15), closeTo(dxAtZoom(14) * 2, 1e-9));
      expect(dxAtZoom(16), closeTo(dxAtZoom(14) * 4, 1e-9));
    });

    test('puts north above the camera and south below it', () {
      final north = projectToScreen(
        lat: 0.01,
        lng: 0,
        cameraLat: 0,
        cameraLng: 0,
        zoom: 15,
        viewport: viewport,
      );
      final south = projectToScreen(
        lat: -0.01,
        lng: 0,
        cameraLat: 0,
        cameraLng: 0,
        zoom: 15,
        viewport: viewport,
      );

      expect(north.dy, lessThan(viewport.height / 2));
      expect(south.dy, greaterThan(viewport.height / 2));
      // Mercator is symmetric about the equator.
      expect(
        viewport.height / 2 - north.dy,
        closeTo(south.dy - viewport.height / 2, 1e-9),
      );
    });

    test('matches metre scaling northward as well as eastward', () {
      // At the equator a Mercator pixel is square, so 1 km north must displace
      // by the same number of pixels as 1 km east. This is what keeps a pin
      // glued to its coordinate rather than drifting on one axis only.
      const zoom = 15.0;
      const meters = 1000.0;
      const metersPerDegreeLat = _equatorCircumferenceMeters / 360.0;

      final east = projectToScreen(
        lat: 0,
        lng: meters / _metersPerDegreeLngAtEquator,
        cameraLat: 0,
        cameraLng: 0,
        zoom: zoom,
        viewport: viewport,
      );
      final north = projectToScreen(
        lat: meters / metersPerDegreeLat,
        lng: 0,
        cameraLat: 0,
        cameraLng: 0,
        zoom: zoom,
        viewport: viewport,
      );

      expect(
        east.dx - viewport.width / 2,
        closeTo(viewport.height / 2 - north.dy, 1e-3),
      );
    });

    test('takes the short way around the antimeridian', () {
      // A marker at -179.9 seen from a camera at +179.9 is 0.2 degrees east,
      // not 359.8 degrees west. Without normalisation the pin would be flung a
      // whole world-width off-screen.
      final offset = projectToScreen(
        lat: 0,
        lng: -179.9,
        cameraLat: 0,
        cameraLng: 179.9,
        zoom: 10,
        viewport: viewport,
      );

      final worldSize = 512 * math.pow(2.0, 10);
      final expectedDx = (0.2 / 360.0) * worldSize;

      expect(offset.dx - viewport.width / 2, closeTo(expectedDx, 1e-6));
    });

    test('stays finite at the poles', () {
      // tan(pi/4 + rad/2) diverges at +/-90 degrees; latitudes are clamped to
      // the Mercator limit so a bad coordinate can never produce an infinite or
      // NaN Positioned offset (which would throw during layout).
      for (final lat in [90.0, -90.0, 89.999, -89.999]) {
        final offset = projectToScreen(
          lat: lat,
          lng: 0,
          cameraLat: 0,
          cameraLng: 0,
          zoom: 15,
          viewport: viewport,
        );

        expect(offset.dx.isFinite, isTrue, reason: 'lat $lat');
        expect(offset.dy.isFinite, isTrue, reason: 'lat $lat');
      }
    });

    test('centres on the viewport it is given, not the screen', () {
      // RouteStatsSheet embeds a VectorMap in a 360px-tall box rather than
      // full-screen, so the centre must come from the map's own layout size.
      const small = Size(300, 360);
      final offset = projectToScreen(
        lat: 30,
        lng: 31,
        cameraLat: 30,
        cameraLng: 31,
        zoom: 15,
        viewport: small,
      );

      expect(offset.dx, closeTo(150, 1e-9));
      expect(offset.dy, closeTo(180, 1e-9));
    });
  });
}
