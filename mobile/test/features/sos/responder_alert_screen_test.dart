// Behavior under test (03-04-PLAN.md Task 2, extended by 03-08-PLAN.md Task 3):
// - renders the sender's name in the incoming headline
// - shows both Phase 3 actions (Acknowledge, Call sender)
// - shows no mark-resolved control (D-23)
// - acknowledging calls the API once and switches to the acknowledged form
// - keeps Call sender available after acknowledging
// - shows the acknowledged timestamp caption
// - renders a red header strip in the incoming state
// - renders a countdown for the live window, without a layout-width change
//   as digits tick (tabular figures)
// - shows a labelled LIVE indicator, static under reduced motion
// - stops applying liveLocationUpdates once the window expires, leaving the
//   last known position and a zeroed countdown on screen
// - renders the sender's position on the responder map
// - the sender's own screen shows the matching live-active headline/copy

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mobile/core/theme/app_colors.dart';
import 'package:mobile/features/auth/data/auth_models.dart';
import 'package:mobile/features/family/application/family_controller.dart';
import 'package:mobile/features/family/data/family_models.dart';
import 'package:mobile/features/location/presentation/vector_map.dart';
import 'package:mobile/features/sos/application/sos_controller.dart';
import 'package:mobile/features/sos/application/sos_responder_controller.dart';
import 'package:mobile/features/sos/application/sos_session_state.dart';
import 'package:mobile/features/sos/data/sos_api.dart';
import 'package:mobile/features/sos/data/sos_hub_client.dart';
import 'package:mobile/features/sos/data/sos_models.dart';
import 'package:mobile/features/sos/presentation/responder_alert_screen.dart';
import 'package:mobile/features/sos/presentation/sender_emergency_session_screen.dart';
import 'package:mobile/features/sos/presentation/sos_countdown.dart';

import '../../helpers/fake_sos_api.dart';
import '../../helpers/fake_sos_hub_client.dart';

/// Stands in for the native map view so no widget test mounts a real
/// platform view (matches `live_map_screen_test.dart`'s own seam).
Widget _fakePlatformViewBuilder(BuildContext context) =>
    const SizedBox.expand();

class _FixedFamilyController extends FamilyController {
  @override
  FamilyState build() => FamilyState(
    family: const Family(id: 'family-1'),
    members: [
      FamilyMemberView(
        memberId: 'member-1',
        userId: 'ana-user-id',
        displayName: 'Ana',
        role: Role.member,
        permission: PermissionLevel.fullLocation,
        joinedAt: DateTime.utc(2026, 1, 1),
      ),
    ],
  );
}

class _FixedResponderController extends SosResponderController {
  _FixedResponderController(this.initialState);

  final SosResponderState initialState;

  @override
  SosResponderState build() => initialState;
}

/// A fixed sender-side controller state — mirrors
/// `_FixedResponderController` above so the sender-screen test doesn't need
/// to drive a real `arm()`/trigger flow just to reach `SosLiveActive`.
class _FixedSosController extends SosController {
  _FixedSosController(this.initialState);

  final SosSessionState initialState;

  @override
  SosSessionState build() => initialState;
}

SosSession _incomingSession({DateTime? liveWindowEndsAtUtc}) {
  return SosSession(
    sosSessionId: 'session-1',
    familyId: 'family-1',
    triggeredByUserId: 'ana-user-id',
    status: SosSessionStatus.active,
    triggeredAtUtc: DateTime.now().toUtc(),
    receivedAtUtc: DateTime.now().toUtc(),
    liveWindowEndsAtUtc: liveWindowEndsAtUtc,
  );
}

Widget _wrap({
  required SosResponderState initialState,
  required FakeSosApi sosApi,
  FakeSosHubClient? hubClient,
  bool reduceMotion = false,
}) {
  final scope = ProviderScope(
    overrides: [
      sosResponderControllerProvider.overrideWith(
        () => _FixedResponderController(initialState),
      ),
      sosApiProvider.overrideWithValue(sosApi),
      familyControllerProvider.overrideWith(_FixedFamilyController.new),
      sosHubClientProvider.overrideWithValue(hubClient ?? FakeSosHubClient()),
    ],
    child: const MaterialApp(
      home: ResponderAlertScreen(
        sessionId: 'session-1',
        mapPlatformViewBuilder: _fakePlatformViewBuilder,
      ),
    ),
  );
  return reduceMotion
      ? MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: scope,
        )
      : scope;
}

void main() {
  testWidgets('renders the sender\'s name in the incoming headline', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        initialState: SosResponderState(activeSession: _incomingSession()),
        sosApi: FakeSosApi(),
      ),
    );

    expect(find.text('Ana triggered SOS'), findsOneWidget);
  });

  testWidgets('shows both Phase 3 actions', (tester) async {
    await tester.pumpWidget(
      _wrap(
        initialState: SosResponderState(activeSession: _incomingSession()),
        sosApi: FakeSosApi(),
      ),
    );

    expect(find.text('Acknowledge'), findsOneWidget);
    expect(find.text('Call sender'), findsOneWidget);
  });

  testWidgets('loads the session when opened from a notification tap', (
    tester,
  ) async {
    final sosApi = FakeSosApi()
      ..getSessionResponseBuilder = (_) => _incomingSession();

    await tester.pumpWidget(
      _wrap(initialState: const SosResponderState(), sosApi: sosApi),
    );
    await tester.pumpAndSettle();

    expect(sosApi.getSessionCallCount, 1);
    expect(find.text('Ana triggered SOS'), findsOneWidget);
  });

  testWidgets('shows no mark-resolved control', (tester) async {
    await tester.pumpWidget(
      _wrap(
        initialState: SosResponderState(activeSession: _incomingSession()),
        sosApi: FakeSosApi(),
      ),
    );

    expect(find.textContaining('esolve'), findsNothing);
    expect(find.text('Mark resolved'), findsNothing);
  });

  testWidgets(
    'acknowledging calls the API once and switches the control to its '
    'acknowledged form',
    (tester) async {
      final sosApi = FakeSosApi();
      await tester.pumpWidget(
        _wrap(
          initialState: SosResponderState(activeSession: _incomingSession()),
          sosApi: sosApi,
        ),
      );

      await tester.tap(find.text('Acknowledge'));
      await tester.pumpAndSettle();

      expect(sosApi.acknowledgeCallCount, 1);
      expect(sosApi.acknowledgeCalls.single, 'session-1');
      expect(find.text('Acknowledged'), findsOneWidget);
      expect(find.text('Acknowledge'), findsNothing);

      final button = tester.widget<ElevatedButton>(
        find.ancestor(
          of: find.text('Acknowledged'),
          matching: find.byType(ElevatedButton),
        ),
      );
      expect(button.onPressed, isNull);
    },
  );

  testWidgets('keeps Call sender available after acknowledging', (
    tester,
  ) async {
    final sosApi = FakeSosApi();
    await tester.pumpWidget(
      _wrap(
        initialState: SosResponderState(activeSession: _incomingSession()),
        sosApi: sosApi,
      ),
    );

    await tester.tap(find.text('Acknowledge'));
    await tester.pumpAndSettle();

    final button = tester.widget<ElevatedButton>(
      find.ancestor(
        of: find.text('Call sender'),
        matching: find.byType(ElevatedButton),
      ),
    );
    expect(button.onPressed, isNotNull);
  });

  testWidgets('shows the acknowledged timestamp caption', (tester) async {
    final sosApi = FakeSosApi();
    await tester.pumpWidget(
      _wrap(
        initialState: SosResponderState(activeSession: _incomingSession()),
        sosApi: sosApi,
      ),
    );

    await tester.tap(find.text('Acknowledge'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('You acknowledged this alert at'),
      findsOneWidget,
    );
  });

  testWidgets('renders a red header strip in the incoming state', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        initialState: SosResponderState(activeSession: _incomingSession()),
        sosApi: FakeSosApi(),
      ),
    );

    final header = tester.widget<DecoratedBox>(
      find.byKey(const ValueKey('responder-header-strip')),
    );
    final decoration = header.decoration as BoxDecoration;
    expect(decoration.color, AppColors.sosRed);
  });

  testWidgets('renders a countdown for the live window', (tester) async {
    final endsAtUtc = DateTime.now().toUtc().add(const Duration(minutes: 5));
    await tester.pumpWidget(
      _wrap(
        initialState: SosResponderState(
          activeSession: _incomingSession(liveWindowEndsAtUtc: endsAtUtc),
        ),
        sosApi: FakeSosApi(),
      ),
    );
    await tester.pump();

    // Tolerant of a few milliseconds' setup jitter: "five minutes" reads as
    // 04:5x or 05:00.
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Text &&
            RegExp(r'^0[45]:[0-5]\d$').hasMatch(widget.data ?? ''),
      ),
      findsOneWidget,
    );
  });

  testWidgets('counts down without changing layout width', (tester) async {
    final endsAtUtc = DateTime.now().toUtc().add(const Duration(seconds: 11));
    await tester.pumpWidget(
      _wrap(
        initialState: SosResponderState(
          activeSession: _incomingSession(liveWindowEndsAtUtc: endsAtUtc),
        ),
        sosApi: FakeSosApi(),
      ),
    );
    await tester.pump();

    final initialWidth = tester.getSize(find.byType(SosCountdown)).width;

    await tester.pump(const Duration(seconds: 2));

    final laterWidth = tester.getSize(find.byType(SosCountdown)).width;
    expect(laterWidth, initialWidth);
  });

  testWidgets('shows a LIVE label next to the live indicator', (
    tester,
  ) async {
    final endsAtUtc = DateTime.now().toUtc().add(const Duration(minutes: 5));
    await tester.pumpWidget(
      _wrap(
        initialState: SosResponderState(
          activeSession: _incomingSession(liveWindowEndsAtUtc: endsAtUtc),
        ),
        sosApi: FakeSosApi(),
      ),
    );
    await tester.pump();

    expect(find.text('LIVE'), findsOneWidget);
  });

  // Exercised on the sender screen rather than the responder screen: it is
  // the only surface where both the live dot and the pulse ring render
  // together (the responder's live-location card shows the live indicator
  // only — the pulse ring sits behind the sender's own header SOS icon).
  testWidgets('renders a static indicator under reduced motion', (
    tester,
  ) async {
    final endsAtUtc = DateTime.now().toUtc().add(const Duration(minutes: 5));
    final session = SosSession(
      sosSessionId: 'session-1',
      familyId: 'family-1',
      triggeredByUserId: 'self-user',
      status: SosSessionStatus.active,
      triggeredAtUtc: DateTime.now().toUtc(),
      receivedAtUtc: DateTime.now().toUtc(),
      liveWindowEndsAtUtc: endsAtUtc,
    );

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: ProviderScope(
          overrides: [
            sosControllerProvider.overrideWith(
              () => _FixedSosController(SosLiveActive(session, endsAtUtc)),
            ),
          ],
          child: const MaterialApp(home: SenderEmergencySessionScreen()),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(SosPulseRing), findsOneWidget);

    final dotFinder = find.byWidgetPredicate(
      (widget) => widget is Opacity && widget.opacity == 1.0,
    );
    expect(dotFinder, findsWidgets);

    final opacityBefore = tester
        .widgetList<Opacity>(dotFinder)
        .map((w) => w.opacity)
        .toList();

    await tester.pump(const Duration(milliseconds: 700));

    final opacityAfter = tester
        .widgetList<Opacity>(dotFinder)
        .map((w) => w.opacity)
        .toList();
    expect(opacityAfter, opacityBefore);
  });

  testWidgets(
    'stops updating after the window expires',
    (tester) async {
      final endsAtUtc = DateTime.now().toUtc().add(const Duration(seconds: 2));
      final hubClient = FakeSosHubClient();
      await tester.pumpWidget(
        _wrap(
          initialState: SosResponderState(
            activeSession: _incomingSession(liveWindowEndsAtUtc: endsAtUtc),
          ),
          sosApi: FakeSosApi(),
          hubClient: hubClient,
        ),
      );
      await tester.pump();

      hubClient.emitLiveLocationUpdate(
        SosLocationUpdate(
          sosSessionId: 'session-1',
          latitude: 30.01,
          longitude: 31.01,
          recordedAtUtc: DateTime.now().toUtc(),
          windowEndsAtUtc: endsAtUtc,
        ),
      );
      await tester.pump();

      // Advance well past the window end so the local expiry timer fires.
      await tester.pump(const Duration(seconds: 3));

      // A late update (fresh session-scoped window, different position)
      // must be ignored — the last known position/countdown stay frozen.
      hubClient.emitLiveLocationUpdate(
        SosLocationUpdate(
          sosSessionId: 'session-1',
          latitude: 40.02,
          longitude: 41.02,
          recordedAtUtc: DateTime.now().toUtc(),
          windowEndsAtUtc: DateTime.now().toUtc().add(const Duration(minutes: 5)),
        ),
      );
      await tester.pump();

      final map = tester.widget<VectorMap>(find.byType(VectorMap));
      expect(map.markers.single.lat, 30.01);
      expect(map.markers.single.lng, 31.01);
      expect(find.text('00:00'), findsOneWidget);
    },
  );

  testWidgets('renders the sender\'s position on the responder map', (
    tester,
  ) async {
    final endsAtUtc = DateTime.now().toUtc().add(const Duration(minutes: 5));
    final hubClient = FakeSosHubClient();
    await tester.pumpWidget(
      _wrap(
        initialState: SosResponderState(
          activeSession: _incomingSession(liveWindowEndsAtUtc: endsAtUtc),
        ),
        sosApi: FakeSosApi(),
        hubClient: hubClient,
      ),
    );
    await tester.pump();

    hubClient.emitLiveLocationUpdate(
      SosLocationUpdate(
        sosSessionId: 'session-1',
        latitude: 30.0444,
        longitude: 31.2357,
        recordedAtUtc: DateTime.now().toUtc(),
        windowEndsAtUtc: endsAtUtc,
      ),
    );
    await tester.pump();

    final map = tester.widget<VectorMap>(find.byType(VectorMap));
    expect(map.markers.single.lat, 30.0444);
    expect(map.markers.single.lng, 31.2357);
  });

  testWidgets(
    'renders the live-active headline and end-time copy on the sender screen',
    (tester) async {
      final endsAtUtc = DateTime.now().toUtc().add(const Duration(minutes: 5));
      final session = SosSession(
        sosSessionId: 'session-1',
        familyId: 'family-1',
        triggeredByUserId: 'self-user',
        status: SosSessionStatus.active,
        triggeredAtUtc: DateTime.now().toUtc(),
        receivedAtUtc: DateTime.now().toUtc(),
        liveWindowEndsAtUtc: endsAtUtc,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sosControllerProvider.overrideWith(
              () => _FixedSosController(SosLiveActive(session, endsAtUtc)),
            ),
          ],
          child: const MaterialApp(home: SenderEmergencySessionScreen()),
        ),
      );
      await tester.pump();

      expect(find.text('Streaming your live location'), findsOneWidget);
      expect(find.textContaining('Live until'), findsOneWidget);
    },
  );
}
