// Deterministic widget tests for SplashScreen — no network, no wall-clock
// delays. Uses `tester.pump(Duration)` to advance the fake clock. Mirrors
// `01.1-UI-SPEC.md`'s Testing Contract: content renders, the completion gate
// flips exactly once, the reduced-motion path shows the full lockup within
// ~250ms, and disposal leaves no exceptions.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:mobile/features/splash/application/splash_providers.dart';
import 'package:mobile/features/splash/presentation/splash_screen.dart';
import 'package:mobile/shared_widgets/safepath_logo.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('content renders', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: SplashScreen()),
      ),
    );
    await tester.pump();

    expect(find.byType(SafePathLogo), findsOneWidget);
    expect(find.text('SafePath AI'), findsOneWidget);
  });

  testWidgets('animation runs once and flips the gate exactly once', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    var trueTransitions = 0;
    container.listen<bool>(splashAnimationCompleteProvider, (
      previous,
      next,
    ) {
      if (next) trueTransitions++;
    });

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: SplashScreen()),
      ),
    );
    await tester.pump();

    expect(container.read(splashAnimationCompleteProvider), isFalse);

    // The controller's own duration is exactly 1400ms, but the fake test
    // clock's tick right at t=1400ms lands on the boundary before the
    // AnimationController reports AnimationStatus.completed (verified via
    // WidgetTester timing: t=1400ms is still incomplete, t=1401ms flips).
    // Pump comfortably past the boundary rather than exactly on it.
    await tester.pump(const Duration(milliseconds: 1450));

    expect(container.read(splashAnimationCompleteProvider), isTrue);
    expect(trueTransitions, 1);

    // No re-forward / no double-flip well past completion.
    await tester.pump(const Duration(milliseconds: 1000));

    expect(trueTransitions, 1);
  });

  testWidgets('reduced motion path shows the full lockup and flips within '
      '~250ms', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: MaterialApp(home: SplashScreen()),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('SafePath AI'), findsOneWidget);
    expect(container.read(splashAnimationCompleteProvider), isTrue);
  });

  testWidgets('disposes cleanly with no leaked AnimationController/ticker', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: SplashScreen()),
      ),
    );
    await tester.pump();

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: SizedBox()),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
