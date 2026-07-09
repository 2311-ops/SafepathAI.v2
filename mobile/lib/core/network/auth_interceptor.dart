import 'package:dio/dio.dart';

import '../../features/auth/data/auth_api.dart';

/// Attaches the current Supabase access token to outgoing requests and
/// performs one refresh/retry on a 401 response.
class AuthInterceptor extends Interceptor {
  AuthInterceptor({required this.authApi, required this.refreshDio});

  final AuthApi authApi;

  /// A plain [Dio] instance (no interceptors attached) used for the retry
  /// request so the interceptor never recurses into itself.
  final Dio refreshDio;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final accessToken = authApi.currentSession?.accessToken;
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

    try {
      final refreshResult = await authApi.refreshSession();
      final newAccessToken = authApi.currentSession?.accessToken;

      if (!refreshResult.signedIn || newAccessToken == null) {
        await authApi.logout();
        handler.next(err);
        return;
      }

      final retryOptions = err.requestOptions
        ..headers['Authorization'] = 'Bearer $newAccessToken'
        ..extra['sp_retried'] = true;

      final retryResponse = await refreshDio.fetch<dynamic>(retryOptions);
      handler.resolve(retryResponse);
    } on AuthApiException catch (error) {
      // Only a genuinely dead session (invalid/expired/revoked refresh
      // token) should force a sign-out. A transient failure while
      // refreshing (network timeout, Supabase temporarily unreachable, or
      // any other unexpected error) leaves the existing session intact —
      // the original request simply fails this time, and a later retry
      // (once connectivity returns) can still succeed against the same
      // still-valid session.
      if (error.issue != AuthIssue.network) {
        await authApi.logout();
      }
      handler.next(err);
    } on DioException {
      handler.next(err);
    }
  }
}
