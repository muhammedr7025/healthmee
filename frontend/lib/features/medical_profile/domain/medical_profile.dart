class MedicalProfileData {
  const MedicalProfileData({
    required this.id,
    required this.version,
    required this.conditions,
    required this.medications,
    required this.baselineVitals,
    this.notes,
  });

  final String id;
  final int version;
  final List<String> conditions;
  final List<String> medications;
  final Map<String, dynamic> baselineVitals;
  final String? notes;

  factory MedicalProfileData.fromJson(Map<String, dynamic> json) => MedicalProfileData(
        id: json['id'] as String,
        version: json['version'] as int,
        conditions: List<String>.from(json['conditions'] as List? ?? []),
        medications: List<String>.from(json['medications'] as List? ?? []),
        baselineVitals: Map<String, dynamic>.from(json['baseline_vitals'] as Map? ?? {}),
        notes: json['notes'] as String?,
      );
}

class AllergyData {
  const AllergyData({required this.id, required this.name, required this.severity});

  final String id;
  final String name;
  final String severity;

  factory AllergyData.fromJson(Map<String, dynamic> json) =>
      AllergyData(id: json['id'] as String, name: json['name'] as String, severity: json['severity'] as String);
}
