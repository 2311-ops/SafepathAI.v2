import 'package:mobile/features/family/data/family_api.dart';
import 'package:mobile/features/family/data/family_models.dart';

class FakeFamilyApi implements FamilyApi {
  bool getMyFamiliesShouldThrow = false;
  List<MyFamily> myFamiliesToReturn = const [];
  Map<String, List<FamilyMemberView>> membersByFamilyId = {};
  Invitation? inviteToReturn;
  RedeemResult? redeemResultToReturn;
  FamilyApiException? redeemError;
  FamilyApiException? generateInviteError;

  int getMyFamiliesCallCount = 0;
  int generateInviteCallCount = 0;
  int redeemCallCount = 0;
  int listMembersCallCount = 0;
  String? lastGenerateInviteFamilyId;
  String? lastGenerateInviteLabel;
  String? lastRedeemCode;
  String? lastRedeemLinkToken;
  bool? lastRedeemAccept;

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
  Future<Family> createFamily(String name) async =>
      Family(id: 'fam-1', name: name);

  @override
  Future<List<FamilyMemberView>> listMembers(String familyId) async {
    listMembersCallCount++;
    return membersByFamilyId[familyId] ?? const [];
  }

  @override
  Future<Invitation> generateInvite(
    String familyId, {
    String? inviteeLabel,
  }) async {
    generateInviteCallCount++;
    lastGenerateInviteFamilyId = familyId;
    lastGenerateInviteLabel = inviteeLabel;
    final error = generateInviteError;
    if (error != null) throw error;
    return inviteToReturn!;
  }

  @override
  Future<RedeemResult> redeemInvite({
    String? code,
    String? linkToken,
    required bool accept,
  }) async {
    redeemCallCount++;
    lastRedeemCode = code;
    lastRedeemLinkToken = linkToken;
    lastRedeemAccept = accept;
    final error = redeemError;
    if (error != null) throw error;
    return redeemResultToReturn!;
  }

  @override
  Future<PermissionLevel> updatePermission(
    String familyId,
    String memberId,
    PermissionLevel level,
  ) async => level;

  @override
  Future<void> removeMember(String familyId, String memberId) async {}
}
