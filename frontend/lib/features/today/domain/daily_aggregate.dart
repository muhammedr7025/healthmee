class DailyAggregate {
  const DailyAggregate({
    required this.date,
    required this.totalCalories,
    required this.activityMinutes,
    this.sleepHours,
    this.moodScore,
    required this.waterMl,
    required this.logCount,
    this.weightKg,
    this.systolic,
    this.diastolic,
    this.glucoseMgDl,
    this.heartRateBpm,
  });

  final String date;
  final double totalCalories;
  final double activityMinutes;
  final double? sleepHours;
  final double? moodScore;
  final double waterMl;
  final int logCount;

  // Vitals the user told MeMe that day; null when nothing was measured.
  final double? weightKg;
  final double? systolic;
  final double? diastolic;
  final double? glucoseMgDl;
  final double? heartRateBpm;

  factory DailyAggregate.fromJson(Map<String, dynamic> json) => DailyAggregate(
        date: json['date'] as String,
        totalCalories: (json['total_calories'] as num).toDouble(),
        activityMinutes: (json['activity_minutes'] as num).toDouble(),
        sleepHours: (json['sleep_hours'] as num?)?.toDouble(),
        moodScore: (json['mood_score'] as num?)?.toDouble(),
        waterMl: (json['water_ml'] as num).toDouble(),
        logCount: json['log_count'] as int,
        weightKg: (json['weight_kg'] as num?)?.toDouble(),
        systolic: (json['systolic'] as num?)?.toDouble(),
        diastolic: (json['diastolic'] as num?)?.toDouble(),
        glucoseMgDl: (json['glucose_mg_dl'] as num?)?.toDouble(),
        heartRateBpm: (json['heart_rate_bpm'] as num?)?.toDouble(),
      );
}
