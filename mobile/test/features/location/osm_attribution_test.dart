import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:mobile/features/location/presentation/osm_attribution.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  Widget wrap(Widget child) {
    return MaterialApp(
      home: Scaffold(body: Stack(children: [child])),
    );
  }

  testWidgets('renders the OpenStreetMap credit text', (tester) async {
    await tester.pumpWidget(wrap(const OsmAttribution()));
    await tester.pump();

    expect(find.text('OpenStreetMap contributors'), findsOneWidget);
  });
}
