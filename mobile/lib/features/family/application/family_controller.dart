import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_controller.dart';
import '../../auth/application/auth_state.dart';
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
    this.isLoading = false,
  });

  final Family? family;
  final List<FamilyMemberView> members;
  final List<Invitation> pendingInvites;
  final Invitation? latestInvite;
  final String? error;

  /// True while the auth-triggered bootstrap fetch (`GET /families/mine`,
  /// 01-10-PLAN.md D-10-3) is in flight. Lets `landing_stub_screen.dart`
  /// distinguish "still checking for an existing circle" from "confirmed no
  /// circle yet, show the create-circle prompt" — both look like
  /// `family == null` otherwise.
  final bool isLoading;

  FamilyState copyWith({
    Family? family,
    List<FamilyMemberView>? members,
    List<Invitation>? pendingInvites,
    Invitation? latestInvite,
    String? error,
    bool clearError = false,
    bool? isLoading,
  }) {
    return FamilyState(
      family: family ?? this.family,
      members: members ?? this.members,
      pendingInvites: pendingInvites ?? this.pendingInvites,
      latestInvite: latestInvite ?? this.latestInvite,
      error: clearError ? null : (error ?? this.error),
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

/// Riverpod controller driving the family-circle screens against
/// [FamilyApi] (plan-05 backend). Holds the current family + member list in
/// memory, restored from `GET /families/mine` on cold app start (if a
/// session already exists) and on every fresh login (01-10-PLAN.md D-10-3)
/// — so logging out and back in no longer loses the circle (closes the gap
/// noted in 01-07-SUMMARY.md deviations).
class FamilyController extends AsyncNotifier<FamilyState> {
  @override
  FamilyState build() {
    ref.listen<AuthState>(authControllerProvider, (previous, next) {
      final wasAuthenticated = previous is AuthAuthenticated;
      if (next is AuthAuthenticated && !wasAuthenticated) {
        _bootstrap();
      } else if (next is AuthUnauthenticated) {
        state = const AsyncData(FamilyState());
      }
    });

    if (ref.read(authControllerProvider) is AuthAuthenticated) {
      // Fire-and-forget: must run after build() returns (the framework
      // assigns `state` from this method's return value), so this is
      // scheduled via a microtask rather than awaited here.
      Future.microtask(_bootstrap);
      return const FamilyState(isLoading: true);
    }

    return const FamilyState();
  }

  FamilyState get _current => state.value ?? const FamilyState();

  /// Fetches the caller's own family memberships (`GET /families/mine`) and
  /// restores [FamilyState] from the first one. D-10-1: the schema allows
  /// multiple active memberships, but no screen/flow supports more than one
  /// yet, so only the first is used.
  /// TODO(multi-family): revisit once a family-switcher UI exists.
  Future<void> _bootstrap() async {
    final api = ref.read(familyApiProvider);
    state = AsyncData(_current.copyWith(isLoading: true, clearError: true));
    try {
      final families = await api.getMyFamilies();
      if (families.isEmpty) {
        state = const AsyncData(FamilyState());
        return;
      }

      final mine = families.first;
      final members = await api.listMembers(mine.familyId);
      state = AsyncData(
        FamilyState(
          family: Family(id: mine.familyId, name: mine.familyName),
          members: members,
          isLoading: false,
        ),
      );
    } on FamilyApiException catch (error) {
      state = AsyncData(
        _current.copyWith(isLoading: false, error: error.message),
      );
    }
  }

  Future<void> refresh() => _bootstrap();

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
      final invite = await api.generateInvite(
        familyId,
        inviteeLabel: inviteeLabel,
      );
      state = AsyncData(
        current.copyWith(
          latestInvite: invite,
          pendingInvites: [...current.pendingInvites, invite],
          clearError: true,
        ),
      );
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
      final result = await api.redeemInvite(
        code: code,
        linkToken: linkToken,
        accept: accept,
      );
      if (!result.accepted) {
        state = AsyncData(current.copyWith(clearError: true));
        return;
      }

      final families = await api.getMyFamilies();
      MyFamily? joinedFamily;
      for (final family in families) {
        if (family.familyId == result.familyId) {
          joinedFamily = family;
          break;
        }
      }

      final members = await api.listMembers(result.familyId);
      state = AsyncData(
        current.copyWith(
          family: Family(
            id: result.familyId,
            name: joinedFamily?.familyName ?? current.family?.name,
          ),
          members: members,
          clearError: true,
        ),
      );
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
          if (member.memberId == memberId)
            member.copyWith(permission: updated)
          else
            member,
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
      final members = current.members
          .where((member) => member.memberId != memberId)
          .toList();
      state = AsyncData(current.copyWith(members: members, clearError: true));
    } on FamilyApiException catch (error) {
      state = AsyncData(current.copyWith(error: error.message));
    }
  }
}

final familyControllerProvider =
    AsyncNotifierProvider<FamilyController, FamilyState>(FamilyController.new);
