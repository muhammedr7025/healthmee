import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../domain/generated_report.dart';

class ReportsRepository {
  ReportsRepository(this._dio);

  final Dio _dio;

  Future<List<GeneratedReport>> listReports() async {
    final resp = await _dio.get('/reports');
    return (resp.data as List).map((r) => GeneratedReport.fromJson(r as Map<String, dynamic>)).toList();
  }

  /// Generates a real PDF from the account's real data in [start, end] and
  /// returns it with a fresh (7-day) download URL.
  Future<GeneratedReport> generate({DateTime? start, DateTime? end}) async {
    final resp = await _dio.post('/reports/generate', data: {
      'start': ?start?.toIso8601String().split('T').first,
      'end': ?end?.toIso8601String().split('T').first,
    });
    return GeneratedReport.fromJson(resp.data as Map<String, dynamic>);
  }

  /// Re-presigns a fresh download link for a report generated earlier.
  Future<GeneratedReport> refreshDownloadUrl(String reportId) async {
    final resp = await _dio.get('/reports/$reportId');
    return GeneratedReport.fromJson(resp.data as Map<String, dynamic>);
  }

  Future<void> revoke(String reportId) async {
    await _dio.delete('/reports/$reportId');
  }
}

final reportsRepositoryProvider = Provider<ReportsRepository>((ref) => ReportsRepository(ref.watch(dioProvider)));

final reportsListProvider = FutureProvider.autoDispose<List<GeneratedReport>>((ref) {
  return ref.watch(reportsRepositoryProvider).listReports();
});
