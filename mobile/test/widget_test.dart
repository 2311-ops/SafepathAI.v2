// Basic smoke test: the SafePath app boots without throwing and shows the
// themed placeholder home. Theme-token assertions live in theme_test.dart.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:mobile/app.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('SafePathApp pumps without exceptions', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(child: SafePathApp()),
    );
    await tester.pumpAndSettle();

    expect(find.text('SafePath AI'), findsOneWidget);
  });
}
