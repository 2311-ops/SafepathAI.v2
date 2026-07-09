// Behavior under test (01-07-PLAN.md Task 2, locked decision D3):
// - The Invite screen renders a QR code + the mono share code + Copy link +
//   Share (share_plus) buttons.
// - There is NO email-address input field anywhere on the screen.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:mobile/features/family/application/family_controller.dart';
import 'package:mobile/features/family/data/family_api.dart';
import 'package:mobile/features/family/data/family_models.dart';
import 'package:mobile/features/family/presentation/invite_member_screen.dart';

/// Minimal fake — this test only exercises `generateInvite`, called once
/// from the screen's `initState`.
class _FakeFamilyApi implements FamilyApi {
  @override
  Future<Family> createFamily(String name) async => Family(id: 'fam-1', name: name);

  @override
  Future<List<FamilyMemberView>> listMembers(String familyId) async => const [];

  @override
  Future<Invitation> generateInvite(String familyId, {String? inviteeLabel}) async {
    return Invitation(
      invitationId: 'inv-1',
      code: 'SP-4K9X',
      linkToken: 'opaque-link-token',
      expiresAt: DateTime.now().toUtc().add(const Duration(hours: 24)),
      inviteeLabel: inviteeLabel,
    );
  }

  @override
  Future<RedeemResult> redeemInvite({
    String? code,
    String? linkToken,
    required bool accept,
  }) async => throw UnimplementedError();

  @override
  Future<PermissionLevel> updatePermission(
    String familyId,
    String memberId,
    PermissionLevel level,
  ) async => throw UnimplementedError();

  @override
  Future<void> removeMember(String familyId, String memberId) async =>
      throw UnimplementedError();
}

/// Seeds [FamilyController] with an already-created family (so the screen's
/// `initState` has a `familyId` to call `generateInvite` with) without
/// exercising `createCircle`/Dio.
class _SeededFamilyController extends FamilyController {
  @override
  FamilyState build() => const FamilyState(
        family: Family(id: 'fam-1', name: 'The Rivera Family'),
        members: [],
      );
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  Widget buildTestApp() {
    final router = GoRouter(
      initialLocation: '/circle/invite',
      routes: [
        GoRoute(
          path: '/circle/invite',
          builder: (context, state) => const InviteMemberScreen(),
        ),
      ],
    );
    return ProviderScope(
      overrides: [
        familyApiProvider.overrideWithValue(_FakeFamilyApi()),
        familyControllerProvider.overrideWith(_SeededFamilyController.new),
      ],
      child: MaterialApp.router(routerConfig: router),
    );
  }

  testWidgets(
    'renders a QR code, the mono share code, Copy link + Share, and no email field',
    (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      expect(find.byType(QrImageView), findsOneWidget);
      expect(find.text('SP-4K9X'), findsOneWidget);
      expect(find.text('Expires in 24h'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Copy link'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'Share'), findsOneWidget);

      // D3: no email-address input field anywhere on this screen.
      expect(find.byType(TextField), findsNothing);
      expect(find.byType(TextFormField), findsNothing);
      expect(find.textContaining('email'), findsNothing);
      expect(find.textContaining('Email'), findsNothing);
    },
  );

  testWidgets('shows the "No pending invites yet" empty state on first open', (tester) async {
    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();

    expect(find.text('No pending invites yet'), findsOneWidget);
    expect(
      find.text('Share your code or link above to add someone to your circle.'),
      findsOneWidget,
    );
  });
}
