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

/// Converts a native screen-projection result (from `toScreenLocation`/
/// `toScreenLocationBatch`) into the logical-pixel [Offset] that
/// Positioned/Offset expect in the Flutter widget layer.
///
/// Confirmed via on-device testing that the plugin's native Android side
/// returns coordinates in PHYSICAL pixels (raw View/Projection pixel space),
/// not logical pixels - e.g. at devicePixelRatio 2.625 on a 1080x2400
/// physical-pixel device, a marker at the exact camera-centre coordinate
/// projected to `Point(540.75, 1200.9375)` (exactly half of 1080/2400, the
/// physical centre) rather than the ~205.7/~457 logical centre. Left
/// unconverted, every marker renders roughly `devicePixelRatio`x further
/// right/down than its correct on-screen position - typically far enough to
/// fall outside the enclosing Stack's default hard-edge clip and disappear
/// entirely.
@visibleForTesting
Offset physicalToLogicalOffset(Point<num> point, double devicePixelRatio) {
  return Offset(
    point.x.toDouble() / devicePixelRatio,
    point.y.toDouble() / devicePixelRatio,
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
    @visibleForTesting this.platformViewBuilder,
  });

  final MapPoint initialTarget;
  final double initialZoom;
  final VectorMapController? controller;
  final List<OverlayMarker> markers;
  final List<MapCircle> circles;
  final List<MapLine> lines;

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
  Map<String, Offset> _screenPositions = const {};
  bool _styleLoaded = false;

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
            !identical(oldWidget.lines, widget.lines)) &&
        (oldWidget.circles != widget.circles ||
            oldWidget.lines != widget.lines)) {
      _drawAnnotations();
    }
    if (oldWidget.markers != widget.markers) {
      _reprojectMarkers();
    }
  }

  @override
  void dispose() {
    widget.controller?.removeListener(_onCameraCommand);
    // Symmetric with _onMapCreated's controller.addListener(_onControllerNotified)
    // - without this, a camera-changed notification firing after this State
    // disposes but before the native platform view itself fully tears down
    // (a real race when popping the screen or switching tabs mid-pan) would
    // still invoke _onControllerNotified -> _reprojectMarkers() on a
    // disposed State. _reprojectMarkers()'s own `if (!mounted) return;`
    // guard is a second, independent line of defence for that same race.
    _mapController?.removeListener(_onControllerNotified);
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
    controller.addListener(_onControllerNotified);
  }

  void _onControllerNotified() {
    // The controller is a ChangeNotifier that fires on every camera
    // movement while trackCameraPosition is true; reproject on each one so
    // pins visibly track the basemap during a pan/zoom, not just when it
    // comes to rest.
    if (!_styleLoaded) return;
    _reprojectMarkers();
  }

  Future<void> _onStyleLoaded() async {
    _styleLoaded = true;
    await _drawAnnotations();
    await _reprojectMarkers();
  }

  void _onCameraIdle() {
    // Reprojection is asynchronous over a method channel and visibly lags
    // the basemap by roughly a frame during fast motion; this call is what
    // guarantees pins settle exactly on their coordinate once the camera
    // comes to rest.
    _reprojectMarkers();
  }

  Future<void> _drawAnnotations() async {
    final controller = _mapController;
    if (controller == null) return;

    await controller.clearFills();
    await controller.clearLines();

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
  }

  Future<void> _reprojectMarkers() async {
    // Belt-and-braces against the dispose-path race this class's listener
    // wiring is designed to prevent (see dispose()'s comment): checked here,
    // as the very first line, before _mapController or context are touched
    // at all, so a stray notification arriving between listener-removal and
    // the State actually finishing disposal still can't reach a context
    // read or a native platform-channel call.
    if (!mounted) return;

    final controller = _mapController;
    if (controller == null || widget.markers.isEmpty) {
      if (_screenPositions.isNotEmpty) {
        setState(() => _screenPositions = const {});
      }
      return;
    }

    // toScreenLocationBatch (and the singular toScreenLocation) return
    // PHYSICAL pixel coordinates from the native side, but Positioned/Offset
    // in the Flutter widget layer operate in LOGICAL pixels - confirmed by
    // on-device testing (the raw returned x/y exactly matched half the
    // device's physical screen dimensions, ~2.6x the logical centre at
    // devicePixelRatio 2.625). Capture the ratio synchronously, before the
    // await, while `context` is known valid - this method only ever runs
    // while mounted, and awaiting first would make a post-await `context`
    // read unsafe.
    final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);

    // A single batched screen-location call for every marker - never one
    // method-channel round trip per pin per frame. Explicit try/catch so a
    // platform-channel failure here is never silent (it would otherwise
    // become an unhandled Future error on this fire-and-forget call site,
    // easy to miss) - the previously-known positions are kept rather than
    // cleared, so a transient failure doesn't blank out an already-correct
    // pin.
    final List<Point> points;
    try {
      points = await controller.toScreenLocationBatch([
        for (final marker in widget.markers) LatLng(marker.lat, marker.lng),
      ]);
    } catch (error, stackTrace) {
      debugPrint(
        'VectorMap: toScreenLocationBatch failed for '
        '${widget.markers.length} marker(s): $error\n$stackTrace',
      );
      return;
    }

    if (!mounted) return;

    final positions = <String, Offset>{
      for (var i = 0; i < widget.markers.length; i++)
        widget.markers[i].id: physicalToLogicalOffset(
          points[i],
          devicePixelRatio,
        ),
    };
    setState(() => _screenPositions = positions);
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
        );

    return Stack(
      children: [
        Positioned.fill(child: base),
        for (final marker in widget.markers)
          Positioned(
            left: (_screenPositions[marker.id]?.dx ?? 0) - marker.width / 2,
            top: (_screenPositions[marker.id]?.dy ?? 0) - marker.height / 2,
            width: marker.width,
            height: marker.height,
            child: Visibility(
              visible: _screenPositions.containsKey(marker.id),
              maintainState: true,
              maintainSize: true,
              maintainAnimation: true,
              child: marker.child,
            ),
          ),
      ],
    );
  }
}
