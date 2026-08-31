import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// JWT token persistence — kept out of the Dio layer so the interceptor and
/// the auth feature both read/write through one place.
class AuthStorage {
  AuthStorage() : _storage = const FlutterSecureStorage();

  final FlutterSecureStorage _storage;
  static const _tokenKey = 'access_token';

  Future<String?> readToken() => _storage.read(key: _tokenKey);

  Future<void> saveToken(String token) => _storage.write(key: _tokenKey, value: token);

  Future<void> clearToken() => _storage.delete(key: _tokenKey);
}
