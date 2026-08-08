import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:mobile/features/location/data/location_models.dart';
import 'package:mobile/features/location/presentation/route_stats_sheet.dart';
import 'package:mobile/features/location/presentation/vector_map.dart';

/// Stands in for the native map view so no widget test mounts a real
/// platform view, which has no test implementation and throws on the
/// platform-views channel.
Widget _fakePlatformViewBuilder(BuildContext context) =>
    const SizedBox.expand();

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets(
    'route history renders on a VectorMap with stat tiles',
    (tester) async {
      final now = DateTime.now().toUtc();
      final history = LocationHistory(
        polylinePoints: [
          RoutePoint(lat: 30.0444, lng: 31.2357, recordedAtUtc: now),
          RoutePoint(
            lat: 30.0500,
            lng: 31.2400,
            recordedAtUtc: now.add(const Duration(minutes: 5)),
          ),
          RoutePoint(
            lat: 30.0550,
            lng: 31.2450,
            recordedAtUtc: now.add(const Duration(minutes: 10)),
          ),
        ],
        stops: [
          HistoryStop(
            startUtc: now,
            endUtc: now.add(const Duration(minutes: 15)),
            lat: 30.0500,
            lng: 31.2400,
          ),
        ],
      );
      const stats = TravelStats(
        distanceMeters: 3200,
        timeAway: Duration(hours: 1, minutes: 20),
        stopCount: 1,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RouteStatsSheet(
              history: history,
              stats: stats,
              memberName: 'Sam',
              mapPlatformViewBuilder: _fakePlatformViewBuilder,
            ),
          ),
        ),
      );
      // No native platform view is mounted (a stand-in is injected above),
      // but pumpAndSettle can still hang on the sheet's own entrance
      // animation, so build the tree with a fixed-duration pump instead.
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(VectorMap), findsOneWidget);
      expect(find.text('DISTANCE'), findsOneWidget);
      expect(find.text('TIME AWAY'), findsOneWidget);
      expect(find.text('STOPS'), findsOneWidget);
    },
  );
}
