// Behavior under test (03-09-PLAN.md Task 1, SOS-05, D-05/D-24):
// - holding the cancel control for the full 2000ms records exactly one
//   `cancel` call on the fake API
// - releasing before 2000ms cancels nothing and the ring resets
// - a plain tap cancels nothing
// - completing the hold shows no confirmation dialog anywhere in the tree
// - cancelling moves the sender to the locked "Alert canceled" copy
// - the canceled state uses the de-escalated Deep Teal chrome, never red
// - cancelling stops the live-location stream exactly once
// - the recipient delivery list captured before cancelling stays visible
//   after cancelling — nothing about the original alert is retracted

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';

import 'package:mobile/core/network/connectivity_service.dart';
import 'package:mobile/core/theme/app_colors.dart';
import 'package:mobile/features/family/application/family_controller.dart';
import 'package:mobile/features/family/data/family_models.dart';
import 'package:mobile/features/location/application/location_controller.dart';
import 'package:mobile/features/sos/application/sos_controller.dart';
import 'package:mobile/features/sos/application/sos_live_location_service.dart';
import 'package:mobile/features/sos/application/sos_session_state.dart';
import 'package:mobile/features/sos/data/sos_api.dart';
import 'package:mobile/features/sos/data/sos_hub_client.dart';
import 'package:mobile/features/sos/data/sos_local_store.dart';
import 'package:mobile/features/sos/data/sos_models.dart';
import 'package:mobile/features/sos/presentation/sender_emergency_session_screen.dart';
import 'package:mobile/features/sos/presentation/sos_arm_ring_painter.dart';
import 'package:mobile/features/sos/presentation/sos_hold_to_cancel_button.dart';

import '../../helpers/fake_connectivity_service.dart';
import '../../helpers/fake_location_permission_service.dart';
import '../../helpers/fake_sos_api.dart';
import '../../helpers/fake_sos_hub_client.dart';
import '../../helpers/fake_sos_local_store.dart';

class _FixedFamilyController extends FamilyController {
  @override
  FamilyState build() => const FamilyState(family: Family(id: 'family-1'));
}

class _EmptyLocationController extends LocationController {
  @override
  LocationState build() => const LocationState();
}

class _NoOpForegroundTaskHost implements SosForegroundTaskHost {
  @override
  Future<void> start({
    required String notificationTitle,
    required String notificationText,
  }) async {}

  @override
  Future<void> stop() async {}
}

class _NoOpPositionSource implements SosPositionSource {
  @override
  Stream<Position> positions() => const Stream<Position>.empty();

  @override
  Future<Position> currentPosition() => Future.error(StateError('no fix'));
}

class _NoOpExpiryScheduler implements SosRetryScheduler {
  @override
  SosRetryHandle schedule(Duration delay, void Function() callback) =>
      _NoOpRetryHandle();
}

class _NoOpRetryHandle implements SosRetryHandle {
  @override
  void cancel() {}
}

/// Overrides both [start] and [stop] directly rather than exercising the
/// real foreground-service/position-subscription teardown chain — this
/// test's only concern is "does `SosController.cancel()` call
/// `SosLiveLocationService.stop()` exactly once", not the service's own
/// internal shutdown mechanics (already covered end-to-end by
/// `sos_live_window_test.dart`). Mirrors the real class's own
/// `_isStreaming`-gated idempotency (`SosController._replaceState`'s
/// generic leaving-live-active handling always fires a second,
/// belt-and-suspenders `stop()` call right after the explicit one in
/// `cancel()` — the real class swallows that redundant second call the
/// same way this fake does).
class _RecordingSosLiveLocationService extends SosLiveLocationService {
  _RecordingSosLiveLocationService()
    : super(
        foregroundTaskHost: _NoOpForegroundTaskHost(),
        positionSource: _NoOpPositionSource(),
        sosApi: _UnusedSosApi(),
        permissionService: FakeLocationPermissionService(),
        expiryScheduler: _NoOpExpiryScheduler(),
      );

  int stopCallCount = 0;
  bool _streaming = false;

  @override
  Future<void> start(String sosSessionId, DateTime windowEndsAtUtc) async {
    _streaming = true;
  }

  @override
  Future<void> stop() async {
    if (!_streaming) return;
    _streaming = false;
    stopCallCount++;
  }
}

/// A [SosApi] this service instance never actually calls — [stop] is
/// overridden above before any of these methods would be reached.
class _UnusedSosApi implements SosApi {
  @override
  Future<SosSession> trigger(SosTriggerRequest request) =>
      throw UnimplementedError();

  @override
  Future<SosSession> getSession(String sosSessionId) =>
      throw UnimplementedError();

  @override
  Future<SosSession> acknowledge(String sosSessionId) =>
      throw UnimplementedError();

  @override
  Future<SosSession> cancel(String sosSessionId) => throw UnimplementedError();

  @override
  Future<SosLocationWindow> reportSosLocation(
    String sosSessionId,
    double latitude,
    double longitude,
    double? accuracyMeters,
    DateTime recordedAtUtc,
  ) => throw UnimplementedError();
}

ProviderContainer _container({
  required FakeSosApi sosApi,
  FakeSosHubClient? hubClient,
  SosLiveLocationService? liveLocationService,
}) {
  return ProviderContainer(
    overrides: [
      familyControllerProvider.overrideWith(_FixedFamilyController.new),
      locationControllerProvider.overrideWith(_EmptyLocationController.new),
      sosApiProvider.overrideWithValue(sosApi),
      sosLocalStoreProvider.overrideWithValue(FakeSosLocalStore()),
      connectivityServiceProvider.overrideWithValue(
        FakeConnectivityService(),
      ),
      sosHubClientProvider.overrideWithValue(hubClient ?? FakeSosHubClient()),
      if (liveLocationService != null)
        sosLiveLocationServiceProvider.overrideWithValue(liveLocationService),
    ],
  );
}

SosRecipientStatus _recipient({String name = 'Ana', String? userId = 'ana-user-id'}) {
  return SosRecipientStatus(
    displayName: name,
    recipientUserId: userId,
    channels: const [
      SosChannelStatus(
        channel: SosChannel.signalR,
        status: SosDeliveryStatus.queued,
      ),
    ],
  );
}

/// Arms a fresh session (with one recipient) and pushes a delivery-status
/// update so the controller lands on `SosDelivering` — the state that
/// renders `SosHoldToCancelButton` alongside the recipient delivery list.
///
/// Flushes with `tester.pump()`, never `pumpEventQueue()` — this helper runs
/// inside `testWidgets`, where `TestWidgetsFlutterBinding` intercepts every
/// `Timer` (including the zero-duration one `pumpEventQueue()` schedules
/// internally) behind a fake clock that only `tester.pump()` advances;
/// awaiting `pumpEventQueue()` here would hang forever.
Future<SosController> _armDeliveringSession(
  WidgetTester tester, {
  required ProviderContainer container,
  required FakeSosApi sosApi,
  required FakeSosHubClient hubClient,
}) async {
  sosApi.triggerResponseBuilder = (request) => SosSession(
    sosSessionId: request.sosSessionId,
    familyId: request.familyId,
    triggeredByUserId: 'self-user',
    status: SosSessionStatus.active,
    triggeredAtUtc: request.triggeredAtUtc,
    receivedAtUtc: DateTime.now().toUtc(),
    recipients: [_recipient()],
  );

  final controller = container.read(sosControllerProvider.notifier);
  await controller.arm();
  await tester.pump();

  hubClient.emitDeliveryStatusChanged(
    SosDeliveryStatusChange(
      sosSessionId: controller.sosSessionId!,
      recipientUserId: 'ana-user-id',
      channel: SosChannel.signalR,
      status: SosDeliveryStatus.delivered,
      atUtc: DateTime.now().toUtc(),
    ),
  );
  await tester.pump();

  return controller;
}

void main() {
  late FakeSosApi sosApi;
  late FakeSosHubClient hubClient;
  late ProviderContainer container;

  setUp(() {
    sosApi = FakeSosApi();
    hubClient = FakeSosHubClient();
    sosApi.cancelResponseBuilder = (id) => SosSession(
      sosSessionId: id,
      familyId: 'family-1',
      triggeredByUserId: 'self-user',
      status: SosSessionStatus.canceled,
      triggeredAtUtc: DateTime.now().toUtc(),
      receivedAtUtc: DateTime.now().toUtc(),
      canceledAtUtc: DateTime.now().toUtc(),
      recipients: [_recipient()],
    );
    container = _container(sosApi: sosApi, hubClient: hubClient);
  });

  tearDown(() {
    container.dispose();
  });

  Future<void> pumpSession(WidgetTester tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: SenderEmergencySessionScreen()),
      ),
    );
    await tester.pump();
  }

  testWidgets('cancels after a two-second hold', (tester) async {
    await _armDeliveringSession(
      tester,
      container: container,
      sosApi: sosApi,
      hubClient: hubClient,
    );
    await pumpSession(tester);

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(SosHoldToCancelButton)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 2000));
    await tester.pump(const Duration(milliseconds: 1));
    await gesture.up();
    await tester.pump();

    expect(sosApi.cancelCallCount, 1);
  });

  testWidgets('does not cancel on a shorter hold', (tester) async {
    await _armDeliveringSession(
      tester,
      container: container,
      sosApi: sosApi,
      hubClient: hubClient,
    );
    await pumpSession(tester);

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(SosHoldToCancelButton)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1500));
    await gesture.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(sosApi.cancelCallCount, 0);

    final painter =
        tester
                .widget<CustomPaint>(
                  find.descendant(
                    of: find.byType(SosHoldToCancelButton),
                    matching: find.byType(CustomPaint),
                  ),
                )
                .painter
            as SosArmRingPainter;
    expect(painter.progress, 0);
  });

  testWidgets('does not cancel on a single tap', (tester) async {
    await _armDeliveringSession(
      tester,
      container: container,
      sosApi: sosApi,
      hubClient: hubClient,
    );
    await pumpSession(tester);

    await tester.tap(find.byType(SosHoldToCancelButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 2500));

    expect(sosApi.cancelCallCount, 0);
  });

  testWidgets('shows no confirmation dialog', (tester) async {
    await _armDeliveringSession(
      tester,
      container: container,
      sosApi: sosApi,
      hubClient: hubClient,
    );
    await pumpSession(tester);

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(SosHoldToCancelButton)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 2000));
    await tester.pump(const Duration(milliseconds: 1));
    await gesture.up();
    // Not pumpAndSettle(): the screen's elapsed-time ticker
    // (`Timer.periodic(seconds: 1)`) keeps scheduling frames for as long as
    // it is mounted, so pumpAndSettle() never settles here — matches
    // responder_alert_screen_test.dart's own convention of pumping this
    // screen with explicit durations instead.
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(Dialog), findsNothing);
  });

  testWidgets(
    'moves the sender to the canceled state with the locked copy',
    (tester) async {
      await _armDeliveringSession(
        tester,
        container: container,
        sosApi: sosApi,
        hubClient: hubClient,
      );
      await pumpSession(tester);

      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(SosHoldToCancelButton)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 2000));
      await tester.pump(const Duration(milliseconds: 1));
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 250));

      expect(find.text('Alert canceled'), findsOneWidget);
      expect(find.textContaining('You canceled this alert at'), findsOneWidget);
    },
  );

  testWidgets('uses the de-escalated chrome rather than red', (tester) async {
    await _armDeliveringSession(
      tester,
      container: container,
      sosApi: sosApi,
      hubClient: hubClient,
    );
    await pumpSession(tester);

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(SosHoldToCancelButton)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 2000));
    await tester.pump(const Duration(milliseconds: 1));
    await gesture.up();
    // Not pumpAndSettle(): the screen's elapsed-time ticker
    // (`Timer.periodic(seconds: 1)`) keeps scheduling frames for as long as
    // it is mounted, so pumpAndSettle() never settles here — matches
    // responder_alert_screen_test.dart's own convention of pumping this
    // screen with explicit durations instead.
    await tester.pump(const Duration(milliseconds: 250));

    final chrome = tester.widget<DecoratedBox>(
      find.byKey(const ValueKey('sender-chrome')),
    );
    final decoration = chrome.decoration as BoxDecoration;
    expect(decoration.color, AppColors.deepTeal);
    expect(decoration.gradient, isNull);
  });

  testWidgets(
    'keeps the delivery list visible after cancelling',
    (tester) async {
      await _armDeliveringSession(
        tester,
        container: container,
        sosApi: sosApi,
        hubClient: hubClient,
      );
      await pumpSession(tester);

      expect(find.text('Ana'), findsOneWidget);

      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(SosHoldToCancelButton)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 2000));
      await tester.pump(const Duration(milliseconds: 1));
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 250));

      expect(find.text('Ana'), findsOneWidget);
    },
  );

  // Exercises SosController.cancel()'s live-location shutdown directly
  // (mirrors sos_live_window_test.dart's own controller-level convention)
  // rather than through SosHoldToCancelButton's gesture — the hold-to-cancel
  // mechanics themselves are already covered end-to-end by "cancels after a
  // two-second hold" above; this test's own concern is purely whether
  // SosController.cancel() calls SosLiveLocationService.stop() exactly
  // once. [_RecordingSosLiveLocationService] overrides stop() directly
  // rather than exercising the service's own real foreground-service/
  // position-subscription teardown, which is separately covered end-to-end
  // by sos_live_window_test.dart.
  testWidgets('stops live-location streaming on cancel', (tester) async {
    final liveLocationService = _RecordingSosLiveLocationService();
    final liveContainer = _container(
      sosApi: sosApi,
      hubClient: hubClient,
      liveLocationService: liveLocationService,
    );
    addTearDown(liveContainer.dispose);

    sosApi.triggerResponseBuilder = (request) => SosSession(
      sosSessionId: request.sosSessionId,
      familyId: request.familyId,
      triggeredByUserId: 'self-user',
      status: SosSessionStatus.active,
      triggeredAtUtc: request.triggeredAtUtc,
      receivedAtUtc: DateTime.now().toUtc(),
      liveWindowEndsAtUtc: DateTime.now().toUtc().add(const Duration(minutes: 15)),
      recipients: [_recipient()],
    );

    final controller = liveContainer.read(sosControllerProvider.notifier);
    await controller.arm();
    await tester.pump();
    expect(liveContainer.read(sosControllerProvider).value, isA<SosLiveActive>());

    await controller.cancel();
    await tester.pump();

    expect(sosApi.cancelCallCount, 1);
    expect(liveContainer.read(sosControllerProvider).value, isA<SosCanceled>());
    expect(liveLocationService.stopCallCount, 1);
  });
}
