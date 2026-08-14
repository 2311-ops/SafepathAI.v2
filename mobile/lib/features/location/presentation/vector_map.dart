import 'dart:math' as math;
import 'dart:math' show Point;

import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../application/map_geometry.dart';

/// OpenFreeMap's flat, top-down Liberty vector-tile style (D-01). Hard-coded
/// because it takes no API key and is not user input, and self-hosting the
/// tiles is explicitly deferred (D-02).
const kOpenFreeMapLibertyStyle = 'https://tiles.openfreemap.org/styles/liberty';

/// Formats a Flutter [Color] as `#RRGGBB` for the plugin's CSS/hex color
/// fields. Alpha is deliberately not encoded here - annotation opacity is a
/// separate field on each option object (`fillOpacity`, `outlineOpacity`,
/// `opacity`), and mixing the two would double-apply transparency.
String hexColor(Color color) {
  final argb = color.toARGB32() & 0xFFFFFF;
  return '#${argb.toRadixString(16).padLeft(6, '0')}';
}

/// MapLibre's core renderer projects through 512-pixel tiles, so at zoom `z`
/// the whole world spans `512 * 2^z` pixels. Those are LOGICAL (density-
/// independent) pixels: MapLibre Android hands the core a viewport already
/// divided by the display density (`resizeView(w / pixelRatio, ...)`) and
/// multiplies the core's answer back up in `NativeMapView.pixelForLatLng`.
/// Working in the core's own units therefore lands directly in the logical
/// pixel space `Positioned` expects, with no density conversion anywhere.
const double _kTileSize = 512.0;

/// The latitude at which the Web Mercator projection is truncated to keep the
/// world square. Beyond it the projection diverges toward infinity.
const double _kMaxMercatorLatitude = 85.05112878;

/// Normalised Web Mercator northing in `[0, 1]`, increasing southward.
double _mercatorY(double latitude) {
  final clamped = latitude.clamp(-_kMaxMercatorLatitude, _kMaxMercatorLatitude);
  final radians = clamped * math.pi / 180.0;
  return 0.5 - math.log(math.tan(math.pi / 4 + radians / 2)) / (2 * math.pi);
}

/// Projects a geographic coordinate to a logical-pixel [Offset] within a map
/// viewport of [viewport] size, given the camera's current centre and zoom.
///
/// This deliberately replaces the previous `toScreenLocationBatch()` platform-
/// channel round trip. The plugin assigns `controller.cameraPosition`
/// synchronously *before* it fires the change notification that drives
/// reprojection, so every input needed here is already in Dart memory at that
/// moment - asking the native side to recompute it bought nothing but latency,
/// and because that latency varies per call the marker's applied offset
/// advanced in irregular increments during a pan, which is what read as the
/// pin "rolling"/vibrating rather than trailing smoothly.
///
/// Assumes a north-up, unpitched camera. That is not an assumption about
/// defaults but an invariant this widget enforces: D-01 requires the map stay
/// flat and top-down, and [VectorMap] hard-disables both tilt and rotate
/// gestures, so bearing and pitch are always zero.
@visibleForTesting
Offset projectToScreen({
  required double lat,
  required double lng,
  required double cameraLat,
  required double cameraLng,
  required double zoom,
  required Size viewport,
}) {
  final worldSize = _kTileSize * math.pow(2.0, zoom);

  // Normalise across the antimeridian so a marker just east of +180 doesn't
  // project a whole world-width away from a camera just west of it. Dart's `%`
  // takes the divisor's sign, so this maps any delta into (-180, 180].
  final deltaLng = (lng - cameraLng + 180.0) % 360.0 - 180.0;

  return Offset(
    viewport.width / 2 + (deltaLng / 360.0) * worldSize,
    viewport.height / 2 + (_mercatorY(lat) - _mercatorY(cameraLat)) * worldSize,
  );
}

/// An immutable camera-move intent: where the camera should go and at what
/// zoom. Written by screens, forwarded to the native camera by [VectorMap],
/// and read back by widget tests via [VectorMapController.lastCommand].
class CameraCommand {
  const CameraCommand({
    required this.lat,
    required this.lng,
    required this.zoom,
  });

  final double lat;
  final double lng;
  final double zoom;
}

/// The camera-command sink that replaces the pre-migration test-owned map
/// controller.
///
/// A real `MapLibreMapController` is only handed out by [VectorMap]'s
/// `onMapCreated` callback and cannot be constructed directly in a widget
/// test. Screens write their camera *intent* here via [animateTo];
/// production [VectorMap] forwards that intent to the native camera, while
/// widget tests assert against [lastCommand] instead of a resulting camera
/// position.
class VectorMapController extends ChangeNotifier {
  CameraCommand? _lastCommand;

  /// The most recently requested camera move, or null if none has been
  /// requested yet.
  CameraCommand? get lastCommand => _lastCommand;

  /// Requests the camera animate to the given [lat]/[lng] at [zoom].
  void animateTo({
    required double lat,
    required double lng,
    required double zoom,
  }) {
    _lastCommand = CameraCommand(lat: lat, lng: lng, zoom: zoom);
    notifyListeners();
  }
}

/// Describes a screen-space Flutter widget positioned above the map at a
/// real-world coordinate, reprojected on every camera movement. Used for
/// family pins and route-stop pins, both of which need design-system
/// styling, an avatar image, a Semantics label and/or a tap target - none of
/// which the plugin's native symbol annotations can host.
class OverlayMarker {
  const OverlayMarker({
    required this.id,
    required this.lat,
    required this.lng,
    required this.width,
    required this.height,
    required this.child,
  });

  /// Stable identity used to key screen positions across rebuilds.
  final String id;
  final double lat;
  final double lng;
  final double width;
  final double height;
  final Widget child;
}

/// A native-rendered accuracy circle, drawn as a metre-accurate geodesic
/// fill (see [geodesicRing]) rather than the plugin's own screen-pixel
/// circle annotation, plus a companion outline line since the fill option
/// object exposes no outline width.
class MapCircle {
  const MapCircle({
    required this.id,
    required this.center,
    required this.radiusMeters,
    required this.colorHex,
    this.fillOpacity = 0.15,
    this.outlineOpacity = 0.40,
    this.outlineWidth = 2.0,
  });

  final String id;
  final MapPoint center;
  final double radiusMeters;
  final String colorHex;
  final double fillOpacity;
  final double outlineOpacity;
  final double outlineWidth;
}

/// A native-rendered polyline, used for the route history track.
class MapLine {
  const MapLine({
    required this.points,
    required this.colorHex,
    this.width = 5.0,
    this.opacity = 1.0,
  });

  final List<MapPoint> points;
  final String colorHex;
  final double width;
  final double opacity;
}

/// A native-rendered screen-pixel dot anchored to a geographic point.
///
/// Used as the in-motion stand-in for a richer Flutter marker widget: the dot
/// moves in lockstep with the basemap because both are rendered natively,
/// while the richer Flutter widget can remain reserved for idle frames where
/// it does not jitter against the map.
class MapDot {
  const MapDot({
    required this.id,
    required this.center,
    required this.radius,
    required this.colorHex,
    required this.opacity,
    required this.strokeColorHex,
    this.strokeWidth = 3.0,
    this.strokeOpacity = 1.0,
  });

  final String id;
  final MapPoint center;
  final double radius;
  final String colorHex;
  final double opacity;
  final String strokeColorHex;
  final double strokeWidth;
  final double strokeOpacity;
}

/// The single widget in `mobile/lib` permitted to import `maplibre_gl` (a
/// grep gate enforces this). Both `LiveMapScreen` and `RouteStatsSheet`
/// describe *what* to draw via [markers]/[circles]/[lines] and never touch a
/// plugin type directly.
///
/// Pins stay Flutter widgets, positioned in a `Stack` above the native map
/// and reprojected from the native projection via `toScreenLocationBatch()`
/// (MapLibre's documented `custom_marker` pattern) - the plugin's native
/// symbol annotations cannot host a widget tree. Geometry with no widget
/// content or tap target (the accuracy circle, the route line) is drawn as a
/// native annotation instead, for free GPU rendering and correct zoom
/// behaviour.
class VectorMap extends StatefulWidget {
  const VectorMap({
    super.key,
    required this.initialTarget,
    required this.initialZoom,
    this.controller,
    this.markers = const [],
    this.circles = const [],
    this.lines = const [],
    this.dots = const [],
    this.onTap,
    @visibleForTesting this.platformViewBuilder,
  });

  final MapPoint initialTarget;
  final double initialZoom;
  final VectorMapController? controller;
  final List<OverlayMarker> markers;
  final List<MapCircle> circles;
  final List<MapLine> lines;
  final List<MapDot> dots;
  final ValueChanged<MapPoint>? onTap;

  /// Test seam: when supplied, this builder replaces the native map view
  /// entirely so a widget test never mounts a real platform view (which has
  /// no test implementation and throws on the platform-views channel).
  /// Production callers leave this null.
  @visibleForTesting
  final WidgetBuilder? platformViewBuilder;

  @override
  State<VectorMap> createState() => _VectorMapState();
}

class _VectorMapState extends State<VectorMap> {
  MapLibreMapController? _mapController;
  bool _styleLoaded = false;
  late final ValueNotifier<CameraPosition?> _cameraPosition =
      ValueNotifier<CameraPosition?>(null);
  late final ValueNotifier<bool> _isCameraMoving = ValueNotifier<bool>(false);

  @override
  void initState() {
    super.initState();
    // Force Hybrid Composition (texture-based rendering) on Android instead
    // of the plugin's actual default of legacy Virtual-Display rendering
    // (the doc comment on MapLibreMap.useHybridComposition claims a `true`
    // default, but the underlying static field is initialized to `false`).
    // Under Virtual Display, the native `getProjection().toScreenLocation()`
    // calls behind toScreenLocationBatch return coordinates relative to the
    // offscreen virtual-display surface, not this widget's real on-screen
    // position - so every OverlayMarker gets a wrong/degenerate offset that
    // falls outside the Stack's default hard-edge clip and never becomes
    // visible, while native geometry (the accuracy circle, drawn directly in
    // lat/lng space) is unaffected. This matches the plan's own threat
    // register (T-3ZB-03), which already assumed hybrid composition would be
    // active and pinned plugin 0.26.2 specifically because it fixed
    // hybrid-composition crashes on older Android hardware. A global static
    // setter is the plugin's own API for this - safe to set redundantly on
    // every VectorMap instance.
    MapLibreMap.useHybridComposition = true;
    widget.controller?.addListener(_onCameraCommand);
  }

  @override
  void didUpdateWidget(covariant VectorMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.removeListener(_onCameraCommand);
      widget.controller?.addListener(_onCameraCommand);
    }
    if (_styleLoaded &&
        (!identical(oldWidget.circles, widget.circles) ||
            !identical(oldWidget.lines, widget.lines) ||
            !identical(oldWidget.dots, widget.dots))) {
      _drawAnnotations();
    }
    // Markers need no explicit reprojection step any more: they are projected
    // synchronously in build() from the live camera, so this rebuild has
    // already repositioned them.
  }

  @override
  void dispose() {
    widget.controller?.removeListener(_onCameraCommand);
    // Symmetric with _onMapCreated's controller.addListener(_onControllerNotified)
    // - without this, a camera-changed notification firing after this State
    // disposes but before the native platform view itself fully tears down
    // (a real race when popping the screen or switching tabs mid-pan) would
    // still invoke _onControllerNotified on a disposed State.
    // _onControllerNotified's own `if (!mounted) return;` guard is a second,
    // independent line of defence for that same race.
    _mapController?.removeListener(_onControllerNotified);
    _cameraPosition.dispose();
    _isCameraMoving.dispose();
    super.dispose();
  }

  void _onCameraCommand() {
    final command = widget.controller?.lastCommand;
    final controller = _mapController;
    if (command == null || controller == null) return;
    controller.animateCamera(
      CameraUpdate.newLatLngZoom(
        LatLng(command.lat, command.lng),
        command.zoom,
      ),
      duration: const Duration(milliseconds: 300),
    );
  }

  void _onMapCreated(MapLibreMapController controller) {
    _mapController = controller;
    _cameraPosition.value = controller.cameraPosition;
    _isCameraMoving.value = controller.isCameraMoving;
    controller.addListener(_onControllerNotified);
    // A camera command issued before the native map existed would otherwise be
    // dropped on the floor by _onCameraCommand's null-controller guard. That is
    // a real ordering, not a hypothetical: the screen asks to centre on the
    // user's live position as soon as it knows it, which can easily land while
    // the platform view is still being created.
    _onCameraCommand();
  }

  void _onControllerNotified() {
    // Keep camera-tick rebuilds off the PlatformView subtree itself: only the
    // overlay layer needs the new camera, not the MapLibre widget config.
    if (!mounted) return;
    _cameraPosition.value = _mapController?.cameraPosition;
    _isCameraMoving.value = _mapController?.isCameraMoving ?? false;
  }

  Future<void> _onStyleLoaded() async {
    _styleLoaded = true;
    await _drawAnnotations();
  }

  void _onCameraIdle() {
    // Seed the final settled camera even if the last move callback was skipped
    // or coalesced by the native side.
    if (!mounted) return;
    _cameraPosition.value = _mapController?.cameraPosition;
    _isCameraMoving.value = false;
  }

  Future<void> _drawAnnotations() async {
    final controller = _mapController;
    if (controller == null) return;

    await controller.clearFills();
    await controller.clearLines();
    await controller.clearCircles();

    for (final circle in widget.circles) {
      final ring = geodesicRing(circle.center, circle.radiusMeters);
      if (ring.isEmpty) continue;
      final geometry = [
        [for (final point in ring) LatLng(point.lat, point.lng)],
      ];
      await controller.addFill(
        FillOptions(
          geometry: geometry,
          fillColor: circle.colorHex,
          fillOutlineColor: circle.colorHex,
          fillOpacity: circle.fillOpacity,
        ),
      );
      await controller.addLine(
        LineOptions(
          geometry: [for (final point in ring) LatLng(point.lat, point.lng)],
          lineColor: circle.colorHex,
          lineWidth: circle.outlineWidth,
          lineOpacity: circle.outlineOpacity,
          lineJoin: 'round',
        ),
      );
    }

    for (final line in widget.lines) {
      if (line.points.length < 2) continue;
      await controller.addLine(
        LineOptions(
          geometry: [
            for (final point in line.points) LatLng(point.lat, point.lng),
          ],
          lineColor: line.colorHex,
          lineWidth: line.width,
          lineOpacity: line.opacity,
          lineJoin: 'round',
        ),
      );
    }

    if (widget.dots.isNotEmpty) {
      await controller.addCircles([
        for (final dot in widget.dots)
          CircleOptions(
            geometry: LatLng(dot.center.lat, dot.center.lng),
            circleRadius: dot.radius,
            circleColor: dot.colorHex,
            circleOpacity: dot.opacity,
            circleStrokeColor: dot.strokeColorHex,
            circleStrokeWidth: dot.strokeWidth,
            circleStrokeOpacity: dot.strokeOpacity,
          ),
      ]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final Widget base =
        widget.platformViewBuilder?.call(context) ??
        MapLibreMap(
          styleString: kOpenFreeMapLibertyStyle,
          initialCameraPosition: CameraPosition(
            target: LatLng(widget.initialTarget.lat, widget.initialTarget.lng),
            zoom: widget.initialZoom,
          ),
          trackCameraPosition: true,
          // Flatness is enforced, not assumed (D-01): Liberty contains a
          // building-extrusion layer that would render in 3D under a tilt
          // gesture even though the style declares no default pitch.
          tiltGesturesEnabled: false,
          rotateGesturesEnabled: false,
          compassEnabled: false,
          // The current map draws no native location dot - the user's own
          // position is a LiveMemberMarker overlay - so the built-in
          // my-location layer stays off to avoid a second location
          // consumer for no visual gain.
          myLocationEnabled: false,
          attributionButtonPosition: AttributionButtonPosition.bottomRight,
          attributionButtonMargins: const Point(8, 8),
          onMapCreated: _onMapCreated,
          onStyleLoadedCallback: _onStyleLoaded,
          onCameraIdle: _onCameraIdle,
          featureTapsTriggersMapClick: widget.onTap != null,
          onMapClick: (_, coordinates) => widget.onTap?.call(
            MapPoint(coordinates.latitude, coordinates.longitude),
          ),
        );

    // LayoutBuilder supplies the map's own logical size, which projectToScreen
    // needs to place the camera centre. Reading it here rather than from
    // MediaQuery keeps the projection correct for a VectorMap that doesn't fill
    // the screen - RouteStatsSheet embeds one in a 360px-tall SizedBox.
    return LayoutBuilder(
      builder: (context, constraints) {
        final viewport = constraints.biggest;
        return Stack(
          children: [
            Positioned.fill(child: base),
            Positioned.fill(
              child: ValueListenableBuilder<bool>(
                valueListenable: _isCameraMoving,
                builder: (context, isCameraMoving, _) {
                  if (isCameraMoving) {
                    return const SizedBox.shrink();
                  }
                  return ValueListenableBuilder<CameraPosition?>(
                    valueListenable: _cameraPosition,
                    builder: (context, camera, _) {
                      // Before the platform view reports a camera (or under
                      // the widget-test platformViewBuilder seam, which never
                      // creates one) there is nothing to project against, so
                      // markers stay hidden exactly as they did while the old
                      // async reprojection had not yet returned its first
                      // result.
                      final canProject = camera != null && viewport.isFinite;
                      final screenPositions = <String, Offset>{
                        if (canProject)
                          for (final marker in widget.markers)
                            marker.id: projectToScreen(
                              lat: marker.lat,
                              lng: marker.lng,
                              cameraLat: camera.target.latitude,
                              cameraLng: camera.target.longitude,
                              zoom: camera.zoom,
                              viewport: viewport,
                            ),
                      };

                      return Stack(
                        children: [
                          for (final marker in widget.markers)
                            Positioned(
                              left:
                                  (screenPositions[marker.id]?.dx ?? 0) -
                                  marker.width / 2,
                              top:
                                  (screenPositions[marker.id]?.dy ?? 0) -
                                  marker.height / 2,
                              width: marker.width,
                              height: marker.height,
                              child: Visibility(
                                visible: screenPositions.containsKey(marker.id),
                                maintainState: true,
                                maintainSize: true,
                                maintainAnimation: true,
                                child: marker.child,
                              ),
                            ),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
