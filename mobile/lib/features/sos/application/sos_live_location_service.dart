import 'dart:async';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../location/application/permission_controller.dart';
import '../data/sos_api.dart';
import 'sos_controller.dart';

/// Abstraction over the platform foreground-task capability so
/// [SosLiveLocationService] never touches a platform channel directly and
/// `sos_live_window_test.dart` can drive it with a fake. Scoped exclusively
/// to the active SOS window (D-31) — this is not a general background-
/// tracking capability.
abstract class SosForegroundTaskHost {
  Future<void> start({
    required String notificationTitle,
    required String notificationText,
  });

  Future<void> stop();
}

/// Real implementation backed by `flutter_foreground_task` v10.0.0. Sets
/// `stopWithTask: false` (D-33) so the plugin's own `onTaskRemoved`
/// restart-alarm logic (see its `ForegroundService.kt`) keeps the stream
/// alive if the sender swipes the app away from Android's recents screen —
/// this is paired with `android:stopWithTask="false"` on the manifest
/// `<service>` declaration for defense-in-depth (either alone satisfies the
/// plugin's own `isSetStopWithTaskFlag` check). [stop] still shuts the
/// service down cleanly for every legitimate termination path (window-end,
/// cancellation, explicit stop) — the plugin marks a `stopService()` call as
/// "correctly stopped" internally, so the restart-alarm logic never
/// resurrects a deliberately-stopped service. OEM battery managers
/// (Xiaomi, Huawei, Samsung, etc.) can still override this regardless — an
/// accepted platform limitation, not a defect in this configuration.
class FlutterForegroundTaskHost implements SosForegroundTaskHost {
  const FlutterForegroundTaskHost();

  static const int _serviceId = 8503;

  @override
  Future<void> start({
    required String notificationTitle,
    required String notificationText,
  }) async {
    FlutterForegroundTask.initCommunicationPort();
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'sos_live_location',
        channelName: 'Emergency live location',
        channelDescription:
            'Shown while your live location is being shared with your '
            'guardians during an active SOS.',
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.nothing(),
        autoRunOnBoot: false,
        autoRunOnMyPackageReplaced: false,
        allowWakeLock: true,
        allowWifiLock: false,
        // D-33: survives the app being swiped from Android's recents
        // screen mid-emergency — see class doc.
        stopWithTask: false,
      ),
    );

    if (await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.updateService(
        notificationTitle: notificationTitle,
        notificationText: notificationText,
      );
      return;
    }

    await FlutterForegroundTask.startService(
      serviceId: _serviceId,
      notificationTitle: notificationTitle,
      notificationText: notificationText,
      callback: _sosForegroundTaskStartCallback,
    );
  }

  @override
  Future<void> stop() async {
    if (await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.stopService();
    }
  }
}

/// The foreground-service host merely keeps the app process alive with a
/// persistent notification while the SOS window is open — the actual
/// position-stream/report loop runs in the main isolate ([SosLiveLocationService]
/// itself), not inside this TaskHandler. This handler intentionally does
/// nothing beyond satisfying the plugin's callback contract.
@pragma('vm:entry-point')
void _sosForegroundTaskStartCallback() {
  FlutterForegroundTask.setTaskHandler(_SosNoOpTaskHandler());
}

class _SosNoOpTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {}

  @override
  void onRepeatEvent(DateTime timestamp) {}

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {}
}

/// Abstraction over the device position stream so
/// [SosLiveLocationService] never touches `geolocator`'s platform channel
/// directly and `sos_live_window_test.dart` can drive it with a fake fix
/// stream. Deliberately separate from `positionStreamProvider`
/// (`location_controller.dart`) — this stream uses emergency-appropriate
/// settings, not the routine 10m-distance-filter one, and this feature must
/// never share a subscription with routine tracking (Core Value/SOS-01).
abstract class SosPositionSource {
  Stream<Position> positions();
}

class GeolocatorSosPositionSource implements SosPositionSource {
  const GeolocatorSosPositionSource();

  @override
  Stream<Position> positions() => Geolocator.getPositionStream(
    locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.best,
      distanceFilter: 5,
    ),
  );
}

/// Whether [SosLiveLocationService] is actually streaming, and why not when
/// it isn't. Exposed so a future UI surface can say live location is
/// unavailable rather than silently showing nothing when permission is
/// missing — this plan does not yet render that state (see SUMMARY).
enum SosLiveLocationAvailability {
  idle,
  streaming,
  unavailablePermissionDenied,
  stopped,
}

/// Streams the sender's position into the active SOS's live-location window
/// for exactly as long as the window is open (D-21/SOS-04), surviving the
/// phone being locked or the app being backgrounded via a foreground
/// service scoped strictly to this window (D-31) — never a general
/// background-tracking capability, and never started by anything other than
/// an active emergency.
///
/// Every dependency is injected so this class never touches a platform
/// channel directly and is fully testable with fakes.
class SosLiveLocationService {
  SosLiveLocationService({
    required SosForegroundTaskHost foregroundTaskHost,
    required SosPositionSource positionSource,
    required SosApi sosApi,
    required LocationPermissionService permissionService,
    required SosRetryScheduler expiryScheduler,
  }) : this._(
         foregroundTaskHost,
         positionSource,
         sosApi,
         permissionService,
         expiryScheduler,
       );

  SosLiveLocationService._(
    this._foregroundTaskHost,
    this._positionSource,
    this._sosApi,
    this._permissionService,
    this._expiryScheduler,
  );

  final SosForegroundTaskHost _foregroundTaskHost;
  final SosPositionSource _positionSource;
  final SosApi _sosApi;
  final LocationPermissionService _permissionService;
  final SosRetryScheduler _expiryScheduler;

  String? _sosSessionId;
  StreamSubscription<Position>? _positionSubscription;
  SosRetryHandle? _expiryHandle;
  bool _isStreaming = false;

  SosLiveLocationAvailability _availability = SosLiveLocationAvailability.idle;
  final StreamController<SosLiveLocationAvailability> _availabilityController =
      StreamController<SosLiveLocationAvailability>.broadcast();

  SosLiveLocationAvailability get availability => _availability;

  Stream<SosLiveLocationAvailability> get availabilityChanges =>
      _availabilityController.stream;

  /// Starts (or, for the same already-active session, no-ops) the
  /// foreground service and position stream. When location permission is
  /// not granted, does not start the service and reports
  /// [SosLiveLocationAvailability.unavailablePermissionDenied] instead of
  /// throwing or silently doing nothing.
  Future<void> start(String sosSessionId, DateTime windowEndsAtUtc) async {
    if (_isStreaming && _sosSessionId == sosSessionId) {
      // Already streaming for this exact session — only the expiry needs
      // refreshing (the server may have echoed the same end time again).
      _scheduleExpiry(windowEndsAtUtc);
      return;
    }
    await stop();

    final permissionStatus = await _permissionService.checkPermission();
    if (permissionStatus != LocationPermissionStatus.granted) {
      _setAvailability(SosLiveLocationAvailability.unavailablePermissionDenied);
      return;
    }

    _sosSessionId = sosSessionId;
    await _foregroundTaskHost.start(
      notificationTitle: 'SafePath — Emergency active',
      notificationText:
          'Sharing your live location with your guardians during an '
          'emergency.',
    );
    _isStreaming = true;
    _setAvailability(SosLiveLocationAvailability.streaming);

    _positionSubscription = _positionSource.positions().listen(
      _handlePosition,
      onError: (_) {},
    );

    _scheduleExpiry(windowEndsAtUtc);
  }

  /// Cancels the subscription and stops the foreground service. Idempotent
  /// — several conditions (window-end, cancellation, an explicit call) can
  /// race to end the window at once.
  Future<void> stop() async {
    _expiryHandle?.cancel();
    _expiryHandle = null;
    await _positionSubscription?.cancel();
    _positionSubscription = null;

    final wasStreaming = _isStreaming;
    _isStreaming = false;
    _sosSessionId = null;

    if (wasStreaming) {
      await _foregroundTaskHost.stop();
    }
    _setAvailability(SosLiveLocationAvailability.stopped);
  }

  /// Semantic alias for the "the session was canceled" self-termination
  /// path — a thin wrapper over [stop] so callers reacting to a
  /// `SosCancellation` event can express intent clearly.
  Future<void> handleSessionCanceled() => stop();

  void _scheduleExpiry(DateTime windowEndsAtUtc) {
    _expiryHandle?.cancel();
    final delay = windowEndsAtUtc.difference(DateTime.now().toUtc());
    _expiryHandle = _expiryScheduler.schedule(
      delay.isNegative ? Duration.zero : delay,
      () {
        unawaited(stop());
      },
    );
  }

  Future<void> _handlePosition(Position position) async {
    final sosSessionId = _sosSessionId;
    if (sosSessionId == null || !_isStreaming) return;

    try {
      final window = await _sosApi.reportSosLocation(
        sosSessionId,
        position.latitude,
        position.longitude,
        position.accuracy,
        position.timestamp.toUtc(),
      );
      // The server is the sole authority on when the window closes — a
      // report response saying so stops the stream immediately, without
      // waiting for the local expiry timer above.
      if (window.outcome == SosLocationWindowOutcome.windowClosed) {
        unawaited(stop());
      }
    } catch (_) {
      // Best-effort: a single failed report never ends the stream on its
      // own — the next fix (or the local expiry timer) resolves state.
    }
  }

  void _setAvailability(SosLiveLocationAvailability next) {
    _availability = next;
    if (!_availabilityController.isClosed) {
      _availabilityController.add(next);
    }
  }

  void dispose() {
    _expiryHandle?.cancel();
    unawaited(_positionSubscription?.cancel());
    unawaited(_availabilityController.close());
  }
}

final sosLiveLocationServiceProvider = Provider<SosLiveLocationService>((ref) {
  final service = SosLiveLocationService(
    foregroundTaskHost: const FlutterForegroundTaskHost(),
    positionSource: const GeolocatorSosPositionSource(),
    sosApi: ref.watch(sosApiProvider),
    permissionService: ref.watch(locationPermissionServiceProvider),
    expiryScheduler: ref.watch(sosRetrySchedulerProvider),
  );
  ref.onDispose(service.dispose);
  return service;
});
