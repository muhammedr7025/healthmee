import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';

class ReportsRepository {
  ReportsRepository(this._dio);

  final Dio _dio;

  /// Always fails today (backend returns 501 — PDF export is Phase 2).
  /// Surfaces the server's real message rather than a canned client string.
  Future<void> requestExport() async {
    await _dio.get('/reports');
  }
}

final reportsRepositoryProvider = Provider<ReportsRepository>((ref) => ReportsRepository(ref.watch(dioProvider)));
