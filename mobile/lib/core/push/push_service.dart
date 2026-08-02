// PushService's constructor deliberately assigns named parameters to
// underscore-prefixed fields by name (not via `this._field` initializing
// formals), so the public parameter names (messaging, deviceTokenApi, ...)
// stay the external named-argument labels at every call site rather than
// the private field names.
// ignore_for_file: prefer_initializing_formals

import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart' as fcm;
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/application/auth_controller.dart';
import '../../features/auth/application/auth_state.dart';
import '../../features/sos/data/device_token_api.dart';
import '../router/app_router.dart';

/// The SOS marker every FCM data payload for an emergency push carries
/// (`type` field) — distinguishes an SOS push from any future non-emergency
/// notification type without guessing from title/body text.
const sosPushMarker = 'sos';

/// Matches the Android notification channel `FirebasePushSender` targets
/// server-side and the one declared in `AndroidManifest.xml`'s default-channel
/// metadata — must stay in sync across all three.
const sosAndroidChannelId = 'safepath_sos';

/// Callback invoked to force-navigate to the SOS responder route for a given
/// session id. Kept router-agnostic — mirrors `SosResponderNavigate`
/// (`sos_responder_controller.dart`) so this feature layer's core class
/// never imports go_router directly; only `pushServiceProvider` below (the
/// composition point, reusing the single shared `routerProvider` instance
/// rather than a second router handle) does.
typedef PushResponderNavigate = void Function(String sosSessionId);

/// The subset of an inbound FCM message `PushService` reads: the data
/// payload (never a coordinate/phone number — D-28 keeps duress/covert
/// signalling out of this channel entirely) plus the notification
/// title/body for a foreground local-notification render.
class PushMessageData {
  const PushMessageData({required this.data, this.title, this.body});

  final Map<String, String> data;
  final String? title;
  final String? body;

  factory PushMessageData.fromRemoteMessage(fcm.RemoteMessage message) {
    return PushMessageData(
      data: message.data.map((key, value) => MapEntry(key, '$value')),
      title: message.notification?.title,
      body: message.notification?.body,
    );
  }
}

/// Abstraction over `firebase_messaging` so `push_service_test.dart` can
/// drive `PushService` with fakes and no platform channels. `PushService`
/// never calls `FirebaseMessaging.instance`/`FirebaseMessaging.onMessage`
/// directly from its own body — only this interface's real implementation
/// does.
abstract class PushMessagingClient {
  Future<void> requestPermission();
  Future<String?> getToken();
  Stream<String> get onTokenRefresh;
  Stream<PushMessageData> get onMessage;
  Stream<PushMessageData> get onMessageOpenedApp;
  Future<PushMessageData?> getInitialMessage();
}

class FirebaseMessagingClient implements PushMessagingClient {
  @override
  Future<void> requestPermission() async {
    await fcm.FirebaseMessaging.instance.requestPermission();
  }

  @override
  Future<String?> getToken() => fcm.FirebaseMessaging.instance.getToken();

  @override
  Stream<String> get onTokenRefresh =>
      fcm.FirebaseMessaging.instance.onTokenRefresh;

  @override
  Stream<PushMessageData> get onMessage => fcm.FirebaseMessaging.onMessage.map(
    PushMessageData.fromRemoteMessage,
  );

  @override
  Stream<PushMessageData> get onMessageOpenedApp =>
      fcm.FirebaseMessaging.onMessageOpenedApp.map(
        PushMessageData.fromRemoteMessage,
      );

  @override
  Future<PushMessageData?> getInitialMessage() async {
    final message = await fcm.FirebaseMessaging.instance.getInitialMessage();
    return message == null ? null : PushMessageData.fromRemoteMessage(message);
  }
}

/// Handles a data-only FCM message delivered while the app process is fully
/// terminated, on a background isolate — required by `firebase_messaging`
/// for background isolate execution. Kept a top-level function (not a
/// method) and annotated so the Dart compiler never strips it (background
/// isolates cannot resolve instance methods). Intentionally a no-op beyond
/// what the OS already does for the notification block: the foreground/tap
/// paths (`onMessage`/`onMessageOpenedApp`/`getInitialMessage`) are what
/// route and confirm receipt — this handler exists only so the plugin does
/// not warn about a missing background handler registration.
@pragma('vm:entry-point')
Future<void> firebasePushBackgroundHandler(fcm.RemoteMessage message) async {}

/// Shows a local heads-up notification for a foreground SOS arrival, so a
/// guardian with the app open sees the same urgency an OS-tray notification
/// gives a backgrounded guardian (belt-and-braces alongside the OS's own
/// FCM-notification-block rendering).
abstract class LocalNotificationPresenter {
  Future<void> initialize();
  Future<void> show({required String title, required String body});
}

class FlutterLocalNotificationPresenter implements LocalNotificationPresenter {
  FlutterLocalNotificationPresenter([FlutterLocalNotificationsPlugin? plugin])
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;

  @override
  Future<void> initialize() async {
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings();
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
    );

    const channel = AndroidNotificationChannel(
      sosAndroidChannelId,
      'SafePath SOS',
      description: 'Emergency SOS alerts from your family circle.',
      importance: Importance.max,
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);
  }

  @override
  Future<void> show({required String title, required String body}) async {
    await _plugin.show(
      id: DateTime.now().millisecondsSinceEpoch.remainder(1 << 31),
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          sosAndroidChannelId,
          'SafePath SOS',
          channelDescription: 'Emergency SOS alerts from your family circle.',
          importance: Importance.max,
          priority: Priority.max,
        ),
        iOS: DarwinNotificationDetails(interruptionLevel: InterruptionLevel.critical),
      ),
    );
  }
}

/// Owns the FCM token lifecycle and all three notification-tap lifecycles
/// for SOS pushes. A plain, directly-constructible class (not a Riverpod
/// Notifier) so `push_service_test.dart` can drive it with fakes and no
/// platform channels — mirrors `SosHubClient`'s data-layer/testability
/// split from its Riverpod-owning controller.
class PushService {
  PushService({
    required PushMessagingClient messaging,
    required DeviceTokenApi deviceTokenApi,
    required PushResponderNavigate navigate,
    LocalNotificationPresenter? notifier,
    String platform = 'android',
  }) : _messaging = messaging,
       _deviceTokenApi = deviceTokenApi,
       _navigate = navigate,
       _notifier = notifier,
       _platform = platform;

  final PushMessagingClient _messaging;
  final DeviceTokenApi _deviceTokenApi;
  final PushResponderNavigate _navigate;
  final LocalNotificationPresenter? _notifier;
  final String _platform;

  StreamSubscription<String>? _tokenRefreshSubscription;
  StreamSubscription<PushMessageData>? _onMessageSubscription;
  StreamSubscription<PushMessageData>? _onMessageOpenedAppSubscription;

  bool _initialized = false;
  bool _isAuthenticated = false;
  String? _registeredToken;
  String? _pendingSessionId;

  /// Requests notification permission, initialises the local-notification
  /// channel, wires all three tap lifecycles, and checks for a tap that
  /// cold-started the app (`getInitialMessage`). Safe to call once; a
  /// second call is a no-op.
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    await _messaging.requestPermission();
    await _notifier?.initialize();

    _onMessageSubscription = _messaging.onMessage.listen(_handleForeground);
    _onMessageOpenedAppSubscription = _messaging.onMessageOpenedApp.listen(
      _handleTap,
    );
    _tokenRefreshSubscription = _messaging.onTokenRefresh.listen(
      _onTokenRefreshed,
    );

    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleTap(initialMessage);
    }
  }

  /// Registers this device's current token on sign-in; removes it on
  /// sign-out. Never calls `remove` for a token this service never
  /// registered. Also replays a tap that arrived before auth settled
  /// (mirrors `pendingInviteProvider`'s pending-link replay).
  Future<void> onAuthStateChanged(bool isAuthenticated) async {
    _isAuthenticated = isAuthenticated;

    if (isAuthenticated) {
      final token = await _messaging.getToken();
      if (token != null && token.isNotEmpty) {
        _registeredToken = token;
        await _deviceTokenApi.register(token, _platform);
      }

      final pending = _pendingSessionId;
      if (pending != null) {
        _pendingSessionId = null;
        _navigate(pending);
      }
    } else {
      final token = _registeredToken;
      _registeredToken = null;
      if (token != null) {
        await _deviceTokenApi.remove(token);
      }
    }
  }

  Future<void> _onTokenRefreshed(String token) async {
    _registeredToken = token;
    if (!_isAuthenticated) return;
    await _deviceTokenApi.register(token, _platform);
  }

  /// A foreground arrival is not a tap — the guardian has not acted yet.
  /// Show a local heads-up notification and report receipt (the device did
  /// receive the push), but do not navigate: navigation only happens once
  /// the guardian actually taps (`onMessageOpenedApp`/`getInitialMessage`).
  void _handleForeground(PushMessageData message) {
    if (!_isSos(message)) return;

    unawaited(
      _notifier?.show(
        title: message.title ?? 'SafePath SOS',
        body: message.body ?? 'A family member needs help.',
      ),
    );

    final sessionId = message.data['sosSessionId'];
    if (sessionId != null && sessionId.isNotEmpty) {
      unawaited(_deviceTokenApi.confirmPushReceipt(sessionId));
    }
  }

  /// Handles a tap from either `onMessageOpenedApp` (backgrounded) or
  /// `getInitialMessage` (cold-started from terminated) — both funnel here
  /// so the responder-route deep-link is identical from any app lifecycle
  /// (D-19).
  void _handleTap(PushMessageData message) {
    if (!_isSos(message)) return;

    final sessionId = message.data['sosSessionId'];
    if (sessionId == null || sessionId.isEmpty) return;

    unawaited(_deviceTokenApi.confirmPushReceipt(sessionId));

    if (_isAuthenticated) {
      _navigate(sessionId);
    } else {
      // The tap arrived before auth settled (e.g. a fresh cold start still
      // resolving the Supabase session) — replay it once
      // onAuthStateChanged(true) fires, rather than dropping it.
      _pendingSessionId = sessionId;
    }
  }

  bool _isSos(PushMessageData message) => message.data['type'] == sosPushMarker;

  void dispose() {
    unawaited(_tokenRefreshSubscription?.cancel());
    unawaited(_onMessageSubscription?.cancel());
    unawaited(_onMessageOpenedAppSubscription?.cancel());
  }
}

/// Composition point: constructs the real `PushService`, reusing the single
/// shared `routerProvider` instance for navigation (never a second router
/// handle) and the shared `deviceTokenApiProvider`.
final pushServiceProvider = Provider<PushService>((ref) {
  final router = ref.watch(routerProvider);
  return PushService(
    messaging: FirebaseMessagingClient(),
    deviceTokenApi: ref.watch(deviceTokenApiProvider),
    navigate: (sessionId) => router.goNamed(
      'sos-responder',
      pathParameters: {'sessionId': sessionId},
    ),
    notifier: FlutterLocalNotificationPresenter(),
    platform: defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android',
  );
});

/// Owns `PushService`'s lifecycle: initialises it once and forwards every
/// `AuthController` transition into `onAuthStateChanged`. A Firebase-project
/// not yet being provisioned (no `google-services.json`/
/// `GoogleService-Info.plist`) must never crash the rest of the app — any
/// failure here is caught and logged, leaving the push channel inactive
/// until Task 3's human Firebase setup is done.
class PushServiceController extends Notifier<void> {
  @override
  void build() {
    final service = ref.read(pushServiceProvider);

    unawaited(
      service.initialize().catchError((Object error, StackTrace stack) {
        debugPrint('PushService.initialize failed (Firebase not configured yet?): $error');
      }),
    );

    ref.listen<AuthState>(authControllerProvider, (previous, next) {
      unawaited(
        service
            .onAuthStateChanged(next is AuthAuthenticated)
            .catchError((Object error, StackTrace stack) {
              debugPrint('PushService.onAuthStateChanged failed: $error');
            }),
      );
    }, fireImmediately: true);

    ref.onDispose(service.dispose);
  }
}

final pushServiceControllerProvider = NotifierProvider<PushServiceController, void>(
  PushServiceController.new,
);
