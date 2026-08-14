import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/push/push_service.dart';
import 'package:mobile/core/push/routine_push_service.dart';

void main() {
  const activityId = '11111111-1111-4111-8111-111111111111';
  const zoneId = '22222222-2222-4222-8222-222222222222';

  group('RoutinePushService', () {
    late _FakeMessagingClient messaging;
    late _FakeLocalNotificationPresenter notifier;
    late List<String> navigatedZoneIds;
    late RoutinePushService service;

    setUp(() {
      messaging = _FakeMessagingClient();
      notifier = _FakeLocalNotificationPresenter();
      navigatedZoneIds = [];
      service = RoutinePushService(
        messaging: messaging,
        notifier: notifier,
        navigate: navigatedZoneIds.add,
      );
    });

    tearDown(() => service.dispose());

    test('shows a normal routine notification in foreground without navigating', () async {
      await service.initialize();
      await service.onAuthStateChanged(true);

      messaging.emitMessage(
        const PushMessageData(
          data: {
            'type': routinePushMarker,
            'activityId': activityId,
            'zoneId': zoneId,
            'latitude': '30.0444',
            'longitude': '31.2357',
          },
          title: 'Maya entered Home',
          body: 'Safe-zone activity',
        ),
      );
      await pumpEventQueue();

      expect(notifier.shownCalls, [
        (title: 'Maya entered Home', body: 'Safe-zone activity', payload: zoneId),
      ]);
      expect(navigatedZoneIds, isEmpty);
    });

    test('replays a background tap only after authentication settles', () async {
      await service.initialize();

      messaging.emitMessageOpenedApp(_routineMessage);
      await pumpEventQueue();
      expect(navigatedZoneIds, isEmpty);

      await service.onAuthStateChanged(true);
      expect(navigatedZoneIds, [zoneId]);
    });

    test('replays a cold-start local notification tap after authentication', () async {
      messaging.initialMessage = _routineMessage;
      await service.initialize();
      await pumpEventQueue();
      expect(navigatedZoneIds, isEmpty);

      await service.onAuthStateChanged(true);
      expect(navigatedZoneIds, [zoneId]);
    });

    test('replays a foreground local notification tap after authentication', () async {
      await service.initialize();
      messaging.emitMessage(_routineMessage);
      await pumpEventQueue();

      notifier.tapLast();
      expect(navigatedZoneIds, isEmpty);

      await service.onAuthStateChanged(true);
      expect(navigatedZoneIds, [zoneId]);
    });

    test('ignores malformed and non-routine payloads', () async {
      await service.initialize();
      await service.onAuthStateChanged(true);

      messaging.emitMessageOpenedApp(
        const PushMessageData(
          data: {'type': 'sos', 'sosSessionId': 'session-abc'},
        ),
      );
      messaging.emitMessage(
        const PushMessageData(
          data: {
            'type': routinePushMarker,
            'activityId': 'not-a-uuid',
            'zoneId': zoneId,
          },
        ),
      );
      messaging.emitMessageOpenedApp(
        const PushMessageData(
          data: {
            'type': routinePushMarker,
            'activityId': activityId,
            'zoneId': '',
          },
        ),
      );
      await pumpEventQueue();

      expect(notifier.shownCalls, isEmpty);
      expect(navigatedZoneIds, isEmpty);
    });
  });
}

const _routineMessage = PushMessageData(
  data: {
    'type': routinePushMarker,
    'activityId': '11111111-1111-4111-8111-111111111111',
    'zoneId': '22222222-2222-4222-8222-222222222222',
  },
  title: 'Maya entered Home',
  body: 'Safe-zone activity',
);

class _FakeMessagingClient implements PushMessagingClient {
  PushMessageData? initialMessage;

  final _onMessage = StreamController<PushMessageData>.broadcast();
  final _onMessageOpenedApp = StreamController<PushMessageData>.broadcast();

  @override
  Future<PushMessageData?> getInitialMessage() async => initialMessage;

  @override
  Future<String?> getToken() async => null;

  @override
  Stream<PushMessageData> get onMessage => _onMessage.stream;

  @override
  Stream<PushMessageData> get onMessageOpenedApp => _onMessageOpenedApp.stream;

  @override
  Stream<String> get onTokenRefresh => const Stream.empty();

  @override
  Future<void> requestPermission() async {}

  void emitMessage(PushMessageData message) => _onMessage.add(message);

  void emitMessageOpenedApp(PushMessageData message) =>
      _onMessageOpenedApp.add(message);
}

class _FakeLocalNotificationPresenter implements LocalNotificationPresenter {
  void Function(String payload)? _onTap;
  final List<({String title, String body, String? payload})> shownCalls = [];

  @override
  Future<void> initialize({required void Function(String payload) onTap}) async {
    _onTap = onTap;
  }

  @override
  Future<void> show({
    required String title,
    required String body,
    String? payload,
  }) async {
    shownCalls.add((title: title, body: body, payload: payload));
  }

  void tapLast() {
    final payload = shownCalls.lastOrNull?.payload;
    if (payload != null) _onTap?.call(payload);
  }
}
