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
    this.referenceRange,
    required this.takenAt,
  });

  final String id;
  final String source;
  final String testName;
  final String value;
  final String? unit;
  final String? referenceRange;
  final DateTime takenAt;

  factory LabResultData.fromJson(Map<String, dynamic> json) => LabResultData(
        id: json['id'] as String,
        source: json['source'] as String,
        testName: json['test_name'] as String,
        value: json['value'] as String,
        unit: json['unit'] as String?,
        referenceRange: json['reference_range'] as String?,
        takenAt: DateTime.parse(json['taken_at'] as String),
      );
}

/// One row MeMe read off a report — shown for review, not yet saved.
class LabCandidate {
  const LabCandidate({required this.testName, required this.value, this.unit, this.referenceRange});

  final String testName;
  final String value;
  final String? unit;
  final String? referenceRange;

  factory LabCandidate.fromJson(Map<String, dynamic> json) => LabCandidate(
        testName: json['test_name'] as String,
        value: json['value'] as String,
        unit: json['unit'] as String?,
        referenceRange: json['reference_range'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'test_name': testName,
        'value': value,
        'unit': ?unit,
        'reference_range': ?referenceRange,
      };
}

class LabScanResult {
  const LabScanResult({required this.mediaAssetId, required this.candidates, this.reportDate});

  final String mediaAssetId;
  final List<LabCandidate> candidates;

  /// The date printed on the report, when the reader found one.
  final DateTime? reportDate;

  factory LabScanResult.fromJson(Map<String, dynamic> json) => LabScanResult(
        mediaAssetId: json['media_asset_id'] as String,
        candidates: (json['candidates'] as List? ?? []).map((c) => LabCandidate.fromJson(c as Map<String, dynamic>)).toList(),
        reportDate: json['report_date'] == null ? null : DateTime.tryParse(json['report_date'] as String),
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
