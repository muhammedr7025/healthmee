import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../today/domain/daily_aggregate.dart';

class TrendsData {
  const TrendsData({required this.days, required this.callouts});

  final List<DailyAggregate> days;
  final List<String> callouts;

  factory TrendsData.fromJson(Map<String, dynamic> json) => TrendsData(
        days: (json['days'] as List).map((d) => DailyAggregate.fromJson(d as Map<String, dynamic>)).toList(),
        callouts: List<String>.from(json['callouts'] as List? ?? []),
      );
}

class TrendsRepository {
  TrendsRepository(this._dio);

  final Dio _dio;

  Future<TrendsData> fetchTrends() async {
    final resp = await _dio.get('/trends');
    return TrendsData.fromJson(resp.data as Map<String, dynamic>);
  }
}

final trendsRepositoryProvider = Provider<TrendsRepository>((ref) => TrendsRepository(ref.watch(dioProvider)));

final trendsDataProvider = FutureProvider.autoDispose<TrendsData>((ref) {
  return ref.watch(trendsRepositoryProvider).fetchTrends();
});
