class NarrativeStats {
  const NarrativeStats({
    required this.daysTotal,
    required this.daysLogged,
    required this.logCount,
    this.avgSleep,
    this.avgMood,
    required this.totalActivityMinutes,
    this.avgCalories,
    this.avgWaterMl,
    this.avgWeightKg,
    this.weightChangeKg,
    this.avgSystolic,
    this.avgDiastolic,
    this.avgGlucoseMgDl,
    this.avgHeartRateBpm,
    this.vitalsDays = 0,
  });

  final int daysTotal;
  final int daysLogged;
  final int logCount;
  final double? avgSleep;
  final double? avgMood;
  final double totalActivityMinutes;
  final double? avgCalories;
  final double? avgWaterMl;
  final double? avgWeightKg;
  final double? weightChangeKg;
  final double? avgSystolic;
  final double? avgDiastolic;
  final double? avgGlucoseMgDl;
  final double? avgHeartRateBpm;
  final int vitalsDays;

  factory NarrativeStats.fromJson(Map<String, dynamic> json) => NarrativeStats(
        daysTotal: json['days_total'] as int,
        daysLogged: json['days_logged'] as int,
        logCount: json['log_count'] as int,
        avgSleep: (json['avg_sleep'] as num?)?.toDouble(),
        avgMood: (json['avg_mood'] as num?)?.toDouble(),
        totalActivityMinutes: (json['total_activity_minutes'] as num).toDouble(),
        avgCalories: (json['avg_calories'] as num?)?.toDouble(),
        avgWaterMl: (json['avg_water_ml'] as num?)?.toDouble(),
        avgWeightKg: (json['avg_weight_kg'] as num?)?.toDouble(),
        weightChangeKg: (json['weight_change_kg'] as num?)?.toDouble(),
        avgSystolic: (json['avg_systolic'] as num?)?.toDouble(),
        avgDiastolic: (json['avg_diastolic'] as num?)?.toDouble(),
        avgGlucoseMgDl: (json['avg_glucose_mg_dl'] as num?)?.toDouble(),
        avgHeartRateBpm: (json['avg_heart_rate_bpm'] as num?)?.toDouble(),
        vitalsDays: (json['vitals_days'] as num?)?.toInt() ?? 0,
      );
}

class Momentum {
  const Momentum({required this.label, required this.detail});

  /// starting | building | steady | slipping
  final String label;
  final String detail;

  factory Momentum.fromJson(Map<String, dynamic> json) =>
      Momentum(label: json['label'] as String? ?? 'steady', detail: json['detail'] as String? ?? '');
}

class Narrative {
  const Narrative({
    required this.period,
    required this.start,
    required this.end,
    required this.summary,
    required this.stats,
    this.previous,
    this.deltas = const {},
    this.momentum,
    required this.wins,
    required this.watch,
    this.achievements = const [],
    this.risks = const [],
    this.recommendations = const [],
  });

  final String period;
  final String start;
  final String end;
  final String summary;
  final NarrativeStats stats;
  final NarrativeStats? previous;

  /// This period minus the one before, per stat key (null = nothing to compare).
  final Map<String, double?> deltas;
  final Momentum? momentum;
  final List<String> wins;
  final List<String> watch;
  final List<String> achievements;
  final List<String> risks;
  final List<String> recommendations;

  factory Narrative.fromJson(Map<String, dynamic> json) => Narrative(
        period: json['period'] as String,
        start: json['start'] as String,
        end: json['end'] as String,
        summary: json['summary'] as String,
        stats: NarrativeStats.fromJson(json['stats'] as Map<String, dynamic>),
        previous: json['previous'] == null ? null : NarrativeStats.fromJson(json['previous'] as Map<String, dynamic>),
        deltas: {
          for (final e in (json['deltas'] as Map? ?? {}).entries) '${e.key}': (e.value as num?)?.toDouble(),
        },
        momentum: json['momentum'] == null ? null : Momentum.fromJson(json['momentum'] as Map<String, dynamic>),
        wins: List<String>.from(json['wins'] as List? ?? []),
        watch: List<String>.from(json['watch'] as List? ?? []),
        achievements: List<String>.from(json['achievements'] as List? ?? []),
        risks: List<String>.from(json['risks'] as List? ?? []),
        recommendations: List<String>.from(json['recommendations'] as List? ?? []),
      );
}
