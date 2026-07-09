import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import 'package:mobile/core/deep_link/deep_link_service.dart';
import 'package:mobile/core/router/app_router.dart';
import 'package:mobile/features/auth/data/auth_api.dart';
import 'package:mobile/features/family/data/family_api.dart';
import 'package:mobile/features/family/data/family_models.dart';

import '../../helpers/fake_auth_api.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('logged-out invite link is restored after sign-in', (
    tester,
  ) async {
    final authApi = FakeAuthApi();
    final familyApi = _PendingInviteFamilyApi();
    final container = ProviderContainer(
      overrides: [
        authApiProvider.overrideWithValue(authApi),
        familyApiProvider.overrideWithValue(familyApi),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(authApi.dispose);

    final router = container.read(routerProvider);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          theme: ThemeData(splashFactory: NoSplash.splashFactory),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    router.go('/invite/accept?token=pending-token');
    await tester.pumpAndSettle();

    expect(find.text('SafePath AI'), findsOneWidget);
    expect(container.read(pendingInviteProvider)?.token, 'pending-token');

    authApi.initialSession = _fakeSession();
    authApi.emitSignedIn();
    await tester.pumpAndSettle();

    expect(find.text("You've been invited"), findsOneWidget);
    expect(
      find.text('Invite link ready. Tap Accept & join to continue.'),
      findsOneWidget,
    );
    expect(container.read(pendingInviteProvider), isNull);
  });
}

sb.Session _fakeSession() => sb.Session(
  accessToken: 'fake-access-token',
  tokenType: 'bearer',
  user: sb.User(
    id: 'fake-user-id',
    appMetadata: const {},
    userMetadata: const {},
    aud: 'authenticated',
    createdAt: DateTime.now().toIso8601String(),
  ),
);

class _PendingInviteFamilyApi implements FamilyApi {
  @override
  Future<List<MyFamily>> getMyFamilies() async => const [];

  @override
  Future<Family> createFamily(String name) async =>
      Family(id: 'fam-1', name: name);

  @override
  Future<List<FamilyMemberView>> listMembers(String familyId) async => const [];

  @override
  Future<Invitation> generateInvite(
    String familyId, {
    String? inviteeLabel,
  }) async => throw UnimplementedError();

  @override
  Future<RedeemResult> redeemInvite({
    String? code,
    String? linkToken,
    required bool accept,
  }) async =>
      const RedeemResult(familyId: 'fam-1', status: 'Accepted', accepted: true);

  @override
  Future<PermissionLevel> updatePermission(
    String familyId,
    String memberId,
    PermissionLevel level,
  ) async => level;

  @override
  Future<void> removeMember(String familyId, String memberId) async {}
}
