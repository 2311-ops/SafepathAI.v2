// Behavior under test (03-07-PLAN.md Task 1):
// - Triggering SOS with no connectivity queues immediately, persists the
//   pending payload before the first network attempt, retries on an
//   escalating backoff, reuses the one session id on every retry, submits
//   sooner when connectivity returns (a hint only — not proof of
//   reachability), resumes the same emergency across an app restart, and
//   never turns a rejected (non-network) payload into an infinite retry
//   loop (D-12..D-17).
// - No test below sleeps in real wall-clock time: the offline-retry backoff
//   timer is routed entirely through `FakeSosRetryScheduler`, which records
//   what was scheduled and lets the test fire it manually.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mobile/core/network/connectivity_service.dart';
import 'package:mobile/features/family/application/family_controller.dart';
import 'package:mobile/features/family/data/family_models.dart';
import 'package:mobile/features/location/application/location_controller.dart';
import 'package:mobile/features/sos/application/sos_controller.dart';
import 'package:mobile/features/sos/application/sos_session_state.dart';
import 'package:mobile/features/sos/data/sos_api.dart';
import 'package:mobile/features/sos/data/sos_hub_client.dart';
import 'package:mobile/features/sos/data/sos_local_store.dart';
import 'package:mobile/features/sos/data/sos_models.dart';

import '../../helpers/fake_connectivity_service.dart';
import '../../helpers/fake_sos_api.dart';
import '../../helpers/fake_sos_hub_client.dart';
import '../../helpers/fake_sos_local_store.dart';

/// Records every scheduled backoff without ever starting a real [Timer], so
/// a test can inspect the delay requested and fire it deterministically.
class _FakeRetryHandle implements SosRetryHandle {
  bool canceled = false;

  @override
  void cancel() => canceled = true;
}

class FakeSosRetryScheduler implements SosRetryScheduler {
  final List<Duration> scheduledDelays = [];
  void Function()? _pendingCallback;
  _FakeRetryHandle? _pendingHandle;

  @override
  SosRetryHandle schedule(Duration delay, void Function() callback) {
    scheduledDelays.add(delay);
    final handle = _FakeRetryHandle();
    _pendingCallback = callback;
    _pendingHandle = handle;
    return handle;
  }

  /// Simulates the most recently scheduled backoff timer firing. A no-op if
  /// nothing is currently scheduled, or if it was canceled (e.g. by a
  /// connectivity-triggered immediate retry) before this call.
  void fire() {
    final handle = _pendingHandle;
    final callback = _pendingCallback;
    _pendingCallback = null;
    _pendingHandle = null;
    if (handle == null || handle.canceled || callback == null) return;
    callback();
  }
}

class _FixedFamilyController extends FamilyController {
  @override
  FamilyState build() => const FamilyState(family: Family(id: 'family-1'));
}

class _EmptyLocationController extends LocationController {
  @override
  LocationState build() => const LocationState();
}

ProviderContainer _container({
  required FakeSosApi sosApi,
  required FakeSosLocalStore localStore,
  required FakeConnectivityService connectivity,
  required FakeSosRetryScheduler scheduler,
}) {
  return ProviderContainer(
    overrides: [
      familyControllerProvider.overrideWith(_FixedFamilyController.new),
      locationControllerProvider.overrideWith(_EmptyLocationController.new),
      sosApiProvider.overrideWithValue(sosApi),
      sosLocalStoreProvider.overrideWithValue(localStore),
      connectivityServiceProvider.overrideWithValue(connectivity),
      sosRetrySchedulerProvider.overrideWithValue(scheduler),
      // Default sosHubClientProvider reads the real Supabase client, which
      // is never initialized in a unit-test process — overriding with the
      // hand-written fake lets SosController.build() actually complete
      // (and thus establish the connectivity subscription this file tests)
      // instead of silently failing into an AsyncError before that line.
      sosHubClientProvider.overrideWithValue(FakeSosHubClient()),
    ],
  );
}

void main() {
  late FakeSosApi sosApi;
  late FakeSosLocalStore localStore;
  late FakeConnectivityService connectivity;
  late FakeSosRetryScheduler scheduler;
  late ProviderContainer container;

  setUp(() {
    sosApi = FakeSosApi();
    localStore = FakeSosLocalStore();
    connectivity = FakeConnectivityService();
    scheduler = FakeSosRetryScheduler();
    container = _container(
      sosApi: sosApi,
      localStore: localStore,
      connectivity: connectivity,
      scheduler: scheduler,
    );
  });

  tearDown(() {
    container.dispose();
    unawaited(connectivity.dispose());
  });

  test(
    'enters the queued state immediately when the first submit fails with '
    'a network error',
    () async {
      sosApi.triggerError = SosApiException(SosApiIssue.network);
      final controller = container.read(sosControllerProvider.notifier);

      await controller.arm();

      final state = container.read(sosControllerProvider).value;
      expect(state, isA<SosOfflineQueued>());
      final queued = state as SosOfflineQueued;
      expect(queued.sessionId, controller.sosSessionId);
      expect(queued.retryCount, 1);
    },
  );

  test(
    'persists the pending trigger payload before attempting to send',
    () async {
      final completer = Completer<SosSession>();
      sosApi.pendingTriggerCompleter = completer;
      final controller = container.read(sosControllerProvider.notifier);

      unawaited(controller.arm());
      await pumpEventQueue();

      expect(localStore.pendingTrigger, isNotNull);
      expect(localStore.pendingTrigger!.sosSessionId, controller.sosSessionId);

      completer.completeError(SosApiException(SosApiIssue.network));
      await pumpEventQueue();
    },
  );

  test('retries on a backoff without user action', () async {
    sosApi.triggerError = SosApiException(SosApiIssue.network);
    final controller = container.read(sosControllerProvider.notifier);

    await controller.arm();
    expect(scheduler.scheduledDelays, hasLength(1));
    expect(sosApi.triggerCallCount, 1);
    final firstQueued =
        container.read(sosControllerProvider).value as SosOfflineQueued;

    scheduler.fire();
    await pumpEventQueue();

    expect(sosApi.triggerCallCount, 2);
    expect(scheduler.scheduledDelays, hasLength(2));
    expect(
      scheduler.scheduledDelays[1],
      greaterThan(scheduler.scheduledDelays[0]),
    );
    final secondQueued =
        container.read(sosControllerProvider).value as SosOfflineQueued;
    expect(secondQueued.retryCount, firstQueued.retryCount + 1);
    expect(
      secondQueued.lastRetryAtUtc.isAfter(firstQueued.lastRetryAtUtc) ||
          secondQueued.lastRetryAtUtc.isAtSameMomentAs(
            firstQueued.lastRetryAtUtc,
          ),
      isTrue,
    );
  });

  test('reuses the same session id across every retry', () async {
    sosApi.triggerError = SosApiException(SosApiIssue.network);
    final controller = container.read(sosControllerProvider.notifier);

    await controller.arm();
    scheduler.fire();
    await pumpEventQueue();
    scheduler.fire();
    await pumpEventQueue();

    expect(sosApi.triggerCallCount, 3);
    final sessionIds = sosApi.triggerCalls
        .map((request) => request.sosSessionId)
        .toSet();
    expect(sessionIds, hasLength(1));
    expect(sessionIds.single, controller.sosSessionId);
  });

  test('submits immediately when connectivity returns', () async {
    sosApi.triggerError = SosApiException(SosApiIssue.network);
    final controller = container.read(sosControllerProvider.notifier);
    await controller.arm();
    expect(sosApi.triggerCallCount, 1);

    connectivity.emit(true);
    await pumpEventQueue();

    // The connectivity-triggered attempt fired without waiting for the
    // scheduled backoff to be manually advanced.
    expect(sosApi.triggerCallCount, 2);
    expect(controller.sosSessionId, isNotNull);
  });

  test(
    'still retries when the connectivity service reports offline',
    () async {
      sosApi.triggerError = SosApiException(SosApiIssue.network);
      final controller = container.read(sosControllerProvider.notifier);
      await controller.arm();

      connectivity.emit(false);
      await pumpEventQueue();
      // A "no interface" report must never itself schedule/suppress a
      // retry — only the HTTP call's own outcome does that.
      expect(sosApi.triggerCallCount, 1);

      scheduler.fire();
      await pumpEventQueue();

      expect(sosApi.triggerCallCount, 2);
      expect(
        container.read(sosControllerProvider).value,
        isA<SosOfflineQueued>(),
      );
    },
  );

  test(
    'leaves the queued state and clears the pending payload on a '
    'successful retry',
    () async {
      sosApi.triggerError = SosApiException(SosApiIssue.network);
      final controller = container.read(sosControllerProvider.notifier);
      await controller.arm();
      expect(localStore.pendingTrigger, isNotNull);

      sosApi.triggerError = null;
      scheduler.fire();
      await pumpEventQueue();

      final state = container.read(sosControllerProvider).value;
      expect(state, isA<SosSubmitted>());
      expect((state as SosSubmitted).session.sosSessionId, controller.sosSessionId);
      expect(localStore.pendingTrigger, isNull);
    },
  );

  test('resumes the same emergency after an app restart', () async {
    final persistedId = 'persisted-session-id';
    final persistedRequest = SosTriggerRequest(
      sosSessionId: persistedId,
      familyId: 'family-1',
      triggeredAtUtc: DateTime.now().toUtc(),
    );
    localStore.savedSessionId = persistedId;
    localStore.pendingTrigger = persistedRequest;
    sosApi.triggerError = SosApiException(SosApiIssue.network);

    // Constructing a fresh controller over a store that already holds a
    // session id and pending payload (as if the app had just been killed
    // and relaunched) — build() is triggered by the first read.
    container.read(sosControllerProvider);
    await pumpEventQueue();

    final state = container.read(sosControllerProvider).value;
    expect(state, isA<SosOfflineQueued>());
    expect((state as SosOfflineQueued).sessionId, persistedId);
    expect(
      sosApi.triggerCalls.any((request) => request.sosSessionId == persistedId),
      isTrue,
    );
  });

  test('reconciles a queued session the server already has', () async {
    sosApi.triggerError = SosApiException(SosApiIssue.network);
    final controller = container.read(sosControllerProvider.notifier);
    await controller.arm();
    final sessionId = controller.sosSessionId!;

    // The retry succeeds because the server already held this exact
    // session id (an idempotent replay, D-15) — the client must treat this
    // exactly like any other successful trigger, never as a conflict/error.
    sosApi.triggerError = null;
    sosApi.triggerResponseBuilder = (request) => SosSession(
      sosSessionId: request.sosSessionId,
      familyId: request.familyId,
      triggeredByUserId: 'self-user',
      status: SosSessionStatus.active,
      triggeredAtUtc: request.triggeredAtUtc,
      receivedAtUtc: DateTime.now().toUtc(),
    );
    scheduler.fire();
    await pumpEventQueue();

    final state = container.read(sosControllerProvider).value;
    expect(state, isA<SosSubmitted>());
    expect((state as SosSubmitted).session.sosSessionId, sessionId);
    expect(container.read(sosControllerProvider).hasError, isFalse);
  });

  test('does not queue on a non-network failure', () async {
    sosApi.triggerError = SosApiException(SosApiIssue.validation);
    final controller = container.read(sosControllerProvider.notifier);

    await controller.arm();

    final asyncState = container.read(sosControllerProvider);
    expect(asyncState.hasError, isTrue);
    expect(asyncState.value, isNot(isA<SosOfflineQueued>()));
    expect(scheduler.scheduledDelays, isEmpty);
  });
}
