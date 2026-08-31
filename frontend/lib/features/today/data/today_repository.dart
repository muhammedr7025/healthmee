import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../domain/daily_aggregate.dart';

class TodayRepository {
  TodayRepository(this._dio);

  final Dio _dio;

  Future<DailyAggregate> fetchToday() async {
    final resp = await _dio.get('/today');
    return DailyAggregate.fromJson(resp.data as Map<String, dynamic>);
  }
}

final todayRepositoryProvider = Provider<TodayRepository>((ref) => TodayRepository(ref.watch(dioProvider)));

final todayAggregateProvider = FutureProvider.autoDispose<DailyAggregate>((ref) {
  return ref.watch(todayRepositoryProvider).fetchToday();
});
