import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';
import 'privacy_models.dart';

enum PrivacyApiIssue { forbidden, notFound, validation, network, unknown }

class PrivacyApiException implements Exception {
  PrivacyApiException(this.issue, {this.message});

  final PrivacyApiIssue issue;
  final String? message;

  @override
  String toString() => 'PrivacyApiException(issue: $issue, message: $message)';
}

abstract class PrivacyApi {
  /// `GET /families/{familyId}/sharing-matrix`.
  Future<SharingMatrix> getSharingMatrix(String familyId);

  /// `PATCH /families/{familyId}/sharing-preferences`.
  Future<SharingCell> updateSharingPreference(
    String familyId, {
    String? recipientMemberId,
    required SharedDataType dataType,
    required bool isEnabled,
    DateTime? expiresAtUtc,
  });

  /// `GET /privacy/export`.
  Future<String> exportMyData();

  /// `DELETE /privacy/my-data`.
  Future<void> deleteMyData();

  /// `GET /privacy/policy`.
  Future<PrivacyPolicy> getPolicy();
}

class DioPrivacyApi implements PrivacyApi {
  DioPrivacyApi(this._dio);

  final Dio _dio;

  @override
  Future<SharingMatrix> getSharingMatrix(String familyId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/families/$familyId/sharing-matrix',
      );
      return SharingMatrix.fromJson(response.data!);
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  @override
  Future<SharingCell> updateSharingPreference(
    String familyId, {
    String? recipientMemberId,
    required SharedDataType dataType,
    required bool isEnabled,
    DateTime? expiresAtUtc,
  }) async {
    try {
      final response = await _dio.patch<Map<String, dynamic>>(
        '/families/$familyId/sharing-preferences',
        data: {
          'recipientMemberId': recipientMemberId,
          'dataType': dataType.wireValue,
          'isEnabled': isEnabled,
          'expiresAtUtc': expiresAtUtc?.toUtc().toIso8601String(),
        },
      );
      return SharingCell.fromJson(response.data!);
    } on DioException catch (error) {
      throw _mapError(
        error,
        networkMessage:
            "Couldn't save that setting. Check your connection and try again.",
      );
    }
  }

  @override
  Future<String> exportMyData() async {
    try {
      final response = await _dio.get<String>(
        '/privacy/export',
        options: Options(responseType: ResponseType.plain),
      );
      return response.data ?? '{}';
    } on DioException catch (error) {
      throw _mapError(
        error,
        networkMessage: "Couldn't prepare your export. Try again in a moment.",
      );
    }
  }

  @override
  Future<void> deleteMyData() async {
    try {
      await _dio.delete<void>('/privacy/my-data');
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  @override
  Future<PrivacyPolicy> getPolicy() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/privacy/policy');
      return PrivacyPolicy.fromJson(response.data!);
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  PrivacyApiException _mapError(
    DioException error, {
    String networkMessage = "Couldn't connect. Check your connection and try again.",
  }) {
    final status = error.response?.statusCode;
    if (status == 403) {
      return PrivacyApiException(
        PrivacyApiIssue.forbidden,
        message: 'You do not have access to that privacy setting.',
      );
    }
    if (status == 404) {
      return PrivacyApiException(PrivacyApiIssue.notFound, message: 'Not found.');
    }
    if (status == 400 || status == 409) {
      final data = error.response?.data;
      final serverMessage = data is Map ? data['error'] as String? : null;
      return PrivacyApiException(
        PrivacyApiIssue.validation,
        message: serverMessage ?? 'That request could not be completed.',
      );
    }
    if (error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout) {
      return PrivacyApiException(
        PrivacyApiIssue.network,
        message: networkMessage,
      );
    }
    return PrivacyApiException(PrivacyApiIssue.unknown, message: error.message);
  }
}

final privacyApiProvider = Provider<PrivacyApi>(
  (ref) => DioPrivacyApi(ref.watch(dioProvider)),
);
