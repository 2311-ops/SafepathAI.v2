import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';

enum EmergencyContactApiIssue { forbidden, notFound, validation, network, unknown }

class EmergencyContactApiException implements Exception {
  EmergencyContactApiException(this.issue, {this.message});

  final EmergencyContactApiIssue issue;
  final String? message;

  @override
  String toString() =>
      'EmergencyContactApiException(issue: $issue, message: $message)';
}

/// Mirrors `backend/src/SafePath.Application/Sos/SosDtos.cs`'s
/// `EmergencyContactDto` — the only DTO in the codebase carrying a phone
/// number; returned exclusively from `/me/emergency-contacts` for the
/// contact's own owning user (threat T-03-03).
class EmergencyContact {
  const EmergencyContact({
    required this.id,
    required this.displayName,
    required this.phoneNumberE164,
    required this.isActive,
  });

  final String id;
  final String displayName;
  final String phoneNumberE164;
  final bool isActive;

  factory EmergencyContact.fromJson(Map<String, dynamic> json) {
    return EmergencyContact(
      id: json['id'] as String,
      displayName: (json['displayName'] as String?) ?? '',
      phoneNumberE164: (json['phoneNumberE164'] as String?) ?? '',
      isActive: json['isActive'] as bool? ?? true,
    );
  }
}

/// Client for plan 03-05's `EmergencyContactsController`. Phone-number
/// validation/normalisation is the server's job (`PhoneNumberNormalizer`,
/// libphonenumber-csharp) — this client only ever surfaces the server's
/// rejection message, never a second, divergent client-side phone regex.
abstract class EmergencyContactApi {
  /// `GET /me/emergency-contacts` — the caller's own active contacts only.
  Future<List<EmergencyContact>> list();

  /// `POST /me/emergency-contacts`. [region] is a default-region hint (e.g.
  /// derived from the device locale) for normalising a national-format
  /// number — the server is still the sole authority on validity.
  Future<EmergencyContact> add(String name, String phoneNumber, String? region);

  /// `PUT /me/emergency-contacts/{contactId}`.
  Future<EmergencyContact> update(
    String contactId,
    String name,
    String phoneNumber,
    String? region,
  );

  /// `DELETE /me/emergency-contacts/{contactId}` — soft-deactivates
  /// server-side; the caller only needs to know the call succeeded.
  Future<void> delete(String contactId);
}

class DioEmergencyContactApi implements EmergencyContactApi {
  DioEmergencyContactApi(this._dio);

  final Dio _dio;

  @override
  Future<List<EmergencyContact>> list() async {
    try {
      final response = await _dio.get<List<dynamic>>('/me/emergency-contacts');
      return (response.data ?? const [])
          .whereType<Map>()
          .map(
            (entry) =>
                EmergencyContact.fromJson(Map<String, dynamic>.from(entry)),
          )
          .toList();
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  @override
  Future<EmergencyContact> add(
    String name,
    String phoneNumber,
    String? region,
  ) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/me/emergency-contacts',
        data: {'displayName': name, 'phoneNumber': phoneNumber, 'region': region},
      );
      return EmergencyContact.fromJson(response.data ?? const {});
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  @override
  Future<EmergencyContact> update(
    String contactId,
    String name,
    String phoneNumber,
    String? region,
  ) async {
    try {
      final response = await _dio.put<Map<String, dynamic>>(
        '/me/emergency-contacts/$contactId',
        data: {'displayName': name, 'phoneNumber': phoneNumber, 'region': region},
      );
      return EmergencyContact.fromJson(response.data ?? const {});
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  @override
  Future<void> delete(String contactId) async {
    try {
      await _dio.delete<Map<String, dynamic>>('/me/emergency-contacts/$contactId');
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  EmergencyContactApiException _mapError(DioException error) {
    final status = error.response?.statusCode;
    if (status == 403) {
      return EmergencyContactApiException(
        EmergencyContactApiIssue.forbidden,
        message: 'You cannot manage that contact.',
      );
    }
    if (status == 404) {
      return EmergencyContactApiException(
        EmergencyContactApiIssue.notFound,
        message: 'That contact was not found.',
      );
    }
    if (status == 400 || status == 409) {
      final data = error.response?.data;
      final serverMessage = data is Map ? data['error'] as String? : null;
      return EmergencyContactApiException(
        EmergencyContactApiIssue.validation,
        message: serverMessage ?? 'That request could not be completed.',
      );
    }
    if (error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout) {
      return EmergencyContactApiException(
        EmergencyContactApiIssue.network,
        message: "Couldn't connect. Check your connection and try again.",
      );
    }
    return EmergencyContactApiException(
      EmergencyContactApiIssue.unknown,
      message: error.message,
    );
  }
}

final emergencyContactApiProvider = Provider<EmergencyContactApi>(
  (ref) => DioEmergencyContactApi(ref.watch(dioProvider)),
);
