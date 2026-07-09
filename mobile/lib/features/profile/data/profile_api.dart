import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';
import 'user_profile.dart';

enum ProfileApiIssue { unauthenticated, network, unknown }

class ProfileApiException implements Exception {
  ProfileApiException(this.issue, {this.message});

  final ProfileApiIssue issue;
  final String? message;

  @override
  String toString() => 'ProfileApiException(issue: $issue, message: $message)';
}

abstract class ProfileApi {
  Future<UserProfile> getMe();
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

  ProfileApiException _mapError(DioException error) {
    final status = error.response?.statusCode;
    if (status == 401 || status == 403) {
      return ProfileApiException(
        ProfileApiIssue.unauthenticated,
        message: 'Your session expired. Please log in again.',
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
}

final profileApiProvider = Provider<ProfileApi>(
  (ref) => DioProfileApi(ref.watch(dioProvider)),
);
