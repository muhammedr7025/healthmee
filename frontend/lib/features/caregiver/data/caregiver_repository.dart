import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../domain/caregiver_link.dart';

class CaregiverRepository {
  CaregiverRepository(this._dio);

  final Dio _dio;

  /// People I've invited to care for me.
  Future<List<CaregiverLink>> fetchLinks() async {
    final resp = await _dio.get('/caregiver/links');
    return (resp.data as List).map((l) => CaregiverLink.fromJson(l as Map<String, dynamic>)).toList();
  }

  Future<void> invite({
    required String email,
    bool canViewLogs = true,
    bool canViewTrendsReports = true,
    bool canEditProfile = false,
  }) async {
    await _dio.post('/caregiver/links', data: {
      'email': email,
      'can_view_logs': canViewLogs,
      'can_view_trends_reports': canViewTrendsReports,
      'can_edit_profile': canEditProfile,
    });
  }

  Future<void> updatePermissions(
    String linkId, {
    bool? canViewLogs,
    bool? canViewTrendsReports,
    bool? canEditProfile,
  }) async {
    await _dio.patch('/caregiver/links/$linkId', data: {
      'can_view_logs': ?canViewLogs,
      'can_view_trends_reports': ?canViewTrendsReports,
      'can_edit_profile': ?canEditProfile,
    });
  }

  Future<void> revoke(String linkId) async {
    await _dio.delete('/caregiver/links/$linkId');
  }

  /// Invitations addressed to me, as a prospective caregiver.
  Future<List<CaregiverLink>> fetchInvitations() async {
    final resp = await _dio.get('/caregiver/invitations');
    return (resp.data as List).map((l) => CaregiverLink.fromJson(l as Map<String, dynamic>)).toList();
  }

  Future<void> acceptInvitation(String linkId) async {
    await _dio.post('/caregiver/invitations/$linkId/accept');
  }

  Future<void> declineInvitation(String linkId) async {
    await _dio.post('/caregiver/invitations/$linkId/decline');
  }

  /// Owner accounts I (as caregiver) currently have active access to.
  Future<List<CaregiverLink>> fetchAccess() async {
    final resp = await _dio.get('/caregiver/access');
    return (resp.data as List).map((l) => CaregiverLink.fromJson(l as Map<String, dynamic>)).toList();
  }

  Future<Map<String, dynamic>> fetchOwnerSummary(String ownerUserId) async {
    final resp = await _dio.get('/caregiver/access/$ownerUserId/summary');
    return resp.data as Map<String, dynamic>;
  }
}

final caregiverRepositoryProvider = Provider<CaregiverRepository>((ref) => CaregiverRepository(ref.watch(dioProvider)));

final caregiverLinksProvider = FutureProvider.autoDispose<List<CaregiverLink>>((ref) {
  return ref.watch(caregiverRepositoryProvider).fetchLinks();
});

final caregiverInvitationsProvider = FutureProvider.autoDispose<List<CaregiverLink>>((ref) {
  return ref.watch(caregiverRepositoryProvider).fetchInvitations();
});

final caregiverAccessProvider = FutureProvider.autoDispose<List<CaregiverLink>>((ref) {
  return ref.watch(caregiverRepositoryProvider).fetchAccess();
});
