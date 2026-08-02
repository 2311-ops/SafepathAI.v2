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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import 'package:mobile/features/auth/data/auth_api.dart';
import 'package:mobile/features/family/application/family_controller.dart';
import 'package:mobile/features/family/data/family_models.dart';
import 'package:mobile/features/location/application/location_controller.dart';
import 'package:mobile/features/sos/application/sos_controller.dart';
import 'package:mobile/features/sos/application/sos_responder_controller.dart';
import 'package:mobile/features/sos/data/sos_api.dart';
import 'package:mobile/features/sos/data/sos_hub_client.dart';
import 'package:mobile/features/sos/data/sos_local_store.dart';
import 'package:mobile/features/sos/data/sos_models.dart';
import 'package:mobile/features/sos/presentation/delivery_status_chip.dart';
import 'package:mobile/features/sos/presentation/sender_emergency_session_screen.dart';
import 'package:mobile/core/theme/app_colors.dart';

import '../../helpers/fake_auth_api.dart';
import '../../helpers/fake_sos_api.dart';
import '../../helpers/fake_sos_hub_client.dart';
import '../../helpers/fake_sos_local_store.dart';

class _FixedFamilyController extends FamilyController {
  @override
  FamilyState build() => const FamilyState(family: Family(id: 'family-1'));
}

/// Empty, non-loading location state so `SosController` never touches a
/// real geolocator/hub client (matches sos_controller_test.dart's
/// convention).
class _EmptyLocationController extends LocationController {
  @override
  LocationState build() => const LocationState();
}

const _twoRecipients = [
  SosRecipientStatus(
    displayName: 'Maya',
    recipientUserId: 'maya-id',
    channels: [
      SosChannelStatus(
        channel: SosChannel.signalR,
        status: SosDeliveryStatus.acknowledged,
      ),
      SosChannelStatus(
        channel: SosChannel.fcm,
        status: SosDeliveryStatus.delivered,
      ),
    ],
  ),
  SosRecipientStatus(
    displayName: 'Dad',
    emergencyContactId: 'dad-contact-id',
    channels: [
      SosChannelStatus(
        channel: SosChannel.fcm,
        status: SosDeliveryStatus.delivered,
      ),
      SosChannelStatus(
        channel: SosChannel.sms,
        status: SosDeliveryStatus.queued,
      ),
    ],
  ),
];

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

  group('DeliveryStatusChip', () {
    testWidgets('maps each status to its locked icon, colour and copy', (
      tester,
    ) async {
      Future<void> pumpChip(SosDeliveryStatus status) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: DeliveryStatusChip(
                channel: SosChannel.signalR,
                status: status,
              ),
            ),
          ),
        );
      }

      await pumpChip(SosDeliveryStatus.notAttempted);
      expect(find.byIcon(Icons.remove), findsOneWidget);
      expect(
        tester.widget<Icon>(find.byIcon(Icons.remove)).color,
        AppColors.bodySecondary,
      );
      expect(find.text('—'), findsOneWidget);

      await pumpChip(SosDeliveryStatus.queued);
      expect(find.byIcon(Icons.schedule), findsOneWidget);
      expect(
        tester.widget<Icon>(find.byIcon(Icons.schedule)).color,
        AppColors.caution,
      );
      expect(find.text('QUEUED'), findsOneWidget);

      await pumpChip(SosDeliveryStatus.delivered);
      expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
      expect(
        tester.widget<Icon>(find.byIcon(Icons.check_circle_outline)).color,
        AppColors.safe,
      );
      expect(find.text('DELIVERED'), findsOneWidget);

      await pumpChip(SosDeliveryStatus.acknowledged);
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
      expect(
        tester.widget<Icon>(find.byIcon(Icons.check_circle)).color,
        AppColors.safe,
      );
      expect(find.text('SEEN'), findsOneWidget);
    });

    testWidgets('pairs colour with an icon and text for every status', (
      tester,
    ) async {
      for (final status in SosDeliveryStatus.values) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: DeliveryStatusChip(channel: SosChannel.fcm, status: status),
            ),
          ),
        );
        final chipFinder = find.byType(DeliveryStatusChip);
        expect(
          find.descendant(of: chipFinder, matching: find.byType(Icon)),
          findsOneWidget,
        );
        expect(
          find.descendant(of: chipFinder, matching: find.byType(Text)),
          findsOneWidget,
        );
      }
    });
  });

  group('RecipientDeliveryRow', () {
    testWidgets('renders one row per recipient', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                for (final recipient in _twoRecipients)
                  RecipientDeliveryRow(recipient: recipient),
              ],
            ),
          ),
        ),
      );

      expect(find.byType(RecipientDeliveryRow), findsNWidgets(2));
      expect(find.text('Maya'), findsOneWidget);
      expect(find.text('Dad'), findsOneWidget);
    });

    testWidgets('renders one chip per channel within a recipient row', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RecipientDeliveryRow(recipient: _twoRecipients.first),
          ),
        ),
      );

      expect(find.byType(DeliveryStatusChip), findsNWidgets(2));
    });

    testWidgets('never shows a single combined status', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                for (final recipient in _twoRecipients)
                  RecipientDeliveryRow(recipient: recipient),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Sent'), findsNothing);
      expect(find.byIcon(Icons.done_all), findsNothing);
    });
  });

  group('SenderEmergencySessionScreen delivery updates', () {
    testWidgets('updates a chip live from a hub delivery-status event', (
      tester,
    ) async {
      final hubClient = FakeSosHubClient();
      final sosApi = FakeSosApi();
      final localStore = FakeSosLocalStore();

      // Deliberately non-overlapping starting labels (dash vs. Queued) so
      // "the matching chip flips, the other is untouched" is unambiguous.
      const recipients = [
        SosRecipientStatus(
          displayName: 'Maya',
          recipientUserId: 'maya-id',
          channels: [
            SosChannelStatus(
              channel: SosChannel.signalR,
              status: SosDeliveryStatus.notAttempted,
            ),
          ],
        ),
        SosRecipientStatus(
          displayName: 'Dad',
          emergencyContactId: 'dad-contact-id',
          channels: [
            SosChannelStatus(
              channel: SosChannel.sms,
              status: SosDeliveryStatus.queued,
            ),
          ],
        ),
      ];

      sosApi.triggerResponseBuilder = (request) => SosSession(
        sosSessionId: request.sosSessionId,
        familyId: request.familyId,
        triggeredByUserId: 'self-user',
        status: SosSessionStatus.active,
        triggeredAtUtc: request.triggeredAtUtc,
        receivedAtUtc: DateTime.now().toUtc(),
        recipients: recipients,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sosApiProvider.overrideWithValue(sosApi),
            sosLocalStoreProvider.overrideWithValue(localStore),
            sosHubClientProvider.overrideWithValue(hubClient),
            familyControllerProvider.overrideWith(_FixedFamilyController.new),
            locationControllerProvider.overrideWith(
              _EmptyLocationController.new,
            ),
          ],
          child: const MaterialApp(home: SenderEmergencySessionScreen()),
        ),
      );
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(SenderEmergencySessionScreen)),
      );
      await container.read(sosControllerProvider.notifier).arm();
      await tester.pumpAndSettle();

      final sosSessionId = container
          .read(sosControllerProvider.notifier)
          .sosSessionId!;

      // SosSubmitted only shows generic "sending" copy — no recipient list
      // renders until the first hub delivery-status event arrives and
      // transitions the screen into SosDelivering. This first event is a
      // no-op status confirmation (still not-attempted) purely to reach
      // that state; it changes nothing semantically yet.
      hubClient.emitDeliveryStatusChanged(
        SosDeliveryStatusChange(
          sosSessionId: sosSessionId,
          recipientUserId: 'maya-id',
          channel: SosChannel.signalR,
          status: SosDeliveryStatus.notAttempted,
          atUtc: DateTime.now().toUtc(),
        ),
      );
      await tester.pumpAndSettle();

      // Maya's SignalR channel starts not-attempted ("—"), Dad's SMS
      // channel starts Queued.
      expect(find.text('—'), findsOneWidget);
      expect(find.text('QUEUED'), findsOneWidget);

      hubClient.emitDeliveryStatusChanged(
        SosDeliveryStatusChange(
          sosSessionId: sosSessionId,
          emergencyContactId: 'dad-contact-id',
          channel: SosChannel.sms,
          status: SosDeliveryStatus.delivered,
          atUtc: DateTime.now().toUtc(),
        ),
      );
      await tester.pumpAndSettle();

      // Dad's SMS chip flips to Delivered; Maya's SignalR chip is untouched.
      expect(find.text('DELIVERED'), findsOneWidget);
      expect(find.text('—'), findsOneWidget);
      expect(find.text('QUEUED'), findsNothing);
    });
  });
}
