// Behavior under test (03-04-PLAN.md Task 2):
// - renders the sender's name in the incoming headline
// - shows both Phase 3 actions (Acknowledge, Call sender)
// - shows no mark-resolved control (D-23)
// - acknowledging calls the API once and switches to the acknowledged form
// - keeps Call sender available after acknowledging
// - shows the acknowledged timestamp caption
// - renders a red header strip in the incoming state

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mobile/core/theme/app_colors.dart';
import 'package:mobile/features/auth/data/auth_models.dart';
import 'package:mobile/features/family/application/family_controller.dart';
import 'package:mobile/features/family/data/family_models.dart';
import 'package:mobile/features/sos/application/sos_responder_controller.dart';
import 'package:mobile/features/sos/data/sos_api.dart';
import 'package:mobile/features/sos/data/sos_models.dart';
import 'package:mobile/features/sos/presentation/responder_alert_screen.dart';

import '../../helpers/fake_sos_api.dart';

class _FixedFamilyController extends FamilyController {
  @override
  FamilyState build() => FamilyState(
    family: const Family(id: 'family-1'),
    members: [
      FamilyMemberView(
        memberId: 'member-1',
        userId: 'ana-user-id',
        displayName: 'Ana',
        role: Role.member,
        permission: PermissionLevel.fullLocation,
        joinedAt: DateTime.utc(2026, 1, 1),
      ),
    ],
  );
}

class _FixedResponderController extends SosResponderController {
  _FixedResponderController(this.initialState);

  final SosResponderState initialState;

  @override
  SosResponderState build() => initialState;
}

SosSession _incomingSession() {
  return SosSession(
    sosSessionId: 'session-1',
    familyId: 'family-1',
    triggeredByUserId: 'ana-user-id',
    status: SosSessionStatus.active,
    triggeredAtUtc: DateTime.now().toUtc(),
    receivedAtUtc: DateTime.now().toUtc(),
  );
}

Widget _wrap({
  required SosResponderState initialState,
  required FakeSosApi sosApi,
}) {
  return ProviderScope(
    overrides: [
      sosResponderControllerProvider.overrideWith(
        () => _FixedResponderController(initialState),
      ),
      sosApiProvider.overrideWithValue(sosApi),
      familyControllerProvider.overrideWith(_FixedFamilyController.new),
    ],
    child: const MaterialApp(
      home: ResponderAlertScreen(sessionId: 'session-1'),
    ),
  );
}

void main() {
  testWidgets('renders the sender\'s name in the incoming headline', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        initialState: SosResponderState(activeSession: _incomingSession()),
        sosApi: FakeSosApi(),
      ),
    );

    expect(find.text('Ana triggered SOS'), findsOneWidget);
  });

  testWidgets('shows both Phase 3 actions', (tester) async {
    await tester.pumpWidget(
      _wrap(
        initialState: SosResponderState(activeSession: _incomingSession()),
        sosApi: FakeSosApi(),
      ),
    );

    expect(find.text('Acknowledge'), findsOneWidget);
    expect(find.text('Call sender'), findsOneWidget);
  });

  testWidgets('shows no mark-resolved control', (tester) async {
    await tester.pumpWidget(
      _wrap(
        initialState: SosResponderState(activeSession: _incomingSession()),
        sosApi: FakeSosApi(),
      ),
    );

    expect(find.textContaining('esolve'), findsNothing);
    expect(find.text('Mark resolved'), findsNothing);
  });

  testWidgets(
    'acknowledging calls the API once and switches the control to its '
    'acknowledged form',
    (tester) async {
      final sosApi = FakeSosApi();
      await tester.pumpWidget(
        _wrap(
          initialState: SosResponderState(activeSession: _incomingSession()),
          sosApi: sosApi,
        ),
      );

      await tester.tap(find.text('Acknowledge'));
      await tester.pumpAndSettle();

      expect(sosApi.acknowledgeCallCount, 1);
      expect(sosApi.acknowledgeCalls.single, 'session-1');
      expect(find.text('Acknowledged'), findsOneWidget);
      expect(find.text('Acknowledge'), findsNothing);

      final button = tester.widget<ElevatedButton>(
        find.ancestor(
          of: find.text('Acknowledged'),
          matching: find.byType(ElevatedButton),
        ),
      );
      expect(button.onPressed, isNull);
    },
  );

  testWidgets('keeps Call sender available after acknowledging', (
    tester,
  ) async {
    final sosApi = FakeSosApi();
    await tester.pumpWidget(
      _wrap(
        initialState: SosResponderState(activeSession: _incomingSession()),
        sosApi: sosApi,
      ),
    );

    await tester.tap(find.text('Acknowledge'));
    await tester.pumpAndSettle();

    final button = tester.widget<ElevatedButton>(
      find.ancestor(
        of: find.text('Call sender'),
        matching: find.byType(ElevatedButton),
      ),
    );
    expect(button.onPressed, isNotNull);
  });

  testWidgets('shows the acknowledged timestamp caption', (tester) async {
    final sosApi = FakeSosApi();
    await tester.pumpWidget(
      _wrap(
        initialState: SosResponderState(activeSession: _incomingSession()),
        sosApi: sosApi,
      ),
    );

    await tester.tap(find.text('Acknowledge'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('You acknowledged this alert at'),
      findsOneWidget,
    );
  });

  testWidgets('renders a red header strip in the incoming state', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        initialState: SosResponderState(activeSession: _incomingSession()),
        sosApi: FakeSosApi(),
      ),
    );

    final header = tester.widget<DecoratedBox>(
      find.byKey(const ValueKey('responder-header-strip')),
    );
    final decoration = header.decoration as BoxDecoration;
    expect(decoration.color, AppColors.sosRed);
  });
}
