import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:mobile/features/location/data/location_models.dart';
import 'package:mobile/features/location/presentation/live_map_screen.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  Widget wrap(Widget child) {
    return MaterialApp(
      home: Scaffold(body: Center(child: child)),
    );
  }

  testWidgets('renders the always-visible name label', (tester) async {
    final location = LiveLocation(
      userId: 'member-2',
      displayName: 'Sam Rivera',
      lat: 30.05,
      lng: 31.24,
      accuracyMeters: 12,
      recordedAtUtc: DateTime.now().toUtc(),
    );

    await tester.pumpWidget(
      wrap(
        LiveMemberMarker(
          location: location,
          name: 'Sam Rivera',
          isOnline: true,
          isSelf: false,
          color: Colors.purple,
          onTap: () {},
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Sam Rivera'), findsOneWidget);
  });

  testWidgets('renders the initials fallback when profileImageUrl is null', (
    tester,
  ) async {
    final location = LiveLocation(
      userId: 'member-2',
      displayName: 'Sam Rivera',
      lat: 30.05,
      lng: 31.24,
      accuracyMeters: 12,
      recordedAtUtc: DateTime.now().toUtc(),
      profileImageUrl: null,
    );

    await tester.pumpWidget(
      wrap(
        LiveMemberMarker(
          location: location,
          name: 'Sam Rivera',
          isOnline: false,
          isSelf: false,
          color: Colors.purple,
          onTap: () {},
        ),
      ),
    );
    await tester.pump();

    expect(find.text('S'), findsOneWidget);
    expect(find.text('Sam Rivera'), findsOneWidget);
  });

  testWidgets('tapping the marker invokes onTap', (tester) async {
    final location = LiveLocation(
      userId: 'member-2',
      displayName: 'Sam Rivera',
      lat: 30.05,
      lng: 31.24,
      accuracyMeters: 12,
      recordedAtUtc: DateTime.now().toUtc(),
    );
    var tapped = false;

    await tester.pumpWidget(
      wrap(
        LiveMemberMarker(
          location: location,
          name: 'Sam Rivera',
          isOnline: true,
          isSelf: false,
          color: Colors.purple,
          onTap: () => tapped = true,
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.byType(LiveMemberMarker));
    await tester.pump();

    expect(tapped, isTrue);
  });
}
