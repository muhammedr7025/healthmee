/// Today's habit score with its working shown — mirrors GET /today/score.
class ScoreComponent {
  const ScoreComponent({
    required this.key,
    required this.label,
    required this.points,
    required this.max,
    required this.detail,
  });

  final String key;
  final String label;
  final int points;

  /// 0 when the component doesn't apply today (no medicines scheduled).
  final int max;
  final String detail;

  factory ScoreComponent.fromJson(Map<String, dynamic> json) => ScoreComponent(
        key: json['key'] as String,
        label: json['label'] as String,
        points: (json['points'] as num).toInt(),
        max: (json['max'] as num).toInt(),
        detail: json['detail'] as String,
      );
}

class TodayScore {
  const TodayScore({
    required this.score,
    required this.earned,
    required this.achievable,
    required this.components,
    required this.mascot,
  });

  final int score;
  final int earned;
  final int achievable;
  final List<ScoreComponent> components;

  /// A MascotState name chosen server-side so the mascot never looks sad
  /// over a number.
  final String mascot;

  factory TodayScore.fromJson(Map<String, dynamic> json) => TodayScore(
        score: (json['score'] as num).toInt(),
        earned: (json['earned'] as num).toInt(),
        achievable: (json['achievable'] as num).toInt(),
        components: (json['components'] as List? ?? []).map((c) => ScoreComponent.fromJson(c as Map<String, dynamic>)).toList(),
        mascot: json['mascot'] as String? ?? 'happy',
      );
}
