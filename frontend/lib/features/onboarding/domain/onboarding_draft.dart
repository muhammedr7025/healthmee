class AllergyDraft {
  const AllergyDraft({required this.name, this.severity = 'moderate'});

  final String name;
  final String severity;

  Map<String, dynamic> toJson() => {'name': name, 'severity': severity};
}

class GoalDraft {
  const GoalDraft({required this.type, required this.targetValue, this.targetDate});

  final String type;
  final Map<String, dynamic> targetValue;
  final DateTime? targetDate;

  Map<String, dynamic> toJson() => {
        'type': type,
        'target_value': targetValue,
        if (targetDate != null) 'target_date': targetDate!.toIso8601String().split('T').first,
      };
}

class OnboardingDraft {
  const OnboardingDraft({
    this.fullName = '',
    this.accountFor = 'Just me',
    this.conditions = const [],
    this.medications = const [],
    this.allergies = const [],
    this.baselineVitals = const {},
    this.goals = const [],
    this.consentGiven = false,
  });

  /// Captured on its own step right after signup rather than at signup
  /// itself, so the account can exist before we ask anything personal.
  final String fullName;
  // "Just me" | "Me and someone I care for" — a first-run signal for who
  // this profile is for. Doesn't change anything server-side yet (caregiver
  // access is still set up later, from Settings); it's the answer, kept
  // for the account setup UI to reflect back.
  final String accountFor;
  final List<String> conditions;
  final List<String> medications;
  final List<AllergyDraft> allergies;
  final Map<String, dynamic> baselineVitals;
  final List<GoalDraft> goals;
  final bool consentGiven;

  OnboardingDraft copyWith({
    String? fullName,
    String? accountFor,
    List<String>? conditions,
    List<String>? medications,
    List<AllergyDraft>? allergies,
    Map<String, dynamic>? baselineVitals,
    List<GoalDraft>? goals,
    bool? consentGiven,
  }) =>
      OnboardingDraft(
        fullName: fullName ?? this.fullName,
        accountFor: accountFor ?? this.accountFor,
        conditions: conditions ?? this.conditions,
        medications: medications ?? this.medications,
        allergies: allergies ?? this.allergies,
        baselineVitals: baselineVitals ?? this.baselineVitals,
        goals: goals ?? this.goals,
        consentGiven: consentGiven ?? this.consentGiven,
      );

  Map<String, dynamic> toJson() => {
        if (fullName.trim().isNotEmpty) 'full_name': fullName.trim(),
        'conditions': conditions,
        'medications': medications,
        'allergies': allergies.map((a) => a.toJson()).toList(),
        'baseline_vitals': baselineVitals,
        'goals': goals.map((g) => g.toJson()).toList(),
        'consent_given': consentGiven,
      };
}
