// Behavior under test (03-08-PLAN.md Task 2):
// - Entering SosLiveActive (a server-issued liveWindowEndsAtUtc on the
//   trigger response) starts the foreground-task host exactly once and
//   streams position fixes into POST /sos/{id}/location, all carrying the
//   session id (D-21/SOS-04).
// - The stream self-terminates on any of: the local clock passing
//   windowEndsAtUtc, the session being canceled, or the server reporting a
//   closed window in a report response — never waiting on more than one of
//   these when several race.
// - The service never starts for an offline-queued or idle session, and
//   reports (rather than throws on, or silently swallows) a denied
//   location permission.
// - No test below sleeps in real wall-clock time: the window-expiry timer
//   is routed through a fake scheduler the test fires manually, matching
//   `sos_offline_retry_test.dart`'s `FakeSosRetryScheduler` convention.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';

import 'package:mobile/core/network/connectivity_service.dart';
import 'package:mobile/features/family/application/family_controller.dart';
import 'package:mobile/features/family/data/family_models.dart';
import 'package:mobile/features/location/application/location_controller.dart';
import 'package:mobile/features/location/application/permission_controller.dart';
import 'package:mobile/features/sos/application/sos_controller.dart';
import 'package:mobile/features/sos/application/sos_live_location_service.dart';
import 'package:mobile/features/sos/application/sos_session_state.dart';
import 'package:mobile/features/sos/data/sos_api.dart';
import 'package:mobile/features/sos/data/sos_hub_client.dart';
import 'package:mobile/features/sos/data/sos_local_store.dart';
import 'package:mobile/features/sos/data/sos_models.dart';

import '../../helpers/fake_connectivity_service.dart';
import '../../helpers/fake_location_permission_service.dart';
import '../../helpers/fake_sos_api.dart';
import '../../helpers/fake_sos_hub_client.dart';
import '../../helpers/fake_sos_local_store.dart';

/// Records start/stop calls without touching a platform channel, so a test
/// can assert exactly how many times the foreground service was launched or
/// torn down.
class _FakeSosForegroundTaskHost implements SosForegroundTaskHost {
  int startCallCount = 0;
  int stopCallCount = 0;
  String? lastNotificationTitle;
  String? lastNotificationText;

  @override
  Future<void> start({
    required String notificationTitle,
    required String notificationText,
  }) async {
    startCallCount++;
    lastNotificationTitle = notificationTitle;
    lastNotificationText = notificationText;
  }

  @override
  Future<void> stop() async {
    stopCallCount++;
  }
}

/// A controllable position stream a test can push fixes through directly.
class _FakeSosPositionSource implements SosPositionSource {
  final StreamController<Position> _controller =
      StreamController<Position>.broadcast();

  /// When set, [currentPosition] resolves to it; otherwise it throws,
  /// matching a denied/unavailable one-shot fix in production.
  Position? immediateFix;

  @override
  Stream<Position> positions() => _controller.stream;

  @override
  Future<Position> currentPosition() async {
    final fix = immediateFix;
    if (fix == null) {
      throw StateError('no immediate fix configured');
    }
    return fix;
  }

  void emit(Position position) => _controller.add(position);

  Future<void> dispose() => _controller.close();
}

/// Records every scheduled expiry without ever starting a real [Timer] —
/// matches `sos_offline_retry_test.dart`'s `FakeSosRetryScheduler` shape
/// (this file defines its own copy rather than importing that test file).
class _FakeRetryHandle implements SosRetryHandle {
  bool canceled = false;

  @override
  void cancel() => canceled = true;
}

class _FakeExpiryScheduler implements SosRetryScheduler {
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

  /// Simulates the most recently scheduled expiry timer firing. A no-op if
  /// nothing is currently scheduled, or if it was canceled (e.g. by a
  /// re-`start()` refreshing the expiry) before this call.
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

Position _position({double lat = 30.0444, double lng = 31.2357}) {
  return Position(
    latitude: lat,
    longitude: lng,
    timestamp: DateTime.now().toUtc(),
    accuracy: 5,
    altitude: 0,
    altitudeAccuracy: 0,
    heading: 0,
    headingAccuracy: 0,
    speed: 0,
    speedAccuracy: 0,
  );
}

void main() {
  late FakeSosApi sosApi;
  late FakeSosLocalStore localStore;
  late FakeConnectivityService connectivity;
  late FakeSosHubClient hubClient;
  late FakeLocationPermissionService permissionService;
  late _FakeSosForegroundTaskHost foregroundTaskHost;
  late _FakeSosPositionSource positionSource;
  late _FakeExpiryScheduler expiryScheduler;
  late SosLiveLocationService liveLocationService;
  late ProviderContainer container;

  setUp(() {
    sosApi = FakeSosApi();
    localStore = FakeSosLocalStore();
    connectivity = FakeConnectivityService();
    hubClient = FakeSosHubClient();
    permissionService = FakeLocationPermissionService();
    foregroundTaskHost = _FakeSosForegroundTaskHost();
    positionSource = _FakeSosPositionSource();
    expiryScheduler = _FakeExpiryScheduler();
    liveLocationService = SosLiveLocationService(
      foregroundTaskHost: foregroundTaskHost,
      positionSource: positionSource,
      sosApi: sosApi,
      permissionService: permissionService,
      expiryScheduler: expiryScheduler,
    );

    container = ProviderContainer(
      overrides: [
        familyControllerProvider.overrideWith(_FixedFamilyController.new),
        locationControllerProvider.overrideWith(_EmptyLocationController.new),
        sosApiProvider.overrideWithValue(sosApi),
        sosLocalStoreProvider.overrideWithValue(localStore),
        connectivityServiceProvider.overrideWithValue(connectivity),
        sosHubClientProvider.overrideWithValue(hubClient),
        sosLiveLocationServiceProvider.overrideWithValue(liveLocationService),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await positionSource.dispose();
  });

  /// Triggers with a session whose live window is open [minutes] from now,
  /// landing the controller in `SosLiveActive`.
  Future<SosController> armLiveSession({int minutes = 15}) async {
    sosApi.triggerResponseBuilder = (request) => SosSession(
      sosSessionId: request.sosSessionId,
      familyId: request.familyId,
      triggeredByUserId: 'self-user',
      status: SosSessionStatus.active,
      triggeredAtUtc: request.triggeredAtUtc,
      receivedAtUtc: DateTime.now().toUtc(),
      liveWindowEndsAtUtc: DateTime.now().toUtc().add(Duration(minutes: minutes)),
    );
    final controller = container.read(sosControllerProvider.notifier);
    await controller.arm();
    await pumpEventQueue();
    return controller;
  }

  test('starts streaming when the session goes live', () async {
    await armLiveSession();

    expect(foregroundTaskHost.startCallCount, 1);
  });

  test(
    'reports an immediate fix on start without waiting for movement',
    () async {
      positionSource.immediateFix = _position(lat: 30.05);

      final controller = await armLiveSession();

      expect(sosApi.reportSosLocationCallCount, 1);
      expect(sosApi.reportSosLocationSessionIds, [controller.sosSessionId]);
    },
  );

  test(
    'a missing immediate fix does not prevent the ongoing stream from reporting',
    () async {
      // positionSource.immediateFix left unset — mirrors a denied or
      // timed-out one-shot read in production.
      final controller = await armLiveSession();
      final sessionId = controller.sosSessionId!;

      expect(sosApi.reportSosLocationCallCount, 0);

      positionSource.emit(_position(lat: 30.01));
      await pumpEventQueue();

      expect(sosApi.reportSosLocationCallCount, 1);
      expect(sosApi.reportSosLocationSessionIds, [sessionId]);
    },
  );

  test('posts each fix to the session location endpoint', () async {
    final controller = await armLiveSession();
    final sessionId = controller.sosSessionId!;

    positionSource.emit(_position(lat: 30.01));
    positionSource.emit(_position(lat: 30.02));
    positionSource.emit(_position(lat: 30.03));
    await pumpEventQueue();

    expect(sosApi.reportSosLocationCallCount, 3);
    expect(
      sosApi.reportSosLocationSessionIds,
      everyElement(equals(sessionId)),
    );
  });

  test('stops streaming when the window end time passes', () async {
    await armLiveSession();

    expiryScheduler.fire();
    await pumpEventQueue();

    expect(foregroundTaskHost.stopCallCount, 1);

    positionSource.emit(_position());
    await pumpEventQueue();
    expect(sosApi.reportSosLocationCallCount, 0);
  });

  test('stops streaming when the session is canceled', () async {
    final controller = await armLiveSession();
    final sessionId = controller.sosSessionId!;

    hubClient.emitSosCanceled(
      SosCancellation(
        sosSessionId: sessionId,
        canceledByUserId: 'self-user',
        canceledByDisplayName: 'Self',
        canceledAtUtc: DateTime.now().toUtc(),
      ),
    );
    await pumpEventQueue();

    expect(foregroundTaskHost.stopCallCount, 1);
  });

  test(
    'stops streaming when the server says the window has closed',
    () async {
      await armLiveSession();
      sosApi.reportSosLocationResponseBuilder = (_) => const SosLocationWindow(
        outcome: SosLocationWindowOutcome.windowClosed,
      );

      positionSource.emit(_position());
      await pumpEventQueue();

      expect(foregroundTaskHost.stopCallCount, 1);
    },
  );

  test('does not start streaming for a queued offline session', () async {
    sosApi.triggerError = SosApiException(SosApiIssue.network);
    final controller = container.read(sosControllerProvider.notifier);

    await controller.arm();
    await pumpEventQueue();

    expect(container.read(sosControllerProvider).value, isA<SosOfflineQueued>());
    expect(foregroundTaskHost.startCallCount, 0);
  });

  test(
    'surfaces a clear state when location permission is denied',
    () async {
      permissionService.status = LocationPermissionStatus.denied;

      final controller = await armLiveSession();

      expect(
        container.read(sosControllerProvider).value,
        isA<SosLiveActive>(),
      );
      expect(foregroundTaskHost.startCallCount, 0);
      expect(
        liveLocationService.availability,
        SosLiveLocationAvailability.unavailablePermissionDenied,
      );
      // No pending trigger session id was ever cleared/lost — the session
      // remains fully resumable, just without a local stream.
      expect(controller.sosSessionId, isNotNull);
    },
  );

  test('starts no host when the app has no active SOS session', () async {
    final controller = await armLiveSession();
    expect(foregroundTaskHost.startCallCount, 1);

    await controller.closeSession();
    await pumpEventQueue();

    expect(foregroundTaskHost.stopCallCount, 1);
    expect(container.read(sosControllerProvider).value, isA<SosIdle>());
  });
}
