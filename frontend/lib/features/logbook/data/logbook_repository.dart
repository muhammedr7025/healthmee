import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../domain/log_entry.dart';

class LogbookRepository {
  LogbookRepository(this._dio);

  final Dio _dio;

  Future<List<LogEntryView>> fetchEntries({String? type, DateTime? start, DateTime? end}) async {
    final params = <String, dynamic>{};
    if (type != null) params['type'] = type;
    if (start != null) params['start'] = start.toIso8601String();
    if (end != null) params['end'] = end.toIso8601String();
    final resp = await _dio.get('/logbook', queryParameters: params);
    return (resp.data as List).map((e) => LogEntryView.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> editEntrySummary(String entryId, String summary) async {
    await _dio.patch('/log-entries/$entryId', data: {'summary': summary});
  }

  Future<void> deleteEntry(String entryId) async {
    await _dio.delete('/log-entries/$entryId');
  }
}

final logbookRepositoryProvider = Provider<LogbookRepository>((ref) => LogbookRepository(ref.watch(dioProvider)));

final logbookTypeFilterProvider = StateProvider<String?>((ref) => null);

final logbookEntriesProvider = FutureProvider.autoDispose<List<LogEntryView>>((ref) {
  final type = ref.watch(logbookTypeFilterProvider);
  return ref.watch(logbookRepositoryProvider).fetchEntries(type: type);
});

final todayEntriesProvider = FutureProvider.autoDispose<List<LogEntryView>>((ref) {
  final now = DateTime.now();
  final startOfDay = DateTime(now.year, now.month, now.day);
  return ref.watch(logbookRepositoryProvider).fetchEntries(start: startOfDay);
});
