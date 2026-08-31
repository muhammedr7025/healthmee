import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../domain/onboarding_draft.dart';

class OnboardingRepository {
  OnboardingRepository(this._dio);

  final Dio _dio;

  Future<void> submit(OnboardingDraft draft) async {
    await _dio.post('/onboarding', data: draft.toJson());
  }
}

final onboardingRepositoryProvider = Provider<OnboardingRepository>((ref) {
  return OnboardingRepository(ref.watch(dioProvider));
});
