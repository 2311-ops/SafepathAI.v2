import 'dart:math';

/// SafePath's own coordinate value type, so screens and application-layer
/// code never need to name a plugin type or a third-party coordinate
/// package directly (see `vector_map.dart`).
class MapPoint {
  const MapPoint(this.lat, this.lng);

  final double lat;
  final double lng;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MapPoint && other.lat == lat && other.lng == lng);

  @override
  int get hashCode => Object.hash(lat, lng);

  @override
  String toString() => 'MapPoint($lat, $lng)';
}

/// Earth radius in metres, used to convert a metre radius into degree
/// offsets for [geodesicRing].
const double _earthRadiusMeters = 6378137.0;

/// Generates a closed ring of [MapPoint]s approximating a circle of
/// [radiusMeters] around [center], measured in real-world metres rather
/// than screen pixels — so an accuracy indicator drawn from this ring keeps
/// the same real-world footprint at every zoom level.
///
/// The longitude offset is scaled by `1 / cos(latitude)` so the ring stays
/// circular on the ground rather than in degree space (a degree of
/// longitude is shorter than a degree of latitude away from the equator).
///
/// Returns an empty list for a non-positive, NaN or infinite radius, and
/// also when `cos(latitude)` is within `1e-9` of zero (a near-polar centre
/// would otherwise divide by ~0 and emit garbage coordinates).
List<MapPoint> geodesicRing(
  MapPoint center,
  double radiusMeters, {
  int segments = 64,
}) {
  if (radiusMeters.isNaN || radiusMeters.isInfinite || radiusMeters <= 0) {
    return const [];
  }

  final latRad = center.lat * pi / 180.0;
  final cosLat = cos(latRad);
  if (cosLat.abs() < 1e-9) {
    return const [];
  }

  final deltaLatDegrees = (radiusMeters / _earthRadiusMeters) * (180.0 / pi);
  final deltaLngDegrees = deltaLatDegrees / cosLat;

  return [
    for (var i = 0; i <= segments; i++)
      _ringPoint(center, deltaLatDegrees, deltaLngDegrees, i, segments),
  ];
}

MapPoint _ringPoint(
  MapPoint center,
  double deltaLatDegrees,
  double deltaLngDegrees,
  int step,
  int segments,
) {
  final theta = 2 * pi * step / segments;
  return MapPoint(
    center.lat + deltaLatDegrees * sin(theta),
    center.lng + deltaLngDegrees * cos(theta),
  );
}
