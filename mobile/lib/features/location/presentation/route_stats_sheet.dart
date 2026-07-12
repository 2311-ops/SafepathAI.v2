import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared_widgets/stat_tile.dart';
import '../data/location_models.dart';

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
  });

  final LocationHistory history;
  final TravelStats stats;
  final String memberName;

  @override
  Widget build(BuildContext context) {
    final points = history.polylinePoints;
    final initial = points.isNotEmpty
        ? LatLng(points.first.lat, points.first.lng)
        : const LatLng(0, 0);
    final routePoints = [
      for (final point in points) LatLng(point.lat, point.lng),
    ];
    final polylines = <Polyline>{
      if (routePoints.length >= 2)
        Polyline(
          polylineId: const PolylineId('history-route'),
          points: routePoints,
          color: AppColors.primaryTeal,
          width: 5,
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
          jointType: JointType.round,
        ),
    };
    final markers = <Marker>{
      for (var i = 0; i < history.stops.length; i++)
        Marker(
          markerId: MarkerId('stop-$i'),
          position: LatLng(history.stops[i].lat, history.stops[i].lng),
          infoWindow: InfoWindow(title: 'Stop ${i + 1}'),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueAzure,
          ),
        ),
    };

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
                      child: GoogleMap(
                        initialCameraPosition: CameraPosition(
                          target: initial,
                          zoom: routePoints.length >= 2 ? 13 : 15,
                        ),
                        polylines: polylines,
                        markers: markers,
                        myLocationButtonEnabled: false,
                        zoomControlsEnabled: false,
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
