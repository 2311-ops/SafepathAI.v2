import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/data/auth_api.dart';
import 'auth_interceptor.dart';

/// Compile-time API base URL — pass `--dart-define=API_BASE_URL=https://...`
/// for staging/production builds. Defaults to a local dev backend.
const String _apiBaseUrlOverride = String.fromEnvironment('API_BASE_URL');

/// Local dev backend URL. Android emulators cannot reach the host machine via
/// `localhost`; `10.0.2.2` is the Android emulator's host loopback alias.
String get apiBaseUrl {
  if (_apiBaseUrlOverride.isNotEmpty) return _apiBaseUrlOverride;
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    return 'http://10.0.2.2:5059';
  }
  return 'http://localhost:5059';
}

/// Builds the app's [Dio] client: attaches [AuthInterceptor] (bearer token +
/// single 401 refresh-retry) backed by Supabase Auth. A separate, plain Dio
/// (no interceptors) is used internally for the refresh call itself so the
/// interceptor never recurses into itself.
Dio buildDio(String baseUrl, {required AuthApi authApi}) {
  final refreshDio = Dio(BaseOptions(baseUrl: baseUrl));

  final dio = Dio(BaseOptions(baseUrl: baseUrl));
  dio.interceptors.add(
    AuthInterceptor(authApi: authApi, refreshDio: refreshDio),
  );
  return dio;
}

/// Riverpod provider exposing the single [Dio] instance for the app.
final dioProvider = Provider<Dio>((ref) {
  final authApi = ref.watch(authApiProvider);
  return buildDio(apiBaseUrl, authApi: authApi);
});
