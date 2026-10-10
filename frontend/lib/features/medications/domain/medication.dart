class MedicationSchedule {
  const MedicationSchedule({
    required this.id,
    required this.name,
    this.dose,
    required this.times,
    this.daysOfWeek,
    required this.active,
  });

  final String id;
  final String name;
  final String? dose;

  /// Local wall-clock slots, "HH:MM".
  final List<String> times;

  /// Monday = 0; null means every day.
  final List<int>? daysOfWeek;
  final bool active;

  factory MedicationSchedule.fromJson(Map<String, dynamic> json) => MedicationSchedule(
        id: json['id'] as String,
        name: json['name'] as String,
        dose: json['dose'] as String?,
        times: List<String>.from(json['times'] as List? ?? []),
        daysOfWeek: json['days_of_week'] == null ? null : List<int>.from(json['days_of_week'] as List),
        active: json['active'] as bool? ?? true,
      );
}

class DoseItem {
  const DoseItem({
    required this.scheduleId,
    required this.name,
    this.dose,
    required this.time,
    required this.status,
  });

  final String scheduleId;
  final String name;
  final String? dose;
  final String time;

  /// pending | taken | skipped
  final String status;

  factory DoseItem.fromJson(Map<String, dynamic> json) => DoseItem(
        scheduleId: json['schedule_id'] as String,
        name: json['name'] as String,
        dose: json['dose'] as String?,
        time: json['time'] as String,
        status: json['status'] as String,
      );
}

class MedicationDayPlan {
  const MedicationDayPlan({
    required this.date,
    required this.items,
    required this.taken,
    required this.total,
    this.adherencePct,
  });

  final String date;
  final List<DoseItem> items;
  final int taken;
  final int total;
  final int? adherencePct;

  factory MedicationDayPlan.fromJson(Map<String, dynamic> json) => MedicationDayPlan(
        date: json['date'] as String,
        items: (json['items'] as List? ?? []).map((i) => DoseItem.fromJson(i as Map<String, dynamic>)).toList(),
        taken: (json['taken'] as num).toInt(),
        total: (json['total'] as num).toInt(),
        adherencePct: (json['adherence_pct'] as num?)?.toInt(),
      );
}
