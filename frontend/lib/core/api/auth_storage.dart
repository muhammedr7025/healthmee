import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// JWT token persistence — kept out of the Dio layer so the interceptor and
/// the auth feature both read/write through one place.
class AuthStorage {
  AuthStorage() : _storage = const FlutterSecureStorage();

  final FlutterSecureStorage _storage;
  static const _tokenKey = 'access_token';
  static const _refreshKey = 'refresh_token';

  Future<String?> readToken() => _storage.read(key: _tokenKey);
  Future<String?> readRefreshToken() => _storage.read(key: _refreshKey);

  Future<void> saveTokens({required String access, String? refresh}) async {
    await _storage.write(key: _tokenKey, value: access);
    if (refresh != null) await _storage.write(key: _refreshKey, value: refresh);
  }

  /// Kept for callers that only have an access token (tests, older paths).
  Future<void> saveToken(String token) => saveTokens(access: token);

  Future<void> clearToken() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _refreshKey);
  }
}
