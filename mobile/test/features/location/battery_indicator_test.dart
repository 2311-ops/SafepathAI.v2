import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:mobile/features/location/presentation/battery_indicator.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  Widget wrap(Widget child) {
    return MaterialApp(
      home: Scaffold(body: Center(child: child)),
    );
  }

  testWidgets('renders the battery percent when known', (tester) async {
    await tester.pumpWidget(wrap(const BatteryIndicator(percent: 72)));
    await tester.pump();

    expect(find.text('72%'), findsOneWidget);
  });

  testWidgets('renders nothing when battery percent is unknown', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(const BatteryIndicator(percent: null)));
    await tester.pump();

    expect(find.textContaining('%'), findsNothing);
  });
}
