import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../domain/goal.dart';

class GoalsRepository {
  GoalsRepository(this._dio);

  final Dio _dio;

  Future<List<Goal>> fetchGoals() async {
    final resp = await _dio.get('/goals');
    return (resp.data as List).map((g) => Goal.fromJson(g as Map<String, dynamic>)).toList();
  }

  Future<void> createGoal({required String type, required Map<String, dynamic> targetValue}) async {
    await _dio.post('/goals', data: {'type': type, 'target_value': targetValue});
  }
}

final goalsRepositoryProvider = Provider<GoalsRepository>((ref) => GoalsRepository(ref.watch(dioProvider)));

final goalsProvider = FutureProvider.autoDispose<List<Goal>>((ref) {
  return ref.watch(goalsRepositoryProvider).fetchGoals();
});
