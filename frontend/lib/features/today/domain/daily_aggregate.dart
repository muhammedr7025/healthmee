class DailyAggregate {
  const DailyAggregate({
    required this.date,
    required this.totalCalories,
    required this.activityMinutes,
    this.sleepHours,
    this.moodScore,
    required this.waterMl,
    required this.logCount,
  });

  final String date;
  final double totalCalories;
  final double activityMinutes;
  final double? sleepHours;
  final double? moodScore;
  final double waterMl;
  final int logCount;

  factory DailyAggregate.fromJson(Map<String, dynamic> json) => DailyAggregate(
        date: json['date'] as String,
        totalCalories: (json['total_calories'] as num).toDouble(),
        activityMinutes: (json['activity_minutes'] as num).toDouble(),
        sleepHours: (json['sleep_hours'] as num?)?.toDouble(),
        moodScore: (json['mood_score'] as num?)?.toDouble(),
        waterMl: (json['water_ml'] as num).toDouble(),
        logCount: json['log_count'] as int,
      );
}
