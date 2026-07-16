import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:mobile/features/privacy/data/privacy_api.dart';
import 'package:mobile/features/privacy/presentation/privacy_policy_screen.dart';
import '../../helpers/fake_privacy_api.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('renders the no-data-resale commitment from the API', (
    tester,
  ) async {
    final fakeApi = FakePrivacyApi();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [privacyApiProvider.overrideWithValue(fakeApi)],
        child: const MaterialApp(home: PrivacyPolicyScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(fakeApi.getPolicyCallCount, 1);
    expect(find.text('SafePath Privacy Commitment'), findsOneWidget);
    expect(
      find.text('SafePath does not sell, rent, or resell data.'),
      findsOneWidget,
    );
    expect(find.text('Export and delete rights'), findsOneWidget);
  });
}
