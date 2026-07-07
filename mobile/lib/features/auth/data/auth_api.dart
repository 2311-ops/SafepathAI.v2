import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';
import 'auth_models.dart';

/// Thrown when a `/auth/*` call fails. [statusCode] and [serverMessage] come
/// from the backend's `AuthResult.Error` field where available (null on a
/// pure network failure, e.g. no connection).
class AuthApiException implements Exception {
  AuthApiException({this.statusCode, this.serverMessage});

  final int? statusCode;
  final String? serverMessage;

  @override
  String toString() => 'AuthApiException(statusCode: $statusCode, '
      'serverMessage: $serverMessage)';
}

/// dio-backed client for the backend's `/auth/*` endpoints (plan 01):
/// `/auth/register`, `/auth/login`, `/auth/logout`, `/auth/refresh`.
class AuthApi {
  AuthApi(this._dio);

  final Dio _dio;

  Future<AuthResponse> register(RegisterRequest request) =>
      _postForAuthResponse('/auth/register', request.toJson());

  Future<AuthResponse> login(LoginRequest request) =>
      _postForAuthResponse('/auth/login', request.toJson());

  Future<AuthResponse> refresh(String refreshToken) => _postForAuthResponse(
    '/auth/refresh',
    {'refreshToken': refreshToken},
  );

  /// Posts the stored refresh token to `/auth/logout` to revoke it
  /// server-side. Callers should clear local [TokenStorage] regardless of
  /// whether this succeeds.
  Future<void> logout(String refreshToken) async {
    try {
      await _dio.post<dynamic>(
        '/auth/logout',
        data: {'refreshToken': refreshToken},
      );
    } on DioException catch (e) {
      throw _toAuthApiException(e);
    }
  }

  Future<AuthResponse> _postForAuthResponse(
    String path,
    Map<String, dynamic> body,
  ) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(path, data: body);
      return AuthResponse.fromJson(response.data!);
    } on DioException catch (e) {
      throw _toAuthApiException(e);
    }
  }

  AuthApiException _toAuthApiException(DioException e) {
    final data = e.response?.data;
    final serverMessage = data is Map ? data['error'] as String? : null;
    return AuthApiException(
      statusCode: e.response?.statusCode,
      serverMessage: serverMessage,
    );
  }
}

/// Riverpod provider exposing the single [AuthApi] instance for the app.
final authApiProvider = Provider<AuthApi>(
  (ref) => AuthApi(ref.watch(dioProvider)),
);
