import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';

class AccountRepository {
  AccountRepository(this._dio);

  final Dio _dio;

  Future<Map<String, dynamic>> exportData() async {
    final resp = await _dio.get('/auth/me/export');
    return resp.data as Map<String, dynamic>;
  }

  /// Cascade-deletes every row tied to this account, immediately and
  /// irreversibly. The caller is expected to have its own confirmation
  /// step before calling this.
  Future<void> deleteAccount() async {
    await _dio.delete('/auth/me');
  }
}

final accountRepositoryProvider = Provider<AccountRepository>((ref) => AccountRepository(ref.watch(dioProvider)));
