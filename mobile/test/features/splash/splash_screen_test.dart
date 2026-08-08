// Deterministic widget tests for SplashScreen — no network, no wall-clock
// delays. Uses `tester.pump(Duration)` to advance the fake clock. Mirrors
// `01.1-UI-SPEC.md`'s Testing Contract: content renders, the completion gate
// flips exactly once, the reduced-motion path shows the full lockup within
// ~250ms, the ring closes on the motion path and is absent under reduced
// motion (both surfaces), and disposal leaves no exceptions.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:mobile/features/splash/application/splash_providers.dart';
import 'package:mobile/features/splash/presentation/splash_screen.dart';
import 'package:mobile/shared_widgets/animated_safepath_mark.dart';
import 'package:mobile/shared_widgets/safepath_logo.dart';

/// Reads the wordmark rendered by the single [AnimatedSafePathMark] on
/// screen. Under reduced motion this is one plain `Text`; under full motion
/// it is eleven single-character `Text` widgets — either way, concatenating
/// every descendant `Text`'s data (and normalising the non-breaking space
/// the staggered renderer substitutes for the literal space back to a
/// regular space) reconstructs the full wordmark string.
String _lockupWordmark(WidgetTester tester) {
  final texts = tester.widgetList<Text>(
    find.descendant(
      of: find.byType(AnimatedSafePathMark),
      matching: find.byType(Text),
    ),
  );
  return texts
      .map((widget) => widget.data ?? '')
      .join()
      .replaceAll(' ', ' ');
}

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
    expect(_lockupWordmark(tester), 'SafePath AI');
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

    // The controller's own duration is exactly 1800ms, but the fake test
    // clock's tick right at t=1800ms lands on the boundary before the
    // AnimationController reports AnimationStatus.completed (verified via
    // WidgetTester timing: t=1800ms is still incomplete, t=1801ms flips).
    // Pump comfortably past the boundary rather than exactly on it.
    await tester.pump(const Duration(milliseconds: 1850));

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

    expect(_lockupWordmark(tester), 'SafePath AI');
    expect(container.read(splashAnimationCompleteProvider), isTrue);
    expect(find.byKey(AnimatedSafePathMark.ringKey), findsNothing);
  });

  testWidgets('ring is drawn mid-animation with motion enabled', (
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
    await tester.pump(const Duration(milliseconds: 900));

    expect(find.byKey(AnimatedSafePathMark.ringKey), findsOneWidget);
  });

  group('StartupSplashOverlay reduced motion', () {
    testWidgets(
      'renders the wordmark with no ring, then clears to reveal the child',
      (tester) async {
        const childKey = Key('startup-splash-overlay-child');

        await tester.pumpWidget(
          const MediaQuery(
            data: MediaQueryData(disableAnimations: true),
            child: MaterialApp(
              home: StartupSplashOverlay(child: SizedBox(key: childKey)),
            ),
          ),
        );
        await tester.pump();

        // Post-frame start delay (120ms) elapses, comfortably before the
        // 260ms reduced-motion window closes.
        await tester.pump(const Duration(milliseconds: 150));

        expect(_lockupWordmark(tester), 'SafePath AI');
        expect(find.byKey(AnimatedSafePathMark.ringKey), findsNothing);

        // Pump past the full reduced-motion window (120ms delay + 260ms).
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.byKey(childKey), findsOneWidget);
        expect(find.byType(AnimatedSafePathMark), findsNothing);
      },
    );
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
