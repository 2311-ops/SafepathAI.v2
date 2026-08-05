// Behavior under test (03-02-PLAN.md Task 1 — DESIGN-02):
// - The SOS control renders at the locked 72x72 geometry with a 4px border.
// - Holding for the full 3000ms fires the arm-complete callback exactly once.
// - Releasing before 3000ms cancels the arm and fires nothing.
// - A cancelled gesture resets the ring's progress back to 0.
// - The control exposes a long-press semantics action so a screen reader can
//   arm it via the platform "double-tap and hold" gesture.
// - Reduced motion (`disableAnimations`) does not shorten the 3000ms timing.
// - Tapping (not holding) the control never changes MainShell's selected tab.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import 'package:mobile/features/auth/data/auth_api.dart';
import 'package:mobile/features/auth/data/auth_models.dart';
import 'package:mobile/features/family/application/family_controller.dart';
import 'package:mobile/features/home/presentation/main_shell.dart';
import 'package:mobile/features/location/application/location_controller.dart';
import 'package:mobile/features/privacy/application/privacy_controller.dart';
import 'package:mobile/features/sos/presentation/sos_arm_button.dart';
import 'package:mobile/features/sos/presentation/sos_arm_ring_painter.dart';

/// No circle yet, matching the existing `LiveMapScreen` test convention —
/// keeps `MainShell`'s Map tab on a synchronous, non-loading branch.
class _NoFamilyController extends FamilyController {
  @override
  FamilyState build() => const FamilyState();
}

/// Minimal `AuthApi` fake (matches the `family_controller_test.dart` /
/// `location_controller_test.dart` convention) so `PrivacyCenterScreen`'s
/// direct `ref.watch(authApiProvider)` never touches a real, uninitialized
/// Supabase client in this widget test.
class _FakeAuthApi implements AuthApi {
  sb.Session? sessionOverride;
  final StreamController<dynamic> _controller =
      StreamController<dynamic>.broadcast();

  @override
  sb.Session? get currentSession => sessionOverride;

  @override
  Stream<dynamic> get authStateChanges => _controller.stream;

  @override
  Future<AuthSessionResult> register({
    required String email,
    required String password,
    required String fullName,
    required Role role,
  }) => throw UnimplementedError();

  @override
  Future<AuthSessionResult> login({
    required String email,
    required String password,
  }) => throw UnimplementedError();

  @override
  Future<void> logout() => throw UnimplementedError();

  @override
  Future<void> sendPasswordResetEmail({required String email}) =>
      throw UnimplementedError();

  @override
  Future<void> updatePassword({required String password}) =>
      throw UnimplementedError();

  @override
  Future<void> updateRoleMetadata(Role role) => throw UnimplementedError();

  @override
  Future<AuthSessionResult> refreshSession() => throw UnimplementedError();

  @override
  Future<bool> signInWithGoogle() => throw UnimplementedError();
}

/// Empty, non-loading location state so `LocationController.build()` never
/// touches a real geolocator/hub client during this widget test.
class _EmptyLocationController extends LocationController {
  @override
  LocationState build() => const LocationState();
}

/// `MainShell`'s `IndexedStack` builds every tab eagerly, including
/// `PrivacyCenterScreen` (index 3), which otherwise touches `authApiProvider`
/// -> a real (uninitialized) Supabase client in this widget test. Overriding
/// straight to a trivial state sidesteps that entirely.
class _EmptyPrivacyController extends PrivacyController {
  @override
  PrivacyState build() => const PrivacyState();
}

Widget _wrapButton({
  required VoidCallback onArmComplete,
  bool reduceMotion = false,
}) {
  final app = MaterialApp(
    home: Scaffold(
      body: Center(child: SosArmButton(onArmComplete: onArmComplete)),
    ),
  );
  if (!reduceMotion) return app;
  return MediaQuery(
    data: const MediaQueryData(disableAnimations: true),
    child: app,
  );
}

Widget _wrapMainShell() {
  return ProviderScope(
    overrides: [
      familyControllerProvider.overrideWith(_NoFamilyController.new),
      locationControllerProvider.overrideWith(_EmptyLocationController.new),
      privacyControllerProvider.overrideWith(_EmptyPrivacyController.new),
      authApiProvider.overrideWithValue(_FakeAuthApi()),
    ],
    child: const MaterialApp(home: MainShell()),
  );
}

void main() {
  testWidgets('renders at the locked geometry', (tester) async {
    await tester.pumpWidget(_wrapButton(onArmComplete: () {}));

    expect(find.text('SOS'), findsOneWidget);
    expect(find.byIcon(Icons.sos), findsNothing);

    final sizedBox = tester.widget<SizedBox>(
      find
          .descendant(
            of: find.byType(SosArmButton),
            matching: find.byType(SizedBox),
          )
          .first,
    );
    expect(sizedBox.width, 72);
    expect(sizedBox.height, 72);

    final container = tester.widget<Container>(
      find.descendant(
        of: find.byType(SosArmButton),
        matching: find.byType(Container),
      ),
    );
    final decoration = container.decoration as BoxDecoration;
    final border = decoration.border as Border;
    expect(border.top.width, 4);
  });

  testWidgets('fills the ring over three seconds', (tester) async {
    var armCount = 0;
    await tester.pumpWidget(_wrapButton(onArmComplete: () => armCount++));

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(SosArmButton)),
    );
    // Establishes the animation ticker's baseline frame before the clock is
    // fast-forwarded — without it, the ticker's very first tick becomes its
    // own zero point and swallows the jump (a fake-clock/ticker artifact,
    // not a production timing change).
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 3000));
    // The controller's status flips to `completed` one tick after its value
    // reaches 1.0 — nudge one more frame so the transition is observed.
    await tester.pump(const Duration(milliseconds: 1));

    expect(armCount, 1);
    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('release before three seconds cancels and fires nothing', (
    tester,
  ) async {
    var armCount = 0;
    await tester.pumpWidget(_wrapButton(onArmComplete: () => armCount++));

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(SosArmButton)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 2000));
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 500));

    expect(armCount, 0);
  });

  testWidgets('quick tap never completes after release', (tester) async {
    var armCount = 0;
    await tester.pumpWidget(_wrapButton(onArmComplete: () => armCount++));

    await tester.tap(find.byType(SosArmButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 3500));

    expect(armCount, 0);
  });

  testWidgets('cancelled gesture resets progress', (tester) async {
    await tester.pumpWidget(_wrapButton(onArmComplete: () {}));

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(SosArmButton)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 2000));
    await gesture.up();
    // Re-establishes the ticker's baseline for the new `animateBack` leg
    // (direction changes restart the ticker) before jumping its clock.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    final painter =
        tester
                .widget<CustomPaint>(
                  find.descendant(
                    of: find.byType(SosArmButton),
                    matching: find.byType(CustomPaint),
                  ),
                )
                .painter
            as SosArmRingPainter;
    expect(painter.progress, 0);
  });

  testWidgets('exposes a long-press semantics action', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_wrapButton(onArmComplete: () {}));

    final finder = find.bySemanticsLabel(
      RegExp('Press and hold for three seconds'),
    );
    expect(finder, findsOneWidget);
    final semantics = tester.getSemantics(finder);
    expect(
      semantics.getSemanticsData().hasAction(SemanticsAction.longPress),
      isTrue,
    );

    handle.dispose();
  });

  testWidgets('honours reduced motion', (tester) async {
    var armCount = 0;
    await tester.pumpWidget(
      _wrapButton(onArmComplete: () => armCount++, reduceMotion: true),
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(SosArmButton)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 3000));
    await tester.pump(const Duration(milliseconds: 1));

    expect(armCount, 1);
    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('no longer changes the selected tab', (tester) async {
    await tester.pumpWidget(_wrapMainShell());
    await tester.pump();

    expect(find.text('No circle yet'), findsOneWidget);

    await tester.tap(find.byType(SosArmButton));
    await tester.pump();

    expect(find.text('No circle yet'), findsOneWidget);
  });

  testWidgets('system back returns a secondary tab to the map', (tester) async {
    await tester.pumpWidget(_wrapMainShell());
    await tester.pump();

    await tester.tap(find.text('Insights'));
    await tester.pump();
    expect(find.text('Insights are coming soon'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pump();

    expect(find.text('Insights are coming soon'), findsNothing);
    expect(find.text('No circle yet'), findsOneWidget);
  });
}
