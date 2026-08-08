import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared_widgets/stat_tile.dart';
import '../application/map_geometry.dart';
import '../data/location_models.dart';
import 'vector_map.dart';

Future<void> showRouteStatsSheet({
  required BuildContext context,
  required LocationHistory history,
  required TravelStats stats,
  required String memberName,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) =>
        RouteStatsSheet(history: history, stats: stats, memberName: memberName),
  );
}

class RouteStatsSheet extends StatelessWidget {
  const RouteStatsSheet({
    super.key,
    required this.history,
    required this.stats,
    required this.memberName,
    @visibleForTesting this.mapPlatformViewBuilder,
  });

  final LocationHistory history;
  final TravelStats stats;
  final String memberName;

  /// Test seam: when supplied, replaces the native map view entirely so a
  /// widget test never mounts a real platform view. Production callers
  /// leave this null.
  @visibleForTesting
  final WidgetBuilder? mapPlatformViewBuilder;

  @override
  Widget build(BuildContext context) {
    final points = history.polylinePoints;
    final initial = points.isNotEmpty
        ? MapPoint(points.first.lat, points.first.lng)
        : const MapPoint(0, 0);
    final routePoints = [
      for (final point in points) MapPoint(point.lat, point.lng),
    ];
    final markers = [
      for (var i = 0; i < history.stops.length; i++)
        OverlayMarker(
          id: 'stop-${i + 1}',
          lat: history.stops[i].lat,
          lng: history.stops[i].lng,
          width: 28,
          height: 28,
          child: _StopMarker(number: i + 1),
        ),
    ];

    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.55,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return DecoratedBox(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              const SizedBox(height: AppSpacing.sm),
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.hairline,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: EdgeInsets.zero,
                  children: [
                    SizedBox(
                      height: 360,
                      child: VectorMap(
                        initialTarget: initial,
                        initialZoom: routePoints.length >= 2 ? 13 : 15,
                        markers: markers,
                        lines: [
                          if (routePoints.length >= 2)
                            MapLine(
                              points: routePoints,
                              colorHex: hexColor(AppColors.primaryTeal),
                              width: 5,
                            ),
                        ],
                        // Round stroke *caps* are not available on the line
                        // annotation (no cap property exposed), so the
                        // route's two end points render squared off instead
                        // of rounded. Accepted cosmetic parity gap (D-03) -
                        // round *joins* between segments are still applied
                        // by VectorMap's annotation drawing.
                        // ignore: invalid_use_of_visible_for_testing_member
                        platformViewBuilder: mapPlatformViewBuilder,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('$memberName route', style: AppTypography.title),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            'Past travel for the selected day',
                            style: AppTypography.bodySecondary,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Row(
                            children: [
                              Expanded(
                                child: StatTile(
                                  value: _distanceLabel(stats.distanceMeters),
                                  label: 'Distance',
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: StatTile(
                                  value: _durationLabel(stats.timeAway),
                                  label: 'Time away',
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: StatTile(
                                  value: '${stats.stopCount}',
                                  label: 'Stops',
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// A single numbered stop pin on the route map: an always-visible numbered
/// azure dot (equivalent stop identity to the pre-migration tap-to-reveal
/// label, with no hidden popover).
class _StopMarker extends StatelessWidget {
  const _StopMarker({required this.number});

  final int number;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.primaryTeal,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.surface, width: 2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x220C3A3F),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Text(
        '$number',
        style: AppTypography.caption.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

String _distanceLabel(double meters) {
  final miles = meters / 1609.344;
  if (miles < 10) return '${miles.toStringAsFixed(1)} mi';
  return '${miles.round()} mi';
}

String _durationLabel(Duration duration) {
  if (duration.inMinutes < 60) return '${duration.inMinutes}m';
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  if (minutes == 0) return '${hours}h';
  return '${hours}h ${minutes}m';
}
