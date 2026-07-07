import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// The ONLY place SafePath AI persists access/refresh tokens.
///
/// Tokens live exclusively in [FlutterSecureStorage] (Android Keystore /
/// iOS Keychain) — never `shared_preferences` (Pitfall 7 / T-02-01). Do not
/// add any other persistence path for these values.
class TokenStorage {
  TokenStorage({FlutterSecureStorage? secureStorage})
    : _storage = secureStorage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _accessTokenKey = 'sp_access';
  static const _refreshTokenKey = 'sp_refresh';

  Future<void> saveTokens({
    required String access,
    required String refresh,
  }) async {
    await _storage.write(key: _accessTokenKey, value: access);
    await _storage.write(key: _refreshTokenKey, value: refresh);
  }

  Future<String?> readAccessToken() => _storage.read(key: _accessTokenKey);

  Future<String?> readRefreshToken() => _storage.read(key: _refreshTokenKey);

  Future<void> clear() async {
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _refreshTokenKey);
  }
}

/// Riverpod provider exposing the single [TokenStorage] instance for the app.
final tokenStorageProvider = Provider<TokenStorage>((ref) => TokenStorage());
