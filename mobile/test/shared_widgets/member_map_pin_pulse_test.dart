import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:mobile/shared_widgets/member_map_pin.dart';

/// Locks the isSelf-gated pulse behavior of [MemberMapPin]: only a
/// `isSelf: true` instance creates/starts the pulse AnimationController and
/// renders the isolated (RepaintBoundary-wrapped) FadeTransition dot; a
/// `isSelf: false` instance never creates one and disposes safely.
void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  Widget wrap(Widget child) =>
      MaterialApp(home: Scaffold(body: Center(child: child)));

  group('MemberMapPin pulse gating', () {
    testWidgets(
      'isSelf:true renders exactly one pulse FadeTransition wrapped in a '
      'RepaintBoundary',
      (tester) async {
        await tester.pumpWidget(
          wrap(const MemberMapPin(label: 'You', isSelf: true)),
        );
        await tester.pump();

        final fadeTransitionFinder = find.descendant(
          of: find.byType(MemberMapPin),
          matching: find.byType(FadeTransition),
        );
        expect(fadeTransitionFinder, findsOneWidget);

        final repaintBoundaryAncestor = find.ancestor(
          of: fadeTransitionFinder,
          matching: find.byType(RepaintBoundary),
        );
        expect(repaintBoundaryAncestor, findsWidgets);
      },
    );

    testWidgets(
      'isSelf:false renders no pulse FadeTransition and disposes safely',
      (tester) async {
        await tester.pumpWidget(
          wrap(const MemberMapPin(label: 'Sam', isSelf: false)),
        );
        await tester.pump();

        expect(
          find.descendant(
            of: find.byType(MemberMapPin),
            matching: find.byType(FadeTransition),
          ),
          findsNothing,
        );

        await tester.pumpWidget(wrap(const SizedBox.shrink()));

        expect(tester.takeException(), isNull);
      },
    );
  });
}
