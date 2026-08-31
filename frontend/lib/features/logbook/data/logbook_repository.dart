import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../domain/log_entry.dart';

class LogbookRepository {
  LogbookRepository(this._dio);

  final Dio _dio;

  Future<List<LogEntryView>> fetchEntries({String? type}) async {
    final params = <String, dynamic>{};
    if (type != null) {
      params['type'] = type;
    }
    final resp = await _dio.get('/logbook', queryParameters: params);
    return (resp.data as List).map((e) => LogEntryView.fromJson(e as Map<String, dynamic>)).toList();
  }
}

final logbookRepositoryProvider = Provider<LogbookRepository>((ref) => LogbookRepository(ref.watch(dioProvider)));

final logbookTypeFilterProvider = StateProvider<String?>((ref) => null);

final logbookEntriesProvider = FutureProvider.autoDispose<List<LogEntryView>>((ref) {
  final type = ref.watch(logbookTypeFilterProvider);
  return ref.watch(logbookRepositoryProvider).fetchEntries(type: type);
});
