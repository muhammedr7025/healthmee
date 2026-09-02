import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';

class NotificationPreferences {
  const NotificationPreferences({
    required this.medicationReminders,
    required this.quietNudges,
    required this.streakMilestones,
  });

  final bool medicationReminders;
  final bool quietNudges;
  final bool streakMilestones;

  factory NotificationPreferences.fromJson(Map<String, dynamic> json) => NotificationPreferences(
        medicationReminders: json['medication_reminders'] as bool,
        quietNudges: json['quiet_nudges'] as bool,
        streakMilestones: json['streak_milestones'] as bool,
      );
}

class NotificationPreferencesRepository {
  NotificationPreferencesRepository(this._dio);

  final Dio _dio;

  Future<NotificationPreferences> fetch() async {
    final resp = await _dio.get('/notification-preferences');
    return NotificationPreferences.fromJson(resp.data as Map<String, dynamic>);
  }

  Future<void> update({bool? medicationReminders, bool? quietNudges, bool? streakMilestones}) async {
    await _dio.patch('/notification-preferences', data: {
      'medication_reminders': ?medicationReminders,
      'quiet_nudges': ?quietNudges,
      'streak_milestones': ?streakMilestones,
    });
  }
}

final notificationPreferencesRepositoryProvider =
    Provider<NotificationPreferencesRepository>((ref) => NotificationPreferencesRepository(ref.watch(dioProvider)));

final notificationPreferencesProvider = FutureProvider.autoDispose<NotificationPreferences>((ref) {
  return ref.watch(notificationPreferencesRepositoryProvider).fetch();
});
