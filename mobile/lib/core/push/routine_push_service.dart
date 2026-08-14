// RoutinePushService keeps public constructor argument names while assigning
// them to private fields, matching PushService's testable composition seam.
// ignore_for_file: prefer_initializing_formals

import 'dart:async';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'push_service.dart';

/// Identifies identifier-only safe-zone activity pushes. This marker is
/// intentionally distinct from [sosPushMarker], keeping normal activity
/// presentation and routing out of the emergency push path.
const routinePushMarker = 'geofence';

/// Android's normal-priority channel for routine safe-zone activity. SOS uses
/// its own high-importance [sosAndroidChannelId] channel in `push_service`.
const routineAndroidChannelId = 'safepath_routine';

typedef RoutineActivityNavigate = void Function(String zoneId);

/// Presents routine activity on a normal notification channel. It deliberately
/// does not reuse the critical SOS notification details or channel.
class RoutineLocalNotificationPresenter implements LocalNotificationPresenter {
  RoutineLocalNotificationPresenter([FlutterLocalNotificationsPlugin? plugin])
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  void Function(String payload)? _onTap;

  @override
  Future<void> initialize({
    required void Function(String payload) onTap,
  }) async {
    _onTap = onTap;
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings();
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload == null || payload.isEmpty) return;
        _onTap?.call(payload);
      },
    );

    const channel = AndroidNotificationChannel(
      routineAndroidChannelId,
      'SafePath routine activity',
      description: 'Normal safe-zone activity from your family circle.',
      importance: Importance.defaultImportance,
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);
  }

  @override
  Future<void> show({
    required String title,
    required String body,
    String? payload,
  }) => _plugin.show(
    id: DateTime.now().millisecondsSinceEpoch.remainder(1 << 31),
    title: title,
    body: body,
    notificationDetails: const NotificationDetails(
      android: AndroidNotificationDetails(
        routineAndroidChannelId,
        'SafePath routine activity',
        channelDescription:
            'Normal safe-zone activity from your family circle.',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      ),
      iOS: DarwinNotificationDetails(),
    ),
    payload: payload,
  );
}

/// Handles routine safe-zone pushes only. It receives no coordinate fields and
/// retains a pending explicit tap only in process memory until auth settles.
class RoutinePushService {
  RoutinePushService({
    required PushMessagingClient messaging,
    required RoutineActivityNavigate navigate,
    LocalNotificationPresenter? notifier,
  }) : _messaging = messaging,
       _navigate = navigate,
       _notifier = notifier;

  final PushMessagingClient _messaging;
  final RoutineActivityNavigate _navigate;
  final LocalNotificationPresenter? _notifier;

  StreamSubscription<PushMessageData>? _onMessageSubscription;
  StreamSubscription<PushMessageData>? _onMessageOpenedAppSubscription;
  bool _initialized = false;
  bool _isAuthenticated = false;
  _RoutineRouteTarget? _pendingTap;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    await _messaging.requestPermission();
    await _notifier?.initialize(onTap: _handleLocalNotificationTap);
    _onMessageSubscription = _messaging.onMessage.listen(_handleForeground);
    _onMessageOpenedAppSubscription = _messaging.onMessageOpenedApp.listen(
      _handleTap,
    );

    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) _handleTap(initialMessage);
  }

  /// Replays only a user-originated pending tap after auth resolves. The route
  /// target is never persisted, and this service never reads or stores tokens.
  Future<void> onAuthStateChanged(bool isAuthenticated) async {
    _isAuthenticated = isAuthenticated;
    if (!isAuthenticated) return;

    final pendingTap = _pendingTap;
    if (pendingTap == null) return;
    _pendingTap = null;
    _navigate(pendingTap.zoneId);
  }

  void _handleForeground(PushMessageData message) {
    final target = _targetFromMessage(message);
    if (target == null) return;

    unawaited(
      _notifier?.show(
        title: message.title ?? 'SafePath activity',
        body: message.body ?? 'New safe-zone activity.',
        payload: target.localNotificationPayload,
      ),
    );
  }

  void _handleTap(PushMessageData message) {
    final target = _targetFromMessage(message);
    if (target == null) return;
    _handleExplicitTap(target);
  }

  void _handleLocalNotificationTap(String payload) {
    final target = _RoutineRouteTarget.fromLocalNotificationPayload(payload);
    if (target == null) return;
    _handleExplicitTap(target);
  }

  void _handleExplicitTap(_RoutineRouteTarget target) {
    if (_isAuthenticated) {
      _pendingTap = null;
      _navigate(target.zoneId);
    } else {
      _pendingTap = target;
    }
  }

  _RoutineRouteTarget? _targetFromMessage(PushMessageData message) {
    if (message.data['type'] != routinePushMarker) return null;
    return _RoutineRouteTarget.fromIdentifiers(
      activityId: message.data['activityId'],
      zoneId: message.data['zoneId'],
    );
  }

  void dispose() {
    unawaited(_onMessageSubscription?.cancel());
    unawaited(_onMessageOpenedAppSubscription?.cancel());
  }
}

class _RoutineRouteTarget {
  const _RoutineRouteTarget({required this.activityId, required this.zoneId});

  final String activityId;
  final String zoneId;

  String get localNotificationPayload => '$activityId:$zoneId';

  static _RoutineRouteTarget? fromIdentifiers({
    required String? activityId,
    required String? zoneId,
  }) {
    if (!_uuidPattern.hasMatch(activityId ?? '') ||
        !_uuidPattern.hasMatch(zoneId ?? '')) {
      return null;
    }
    return _RoutineRouteTarget(activityId: activityId!, zoneId: zoneId!);
  }

  static _RoutineRouteTarget? fromLocalNotificationPayload(String payload) {
    final identifiers = payload.split(':');
    if (identifiers.length != 2) return null;
    return fromIdentifiers(activityId: identifiers[0], zoneId: identifiers[1]);
  }
}

final _uuidPattern = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
);
