import 'package:dio/dio.dart';

import '../storage/token_storage.dart';

/// Attaches the bearer access token to every outgoing request and performs
/// at most one refresh-retry on a 401 response.
///
/// - onRequest: attaches `Authorization: Bearer <access>` from [TokenStorage]
///   when a token is present.
/// - onError (401 only): calls `POST /auth/refresh` with the stored refresh
///   token via a plain [Dio] instance (no interceptors — avoids recursing
///   back into this interceptor), saves the rotated token pair on success,
///   and retries the original request exactly once. On refresh failure,
///   clears [TokenStorage] and lets the 401 propagate so the app can route
///   to login.
class AuthInterceptor extends Interceptor {
  AuthInterceptor({required this.tokenStorage, required this.refreshDio});

  final TokenStorage tokenStorage;

  /// A plain [Dio] instance (no interceptors attached) used only for the
  /// `/auth/refresh` call, so this interceptor never recurses into itself.
  final Dio refreshDio;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final accessToken = await tokenStorage.readAccessToken();
    if (accessToken != null) {
      options.headers['Authorization'] = 'Bearer $accessToken';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final isUnauthorized = err.response?.statusCode == 401;
    final alreadyRetried = err.requestOptions.extra['sp_retried'] == true;

    if (!isUnauthorized || alreadyRetried) {
      handler.next(err);
      return;
    }

    final refreshToken = await tokenStorage.readRefreshToken();
    if (refreshToken == null) {
      await tokenStorage.clear();
      handler.next(err);
      return;
    }

    try {
      final response = await refreshDio.post<Map<String, dynamic>>(
        '/auth/refresh',
        data: {'refreshToken': refreshToken},
      );

      final data = response.data;
      final newAccess = data?['accessToken'] as String?;
      final newRefresh = data?['refreshToken'] as String?;

      if (newAccess == null || newRefresh == null) {
        await tokenStorage.clear();
        handler.next(err);
        return;
      }

      await tokenStorage.saveTokens(access: newAccess, refresh: newRefresh);

      final retryOptions = err.requestOptions
        ..headers['Authorization'] = 'Bearer $newAccess'
        ..extra['sp_retried'] = true;

      final retryResponse = await refreshDio.fetch<dynamic>(retryOptions);
      handler.resolve(retryResponse);
    } on DioException {
      await tokenStorage.clear();
      handler.next(err);
    }
  }
}
