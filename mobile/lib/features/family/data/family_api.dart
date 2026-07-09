import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';
import 'family_models.dart';

enum FamilyApiIssue {
  /// The caller is authenticated but not authorized for this action (e.g. a
  /// non-Guardian trying to update permissions) — the server-side
  /// `FamilyAuthorizationService` denied the request (T-07-01).
  forbidden,
  notFound,
  validation,
  network,
  unknown,
}

class FamilyApiException implements Exception {
  FamilyApiException(this.issue, {this.message});

  final FamilyApiIssue issue;
  final String? message;

  @override
  String toString() => 'FamilyApiException(issue: $issue, message: $message)';
}

/// Client for the plan-05 `/families` and `/invites` backend endpoints
/// (`FamiliesController`/`InvitesController`). Abstracted behind an interface
/// (mirroring `auth_api.dart`'s `AuthApi` pattern) so `FamilyController` can
/// be unit-tested against a fake without a real Dio/HTTP round-trip.
abstract class FamilyApi {
  /// `GET /families/mine` — the caller's own active family memberships,
  /// used to restore [Family]/[FamilyMemberView] state on cold app start or
  /// after logging back in (01-10-PLAN.md, D-10-2). Never 404s — an empty
  /// list means the caller genuinely has no circle yet.
  Future<List<MyFamily>> getMyFamilies();

  /// `POST /families` — creates a circle; the caller becomes its first
  /// Guardian (FAM-01).
  Future<Family> createFamily(String name);

  /// `GET /families/{familyId}/members` — the active member roster
  /// (membership-gated server-side).
  Future<List<FamilyMemberView>> listMembers(String familyId);

  /// `POST /families/{familyId}/invites` — Guardian-only, generates a
  /// 24h-expiring, single-use share-code/QR invite (FAM-02).
  Future<Invitation> generateInvite(String familyId, {String? inviteeLabel});

  /// `POST /invites/redeem` — accept or decline a Pending invite by short
  /// display code or opaque link token (FAM-03).
  Future<RedeemResult> redeemInvite({
    String? code,
    String? linkToken,
    required bool accept,
  });

  /// `PATCH /families/{familyId}/members/{memberId}/permissions` —
  /// Guardian-only (FAM-04).
  Future<PermissionLevel> updatePermission(
    String familyId,
    String memberId,
    PermissionLevel level,
  );

  /// `DELETE /families/{familyId}/members/{memberId}` — Guardian-only,
  /// soft-remove (FAM-05).
  Future<void> removeMember(String familyId, String memberId);
}

class DioFamilyApi implements FamilyApi {
  DioFamilyApi(this._dio);

  final Dio _dio;

  @override
  Future<List<MyFamily>> getMyFamilies() async {
    try {
      final response = await _dio.get<List<dynamic>>('/families/mine');
      return (response.data ?? const [])
          .map((entry) => MyFamily.fromJson(entry as Map<String, dynamic>))
          .toList();
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  @override
  Future<Family> createFamily(String name) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/families',
        data: {'name': name},
      );
      return Family(id: response.data!['familyId'] as String, name: name);
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  @override
  Future<List<FamilyMemberView>> listMembers(String familyId) async {
    try {
      final response = await _dio.get<List<dynamic>>('/families/$familyId/members');
      return (response.data ?? const [])
          .map((entry) => FamilyMemberView.fromJson(entry as Map<String, dynamic>))
          .toList();
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  @override
  Future<Invitation> generateInvite(String familyId, {String? inviteeLabel}) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/families/$familyId/invites',
        data: {'inviteeLabel': inviteeLabel},
      );
      return Invitation.fromJson(response.data!, inviteeLabel: inviteeLabel);
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  @override
  Future<RedeemResult> redeemInvite({
    String? code,
    String? linkToken,
    required bool accept,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/invites/redeem',
        data: {'code': code, 'linkToken': linkToken, 'accept': accept},
      );
      return RedeemResult.fromJson(response.data!);
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  @override
  Future<PermissionLevel> updatePermission(
    String familyId,
    String memberId,
    PermissionLevel level,
  ) async {
    try {
      final response = await _dio.patch<Map<String, dynamic>>(
        '/families/$familyId/members/$memberId/permissions',
        data: {'permissions': level.wireValue},
      );
      return PermissionLevel.fromWire(response.data!['permissions'] as String);
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  @override
  Future<void> removeMember(String familyId, String memberId) async {
    try {
      await _dio.delete<void>('/families/$familyId/members/$memberId');
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  FamilyApiException _mapError(DioException error) {
    final status = error.response?.statusCode;
    if (status == 403) {
      return FamilyApiException(
        FamilyApiIssue.forbidden,
        message: 'Only a Guardian can do that.',
      );
    }
    if (status == 404) {
      return FamilyApiException(FamilyApiIssue.notFound, message: 'Not found.');
    }
    if (status == 400 || status == 409) {
      final data = error.response?.data;
      final serverMessage = data is Map ? data['error'] as String? : null;
      return FamilyApiException(
        FamilyApiIssue.validation,
        message: serverMessage ?? 'That request could not be completed.',
      );
    }
    if (error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout) {
      return FamilyApiException(
        FamilyApiIssue.network,
        message: "Couldn't connect. Check your connection and try again.",
      );
    }
    return FamilyApiException(FamilyApiIssue.unknown, message: error.message);
  }
}

final familyApiProvider = Provider<FamilyApi>(
  (ref) => DioFamilyApi(ref.watch(dioProvider)),
);
