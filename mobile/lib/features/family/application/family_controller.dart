import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/family_api.dart';
import '../data/family_models.dart';

/// State held by [FamilyController]: the caller's currently-loaded family
/// circle (if any this session), its members, the invite most recently
/// generated (for the Invite screen to render), and the running list of
/// invites generated this session (for the "Pending" list). [error] is a
/// UI-facing message from the last failed action — it is set without
/// touching [family]/[members]/[pendingInvites], so a failed mutation never
/// silently drops previously-loaded data (see `family_controller_test.dart`
/// "non-Guardian authorization failure" case).
class FamilyState {
  const FamilyState({
    this.family,
    this.members = const [],
    this.pendingInvites = const [],
    this.latestInvite,
    this.error,
  });

  final Family? family;
  final List<FamilyMemberView> members;
  final List<Invitation> pendingInvites;
  final Invitation? latestInvite;
  final String? error;

  FamilyState copyWith({
    Family? family,
    List<FamilyMemberView>? members,
    List<Invitation>? pendingInvites,
    Invitation? latestInvite,
    String? error,
    bool clearError = false,
  }) {
    return FamilyState(
      family: family ?? this.family,
      members: members ?? this.members,
      pendingInvites: pendingInvites ?? this.pendingInvites,
      latestInvite: latestInvite ?? this.latestInvite,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Riverpod controller driving the family-circle screens against
/// [FamilyApi] (plan-05 backend). Holds the current family + member list in
/// memory for the app session (the plan-05 backend has no "list my
/// families" endpoint, so there is nothing to restore across a cold app
/// restart yet — see 01-07-SUMMARY.md deviations).
class FamilyController extends AsyncNotifier<FamilyState> {
  @override
  FamilyState build() => const FamilyState();

  FamilyState get _current => state.value ?? const FamilyState();

  /// Creates a circle and loads the caller's own Guardian membership row
  /// (FAM-01).
  Future<void> createCircle(String name) async {
    final api = ref.read(familyApiProvider);
    try {
      final family = await api.createFamily(name);
      final members = await api.listMembers(family.id);
      state = AsyncData(FamilyState(family: family, members: members));
    } on FamilyApiException catch (error) {
      state = AsyncData(_current.copyWith(error: error.message));
    }
  }

  /// Refreshes the member list for [familyId] (e.g. after navigating back to
  /// a screen that shows the roster).
  Future<void> refreshMembers(String familyId) async {
    final api = ref.read(familyApiProvider);
    try {
      final members = await api.listMembers(familyId);
      state = AsyncData(_current.copyWith(members: members, clearError: true));
    } on FamilyApiException catch (error) {
      state = AsyncData(_current.copyWith(error: error.message));
    }
  }

  /// Generates a share-code/QR invite for [familyId] (Guardian-only, FAM-02).
  /// The result is exposed via [FamilyState.latestInvite] for the Invite
  /// screen, and appended to [FamilyState.pendingInvites] for the "Pending"
  /// list.
  Future<void> generateInvite(String familyId, {String? inviteeLabel}) async {
    final api = ref.read(familyApiProvider);
    final current = _current;
    try {
      final invite = await api.generateInvite(familyId, inviteeLabel: inviteeLabel);
      state = AsyncData(current.copyWith(
        latestInvite: invite,
        pendingInvites: [...current.pendingInvites, invite],
        clearError: true,
      ));
    } on FamilyApiException catch (error) {
      state = AsyncData(current.copyWith(error: error.message));
    }
  }

  /// Accepts or declines a Pending invite (FAM-03). On accept, loads the
  /// joined family's member roster; on decline, state is left otherwise
  /// unchanged (the invitee never joins).
  Future<void> redeemInvite({
    String? code,
    String? linkToken,
    required bool accept,
  }) async {
    final api = ref.read(familyApiProvider);
    final current = _current;
    try {
      final result = await api.redeemInvite(code: code, linkToken: linkToken, accept: accept);
      if (!result.accepted) {
        state = AsyncData(current.copyWith(clearError: true));
        return;
      }

      final members = await api.listMembers(result.familyId);
      state = AsyncData(current.copyWith(
        family: Family(id: result.familyId, name: current.family?.name),
        members: members,
        clearError: true,
      ));
    } on FamilyApiException catch (error) {
      state = AsyncData(current.copyWith(error: error.message));
    }
  }

  /// Updates a member's permission level (Guardian-only, FAM-04).
  Future<void> updatePermission(
    String familyId,
    String memberId,
    PermissionLevel level,
  ) async {
    final api = ref.read(familyApiProvider);
    final current = _current;
    try {
      final updated = await api.updatePermission(familyId, memberId, level);
      final members = [
        for (final member in current.members)
          if (member.memberId == memberId) member.copyWith(permission: updated) else member,
      ];
      state = AsyncData(current.copyWith(members: members, clearError: true));
    } on FamilyApiException catch (error) {
      state = AsyncData(current.copyWith(error: error.message));
    }
  }

  /// Removes a member from the circle (Guardian-only, FAM-05).
  Future<void> removeMember(String familyId, String memberId) async {
    final api = ref.read(familyApiProvider);
    final current = _current;
    try {
      await api.removeMember(familyId, memberId);
      final members = current.members.where((member) => member.memberId != memberId).toList();
      state = AsyncData(current.copyWith(members: members, clearError: true));
    } on FamilyApiException catch (error) {
      state = AsyncData(current.copyWith(error: error.message));
    }
  }
}

final familyControllerProvider = AsyncNotifierProvider<FamilyController, FamilyState>(
  FamilyController.new,
);
