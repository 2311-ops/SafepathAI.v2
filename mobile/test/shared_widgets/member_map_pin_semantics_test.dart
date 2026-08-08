import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:mobile/shared_widgets/member_map_pin.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  Widget wrap(Widget child) =>
      MaterialApp(home: Scaffold(body: Center(child: child)));

  testWidgets('announces the label and current-location status as one node', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    addTearDown(semantics.dispose);

    await tester.pumpWidget(wrap(const MemberMapPin(label: 'You', isSelf: true)));
    await tester.pump();

    expect(find.bySemanticsLabel('You, current location'), findsOneWidget);
  });

  testWidgets('announces the label and stale status as one node', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    addTearDown(semantics.dispose);
    final recordedAt = DateTime.now()
        .toUtc()
        .subtract(const Duration(minutes: 5));

    await tester.pumpWidget(
      wrap(MemberMapPin(label: 'Sam', recordedAt: recordedAt)),
    );
    await tester.pump();

    expect(find.bySemanticsLabel('Sam, Last seen 5 min ago'), findsOneWidget);
  });
}
