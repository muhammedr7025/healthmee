import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:health_ui/health_ui.dart';

import 'onboarding_controller.dart';

const _conditionOptions = [
  'Pre-diabetes',
  'Type 2 diabetes',
  'Hypertension',
  'High cholesterol',
  'Thyroid',
  'PCOS',
  'Asthma',
];

const _allergyOptions = ['Peanut', 'Tree nuts', 'Shellfish', 'Dairy', 'Gluten', 'Eggs', 'Soy'];

const _goalOptions = [
  {'type': 'weight', 'label': 'Reach a target weight', 'icon': Icons.monitor_weight_outlined, 'default': {'unit': 'kg', 'value': 65}},
  {'type': 'blood_pressure', 'label': 'Keep blood pressure in range', 'icon': Icons.favorite_outline, 'default': {'systolic': 120, 'diastolic': 80}},
  {'type': 'activity', 'label': 'Move more each week', 'icon': Icons.directions_walk, 'default': {'minutes_per_week': 150}},
  {'type': 'calories', 'label': 'Track daily calories', 'icon': Icons.local_fire_department_outlined, 'default': {'value': 2000}},
];

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pageController = PageController();
  int _step = 0;
  bool _submitting = false;
  String? _error;

  static const _stepCount = 4;
  static const _prompts = [
    "Let's get your basics down — any conditions Kunjan should know about?",
    "Any allergies I should watch for in your food logs?",
    "What are you working toward? Pick as many as you like.",
    'Last thing — a quick word on privacy, then you\'re all set.',
  ];

  void _goTo(int step) {
    setState(() => _step = step);
    _pageController.animateToPage(step, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
  }

  Future<void> _finish() async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref.read(onboardingControllerProvider.notifier).submit();
    } catch (e) {
      setState(() => _error = "Couldn't save that — please try again.");
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(onboardingControllerProvider);
    final controller = ref.read(onboardingControllerProvider.notifier);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(HealthSpacing.lg, HealthSpacing.lg, HealthSpacing.lg, 0),
              child: Row(
                children: [
                  const KunjanMascot(state: MascotState.idle, size: 56),
                  const SizedBox(width: HealthSpacing.sm),
                  Expanded(child: Text(_prompts[_step], style: HealthTypography.mascotSpeech())),
                ],
              ),
            ),
            const SizedBox(height: HealthSpacing.sm),
            LinearProgressIndicator(value: (_step + 1) / _stepCount, minHeight: 4),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _ConditionsStep(draft: draft, controller: controller),
                  _AllergiesStep(draft: draft, controller: controller),
                  _GoalsStep(draft: draft, controller: controller),
                  _ConsentStep(draft: draft, controller: controller, error: _error),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(HealthSpacing.lg),
              child: Row(
                children: [
                  if (_step > 0)
                    TextButton(onPressed: () => _goTo(_step - 1), child: const Text('Back')),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: (_submitting || (_step == _stepCount - 1 && !draft.consentGiven))
                        ? null
                        : () {
                            if (_step < _stepCount - 1) {
                              _goTo(_step + 1);
                            } else {
                              _finish();
                            }
                          },
                    child: Text(_submitting
                        ? 'Saving…'
                        : (_step < _stepCount - 1 ? 'Next' : "I'm ready")),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConditionsStep extends StatelessWidget {
  const _ConditionsStep({required this.draft, required this.controller});
  final dynamic draft;
  final OnboardingController controller;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(HealthSpacing.lg),
      child: Wrap(
        spacing: HealthSpacing.sm,
        runSpacing: HealthSpacing.sm,
        children: _conditionOptions.map((c) {
          final selected = draft.conditions.contains(c);
          return FilterChip(
            label: Text(c),
            selected: selected,
            onSelected: (_) => controller.toggleCondition(c),
          );
        }).toList(),
      ),
    );
  }
}

class _AllergiesStep extends StatelessWidget {
  const _AllergiesStep({required this.draft, required this.controller});
  final dynamic draft;
  final OnboardingController controller;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(HealthSpacing.lg),
      child: Wrap(
        spacing: HealthSpacing.sm,
        runSpacing: HealthSpacing.sm,
        children: _allergyOptions.map((a) {
          final selected = draft.allergies.any((d) => d.name == a);
          return FilterChip(
            label: Text(a),
            selected: selected,
            selectedColor: HealthColors.alertTrigger.withValues(alpha: 0.15),
            onSelected: (_) => controller.toggleAllergy(a),
          );
        }).toList(),
      ),
    );
  }
}

class _GoalsStep extends StatelessWidget {
  const _GoalsStep({required this.draft, required this.controller});
  final dynamic draft;
  final OnboardingController controller;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(HealthSpacing.lg),
      children: _goalOptions.map((option) {
        final type = option['type'] as String;
        final selected = draft.goals.any((g) => g.type == type);
        return Padding(
          padding: const EdgeInsets.only(bottom: HealthSpacing.sm),
          child: HealthCard(
            onTap: () => controller.toggleGoal(type, option['default'] as Map<String, dynamic>),
            child: Row(
              children: [
                Icon(option['icon'] as IconData, color: HealthColors.accentSecondary),
                const SizedBox(width: HealthSpacing.sm),
                Expanded(child: Text(option['label'] as String, style: HealthTypography.body())),
                Icon(
                  selected ? Icons.check_circle : Icons.circle_outlined,
                  color: selected ? HealthColors.accentSecondary : HealthColors.inkMuted,
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _ConsentStep extends StatelessWidget {
  const _ConsentStep({required this.draft, required this.controller, this.error});
  final dynamic draft;
  final OnboardingController controller;
  final String? error;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(HealthSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your logs, photos, and lab history are stored securely and used only to give you '
            'personalized insights — never shared without your say-so. You can export or delete '
            'everything from Settings at any time.',
            style: HealthTypography.body(),
          ),
          const SizedBox(height: HealthSpacing.md),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: draft.consentGiven,
            onChanged: (v) => controller.setConsent(v ?? false),
            title: const Text('I understand and agree to how my data is used.'),
          ),
          if (error != null) ...[
            const SizedBox(height: HealthSpacing.sm),
            AlertBanner(message: error!, hard: false),
          ],
        ],
      ),
    );
  }
}
