class AppUser {
  const AppUser({required this.id, required this.email, this.fullName, required this.onboardingCompleted});

  final String id;
  final String email;
  final String? fullName;
  final bool onboardingCompleted;

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
        id: json['id'] as String,
        email: json['email'] as String,
        fullName: json['full_name'] as String?,
        onboardingCompleted: json['onboarding_completed'] as bool? ?? false,
      );

  AppUser copyWith({bool? onboardingCompleted}) => AppUser(
        id: id,
        email: email,
        fullName: fullName,
        onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
      );
}
