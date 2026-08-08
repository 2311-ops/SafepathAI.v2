// Behavior under test (03-02-PLAN.md Task 2):
// - arm() generates a session id and persists it locally before any network
//   call resolves (D-13, D-14).
// - The persisted id equals the controller's own current session id.
// - arm() then submit() reuse the same session id for every trigger call
//   (D-15, client side).
// - A successful trigger moves state to SosSubmitted carrying the server's
//   recipients.
// - closeSession() clears the persisted id so the next arm starts fresh.
// - The SOS path never calls anything but SosApi.trigger/getSession — no
//   routine location-report endpoint is ever touched (SOS-01).

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

/// A fixed, non-loading family circle — enough for `SosController.submit()`
/// to read a `familyId` without touching auth/network machinery.
class _FixedFamilyController extends FamilyController {
  @override
  FamilyState build() => const FamilyState(family: Family(id: 'family-1'));
}

/// Empty, non-loading location state so `SosController` never touches a
/// real geolocator/hub client — and so the "no cold GPS fix" path is
/// exercised (self position is absent).
class _EmptyLocationController extends LocationController {
  @override
  LocationState build() => const LocationState();
}

ProviderContainer _container({
  required FakeSosApi sosApi,
  required FakeSosLocalStore localStore,
  FakeConnectivityService? connectivity,
}) {
  return ProviderContainer(
    overrides: [
      familyControllerProvider.overrideWith(_FixedFamilyController.new),
      locationControllerProvider.overrideWith(_EmptyLocationController.new),
      sosApiProvider.overrideWithValue(sosApi),
      sosLocalStoreProvider.overrideWithValue(localStore),
      connectivityServiceProvider.overrideWithValue(
        connectivity ?? FakeConnectivityService(),
      ),
      // Default sosHubClientProvider reads the real Supabase client, which
      // is never initialized in a unit-test process — overriding with the
      // hand-written fake lets SosController.build() actually complete
      // instead of silently failing into an AsyncError that later test
      // assertions happen to overwrite anyway.
      sosHubClientProvider.overrideWithValue(FakeSosHubClient()),
    ],
  );
}

void main() {
  late FakeSosApi sosApi;
  late FakeSosLocalStore localStore;
  late ProviderContainer container;

  setUp(() {
    sosApi = FakeSosApi();
    localStore = FakeSosLocalStore();
    container = _container(sosApi: sosApi, localStore: localStore);
  });

  tearDown(() {
    container.dispose();
  });

  test('generates a session id before any network call', () async {
    final pending = Completer<SosSession>();
    sosApi.pendingTriggerCompleter = pending;

    final controller = container.read(sosControllerProvider.notifier);
    unawaited(controller.arm());
    await pumpEventQueue();

    expect(controller.sosSessionId, isNotNull);
    expect(controller.sosSessionId, isNotEmpty);
    expect(localStore.savedSessionId, controller.sosSessionId);

    // Let the in-flight trigger settle so the container can be torn down
    // cleanly.
    pending.complete(
      SosSession(
        sosSessionId: controller.sosSessionId!,
        familyId: 'family-1',
        triggeredByUserId: 'self-user',
        status: SosSessionStatus.active,
        triggeredAtUtc: DateTime.now().toUtc(),
        receivedAtUtc: DateTime.now().toUtc(),
      ),
    );
    await pumpEventQueue();
  });

  test('persists the session id to the local store', () async {
    final controller = container.read(sosControllerProvider.notifier);
    await controller.arm();

    expect(localStore.savedSessionId, isNotNull);
    expect(localStore.savedSessionId, controller.sosSessionId);
  });

  test('reuses the persisted id on resubmission', () async {
    final controller = container.read(sosControllerProvider.notifier);
    await controller.arm();
    await controller.submit();

    expect(sosApi.triggerCallCount, 2);
    expect(
      sosApi.triggerCalls[0].sosSessionId,
      sosApi.triggerCalls[1].sosSessionId,
    );
    expect(sosApi.triggerCalls[0].sosSessionId, controller.sosSessionId);
  });

  test('moves to submitted state on a successful trigger', () async {
    sosApi.triggerResponseBuilder = (request) => SosSession(
      sosSessionId: request.sosSessionId,
      familyId: request.familyId,
      triggeredByUserId: 'self-user',
      status: SosSessionStatus.active,
      triggeredAtUtc: request.triggeredAtUtc,
      receivedAtUtc: DateTime.now().toUtc(),
      recipients: const [
        SosRecipientStatus(displayName: 'Guardian One', channels: []),
      ],
    );

    final controller = container.read(sosControllerProvider.notifier);
    await controller.arm();

    final state = container.read(sosControllerProvider).value;
    expect(state, isA<SosSubmitted>());
    final submitted = state as SosSubmitted;
    expect(submitted.session.recipients, hasLength(1));
    expect(submitted.session.recipients.first.displayName, 'Guardian One');
  });

  test('clears the persisted id when the session is closed', () async {
    final controller = container.read(sosControllerProvider.notifier);
    await controller.arm();
    expect(localStore.savedSessionId, isNotNull);

    await controller.closeSession();

    expect(localStore.savedSessionId, isNull);
    expect(controller.sosSessionId, isNull);
    expect(container.read(sosControllerProvider).value, isA<SosIdle>());
  });

  test('does not call the location report endpoint', () async {
    final controller = container.read(sosControllerProvider.notifier);
    await controller.arm();

    // FakeSosApi exposes only trigger/getSession — there is no location
    // report method for the SOS path to reach, and only trigger was called.
    expect(sosApi.triggerCallCount, 1);
    expect(sosApi.getSessionCallCount, 0);
  });
}
