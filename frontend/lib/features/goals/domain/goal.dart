class Goal {
  const Goal({
    required this.id,
    required this.type,
    required this.targetValue,
    required this.startDate,
    this.targetDate,
    required this.status,
  });

  final String id;
  final String type;
  final Map<String, dynamic> targetValue;
  final DateTime startDate;
  final DateTime? targetDate;
  final String status;

  factory Goal.fromJson(Map<String, dynamic> json) => Goal(
        id: json['id'] as String,
        type: json['type'] as String,
        targetValue: Map<String, dynamic>.from(json['target_value'] as Map? ?? {}),
        startDate: DateTime.parse(json['start_date'] as String),
        targetDate: json['target_date'] != null ? DateTime.parse(json['target_date'] as String) : null,
        status: json['status'] as String,
      );
}
