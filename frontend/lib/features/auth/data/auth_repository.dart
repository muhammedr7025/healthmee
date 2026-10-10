import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/auth_storage.dart';
import '../domain/user.dart';

class AuthRepository {
  AuthRepository(this._dio, this._storage);

  final Dio _dio;
  final AuthStorage _storage;

  Future<AppUser> register({required String email, required String password, String? fullName}) async {
    final resp = await _dio.post('/auth/register', data: {
      'email': email,
      'password': password,
      if (fullName != null && fullName.isNotEmpty) 'full_name': fullName,
    });
    return _handleTokenResponse(resp.data as Map<String, dynamic>);
  }

  Future<AppUser> login({required String email, required String password}) async {
    final resp = await _dio.post('/auth/login', data: {'email': email, 'password': password});
    return _handleTokenResponse(resp.data as Map<String, dynamic>);
  }

  Future<AppUser> _handleTokenResponse(Map<String, dynamic> data) async {
    await _storage.saveTokens(access: data['access_token'] as String, refresh: data['refresh_token'] as String?);
    return AppUser.fromJson(data['user'] as Map<String, dynamic>);
  }

  /// Whether a session is stored at all — lets the app tell "signed out"
  /// from "signed in but offline" when the network is down at launch.
  Future<bool> hasStoredSession() async => (await _storage.readToken()) != null;

  Future<AppUser?> currentUser() async {
    final token = await _storage.readToken();
    if (token == null) return null;
    try {
      // The Dio layer refreshes an expired access token transparently; a
      // 401 reaching here means the refresh token is gone too.
      final resp = await _dio.get('/auth/me');
      return AppUser.fromJson(resp.data as Map<String, dynamic>);
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        await _storage.clearToken();
        return null;
      }
      rethrow;
    }
  }

  Future<void> logout() => _storage.clearToken();

  Future<void> requestPasswordReset({required String email}) async {
    await _dio.post('/auth/password/reset-request', data: {'email': email});
  }

  Future<void> confirmPasswordReset({required String email, required String code, required String newPassword}) async {
    await _dio.post('/auth/password/reset-confirm', data: {'email': email, 'code': code, 'new_password': newPassword});
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(dioProvider), ref.watch(authStorageProvider));
});
