import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../domain/medical_profile.dart';

class MedicalProfileRepository {
  MedicalProfileRepository(this._dio);

  final Dio _dio;

  Future<MedicalProfileData> fetchProfile() async {
    final resp = await _dio.get('/medical-profile');
    return MedicalProfileData.fromJson(resp.data as Map<String, dynamic>);
  }

  Future<void> updateProfile({List<String>? conditions, List<String>? medications, Map<String, dynamic>? baselineVitals}) async {
    await _dio.put('/medical-profile', data: {
      'conditions': ?conditions,
      'medications': ?medications,
      'baseline_vitals': ?baselineVitals,
    });
  }

  Future<List<AllergyData>> fetchAllergies() async {
    final resp = await _dio.get('/allergies');
    return (resp.data as List).map((a) => AllergyData.fromJson(a as Map<String, dynamic>)).toList();
  }

  Future<void> addAllergy({required String name, required String severity}) async {
    await _dio.post('/allergies', data: {'name': name, 'severity': severity});
  }

  Future<void> deleteAllergy(String id) async {
    await _dio.delete('/allergies/$id');
  }

  Future<void> addLabResult({
    required String testName,
    required String value,
    String? unit,
    required DateTime takenAt,
  }) async {
    await _dio.post('/lab-results', data: {
      'test_name': testName,
      'value': value,
      'unit': ?unit,
      'taken_at': takenAt.toIso8601String(),
      'source': 'manual',
    });
  }

  Future<List<LabResultData>> fetchLabResults() async {
    final resp = await _dio.get('/lab-results');
    return (resp.data as List).map((l) => LabResultData.fromJson(l as Map<String, dynamic>)).toList();
  }

  /// Reads a lab report (photo or PDF, already uploaded) and returns the
  /// candidate rows plus the report date — nothing is saved until
  /// [saveLabResults]. Empty in mock mode, since there's no real vision to
  /// fall back on.
  Future<LabScanResult> scanLabReport(String mediaAssetId) async {
    final resp = await _dio.post('/lab-results/scan', data: {'media_asset_id': mediaAssetId});
    return LabScanResult.fromJson(resp.data as Map<String, dynamic>);
  }

  /// Saves the rows the user kept from the review sheet, all dated [takenAt].
  Future<List<LabResultData>> saveLabResults(
    List<LabCandidate> results, {
    required DateTime takenAt,
    String? mediaAssetId,
  }) async {
    final resp = await _dio.post('/lab-results/bulk', data: {
      'taken_at': takenAt.toUtc().toIso8601String(),
      'media_asset_id': ?mediaAssetId,
      'results': results.map((r) => r.toJson()).toList(),
    });
    return (resp.data as List).map((l) => LabResultData.fromJson(l as Map<String, dynamic>)).toList();
  }
}

final medicalProfileRepositoryProvider = Provider<MedicalProfileRepository>((ref) {
  return MedicalProfileRepository(ref.watch(dioProvider));
});

final medicalProfileProvider = FutureProvider.autoDispose<MedicalProfileData>((ref) {
  return ref.watch(medicalProfileRepositoryProvider).fetchProfile();
});

final allergiesProvider = FutureProvider.autoDispose<List<AllergyData>>((ref) {
  return ref.watch(medicalProfileRepositoryProvider).fetchAllergies();
});

final labResultsProvider = FutureProvider.autoDispose<List<LabResultData>>((ref) {
  return ref.watch(medicalProfileRepositoryProvider).fetchLabResults();
});
