// Behavior under test (03-04-PLAN.md Task 1 — hub-client parsing +
// responder-controller receipt confirmation):
// - A well-formed SosTriggered payload parses into a typed SosSession.
// - A malformed payload is swallowed without closing the stream — a
//   subsequent valid payload still arrives.
// - SosResponderController confirms receipt exactly once per distinct
//   incoming session id (a replayed event is a no-op the second time).
//
// Task 3 extends this file with the delivery-status-chip/recipient-row
// rendering behaviours (see the second `main()` group below).

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import 'package:mobile/features/auth/data/auth_api.dart';
import 'package:mobile/features/family/application/family_controller.dart';
import 'package:mobile/features/family/data/family_models.dart';
import 'package:mobile/features/sos/application/sos_responder_controller.dart';
import 'package:mobile/features/sos/data/sos_hub_client.dart';
import 'package:mobile/features/sos/data/sos_models.dart';

import '../../helpers/fake_auth_api.dart';
import '../../helpers/fake_sos_hub_client.dart';

class _FixedFamilyController extends FamilyController {
  @override
  FamilyState build() => const FamilyState(family: Family(id: 'family-1'));
}

sb.Session _session({required String userId}) {
  return sb.Session(
    accessToken: 'token',
    tokenType: 'bearer',
    user: sb.User(
      id: userId,
      appMetadata: const {},
      userMetadata: const {},
      aud: 'authenticated',
      createdAt: DateTime.now().toIso8601String(),
    ),
  );
}

Map<String, dynamic> _wellFormedSosTriggeredJson({
  required String sosSessionId,
  String triggeredByUserId = 'ana-user-id',
}) {
  return {
    'sosSessionId': sosSessionId,
    'familyId': 'family-1',
    'triggeredByUserId': triggeredByUserId,
    'status': 'Active',
    'triggeredAtUtc': '2026-08-01T12:00:00Z',
    'receivedAtUtc': '2026-08-01T12:00:01Z',
    'recipients': <dynamic>[],
  };
}

void main() {
  group('SosHubClient event parsing', () {
    test('parses a well-formed SosTriggered payload into a SosSession', () async {
      final hubClient = FakeSosHubClient();
      final received = <SosSession>[];
      final subscription = hubClient.sosTriggered.listen(received.add);

      hubClient.pushRawSosTriggered(
        _wellFormedSosTriggeredJson(sosSessionId: 'session-1'),
      );
      await pumpEventQueue();

      expect(received, hasLength(1));
      expect(received.single.sosSessionId, 'session-1');
      expect(received.single.triggeredByUserId, 'ana-user-id');

      await subscription.cancel();
      hubClient.dispose();
    });

    test('swallows a malformed payload without closing the stream', () async {
      final hubClient = FakeSosHubClient();
      final received = <SosSession>[];
      final subscription = hubClient.sosTriggered.listen(received.add);

      // Missing required keys (sosSessionId, triggeredByUserId, etc.).
      hubClient.pushRawSosTriggered({'familyId': 'family-1'});
      await pumpEventQueue();
      expect(received, isEmpty);

      hubClient.pushRawSosTriggered(
        _wellFormedSosTriggeredJson(sosSessionId: 'session-2'),
      );
      await pumpEventQueue();

      expect(received, hasLength(1));
      expect(received.single.sosSessionId, 'session-2');

      await subscription.cancel();
      hubClient.dispose();
    });
  });

  group('SosResponderController', () {
    test(
      'confirms receipt after a SosTriggered arrives, exactly once per '
      'distinct session id',
      () async {
        final hubClient = FakeSosHubClient();
        final authApi = FakeAuthApi(
          initialSession: _session(userId: 'guardian-1'),
        );
        final container = ProviderContainer(
          overrides: [
            authApiProvider.overrideWithValue(authApi),
            familyControllerProvider.overrideWith(_FixedFamilyController.new),
            sosHubClientProvider.overrideWithValue(hubClient),
          ],
        );
        addTearDown(container.dispose);

        // Start the controller (build() connects once auth+family resolve).
        container.read(sosResponderControllerProvider);
        await pumpEventQueue();

        final session = SosSession(
          sosSessionId: 'session-1',
          familyId: 'family-1',
          triggeredByUserId: 'ana-user-id',
          status: SosSessionStatus.active,
          triggeredAtUtc: DateTime.now().toUtc(),
          receivedAtUtc: DateTime.now().toUtc(),
        );

        hubClient.emitSosTriggered(session);
        await pumpEventQueue();
        // Replay of the same session id (e.g. reconnect gap-fill) must not
        // confirm receipt a second time.
        hubClient.emitSosTriggered(session);
        await pumpEventQueue();

        expect(hubClient.confirmReceiptCalls, ['session-1']);
      },
    );
  });
}
