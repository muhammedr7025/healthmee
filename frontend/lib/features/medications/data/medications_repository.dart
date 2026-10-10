import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../domain/medication.dart';

class MedicationsRepository {
  MedicationsRepository(this._dio);

  final Dio _dio;

  Future<List<MedicationSchedule>> fetchSchedules() async {
    final resp = await _dio.get('/medications');
    return (resp.data as List).map((m) => MedicationSchedule.fromJson(m as Map<String, dynamic>)).toList();
  }

  Future<MedicationSchedule> addSchedule({
    required String name,
    String? dose,
    required List<String> times,
    List<int>? daysOfWeek,
  }) async {
    final resp = await _dio.post('/medications', data: {
      'name': name,
      'dose': ?dose,
      'times': times,
      'days_of_week': ?daysOfWeek,
    });
    return MedicationSchedule.fromJson(resp.data as Map<String, dynamic>);
  }

  Future<void> deleteSchedule(String id) async {
    await _dio.delete('/medications/$id');
  }

  Future<MedicationDayPlan> fetchToday() async {
    final resp = await _dio.get('/medications/today');
    return MedicationDayPlan.fromJson(resp.data as Map<String, dynamic>);
  }

  /// Marks one slot taken / skipped / back to pending. Returns the day's
  /// refreshed plan.
  Future<MedicationDayPlan> markDose(String scheduleId, {required String time, required String status, DateTime? date}) async {
    final resp = await _dio.post('/medications/$scheduleId/doses', data: {
      'time': time,
      'status': status,
      'date': ?date?.toIso8601String().split('T').first,
    });
    return MedicationDayPlan.fromJson(resp.data as Map<String, dynamic>);
  }
}

final medicationsRepositoryProvider = Provider<MedicationsRepository>((ref) => MedicationsRepository(ref.watch(dioProvider)));

final medicationsTodayProvider = FutureProvider.autoDispose<MedicationDayPlan>((ref) {
  return ref.watch(medicationsRepositoryProvider).fetchToday();
});

final medicationSchedulesProvider = FutureProvider.autoDispose<List<MedicationSchedule>>((ref) {
  return ref.watch(medicationsRepositoryProvider).fetchSchedules();
});
