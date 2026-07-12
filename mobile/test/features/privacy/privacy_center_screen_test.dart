import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import 'package:mobile/features/auth/data/auth_api.dart';
import 'package:mobile/features/auth/data/auth_models.dart';
import 'package:mobile/features/family/application/family_controller.dart';
import 'package:mobile/features/family/data/family_models.dart';
import 'package:mobile/features/privacy/application/privacy_controller.dart';
import 'package:mobile/features/privacy/data/privacy_models.dart';
import 'package:mobile/features/privacy/presentation/privacy_center_screen.dart';
import '../../helpers/fake_auth_api.dart';

class _SeededFamilyController extends FamilyController {
  @override
  FamilyState build() => FamilyState(
        family: const Family(id: 'fam-1', name: 'Safe circle'),
        members: [
          FamilyMemberView(
            memberId: 'mem-self',
            userId: 'self-user',
            role: Role.guardian,
            permission: PermissionLevel.fullLocation,
            joinedAt: DateTime.utc(2026, 7, 12),
          ),
          FamilyMemberView(
            memberId: 'mem-recipient',
            userId: 'recipient-user',
            role: Role.member,
            permission: PermissionLevel.fullLocation,
            joinedAt: DateTime.utc(2026, 7, 12),
          ),
        ],
      );
}

class _SpyPrivacyController extends PrivacyController {
  int toggleCallCount = 0;
  int temporaryShareCallCount = 0;
  String? lastRecipientId;
  SharedDataType? lastDataType;
  bool? lastEnabled;
  Duration? lastDuration;

  @override
  PrivacyState build() => PrivacyState(
        matrix: SharingMatrix(
          entries: [
            const SharingCell(
              recipientId: 'mem-recipient',
              recipientName: 'Recipient',
              dataType: SharedDataType.liveLocation,
              isEnabled: true,
            ),
            const SharingCell(
              recipientId: 'mem-recipient',
              recipientName: 'Recipient',
              dataType: SharedDataType.history,
              isEnabled: false,
            ),
            SharingCell(
              recipientId: 'mem-recipient',
              recipientName: 'Recipient',
              dataType: SharedDataType.wellness,
              isEnabled: true,
              expiresAtUtc: DateTime.utc(2026, 7, 12, 14),
            ),
          ],
        ),
      );

  @override
  Future<void> toggle({
    String? recipientId,
    required SharedDataType dataType,
    required bool enabled,
    DateTime? expiresAtUtc,
  }) async {
    toggleCallCount++;
    lastRecipientId = recipientId;
    lastDataType = dataType;
    lastEnabled = enabled;
  }

  @override
  Future<void> startTemporaryShare({
    String? recipientId,
    required SharedDataType dataType,
    required Duration duration,
  }) async {
    temporaryShareCallCount++;
    lastRecipientId = recipientId;
    lastDataType = dataType;
    lastDuration = duration;
  }
}

Widget _app(_SpyPrivacyController controller) {
  return ProviderScope(
    overrides: [
      authApiProvider.overrideWithValue(
        FakeAuthApi(initialSession: _session(userId: 'self-user')),
      ),
      familyControllerProvider.overrideWith(_SeededFamilyController.new),
      privacyControllerProvider.overrideWith(() => controller),
      privacyNowProvider.overrideWithValue(
        () => DateTime.utc(2026, 7, 12, 10, 30),
      ),
    ],
    child: const MaterialApp(home: PrivacyCenterScreen()),
  );
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('renders toggle matrix and duration controls', (tester) async {
    final controller = _SpyPrivacyController();

    await tester.pumpWidget(_app(controller));

    expect(find.text('Privacy Center'), findsWidgets);
    expect(find.text('Recipient'), findsOneWidget);
    expect(find.text('Live location'), findsOneWidget);
    expect(find.text('History'), findsOneWidget);
    expect(find.text('Wellness'), findsOneWidget);
    expect(find.text('1 hour'), findsOneWidget);
    expect(find.text('4 hours'), findsOneWidget);
    expect(find.text('8 hours'), findsOneWidget);
    expect(find.text('Custom'), findsOneWidget);
    expect(find.text('Sharing for 1 hour - 3h 30m left'), findsOneWidget);
  });

  testWidgets('tapping a toggle calls the privacy controller', (tester) async {
    final controller = _SpyPrivacyController();

    await tester.pumpWidget(_app(controller));
    await tester.tap(find.byType(Switch).first);
    await tester.pump();

    expect(controller.toggleCallCount, 1);
    expect(controller.lastRecipientId, 'mem-recipient');
    expect(controller.lastDataType, SharedDataType.liveLocation);
    expect(controller.lastEnabled, isFalse);
  });

  testWidgets('duration chip starts temporary live-location sharing', (
    tester,
  ) async {
    final controller = _SpyPrivacyController();

    await tester.pumpWidget(_app(controller));
    await tester.tap(find.text('4 hours'));
    await tester.pump();

    expect(controller.temporaryShareCallCount, 1);
    expect(controller.lastRecipientId, 'mem-recipient');
    expect(controller.lastDataType, SharedDataType.liveLocation);
    expect(controller.lastDuration, const Duration(hours: 4));
  });
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
