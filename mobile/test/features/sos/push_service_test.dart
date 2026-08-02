import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/push/push_service.dart';

import '../../helpers/fake_device_token_api.dart';

void main() {
  group('PushService', () {
    late FakePushMessagingClient messaging;
    late FakeDeviceTokenApi deviceTokenApi;
    late List<String> navigateCalls;
    late PushService service;

    setUp(() {
      messaging = FakePushMessagingClient();
      deviceTokenApi = FakeDeviceTokenApi();
      navigateCalls = [];
      service = PushService(
        messaging: messaging,
        deviceTokenApi: deviceTokenApi,
        navigate: (sessionId) => navigateCalls.add(sessionId),
        notifier: FakeLocalNotificationPresenter(),
        platform: 'android',
      );
    });

    tearDown(() {
      service.dispose();
    });

    test('registers the device token on sign-in', () async {
      await service.initialize();
      messaging.tokenToReturn = 'token-1';

      await service.onAuthStateChanged(true);

      expect(deviceTokenApi.registerCalls, hasLength(1));
      expect(deviceTokenApi.registerCalls.single.token, 'token-1');
      expect(deviceTokenApi.registerCalls.single.platform, 'android');
    });

    test('re-registers when the token rotates', () async {
      await service.initialize();
      messaging.tokenToReturn = 'token-1';
      await service.onAuthStateChanged(true);

      messaging.emitTokenRefresh('token-2');
      await Future<void>.delayed(Duration.zero);

      expect(deviceTokenApi.registerCalls, hasLength(2));
      expect(deviceTokenApi.registerCalls.last.token, 'token-2');
    });

    test('removes the token on sign-out', () async {
      await service.initialize();
      messaging.tokenToReturn = 'token-1';
      await service.onAuthStateChanged(true);

      await service.onAuthStateChanged(false);

      expect(deviceTokenApi.removeCalls, hasLength(1));
      expect(deviceTokenApi.removeCalls.single, 'token-1');
    });

    test('does not register while unauthenticated', () async {
      await service.initialize();

      messaging.emitTokenRefresh('token-early');
      await Future<void>.delayed(Duration.zero);

      expect(deviceTokenApi.registerCalls, isEmpty);
    });

    test('routes an SOS notification tap to the responder route', () async {
      await service.initialize();
      await service.onAuthStateChanged(true);

      messaging.emitMessageOpenedApp(
        const PushMessageData(
          data: {'type': 'sos', 'sosSessionId': 'session-abc'},
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(navigateCalls, ['session-abc']);
    });

    test('ignores a notification tap with no session id', () async {
      await service.initialize();
      await service.onAuthStateChanged(true);

      messaging.emitMessageOpenedApp(const PushMessageData(data: {'type': 'sos'}));
      await Future<void>.delayed(Duration.zero);

      expect(navigateCalls, isEmpty);
    });

    test('reports receipt for a foreground SOS message', () async {
      await service.initialize();
      await service.onAuthStateChanged(true);

      messaging.emitMessage(
        const PushMessageData(
          data: {'type': 'sos', 'sosSessionId': 'session-xyz'},
          title: 'SafePath SOS',
          body: 'Alex needs help.',
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(deviceTokenApi.confirmPushReceiptCalls, ['session-xyz']);
      expect(navigateCalls, isEmpty);
    });
  });
}

/// Hand-written [PushMessagingClient] fake — no mocking package, matching
/// `FakeSosHubClient`'s convention. Public stream controllers let tests push
/// events directly; [tokenToReturn] controls what a subsequent
/// `onAuthStateChanged(true)` call's `getToken()` resolves to.
class FakePushMessagingClient implements PushMessagingClient {
  String? tokenToReturn;
  PushMessageData? initialMessage;
  int requestPermissionCallCount = 0;

  final StreamController<String> _onTokenRefresh =
      StreamController<String>.broadcast();
  final StreamController<PushMessageData> _onMessage =
      StreamController<PushMessageData>.broadcast();
  final StreamController<PushMessageData> _onMessageOpenedApp =
      StreamController<PushMessageData>.broadcast();

  @override
  Future<void> requestPermission() async {
    requestPermissionCallCount++;
  }

  @override
  Future<String?> getToken() async => tokenToReturn;

  @override
  Stream<String> get onTokenRefresh => _onTokenRefresh.stream;

  @override
  Stream<PushMessageData> get onMessage => _onMessage.stream;

  @override
  Stream<PushMessageData> get onMessageOpenedApp => _onMessageOpenedApp.stream;

  @override
  Future<PushMessageData?> getInitialMessage() async => initialMessage;

  void emitTokenRefresh(String token) => _onTokenRefresh.add(token);

  void emitMessage(PushMessageData message) => _onMessage.add(message);

  void emitMessageOpenedApp(PushMessageData message) =>
      _onMessageOpenedApp.add(message);
}

/// Hand-written [LocalNotificationPresenter] fake — records calls without
/// touching any platform channel.
class FakeLocalNotificationPresenter implements LocalNotificationPresenter {
  int initializeCallCount = 0;
  final List<({String title, String body})> shownCalls = [];

  @override
  Future<void> initialize() async {
    initializeCallCount++;
  }

  @override
  Future<void> show({required String title, required String body}) async {
    shownCalls.add((title: title, body: body));
  }
}
