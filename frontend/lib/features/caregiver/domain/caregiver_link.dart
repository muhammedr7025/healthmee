class CaregiverLink {
  const CaregiverLink({
    required this.id,
    required this.ownerUserId,
    this.caregiverUserId,
    required this.caregiverEmail,
    required this.status,
    required this.canViewLogs,
    required this.canViewTrendsReports,
    required this.canEditProfile,
    this.ownerEmail,
    this.ownerFullName,
  });

  final String id;
  final String ownerUserId;
  final String? caregiverUserId;
  final String caregiverEmail;
  final String status; // pending|active|declined|revoked
  final bool canViewLogs;
  final bool canViewTrendsReports;
  final bool canEditProfile;
  final String? ownerEmail;
  final String? ownerFullName;

  factory CaregiverLink.fromJson(Map<String, dynamic> json) => CaregiverLink(
        id: json['id'] as String,
        ownerUserId: json['owner_user_id'] as String,
        caregiverUserId: json['caregiver_user_id'] as String?,
        caregiverEmail: json['caregiver_email'] as String,
        status: json['status'] as String,
        canViewLogs: json['can_view_logs'] as bool,
        canViewTrendsReports: json['can_view_trends_reports'] as bool,
        canEditProfile: json['can_edit_profile'] as bool,
        ownerEmail: json['owner_email'] as String?,
        ownerFullName: json['owner_full_name'] as String?,
      );
}
