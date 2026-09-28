import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/geofencing/application/routine_notifications_controller.dart';
import 'package:mobile/features/geofencing/presentation/quiet_hours_screen.dart';

void main() {
  testWidgets('edits a recipient-owned quiet-hours policy', (tester) async {
    QuietHoursSetting? saved;
    await tester.pumpWidget(
      MaterialApp(
        home: QuietHoursScreen(
          initial: const QuietHoursSetting(
            localStart: '22:00:00',
            localEnd: '07:00:00',
            timeZoneId: 'Africa/Cairo',
          ),
          onSave: (setting) async => saved = setting,
        ),
      ),
    );

    expect(find.text('Quiet hours'), findsOneWidget);
    expect(find.textContaining('feed remain immediate'), findsOneWidget);
    expect(find.textContaining('SOS always bypasses'), findsOneWidget);
    expect(find.text('22:00'), findsOneWidget);
    expect(find.text('07:00'), findsOneWidget);

    await tester.tap(find.byType(Switch));
    await tester.enterText(
      find.byKey(const Key('time-zone-id')),
      'Europe/London',
    );
    await tester.tap(find.text('Save quiet hours'));
    await tester.pump();

    expect(saved?.isEnabled, isTrue);
    expect(saved?.timeZoneId, 'Europe/London');
  });

  testWidgets('makes invalid IANA zones actionable', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: QuietHoursScreen(initial: QuietHoursSetting())),
    );

    await tester.enterText(find.byKey(const Key('time-zone-id')), 'EET');
    await tester.tap(find.text('Save quiet hours'));
    await tester.pump();

    expect(
      find.text('Enter an IANA time zone such as Africa/Cairo.'),
      findsOneWidget,
    );
  });
}
