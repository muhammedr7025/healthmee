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
    // Sent as UTC with the Z suffix: a local time without an offset would be
    // read by the server as UTC, shifting "today" by the user's whole offset.
    if (start != null) params['start'] = start.toUtc().toIso8601String();
    if (end != null) params['end'] = end.toUtc().toIso8601String();
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

/// timeline | vitals | labs | symptoms — Vitals and Symptoms are fixed type
/// views; Timeline honours the chip filter; Labs reads lab results instead.
final logbookTabProvider = StateProvider<String>((ref) => 'timeline');

/// The day being looked at, or null for every day.
final logbookDayProvider = StateProvider<DateTime?>((ref) => null);

final logbookEntriesProvider = FutureProvider.autoDispose<List<LogEntryView>>((ref) {
  final tab = ref.watch(logbookTabProvider);
  final type = switch (tab) {
    'vitals' => 'vital',
    'symptoms' => 'symptom',
    _ => ref.watch(logbookTypeFilterProvider),
  };
  final day = ref.watch(logbookDayProvider);
  final start = day == null ? null : DateTime(day.year, day.month, day.day);
  final end = start?.add(const Duration(days: 1)).subtract(const Duration(milliseconds: 1));
  return ref.watch(logbookRepositoryProvider).fetchEntries(type: type, start: start, end: end);
});

final todayEntriesProvider = FutureProvider.autoDispose<List<LogEntryView>>((ref) {
  final now = DateTime.now();
  final startOfDay = DateTime(now.year, now.month, now.day);
  return ref.watch(logbookRepositoryProvider).fetchEntries(start: startOfDay);
});
