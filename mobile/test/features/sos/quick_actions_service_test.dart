// Behavior under test (03-09-PLAN.md Task 2, SOS-06, D-25/D-27):
// - registers exactly one SOS shortcut item, with a clear localized title
// - fires the SOS immediately on invocation — no hold, timer, dialog or
//   confirmation in between
// - navigates straight into the emergency session on invocation
// - ignores an unrecognised shortcut type
// - defers an invocation that arrives before authentication, replaying it
//   exactly once (not twice) once auth settles
// - does not register the shortcut while signed out
// - does not re-arm an already-active session — routes to it instead

import 'package:flutter_test/flutter_test.dart';
import 'package:quick_actions/quick_actions.dart';

import 'package:mobile/core/os_shortcuts/quick_actions_service.dart';

/// Hand-written [QuickActionsClient] fake (matches `FakePushMessagingClient`
/// / `FakeSosApi`'s convention — no mocking package). [invoke] simulates a
/// shortcut launch by calling back into whatever handler
/// [QuickActionsService.initialize] registered.
class FakeQuickActionsClient implements QuickActionsClient {
  void Function(String type)? _handler;

  int initializeCallCount = 0;
  final List<List<ShortcutItem>> setShortcutItemsCalls = [];
  int clearShortcutItemsCallCount = 0;

  @override
  Future<void> initialize(void Function(String type) handler) async {
    initializeCallCount++;
    _handler = handler;
  }

  @override
  Future<void> setShortcutItems(List<ShortcutItem> items) async {
    setShortcutItemsCalls.add(items);
  }

  @override
  Future<void> clearShortcutItems() async {
    clearShortcutItemsCallCount++;
  }

  /// Simulates the plugin delivering a shortcut launch/resume event.
  void invoke(String type) => _handler?.call(type);
}

void main() {
  late FakeQuickActionsClient client;
  late int armCallCount;
  late List<void> navigateCalls;
  late bool sessionActive;
  late QuickActionsService service;

  setUp(() {
    client = FakeQuickActionsClient();
    armCallCount = 0;
    navigateCalls = [];
    sessionActive = false;
    service = QuickActionsService(
      client: client,
      arm: () async {
        armCallCount++;
      },
      isSessionActive: () => sessionActive,
      navigate: () => navigateCalls.add(null),
    );
  });

  test('registers exactly one SOS shortcut item', () async {
    await service.onAuthStateChanged(true);

    expect(client.setShortcutItemsCalls, hasLength(1));
    final items = client.setShortcutItemsCalls.single;
    expect(items, hasLength(1));
    expect(items.single.type, sosQuickActionType);
    expect(items.single.localizedTitle, isNotEmpty);
  });

  test('fires the SOS immediately on invocation', () async {
    await service.initialize();
    await service.onAuthStateChanged(true);

    client.invoke(sosQuickActionType);
    await pumpEventQueue();

    expect(armCallCount, 1);
  });

  test('navigates straight into the emergency session', () async {
    await service.initialize();
    await service.onAuthStateChanged(true);

    client.invoke(sosQuickActionType);
    await pumpEventQueue();

    expect(navigateCalls, hasLength(1));
  });

  test('ignores an unrecognised shortcut type', () async {
    await service.initialize();
    await service.onAuthStateChanged(true);

    client.invoke('some_other_shortcut');
    await pumpEventQueue();

    expect(armCallCount, 0);
    expect(navigateCalls, isEmpty);
  });

  test(
    'defers an invocation that arrives before authentication',
    () async {
      await service.initialize();

      // Arrives before auth has settled — must not fire yet.
      client.invoke(sosQuickActionType);
      await pumpEventQueue();
      expect(armCallCount, 0);

      await service.onAuthStateChanged(true);
      await pumpEventQueue();
      expect(armCallCount, 1);

      // A second, unrelated auth-authenticated transition (e.g. a token
      // refresh re-emitting the same state) must never replay the deferred
      // invocation a second time — it was already consumed.
      await service.onAuthStateChanged(true);
      await pumpEventQueue();
      expect(armCallCount, 1);
    },
  );

  test('does not register the shortcut while signed out', () async {
    await service.onAuthStateChanged(false);

    expect(client.setShortcutItemsCalls, isEmpty);
    expect(client.clearShortcutItemsCallCount, 1);
  });

  test(
    'does not re-arm an already-active session',
    () async {
      await service.initialize();
      await service.onAuthStateChanged(true);
      sessionActive = true;

      client.invoke(sosQuickActionType);
      await pumpEventQueue();

      expect(armCallCount, 0);
      expect(navigateCalls, hasLength(1));
    },
  );
}
