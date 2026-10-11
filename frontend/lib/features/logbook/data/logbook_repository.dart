import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../auth/presentation/auth_controller.dart';
import '../domain/log_entry.dart';

class LogbookRepository {
  LogbookRepository(this._dio);

  final Dio _dio;

  Future<List<LogEntryView>> fetchEntries({String? type, DateTime? start, DateTime? end, int page = 1, int perPage = 50}) async {
    final params = <String, dynamic>{'page': page, 'per_page': perPage};
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

  /// Field-level correction. The server re-validates the payload against
  /// the type and recomputes the day; the updated entry comes back.
  Future<LogEntryView> updateEntry(String entryId, {Map<String, dynamic>? payload, String? summary}) async {
    final resp = await _dio.patch('/log-entries/$entryId', data: {
      'payload': ?payload,
      'summary': ?summary,
    });
    return LogEntryView.fromJson(resp.data as Map<String, dynamic>);
  }

  Future<void> deleteEntry(String entryId) async {
    await _dio.delete('/log-entries/$entryId');
  }
}

final logbookRepositoryProvider = Provider<LogbookRepository>((ref) => LogbookRepository(ref.watch(dioProvider)));

// Each of these resets when a different account signs in.
final logbookTypeFilterProvider = StateProvider<String?>((ref) {
  ref.watch(currentUserIdProvider);
  return null;
});

/// timeline | vitals | labs | symptoms — Vitals and Symptoms are fixed type
/// views; Timeline honours the chip filter; Labs reads lab results instead.
final logbookTabProvider = StateProvider<String>((ref) {
  ref.watch(currentUserIdProvider);
  return 'timeline';
});

/// The day being looked at, or null for every day.
final logbookDayProvider = StateProvider<DateTime?>((ref) {
  ref.watch(currentUserIdProvider);
  return null;
});

/// One page of the logbook plus whether older rows exist.
class LogbookPage {
  const LogbookPage({required this.items, required this.hasMore, this.loadingMore = false});
  final List<LogEntryView> items;
  final bool hasMore;
  final bool loadingMore;

  LogbookPage copyWith({List<LogEntryView>? items, bool? hasMore, bool? loadingMore}) =>
      LogbookPage(items: items ?? this.items, hasMore: hasMore ?? this.hasMore, loadingMore: loadingMore ?? this.loadingMore);
}

/// Loads the logbook 50 rows at a time for the current tab/day/filter;
/// "All days" used to fetch a person's entire history in one request.
class LogbookPager extends StateNotifier<AsyncValue<LogbookPage>> {
  LogbookPager(this._repo, {this.type, this.start, this.end}) : super(const AsyncLoading()) {
    _loadFirst();
  }

  static const perPage = 50;
  final LogbookRepository _repo;
  final String? type;
  final DateTime? start;
  final DateTime? end;
  int _page = 1;

  Future<void> _loadFirst() async {
    try {
      _page = 1;
      final items = await _repo.fetchEntries(type: type, start: start, end: end, page: 1, perPage: perPage);
      state = AsyncData(LogbookPage(items: items, hasMore: items.length == perPage));
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<void> refresh() => _loadFirst();

  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || !current.hasMore || current.loadingMore) return;
    state = AsyncData(current.copyWith(loadingMore: true));
    try {
      final more = await _repo.fetchEntries(type: type, start: start, end: end, page: _page + 1, perPage: perPage);
      _page += 1;
      state = AsyncData(LogbookPage(items: [...current.items, ...more], hasMore: more.length == perPage));
    } catch (_) {
      state = AsyncData(current.copyWith(loadingMore: false));
    }
  }
}

final logbookPagerProvider = StateNotifierProvider.autoDispose<LogbookPager, AsyncValue<LogbookPage>>((ref) {
  final tab = ref.watch(logbookTabProvider);
  final type = switch (tab) {
    'vitals' => 'vital',
    'symptoms' => 'symptom',
    _ => ref.watch(logbookTypeFilterProvider),
  };
  final day = ref.watch(logbookDayProvider);
  final start = day == null ? null : DateTime(day.year, day.month, day.day);
  final end = start?.add(const Duration(days: 1)).subtract(const Duration(milliseconds: 1));
  return LogbookPager(ref.watch(logbookRepositoryProvider), type: type, start: start, end: end);
});

final todayEntriesProvider = FutureProvider.autoDispose<List<LogEntryView>>((ref) {
  final now = DateTime.now();
  final startOfDay = DateTime(now.year, now.month, now.day);
  return ref.watch(logbookRepositoryProvider).fetchEntries(start: startOfDay);
});
