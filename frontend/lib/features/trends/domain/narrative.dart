class NarrativeStats {
  const NarrativeStats({
    required this.daysTotal,
    required this.daysLogged,
    required this.logCount,
    this.avgSleep,
    this.avgMood,
    required this.totalActivityMinutes,
    this.avgCalories,
  });

  final int daysTotal;
  final int daysLogged;
  final int logCount;
  final double? avgSleep;
  final double? avgMood;
  final double totalActivityMinutes;
  final double? avgCalories;

  factory NarrativeStats.fromJson(Map<String, dynamic> json) => NarrativeStats(
        daysTotal: json['days_total'] as int,
        daysLogged: json['days_logged'] as int,
        logCount: json['log_count'] as int,
        avgSleep: (json['avg_sleep'] as num?)?.toDouble(),
        avgMood: (json['avg_mood'] as num?)?.toDouble(),
        totalActivityMinutes: (json['total_activity_minutes'] as num).toDouble(),
        avgCalories: (json['avg_calories'] as num?)?.toDouble(),
      );
}

class Narrative {
  const Narrative({
    required this.period,
    required this.start,
    required this.end,
    required this.summary,
    required this.stats,
    required this.wins,
    required this.watch,
  });

  final String period;
  final String start;
  final String end;
  final String summary;
  final NarrativeStats stats;
  final List<String> wins;
  final List<String> watch;

  factory Narrative.fromJson(Map<String, dynamic> json) => Narrative(
        period: json['period'] as String,
        start: json['start'] as String,
        end: json['end'] as String,
        summary: json['summary'] as String,
        stats: NarrativeStats.fromJson(json['stats'] as Map<String, dynamic>),
        wins: List<String>.from(json['wins'] as List? ?? []),
        watch: List<String>.from(json['watch'] as List? ?? []),
      );
}
