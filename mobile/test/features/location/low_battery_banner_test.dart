import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mobile/features/location/data/location_models.dart';
import 'package:mobile/features/location/presentation/low_battery_banner.dart';

void main() {
  testWidgets('shows exact low-battery copy and dismisses', (tester) async {
    var dismissed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LowBatteryBanner(
            alert: const LowBatteryAlert(
              userId: 'member-2',
              name: 'Maya',
              batteryPercent: 14,
            ),
            onDismissed: () => dismissed = true,
          ),
        ),
      ),
    );

    expect(find.text('Low battery'), findsOneWidget);
    expect(
      find.text(
        "Maya's phone is at 14% — location updates may become less frequent.",
      ),
      findsOneWidget,
    );

    final buttonSize = tester.getSize(find.byType(IconButton));
    expect(buttonSize.width, greaterThanOrEqualTo(44.0));
    expect(buttonSize.height, greaterThanOrEqualTo(44.0));

    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();

    expect(dismissed, isTrue);
  });
}
