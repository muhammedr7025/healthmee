import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_controller.dart';
import '../data/onboarding_repository.dart';
import '../domain/onboarding_draft.dart';

class OnboardingController extends StateNotifier<OnboardingDraft> {
  OnboardingController(this._repo, this._ref) : super(const OnboardingDraft());

  final OnboardingRepository _repo;
  final Ref _ref;

  void toggleCondition(String condition) {
    final list = List<String>.from(state.conditions);
    list.contains(condition) ? list.remove(condition) : list.add(condition);
    state = state.copyWith(conditions: list);
  }

  void toggleAllergy(String name) {
    final list = List<AllergyDraft>.from(state.allergies);
    final index = list.indexWhere((a) => a.name == name);
    if (index >= 0) {
      list.removeAt(index);
    } else {
      list.add(AllergyDraft(name: name));
    }
    state = state.copyWith(allergies: list);
  }

  void setAllergySeverity(String name, String severity) {
    final list = state.allergies.map((a) => a.name == name ? AllergyDraft(name: a.name, severity: severity) : a).toList();
    state = state.copyWith(allergies: list);
  }

  void updateVital(String key, dynamic value) {
    state = state.copyWith(baselineVitals: {...state.baselineVitals, key: value});
  }

  void toggleGoal(String type, Map<String, dynamic> defaultTarget) {
    final list = List<GoalDraft>.from(state.goals);
    final index = list.indexWhere((g) => g.type == type);
    if (index >= 0) {
      list.removeAt(index);
    } else {
      list.add(GoalDraft(type: type, targetValue: defaultTarget));
    }
    state = state.copyWith(goals: list);
  }

  void setConsent(bool value) => state = state.copyWith(consentGiven: value);

  Future<void> submit() async {
    await _repo.submit(state);
    _ref.read(authControllerProvider.notifier).markOnboardingComplete();
  }
}

final onboardingControllerProvider = StateNotifierProvider<OnboardingController, OnboardingDraft>((ref) {
  return OnboardingController(ref.watch(onboardingRepositoryProvider), ref);
});
