import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';
import '../../auth/data/auth_models.dart';
import 'user_profile.dart';

enum ProfileApiIssue { unauthenticated, validation, network, unknown }

class ProfileApiException implements Exception {
  ProfileApiException(this.issue, {this.message});

  final ProfileApiIssue issue;
  final String? message;

  @override
  String toString() => 'ProfileApiException(issue: $issue, message: $message)';
}

abstract class ProfileApi {
  Future<UserProfile> getMe();

  Future<UserProfile> updateRole(Role role);

  Future<UserProfile> updateDisplayName(String displayName);

  Future<UserProfile> uploadProfileImage(List<int> bytes, String filename);

  Future<UserProfile> deleteProfileImage();
}

class DioProfileApi implements ProfileApi {
  DioProfileApi(this._dio);

  final Dio _dio;

  @override
  Future<UserProfile> getMe() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/me');
      return UserProfile.fromJson(response.data!);
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  @override
  Future<UserProfile> updateRole(Role role) async {
    try {
      final response = await _dio.patch<Map<String, dynamic>>(
        '/me/role',
        data: {'role': role.wireValue},
      );
      return UserProfile.fromJson(response.data!);
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  @override
  Future<UserProfile> updateDisplayName(String displayName) async {
    try {
      final response = await _dio.patch<Map<String, dynamic>>(
        '/me/display-name',
        data: {'displayName': displayName},
      );
      return UserProfile.fromJson(response.data!);
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  @override
  Future<UserProfile> uploadProfileImage(
    List<int> bytes,
    String filename,
  ) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/me/profile-image',
        data: FormData.fromMap({
          'file': MultipartFile.fromBytes(bytes, filename: filename),
        }),
      );
      return UserProfile.fromJson(response.data!);
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  @override
  Future<UserProfile> deleteProfileImage() async {
    try {
      final response = await _dio.delete<Map<String, dynamic>>(
        '/me/profile-image',
      );
      return UserProfile.fromJson(response.data!);
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  ProfileApiException _mapError(DioException error) {
    final status = error.response?.statusCode;
    if (status == 401 || status == 403) {
      return ProfileApiException(
        ProfileApiIssue.unauthenticated,
        message: 'Your session expired. Please log in again.',
      );
    }
    if (status == 400) {
      return ProfileApiException(
        ProfileApiIssue.validation,
        message:
            _serverError(error) ?? 'That profile update could not be saved.',
      );
    }
    if (error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout) {
      return ProfileApiException(
        ProfileApiIssue.network,
        message: "Couldn't connect. Check your connection and try again.",
      );
    }
    return ProfileApiException(
      ProfileApiIssue.unknown,
      message: error.message ?? 'Unable to load your profile.',
    );
  }

  String? _serverError(DioException error) {
    final data = error.response?.data;
    if (data is Map) {
      final message = data['error'];
      if (message is String && message.trim().isNotEmpty) {
        return message;
      }
    }
    return null;
  }
}

final profileApiProvider = Provider<ProfileApi>(
  (ref) => DioProfileApi(ref.watch(dioProvider)),
);
