import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:mobile/shared_widgets/member_map_pin.dart';

/// Locks the Semantics label MemberMapPin exposes to assistive tech: the
/// member's label plus a status phrase (staleness badge text when known,
/// otherwise a current-location phrase), collapsed into one announcement.
void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  Widget wrap(Widget child) => MaterialApp(
    home: Scaffold(body: Center(child: child)),
  );

  group('MemberMapPin semantics', () {
    testWidgets(
      'fresh position with no recordedAt announces "<label>, current location"',
      (tester) async {
        final handle = tester.ensureSemantics();

        await tester.pumpWidget(
          wrap(const MemberMapPin(label: 'You', isSelf: true)),
        );
        await tester.pump();

        expect(find.bySemanticsLabel('You, current location'), findsOneWidget);

        handle.dispose();
      },
    );

    testWidgets('stale position announces "<label>, Last seen X min ago"', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();

      final recordedAt = DateTime.now().toUtc().subtract(
        const Duration(minutes: 5),
      );

      await tester.pumpWidget(
        wrap(MemberMapPin(label: 'Sam', recordedAt: recordedAt)),
      );
      await tester.pump();

      expect(find.bySemanticsLabel('Sam, Last seen 5 min ago'), findsOneWidget);

      handle.dispose();
    });
  });
}
