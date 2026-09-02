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

class LabResultData {
  const LabResultData({
    required this.id,
    required this.source,
    required this.testName,
    required this.value,
    this.unit,
    required this.takenAt,
  });

  final String id;
  final String source;
  final String testName;
  final String value;
  final String? unit;
  final DateTime takenAt;

  factory LabResultData.fromJson(Map<String, dynamic> json) => LabResultData(
        id: json['id'] as String,
        source: json['source'] as String,
        testName: json['test_name'] as String,
        value: json['value'] as String,
        unit: json['unit'] as String?,
        takenAt: DateTime.parse(json['taken_at'] as String),
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
