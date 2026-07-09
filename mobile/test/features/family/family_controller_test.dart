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

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mobile/features/auth/data/auth_models.dart';
import 'package:mobile/features/family/application/family_controller.dart';
import 'package:mobile/features/family/data/family_api.dart';
import 'package:mobile/features/family/data/family_models.dart';

class FakeFamilyApi implements FamilyApi {
  bool shouldDenyAsForbidden = false;

  Family Function(String name)? createFamilyOverride;
  Map<String, List<FamilyMemberView>> membersByFamilyId = {};
  Invitation? inviteToReturn;
  RedeemResult? redeemResultToReturn;
  PermissionLevel? updatePermissionOverride;

  String? lastCreateFamilyName;
  String? lastGenerateInviteFamilyId;
  String? lastGenerateInviteLabel;
  String? lastRedeemCode;
  bool? lastRedeemAccept;
  String? lastUpdatePermissionFamilyId;
  String? lastUpdatePermissionMemberId;
  String? lastRemoveMemberId;

  @override
  Future<Family> createFamily(String name) async {
    lastCreateFamilyName = name;
    if (shouldDenyAsForbidden) {
      throw FamilyApiException(FamilyApiIssue.forbidden, message: 'Only a Guardian can do that.');
    }
    return (createFamilyOverride ?? (n) => Family(id: 'fam-1', name: n))(name);
  }

  @override
  Future<List<FamilyMemberView>> listMembers(String familyId) async {
    if (shouldDenyAsForbidden) {
      throw FamilyApiException(FamilyApiIssue.forbidden, message: 'Only a Guardian can do that.');
    }
    return membersByFamilyId[familyId] ?? const [];
  }

  @override
  Future<Invitation> generateInvite(String familyId, {String? inviteeLabel}) async {
    lastGenerateInviteFamilyId = familyId;
    lastGenerateInviteLabel = inviteeLabel;
    if (shouldDenyAsForbidden) {
      throw FamilyApiException(FamilyApiIssue.forbidden, message: 'Only a Guardian can do that.');
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
    lastRedeemAccept = accept;
    if (shouldDenyAsForbidden) {
      throw FamilyApiException(FamilyApiIssue.forbidden, message: 'Only a Guardian can do that.');
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
      throw FamilyApiException(FamilyApiIssue.forbidden, message: 'Only a Guardian can do that.');
    }
    return updatePermissionOverride ?? level;
  }

  @override
  Future<void> removeMember(String familyId, String memberId) async {
    lastRemoveMemberId = memberId;
    if (shouldDenyAsForbidden) {
      throw FamilyApiException(FamilyApiIssue.forbidden, message: 'Only a Guardian can do that.');
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
  late ProviderContainer container;

  setUp(() {
    fakeApi = FakeFamilyApi();
    container = ProviderContainer(
      overrides: [familyApiProvider.overrideWithValue(fakeApi)],
    );
  });

  tearDown(() {
    container.dispose();
  });

  test('createCircle creates the family and loads the caller as its Guardian member', () async {
    fakeApi.membersByFamilyId['fam-1'] = [
      _member(memberId: 'mem-1', userId: 'guardian-user', role: Role.guardian),
    ];

    await container.read(familyControllerProvider.notifier).createCircle('The Rivera Family');

    final state = container.read(familyControllerProvider).value!;
    expect(state.family?.id, 'fam-1');
    expect(state.family?.name, 'The Rivera Family');
    expect(state.members, hasLength(1));
    expect(state.members.single.role, Role.guardian);
    expect(fakeApi.lastCreateFamilyName, 'The Rivera Family');
  });

  test('generateInvite returns a code + linkToken + expiry', () async {
    final expiry = DateTime.now().toUtc().add(const Duration(hours: 24));
    fakeApi.inviteToReturn = Invitation(
      invitationId: 'inv-1',
      code: 'SP-4K9X',
      linkToken: 'opaque-link-token',
      expiresAt: expiry,
    );

    await container.read(familyControllerProvider.notifier).generateInvite('fam-1');

    final state = container.read(familyControllerProvider).value!;
    expect(state.latestInvite?.code, 'SP-4K9X');
    expect(state.latestInvite?.linkToken, 'opaque-link-token');
    expect(state.latestInvite?.expiresAt, expiry);
    expect(state.pendingInvites, hasLength(1));
    expect(fakeApi.lastGenerateInviteFamilyId, 'fam-1');
  });

  test('redeemInvite(accept: true) joins the circle and loads its members', () async {
    fakeApi.redeemResultToReturn = const RedeemResult(
      familyId: 'fam-2',
      status: 'Accepted',
      accepted: true,
    );
    fakeApi.membersByFamilyId['fam-2'] = [
      _member(memberId: 'mem-1', userId: 'guardian-user', role: Role.guardian),
      _member(memberId: 'mem-2', userId: 'invitee-user', role: Role.member),
    ];

    await container.read(familyControllerProvider.notifier).redeemInvite(
          code: 'SP-4K9X',
          accept: true,
        );

    final state = container.read(familyControllerProvider).value!;
    expect(state.family?.id, 'fam-2');
    expect(state.members, hasLength(2));
    expect(fakeApi.lastRedeemAccept, isTrue);
  });

  test('redeemInvite(accept: false) declines and does not join a circle', () async {
    fakeApi.redeemResultToReturn = const RedeemResult(
      familyId: 'fam-2',
      status: 'Declined',
      accepted: false,
    );

    await container.read(familyControllerProvider.notifier).redeemInvite(
          code: 'SP-4K9X',
          accept: false,
        );

    final state = container.read(familyControllerProvider).value!;
    expect(state.family, isNull);
    expect(state.members, isEmpty);
    expect(fakeApi.lastRedeemAccept, isFalse);
  });

  test('updatePermission reflects the new level in state', () async {
    fakeApi.membersByFamilyId['fam-1'] = [
      _member(memberId: 'mem-2', userId: 'invitee-user'),
    ];
    await container.read(familyControllerProvider.notifier).createCircle('The Rivera Family');
    // Seed state with the target member (createCircle only loads what
    // listMembers returns for the newly-created family, so overwrite it
    // directly here to exercise updatePermission in isolation).
    fakeApi.updatePermissionOverride = PermissionLevel.fullLocation;

    await container.read(familyControllerProvider.notifier).updatePermission(
          'fam-1',
          'mem-2',
          PermissionLevel.fullLocation,
        );

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
    await container.read(familyControllerProvider.notifier).createCircle('The Rivera Family');

    await container.read(familyControllerProvider.notifier).removeMember('fam-1', 'mem-2');

    final state = container.read(familyControllerProvider).value!;
    expect(state.members.map((m) => m.memberId), ['mem-1']);
    expect(fakeApi.lastRemoveMemberId, 'mem-2');
  });

  test(
    'a failed authorization (non-Guardian) surfaces an error without mutating state',
    () async {
      fakeApi.membersByFamilyId['fam-1'] = [
        _member(memberId: 'mem-1', userId: 'guardian-user', role: Role.guardian),
        _member(memberId: 'mem-2', userId: 'invitee-user'),
      ];
      await container.read(familyControllerProvider.notifier).createCircle('The Rivera Family');
      final beforeMembers = container.read(familyControllerProvider).value!.members;

      fakeApi.shouldDenyAsForbidden = true;
      await container.read(familyControllerProvider.notifier).updatePermission(
            'fam-1',
            'mem-2',
            PermissionLevel.fullLocation,
          );

      final state = container.read(familyControllerProvider).value!;
      expect(state.error, isNotNull);
      expect(state.members, beforeMembers);
      expect(
        state.members.firstWhere((m) => m.memberId == 'mem-2').permission,
        PermissionLevel.viewOnly,
      );
    },
  );
}
