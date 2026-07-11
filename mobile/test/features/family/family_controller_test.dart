// Behavior under test (01-07-PLAN.md Task 1):
// - createCircle(name) returns the new family + adds the caller as a
//   Guardian member.
// - generateInvite(familyId, label?) returns a code + linkToken + expiry.
// - redeemInvite(code, accept: true) joins the circle;
//   redeemInvite(code, accept: false) does not.
// - updatePermission(memberId, level) reflects the new level in state.
// - removeMember(memberId) removes them from the list.
// - A failed authorization (non-Guardian) surfaces an error without
//   mutating state.
//
// Behavior under test (01-10-PLAN.md Task 2 — bootstrap fetch on auth):
// - Controller built while authControllerProvider is already
//   AuthAuthenticated -> calls getMyFamilies() and populates family/members
//   from the first result.
// - Controller built while unauthenticated, then auth transitions to
//   AuthAuthenticated -> the same fetch fires on that transition.
// - getMyFamilies() returns empty -> family stays null, no error state.
// - getMyFamilies() throws -> surfaces via the existing error field,
//   doesn't crash, family stays null.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import 'package:mobile/features/auth/data/auth_api.dart';
import 'package:mobile/features/auth/data/auth_models.dart';
import 'package:mobile/features/family/application/family_controller.dart';
import 'package:mobile/features/family/data/family_api.dart';
import 'package:mobile/features/family/data/family_models.dart';

/// Minimal [AuthApi] fake, scoped to this test file, that only implements
/// what [FamilyController.build] needs (`currentSession`/`authStateChanges`)
/// — controls whether `authControllerProvider` computes `AuthAuthenticated`
/// at construction and lets tests simulate a later sign-in event.
class _FakeAuthApi implements AuthApi {
  sb.Session? sessionOverride;

  final StreamController<dynamic> _controller =
      StreamController<dynamic>.broadcast();

  @override
  sb.Session? get currentSession => sessionOverride;

  @override
  Stream<dynamic> get authStateChanges => _controller.stream;

  /// Pushes a SIGNED_IN event, simulating a fresh login completing.
  void emitSession() {
    _controller.add(
      sb.AuthState(
        sb.AuthChangeEvent.signedIn,
        sb.Session(
          accessToken: 'fake-token',
          tokenType: 'bearer',
          user: sb.User(
            id: 'fake-user-id',
            appMetadata: const {},
            userMetadata: const {},
            aud: 'authenticated',
            createdAt: DateTime.now().toIso8601String(),
          ),
        ),
      ),
    );
  }

  void dispose() => _controller.close();

  @override
  Future<AuthSessionResult> register({
    required String email,
    required String password,
    required String fullName,
    required Role role,
  }) => throw UnimplementedError();

  @override
  Future<AuthSessionResult> login({
    required String email,
    required String password,
  }) => throw UnimplementedError();

  @override
  Future<void> logout() => throw UnimplementedError();

  @override
  Future<void> sendPasswordResetEmail({required String email}) =>
      throw UnimplementedError();

  @override
  Future<void> updatePassword({required String password}) =>
      throw UnimplementedError();

  @override
  Future<void> updateRoleMetadata(Role role) => throw UnimplementedError();

  @override
  Future<AuthSessionResult> refreshSession() => throw UnimplementedError();

  @override
  Future<bool> signInWithGoogle() => throw UnimplementedError();
}

class FakeFamilyApi implements FamilyApi {
  bool shouldDenyAsForbidden = false;

  Family Function(String name)? createFamilyOverride;
  Map<String, List<FamilyMemberView>> membersByFamilyId = {};
  Invitation? inviteToReturn;
  RedeemResult? redeemResultToReturn;
  PermissionLevel? updatePermissionOverride;

  /// Controls [getMyFamilies] — the 01-10-PLAN.md bootstrap-fetch behavior.
  List<MyFamily> myFamiliesToReturn = const [];
  bool getMyFamiliesShouldThrow = false;
  int getMyFamiliesCallCount = 0;

  String? lastCreateFamilyName;
  String? lastGenerateInviteFamilyId;
  String? lastGenerateInviteLabel;
  String? lastRedeemCode;
  String? lastRedeemLinkToken;
  bool? lastRedeemAccept;
  String? lastUpdatePermissionFamilyId;
  String? lastUpdatePermissionMemberId;
  String? lastRemoveMemberId;

  @override
  Future<List<MyFamily>> getMyFamilies() async {
    getMyFamiliesCallCount++;
    if (getMyFamiliesShouldThrow) {
      throw FamilyApiException(
        FamilyApiIssue.network,
        message: "Couldn't connect. Check your connection and try again.",
      );
    }
    return myFamiliesToReturn;
  }

  @override
  Future<Family> createFamily(String name) async {
    lastCreateFamilyName = name;
    if (shouldDenyAsForbidden) {
      throw FamilyApiException(
        FamilyApiIssue.forbidden,
        message: 'Only a Guardian can do that.',
      );
    }
    return (createFamilyOverride ?? (n) => Family(id: 'fam-1', name: n))(name);
  }

  @override
  Future<List<FamilyMemberView>> listMembers(String familyId) async {
    if (shouldDenyAsForbidden) {
      throw FamilyApiException(
        FamilyApiIssue.forbidden,
        message: 'Only a Guardian can do that.',
      );
    }
    return membersByFamilyId[familyId] ?? const [];
  }

  @override
  Future<Invitation> generateInvite(
    String familyId, {
    String? inviteeLabel,
  }) async {
    lastGenerateInviteFamilyId = familyId;
    lastGenerateInviteLabel = inviteeLabel;
    if (shouldDenyAsForbidden) {
      throw FamilyApiException(
        FamilyApiIssue.forbidden,
        message: 'Only a Guardian can do that.',
      );
    }
    return inviteToReturn!;
  }

  @override
  Future<RedeemResult> redeemInvite({
    String? code,
    String? linkToken,
    required bool accept,
  }) async {
    lastRedeemCode = code;
    lastRedeemLinkToken = linkToken;
    lastRedeemAccept = accept;
    if (shouldDenyAsForbidden) {
      throw FamilyApiException(
        FamilyApiIssue.forbidden,
        message: 'Only a Guardian can do that.',
      );
    }
    return redeemResultToReturn!;
  }

  @override
  Future<PermissionLevel> updatePermission(
    String familyId,
    String memberId,
    PermissionLevel level,
  ) async {
    lastUpdatePermissionFamilyId = familyId;
    lastUpdatePermissionMemberId = memberId;
    if (shouldDenyAsForbidden) {
      throw FamilyApiException(
        FamilyApiIssue.forbidden,
        message: 'Only a Guardian can do that.',
      );
    }
    return updatePermissionOverride ?? level;
  }

  @override
  Future<void> removeMember(String familyId, String memberId) async {
    lastRemoveMemberId = memberId;
    if (shouldDenyAsForbidden) {
      throw FamilyApiException(
        FamilyApiIssue.forbidden,
        message: 'Only a Guardian can do that.',
      );
    }
  }
}

FamilyMemberView _member({
  required String memberId,
  required String userId,
  Role role = Role.member,
  PermissionLevel permission = PermissionLevel.viewOnly,
}) {
  return FamilyMemberView(
    memberId: memberId,
    userId: userId,
    role: role,
    permission: permission,
    joinedAt: DateTime.utc(2026, 7, 9),
  );
}

void main() {
  late FakeFamilyApi fakeApi;
  late _FakeAuthApi fakeAuthApi;
  late ProviderContainer container;

  setUp(() {
    fakeApi = FakeFamilyApi();
    // Unauthenticated by default so FamilyController.build()'s bootstrap
    // check (D-10-3) is a no-op for the pre-existing tests below, which
    // exercise state purely via explicit action calls.
    fakeAuthApi = _FakeAuthApi();
    container = ProviderContainer(
      overrides: [
        familyApiProvider.overrideWithValue(fakeApi),
        authApiProvider.overrideWithValue(fakeAuthApi),
      ],
    );
  });

  tearDown(() {
    container.dispose();
    fakeAuthApi.dispose();
  });

  test(
    'createCircle creates the family and loads the caller as its Guardian member',
    () async {
      fakeApi.membersByFamilyId['fam-1'] = [
        _member(
          memberId: 'mem-1',
          userId: 'guardian-user',
          role: Role.guardian,
        ),
      ];

      await container
          .read(familyControllerProvider.notifier)
          .createCircle('The Rivera Family');

      final state = container.read(familyControllerProvider).value!;
      expect(state.family?.id, 'fam-1');
      expect(state.family?.name, 'The Rivera Family');
      expect(state.members, hasLength(1));
      expect(state.members.single.role, Role.guardian);
      expect(fakeApi.lastCreateFamilyName, 'The Rivera Family');
    },
  );

  test('generateInvite returns a code + linkToken + expiry', () async {
    final expiry = DateTime.now().toUtc().add(const Duration(hours: 24));
    fakeApi.inviteToReturn = Invitation(
      invitationId: 'inv-1',
      code: 'SP-4K9X',
      linkToken: 'opaque-link-token',
      expiresAt: expiry,
    );

    await container
        .read(familyControllerProvider.notifier)
        .generateInvite('fam-1');

    final state = container.read(familyControllerProvider).value!;
    expect(state.latestInvite?.code, 'SP-4K9X');
    expect(state.latestInvite?.linkToken, 'opaque-link-token');
    expect(state.latestInvite?.expiresAt, expiry);
    expect(state.pendingInvites, hasLength(1));
    expect(fakeApi.lastGenerateInviteFamilyId, 'fam-1');
  });

  test(
    'redeemInvite(accept: true) joins the circle and loads its members',
    () async {
      fakeApi.redeemResultToReturn = const RedeemResult(
        familyId: 'fam-2',
        status: 'Accepted',
        accepted: true,
      );
      fakeApi.membersByFamilyId['fam-2'] = [
        _member(
          memberId: 'mem-1',
          userId: 'guardian-user',
          role: Role.guardian,
        ),
        _member(memberId: 'mem-2', userId: 'invitee-user', role: Role.member),
      ];

      await container
          .read(familyControllerProvider.notifier)
          .redeemInvite(code: 'SP-4K9X', accept: true);

      final state = container.read(familyControllerProvider).value!;
      expect(state.family?.id, 'fam-2');
      expect(state.members, hasLength(2));
      expect(fakeApi.lastRedeemAccept, isTrue);
    },
  );

  test(
    'redeemInvite(accept: false) declines and does not join a circle',
    () async {
      fakeApi.redeemResultToReturn = const RedeemResult(
        familyId: 'fam-2',
        status: 'Declined',
        accepted: false,
      );

      await container
          .read(familyControllerProvider.notifier)
          .redeemInvite(code: 'SP-4K9X', accept: false);

      final state = container.read(familyControllerProvider).value!;
      expect(state.family, isNull);
      expect(state.members, isEmpty);
      expect(fakeApi.lastRedeemAccept, isFalse);
    },
  );

  test('updatePermission reflects the new level in state', () async {
    fakeApi.membersByFamilyId['fam-1'] = [
      _member(memberId: 'mem-2', userId: 'invitee-user'),
    ];
    await container
        .read(familyControllerProvider.notifier)
        .createCircle('The Rivera Family');
    // Seed state with the target member (createCircle only loads what
    // listMembers returns for the newly-created family, so overwrite it
    // directly here to exercise updatePermission in isolation).
    fakeApi.updatePermissionOverride = PermissionLevel.fullLocation;

    await container
        .read(familyControllerProvider.notifier)
        .updatePermission('fam-1', 'mem-2', PermissionLevel.fullLocation);

    final state = container.read(familyControllerProvider).value!;
    final updated = state.members.firstWhere((m) => m.memberId == 'mem-2');
    expect(updated.permission, PermissionLevel.fullLocation);
    expect(fakeApi.lastUpdatePermissionFamilyId, 'fam-1');
    expect(fakeApi.lastUpdatePermissionMemberId, 'mem-2');
  });

  test('removeMember removes them from the member list', () async {
    fakeApi.membersByFamilyId['fam-1'] = [
      _member(memberId: 'mem-1', userId: 'guardian-user', role: Role.guardian),
      _member(memberId: 'mem-2', userId: 'invitee-user'),
    ];
    await container
        .read(familyControllerProvider.notifier)
        .createCircle('The Rivera Family');

    await container
        .read(familyControllerProvider.notifier)
        .removeMember('fam-1', 'mem-2');

    final state = container.read(familyControllerProvider).value!;
    expect(state.members.map((m) => m.memberId), ['mem-1']);
    expect(fakeApi.lastRemoveMemberId, 'mem-2');
  });

  test(
    'a failed authorization (non-Guardian) surfaces an error without mutating state',
    () async {
      fakeApi.membersByFamilyId['fam-1'] = [
        _member(
          memberId: 'mem-1',
          userId: 'guardian-user',
          role: Role.guardian,
        ),
        _member(memberId: 'mem-2', userId: 'invitee-user'),
      ];
      await container
          .read(familyControllerProvider.notifier)
          .createCircle('The Rivera Family');
      final beforeMembers = container
          .read(familyControllerProvider)
          .value!
          .members;

      fakeApi.shouldDenyAsForbidden = true;
      await container
          .read(familyControllerProvider.notifier)
          .updatePermission('fam-1', 'mem-2', PermissionLevel.fullLocation);

      final state = container.read(familyControllerProvider).value!;
      expect(state.error, isNotNull);
      expect(state.members, beforeMembers);
      expect(
        state.members.firstWhere((m) => m.memberId == 'mem-2').permission,
        PermissionLevel.viewOnly,
      );
    },
  );

  group('bootstrap fetch on auth (01-10-PLAN.md D-10-3)', () {
    test(
      'controller built while already authenticated fetches and restores the first family',
      () async {
        final bootstrapApi = FakeFamilyApi()
          ..myFamiliesToReturn = const [
            MyFamily(
              familyId: 'fam-9',
              familyName: 'The Osei Family',
              role: Role.guardian,
              permissions: PermissionLevel.fullLocation,
            ),
          ]
          ..membersByFamilyId['fam-9'] = [
            _member(
              memberId: 'mem-1',
              userId: 'guardian-user',
              role: Role.guardian,
            ),
          ];
        final authApi = _FakeAuthApi()
          ..sessionOverride = sb.Session(
            accessToken: 'existing-token',
            tokenType: 'bearer',
            user: sb.User(
              id: 'guardian-user',
              appMetadata: const {},
              userMetadata: const {},
              aud: 'authenticated',
              createdAt: DateTime.now().toIso8601String(),
            ),
          );
        final bootstrapContainer = ProviderContainer(
          overrides: [
            familyApiProvider.overrideWithValue(bootstrapApi),
            authApiProvider.overrideWithValue(authApi),
          ],
        );
        addTearDown(bootstrapContainer.dispose);
        addTearDown(authApi.dispose);

        // Reading immediately after construction observes the isLoading
        // flag set synchronously by build() before the fetch resolves.
        expect(
          bootstrapContainer.read(familyControllerProvider).value?.isLoading,
          isTrue,
        );

        await pumpEventQueue();

        final state = bootstrapContainer.read(familyControllerProvider).value!;
        expect(state.isLoading, isFalse);
        expect(state.family?.id, 'fam-9');
        expect(state.family?.name, 'The Osei Family');
        expect(state.members, hasLength(1));
        expect(state.members.single.memberId, 'mem-1');
        expect(bootstrapApi.getMyFamiliesCallCount, 1);
      },
    );

    test('a fresh login transition fetches and restores the family', () async {
      final bootstrapApi = FakeFamilyApi()
        ..myFamiliesToReturn = const [
          MyFamily(
            familyId: 'fam-7',
            familyName: 'The Diaz Family',
            role: Role.member,
            permissions: PermissionLevel.viewOnly,
          ),
        ]
        ..membersByFamilyId['fam-7'] = [
          _member(memberId: 'mem-3', userId: 'member-user'),
        ];
      final authApi =
          _FakeAuthApi(); // sessionOverride null -> Unauthenticated at build.
      final bootstrapContainer = ProviderContainer(
        overrides: [
          familyApiProvider.overrideWithValue(bootstrapApi),
          authApiProvider.overrideWithValue(authApi),
        ],
      );
      addTearDown(bootstrapContainer.dispose);
      addTearDown(authApi.dispose);

      // Establish the FamilyController subscription (and its ref.listen)
      // while still unauthenticated, before the login event fires.
      expect(
        bootstrapContainer.read(familyControllerProvider).value?.family,
        isNull,
      );
      expect(bootstrapApi.getMyFamiliesCallCount, 0);

      authApi.emitSession();
      await pumpEventQueue();

      final state = bootstrapContainer.read(familyControllerProvider).value!;
      expect(state.family?.id, 'fam-7');
      expect(state.members, hasLength(1));
      expect(bootstrapApi.getMyFamiliesCallCount, 1);
    });

    test(
      'getMyFamilies() returning empty leaves family null with no error',
      () async {
        fakeAuthApi.sessionOverride = sb.Session(
          accessToken: 'existing-token',
          tokenType: 'bearer',
          user: sb.User(
            id: 'guardian-user',
            appMetadata: const {},
            userMetadata: const {},
            aud: 'authenticated',
            createdAt: DateTime.now().toIso8601String(),
          ),
        );
        fakeApi.myFamiliesToReturn = const [];
        final bootstrapContainer = ProviderContainer(
          overrides: [
            familyApiProvider.overrideWithValue(fakeApi),
            authApiProvider.overrideWithValue(fakeAuthApi),
          ],
        );
        addTearDown(bootstrapContainer.dispose);

        // Reading triggers build() (and the fire-and-forget bootstrap
        // microtask) synchronously; pump before asserting the settled state.
        bootstrapContainer.read(familyControllerProvider);
        await pumpEventQueue();

        final state = bootstrapContainer.read(familyControllerProvider).value!;
        expect(state.family, isNull);
        expect(state.error, isNull);
        expect(state.isLoading, isFalse);
        expect(fakeApi.getMyFamiliesCallCount, 1);
      },
    );

    test(
      'getMyFamilies() throwing surfaces the error without crashing, family stays null',
      () async {
        fakeAuthApi.sessionOverride = sb.Session(
          accessToken: 'existing-token',
          tokenType: 'bearer',
          user: sb.User(
            id: 'guardian-user',
            appMetadata: const {},
            userMetadata: const {},
            aud: 'authenticated',
            createdAt: DateTime.now().toIso8601String(),
          ),
        );
        fakeApi.getMyFamiliesShouldThrow = true;
        final bootstrapContainer = ProviderContainer(
          overrides: [
            familyApiProvider.overrideWithValue(fakeApi),
            authApiProvider.overrideWithValue(fakeAuthApi),
          ],
        );
        addTearDown(bootstrapContainer.dispose);

        bootstrapContainer.read(familyControllerProvider);
        await pumpEventQueue();

        final state = bootstrapContainer.read(familyControllerProvider).value!;
        expect(state.family, isNull);
        expect(state.error, isNotNull);
        expect(state.isLoading, isFalse);
      },
    );
  });
}
