import '../../auth/data/auth_models.dart';

/// Mirrors the backend `Domain.Enums.PermissionLevel` wire values (plan 05:
/// `SafePath.Domain.Enums.PermissionLevel`). Governs how much of a member's
/// location/activity is visible to the rest of the circle.
enum PermissionLevel {
  viewOnly('ViewOnly'),
  fullLocation('FullLocation'),
  notificationOnly('NotificationOnly');

  const PermissionLevel(this.wireValue);

  final String wireValue;

  static PermissionLevel fromWire(String value) => PermissionLevel.values.firstWhere(
        (level) => level.wireValue == value,
        orElse: () => throw ArgumentError('Unknown permission level: $value'),
      );

  /// Short human label for the permission toggle UI (Manage Permissions
  /// screen).
  String get label => switch (this) {
        PermissionLevel.viewOnly => 'View only',
        PermissionLevel.fullLocation => 'Full location',
        PermissionLevel.notificationOnly => 'Notification only',
      };
}

/// A family circle. [name] is only known client-side when this device
/// created the circle (echoed back from the create request) or joined it
/// during this session — the plan-05 backend has no `GET /families/{id}`
/// endpoint that returns the circle's name, so a redeemed invite's circle
/// name is intentionally nullable (see 01-07-SUMMARY.md deviations).
class Family {
  const Family({required this.id, this.name});

  final String id;
  final String? name;
}

/// A member row within a family circle, as returned by
/// `GET /families/{familyId}/members` (`FamilyMemberDto`).
class FamilyMemberView {
  const FamilyMemberView({
    required this.memberId,
    required this.userId,
    required this.role,
    required this.permission,
    required this.joinedAt,
  });

  final String memberId;
  final String userId;
  final Role role;
  final PermissionLevel permission;
  final DateTime joinedAt;

  factory FamilyMemberView.fromJson(Map<String, dynamic> json) => FamilyMemberView(
        memberId: json['id'] as String,
        userId: json['userId'] as String,
        role: Role.fromWire(json['role'] as String),
        permission: PermissionLevel.fromWire(json['permissions'] as String),
        joinedAt: DateTime.parse(json['joinedAt'] as String),
      );

  FamilyMemberView copyWith({PermissionLevel? permission}) => FamilyMemberView(
        memberId: memberId,
        userId: userId,
        role: role,
        permission: permission ?? this.permission,
        joinedAt: joinedAt,
      );
}

/// A share-code/QR invite, as returned by `POST /families/{familyId}/invites`
/// (`GenerateInviteResult`). [inviteeLabel] is the guardian-entered label for
/// the pending list — it is not part of the server response (D3), so it is
/// carried alongside the response client-side.
class Invitation {
  const Invitation({
    required this.invitationId,
    required this.code,
    required this.linkToken,
    required this.expiresAt,
    this.inviteeLabel,
  });

  final String invitationId;
  final String code;
  final String linkToken;
  final DateTime expiresAt;
  final String? inviteeLabel;

  factory Invitation.fromJson(Map<String, dynamic> json, {String? inviteeLabel}) => Invitation(
        invitationId: json['invitationId'] as String,
        code: json['code'] as String,
        linkToken: json['linkToken'] as String,
        expiresAt: DateTime.parse(json['expiresAt'] as String).toLocal(),
        inviteeLabel: inviteeLabel,
      );
}

/// One of the caller's own active family memberships, as returned by
/// `GET /families/mine` (`MyFamilyDto`) — unlike [FamilyMemberView], this is
/// keyed by the caller's own membership row, not another member's. Used to
/// restore [Family]/[FamilyMemberView] state after logout/login or a cold
/// app start, since the plan-05 backend has no other way to discover a
/// family the current session didn't just create or join (01-10-PLAN.md).
class MyFamily {
  const MyFamily({
    required this.familyId,
    required this.familyName,
    required this.role,
    required this.permissions,
  });

  final String familyId;
  final String familyName;
  final Role role;
  final PermissionLevel permissions;

  factory MyFamily.fromJson(Map<String, dynamic> json) => MyFamily(
        familyId: json['familyId'] as String,
        familyName: json['familyName'] as String,
        role: Role.fromWire(json['role'] as String),
        permissions: PermissionLevel.fromWire(json['permissions'] as String),
      );
}

/// Result of `POST /invites/redeem` (`RedeemInviteResult`). [accepted] is a
/// convenience derived from [status] so callers don't need to compare the
/// raw wire string.
class RedeemResult {
  const RedeemResult({
    required this.familyId,
    required this.status,
    required this.accepted,
  });

  final String familyId;
  final String status;
  final bool accepted;

  factory RedeemResult.fromJson(Map<String, dynamic> json) => RedeemResult(
        familyId: json['familyId'] as String,
        status: json['status'] as String,
        accepted: json['status'] == 'Accepted',
      );
}
