import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:health_ui/health_ui.dart';

import '../../medical_profile/data/medical_profile_repository.dart';
import '../../medical_profile/presentation/lab_scan_flow.dart';
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

  static const _stepCount = 9;
  static const _consentStep = 7;
  static const _stepLabels = [
    '1 · About you',
    '2 · Basics',
    '3 · Allergies',
    '4 · Medications',
    '5 · Baseline vitals',
    '6 · Lab report',
    '7 · Your goal',
    '8 · Privacy',
    'All set',
  ];
  static const _prompts = [
    'Before anything else — what should I call you?',
    "Good to meet you. A couple of numbers now means I can show you movement later.",
    "What should I never let slip past? I'll check every meal against this.",
    "Anything you're taking right now? Add as many as you like.",
    "A couple of numbers now means I can show you movement later. All optional.",
    "Got a recent lab report? Snap it and I'll read what I can — or skip it.",
    "What are we working toward? Pick as many as fit.",
    "Last thing — how your data is handled. Then we're done.",
    "That's everything. Here's what I've got for you.",
  ];

  void _goTo(int step) {
    FocusScope.of(context).unfocus();
    setState(() => _step = step);
    _pageController.animateToPage(step, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
  }

  /// MeMe's follow-up bubble — reacts to what's actually been entered so far,
  /// so the flow answers back instead of just marching through forms. Every
  /// line is derived from real draft data; nothing is said that isn't true.
  String? _reactionFor(int step, dynamic draft) {
    switch (step) {
      case 0:
        final name = (draft.fullName as String).trim();
        if (name.isEmpty) return null;
        return "Hi $name. I'll only use your name when I check in on you, never to sell you something.";
      case 1:
        final conditions = List<String>.from(draft.conditions);
        if (conditions.isNotEmpty) {
          return "${_joinNicely(conditions)} — noted. I'll keep that in mind every time you log.";
        }
        final vitals = Map<String, dynamic>.from(draft.baselineVitals);
        if (vitals['age'] != null || vitals['weight_kg'] != null || vitals['height_cm'] != null) {
          return "Got it — that gives me a starting point.";
        }
        return null;
      case 2:
        final names = draft.allergies.map((a) => a.name as String).toList().cast<String>();
        if (names.isEmpty) return null;
        return "${_joinNicely(names)} — I'll flag ${names.length == 1 ? 'it' : 'these'} hard, every single time.";
      case 3:
        final meds = List<String>.from(draft.medications);
        if (meds.isEmpty) return null;
        return "${meds.length} tracked. I'll remember ${meds.length == 1 ? 'it' : 'them'}.";
      case 4:
        final v = Map<String, dynamic>.from(draft.baselineVitals);
        final parts = <String>[];
        if (v['bp_systolic'] != null && v['bp_diastolic'] != null) {
          parts.add('${v['bp_systolic']}/${v['bp_diastolic']}');
        }
        if (v['glucose_mg_dl'] != null) parts.add('${v['glucose_mg_dl']} mg/dL');
        if (parts.isEmpty) return null;
        return "${parts.join(' · ')} — that's your starting line. We'll measure from here.";
      case 6:
        final goals = draft.goals;
        if (goals.isEmpty) return null;
        return "${goals.length} goal${goals.length == 1 ? '' : 's'} — I'll check in on ${goals.length == 1 ? 'it' : 'them'} as you go.";
      case _consentStep:
        return draft.consentGiven == true ? "Thank you. That's everything I need." : null;
      default:
        return null;
    }
  }

  MascotState _mascotFor(int step, dynamic draft) {
    if (step == _stepCount - 1) return MascotState.celebrating;
    if (step == 2 && draft.allergies.isNotEmpty) return MascotState.concerned;
    if (_reactionFor(step, draft) != null) return MascotState.curious;
    return MascotState.happy;
  }

  static String _joinNicely(List<String> items) {
    if (items.length == 1) return items.first;
    if (items.length == 2) return '${items[0]} and ${items[1]}';
    return '${items.sublist(0, items.length - 1).join(', ')} and ${items.last}';
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
              padding: const EdgeInsets.fromLTRB(HealthSpacing.lg, HealthSpacing.md, HealthSpacing.lg, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_stepLabels[_step], style: HealthTypography.label()),
                  const SizedBox(height: 8),
                  Row(
                    children: List.generate(
                      _stepCount,
                      (i) => Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: Container(
                            height: 3,
                            decoration: BoxDecoration(
                              color: i <= _step ? HealthColors.accentPrimary : HealthColors.chipIdleHover,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      MascotHalo(state: _mascotFor(_step, draft), size: 46),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
                              decoration: BoxDecoration(
                                color: HealthColors.surface,
                                border: Border.all(color: HealthColors.inkPrimary.withValues(alpha: 0.09)),
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(18),
                                  topRight: Radius.circular(18),
                                  bottomRight: Radius.circular(18),
                                  bottomLeft: Radius.circular(5),
                                ),
                              ),
                              child: Text(_prompts[_step], style: HealthTypography.body(fontSize: 15)),
                            ),
                            _ReactionBubble(text: _reactionFor(_step, draft)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: HealthSpacing.md),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _NameStep(draft: draft, controller: controller),
                  _BasicsStep(draft: draft, controller: controller),
                  _AllergiesStep(draft: draft, controller: controller),
                  _MedicationsStep(draft: draft, controller: controller),
                  _VitalsStep(draft: draft, controller: controller),
                  const _LabScanStep(),
                  _GoalsStep(draft: draft, controller: controller),
                  _ConsentStep(draft: draft, controller: controller, error: _error),
                  _FinishStep(draft: draft, error: _error),
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
                    onPressed: (_submitting ||
                            (_step == 0 && draft.fullName.trim().isEmpty) ||
                            (_step == _consentStep && !draft.consentGiven))
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
                        : (_step == _stepCount - 1 ? 'Say hello to MeMe' : 'Continue')),
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

/// MeMe's reaction to what you just entered — fades/slides in when there's
/// something real to say, and quietly collapses when there isn't.
class _ReactionBubble extends StatelessWidget {
  const _ReactionBubble({required this.text});
  final String? text;

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
      alignment: Alignment.topLeft,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 260),
        switchInCurve: Curves.easeOut,
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween(begin: const Offset(0, -0.15), end: Offset.zero).animate(animation),
            child: child,
          ),
        ),
        child: text == null
            ? const SizedBox(width: double.infinity)
            : Padding(
                key: ValueKey(text),
                padding: const EdgeInsets.only(top: 7),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  decoration: const BoxDecoration(
                    color: HealthColors.reactionBubble,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                      bottomLeft: Radius.circular(5),
                    ),
                  ),
                  child: Text(
                    text!,
                    style: HealthTypography.body(fontSize: 13, color: HealthColors.reactionText),
                  ),
                ),
              ),
      ),
    );
  }
}

/// The payoff screen — a recap of everything actually captured, so the flow
/// ends on "here's what I know about you now" rather than just stopping.
class _FinishStep extends StatelessWidget {
  const _FinishStep({required this.draft, this.error});
  final dynamic draft;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final vitals = Map<String, dynamic>.from(draft.baselineVitals);
    final basics = [
      if (vitals['age'] != null) '${vitals['age']} yrs',
      if (vitals['height_cm'] != null) '${vitals['height_cm']} cm',
      if (vitals['weight_kg'] != null) '${vitals['weight_kg']} kg',
    ].join(' · ');
    final baseline = [
      if (vitals['bp_systolic'] != null && vitals['bp_diastolic'] != null)
        '${vitals['bp_systolic']}/${vitals['bp_diastolic']}',
      if (vitals['glucose_mg_dl'] != null) '${vitals['glucose_mg_dl']} mg/dL',
    ].join(' · ');
    final allergyNames = draft.allergies.map((a) => a.name as String).toList().cast<String>();
    final conditions = List<String>.from(draft.conditions);
    final medications = List<String>.from(draft.medications);

    final name = (draft.fullName as String).trim();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(HealthSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Column(
              children: [
                const MemeMascot(state: MascotState.celebrating, size: 96),
                const SizedBox(height: 14),
                Text(name.isEmpty ? "You're set." : "You're set, $name.", style: HealthTypography.display(fontSize: 26)),
                const SizedBox(height: 8),
                Text(
                  "Here's what I'll hold in mind from now on. Change any of it in your profile.",
                  style: HealthTypography.body(fontSize: 13, color: HealthColors.inkMuted),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: HealthSpacing.lg),
          _RecapRow(label: 'Basics', value: basics.isEmpty ? '—' : basics),
          _RecapRow(label: 'Conditions', value: conditions.isEmpty ? 'None' : conditions.join(', ')),
          _RecapRow(
            label: 'Hard flags',
            value: allergyNames.isEmpty ? 'None' : allergyNames.join(', '),
            highlight: allergyNames.isNotEmpty,
          ),
          _RecapRow(label: 'Medications', value: medications.isEmpty ? 'None' : '${medications.length} tracked'),
          _RecapRow(label: 'Baseline', value: baseline.isEmpty ? '—' : baseline),
          _RecapRow(
            label: draft.goals.length == 1 ? 'Goal' : 'Goals',
            value: draft.goals.isEmpty ? 'None yet' : '${draft.goals.length} set',
          ),
          const SizedBox(height: HealthSpacing.md),
          Text(
            'You can change any of this later from your Medical Profile — nothing here is locked in.',
            style: HealthTypography.body(fontSize: 12.5, color: HealthColors.inkMuted),
          ),
          if (error != null) ...[
            const SizedBox(height: HealthSpacing.md),
            AlertBanner(message: error!, hard: false),
          ],
        ],
      ),
    );
  }
}

class _RecapRow extends StatelessWidget {
  const _RecapRow({required this.label, required this.value, this.highlight = false});
  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
        decoration: BoxDecoration(
          color: highlight ? const Color(0xFFFDEEE4) : HealthColors.surface,
          border: Border.all(
            color: highlight
                ? HealthColors.accentPrimary.withValues(alpha: 0.35)
                : HealthColors.inkPrimary.withValues(alpha: 0.09),
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 96, child: Text(label, style: HealthTypography.label())),
            Expanded(
              child: Text(
                value,
                style: HealthTypography.body(
                  fontSize: 13.5,
                  color: highlight ? HealthColors.accentPrimaryDark : HealthColors.inkPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

const _accountForOptions = [
  {'label': 'Just me', 'note': 'One profile, one history'},
  {'label': 'Me and someone I care for', 'note': 'Adds a second profile you can switch between'},
];

class _NameStep extends StatefulWidget {
  const _NameStep({required this.draft, required this.controller});
  final dynamic draft;
  final OnboardingController controller;

  @override
  State<_NameStep> createState() => _NameStepState();
}

class _NameStepState extends State<_NameStep> {
  late final TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.draft.fullName);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(HealthSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _nameController,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(labelText: 'Your name', hintText: 'Anand'),
            onChanged: widget.controller.setFullName,
          ),
          const SizedBox(height: HealthSpacing.lg),
          Text('Who is this account for?', style: HealthTypography.label()),
          const SizedBox(height: HealthSpacing.sm),
          ..._accountForOptions.map((option) {
            final label = option['label']!;
            final selected = widget.draft.accountFor == label;
            return Padding(
              padding: const EdgeInsets.only(bottom: HealthSpacing.sm),
              child: HealthCard(
                onTap: () => widget.controller.setAccountFor(label),
                child: Row(
                  children: [
                    Icon(
                      selected ? Icons.radio_button_checked : Icons.radio_button_off,
                      color: selected ? HealthColors.accentSecondary : HealthColors.inkMuted,
                      size: 20,
                    ),
                    const SizedBox(width: HealthSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(label, style: HealthTypography.body()),
                          Text(option['note']!, style: HealthTypography.body(fontSize: 11.5, color: HealthColors.inkMuted)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: HealthSpacing.sm),
          Text(
            'No gender questions here. If a lab range needs it later, I\'ll ask then and tell you why.',
            style: HealthTypography.body(fontSize: 12.5, color: HealthColors.inkMuted),
          ),
        ],
      ),
    );
  }
}

class _BasicsStep extends StatelessWidget {
  const _BasicsStep({required this.draft, required this.controller});
  final dynamic draft;
  final OnboardingController controller;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(HealthSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _VitalField(
                  label: 'Age',
                  vitalKey: 'age',
                  draft: draft,
                  controller: controller,
                  hint: '34',
                ),
              ),
              const SizedBox(width: HealthSpacing.sm),
              Expanded(
                child: _VitalField(
                  label: 'Height (cm)',
                  vitalKey: 'height_cm',
                  draft: draft,
                  controller: controller,
                  hint: '172',
                ),
              ),
            ],
          ),
          const SizedBox(height: HealthSpacing.sm),
          Row(
            children: [
              Expanded(
                child: _VitalField(
                  label: 'Weight (kg)',
                  vitalKey: 'weight_kg',
                  draft: draft,
                  controller: controller,
                  hint: '78',
                ),
              ),
              const SizedBox(width: HealthSpacing.sm),
              Expanded(
                child: _VitalField(
                  label: 'Waking hours',
                  vitalKey: 'waking_hours',
                  draft: draft,
                  controller: controller,
                  hint: '7am – 11pm',
                  keyboardType: TextInputType.text,
                ),
              ),
            ],
          ),
          const SizedBox(height: HealthSpacing.lg),
          Text('Conditions you\'re managing', style: HealthTypography.label()),
          const SizedBox(height: HealthSpacing.sm),
          Wrap(
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
        ],
      ),
    );
  }
}

/// Owns its own TextEditingController and keeps a stable widget identity.
/// (It used to be a StatelessWidget with `key: ValueKey('$vitalKey-$value')`
/// and `initialValue` — so every keystroke changed the key, Flutter tore the
/// field down and rebuilt it, and the keyboard closed after one character.)
class _VitalField extends StatefulWidget {
  const _VitalField({
    required this.label,
    required this.vitalKey,
    required this.draft,
    required this.controller,
    this.hint,
    this.keyboardType = TextInputType.number,
  });

  final String label;
  final String vitalKey;
  final dynamic draft;
  final OnboardingController controller;
  final String? hint;
  final TextInputType keyboardType;

  @override
  State<_VitalField> createState() => _VitalFieldState();
}

class _VitalFieldState extends State<_VitalField> {
  late final TextEditingController _textController;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.draft.baselineVitals[widget.vitalKey]?.toString() ?? '');
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _textController,
      keyboardType: widget.keyboardType,
      textInputAction: TextInputAction.next,
      decoration: InputDecoration(labelText: widget.label, hintText: widget.hint),
      onChanged: (v) {
        if (widget.keyboardType == TextInputType.number) {
          widget.controller.updateVital(widget.vitalKey, int.tryParse(v) ?? v);
        } else {
          widget.controller.updateVital(widget.vitalKey, v);
        }
      },
    );
  }
}

class _AllergiesStep extends StatefulWidget {
  const _AllergiesStep({required this.draft, required this.controller});
  final dynamic draft;
  final OnboardingController controller;

  @override
  State<_AllergiesStep> createState() => _AllergiesStepState();
}

class _AllergiesStepState extends State<_AllergiesStep> {
  final _customController = TextEditingController();

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  void _addCustom() {
    final text = _customController.text.trim();
    if (text.isEmpty) return;
    widget.controller.toggleAllergy(text);
    _customController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final customAllergies = widget.draft.allergies
        .map((a) => a.name as String)
        .where((n) => !_allergyOptions.contains(n))
        .toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(HealthSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: HealthSpacing.sm,
            runSpacing: HealthSpacing.sm,
            children: [
              ..._allergyOptions.map((a) {
                final selected = widget.draft.allergies.any((d) => d.name == a);
                return FilterChip(
                  label: Text(a),
                  selected: selected,
                  selectedColor: HealthColors.alertTrigger.withValues(alpha: 0.15),
                  onSelected: (_) => widget.controller.toggleAllergy(a),
                );
              }),
              ...customAllergies.map((a) => FilterChip(
                    label: Text(a),
                    selected: true,
                    selectedColor: HealthColors.alertTrigger.withValues(alpha: 0.15),
                    onSelected: (_) => widget.controller.toggleAllergy(a),
                  )),
            ],
          ),
          const SizedBox(height: HealthSpacing.lg),
          Text('Something else? Add it yourself', style: HealthTypography.label()),
          const SizedBox(height: HealthSpacing.sm),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _customController,
                  decoration: const InputDecoration(hintText: 'e.g. Brinjal, sulphites, ajinomoto'),
                  onSubmitted: (_) => _addCustom(),
                ),
              ),
              const SizedBox(width: HealthSpacing.sm),
              IconButton.filled(onPressed: _addCustom, icon: const Icon(Icons.add)),
            ],
          ),
          const SizedBox(height: HealthSpacing.sm),
          Text(
            'Anything you add here gets the same hard warning as the ones above.',
            style: HealthTypography.body(fontSize: 12.5, color: HealthColors.inkMuted),
          ),
        ],
      ),
    );
  }
}

class _MedicationsStep extends StatefulWidget {
  const _MedicationsStep({required this.draft, required this.controller});
  final dynamic draft;
  final OnboardingController controller;

  @override
  State<_MedicationsStep> createState() => _MedicationsStepState();
}

class _MedicationsStepState extends State<_MedicationsStep> {
  final _medController = TextEditingController();

  @override
  void dispose() {
    _medController.dispose();
    super.dispose();
  }

  void _add() {
    final text = _medController.text.trim();
    if (text.isEmpty) return;
    widget.controller.addMedication(text);
    _medController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(HealthSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _medController,
                  decoration: const InputDecoration(hintText: 'e.g. Metformin 500mg, twice daily'),
                  onSubmitted: (_) => _add(),
                ),
              ),
              const SizedBox(width: HealthSpacing.sm),
              IconButton.filled(onPressed: _add, icon: const Icon(Icons.add)),
            ],
          ),
          const SizedBox(height: HealthSpacing.md),
          if (widget.draft.medications.isEmpty)
            Text('None yet — skip if you\'re not on anything.', style: HealthTypography.body(color: HealthColors.inkMuted))
          else
            ...widget.draft.medications.map<Widget>((m) => Padding(
                  padding: const EdgeInsets.only(bottom: HealthSpacing.sm),
                  child: HealthCard(
                    child: Row(
                      children: [
                        Expanded(child: Text(m as String, style: HealthTypography.body())),
                        IconButton(
                          onPressed: () => widget.controller.removeMedication(m),
                          icon: const Icon(Icons.close, size: 18),
                        ),
                      ],
                    ),
                  ),
                )),
        ],
      ),
    );
  }
}

class _VitalsStep extends StatelessWidget {
  const _VitalsStep({required this.draft, required this.controller});
  final dynamic draft;
  final OnboardingController controller;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(HealthSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Blood pressure', style: HealthTypography.label()),
          const SizedBox(height: HealthSpacing.sm),
          Row(
            children: [
              Expanded(
                child: _VitalField(
                  label: 'Systolic',
                  vitalKey: 'bp_systolic',
                  draft: draft,
                  controller: controller,
                  hint: '120',
                ),
              ),
              const SizedBox(width: HealthSpacing.sm),
              Expanded(
                child: _VitalField(
                  label: 'Diastolic',
                  vitalKey: 'bp_diastolic',
                  draft: draft,
                  controller: controller,
                  hint: '80',
                ),
              ),
            ],
          ),
          const SizedBox(height: HealthSpacing.lg),
          Text('Blood glucose', style: HealthTypography.label()),
          const SizedBox(height: HealthSpacing.sm),
          _VitalField(
            label: 'Fasting glucose (mg/dL)',
            vitalKey: 'glucose_mg_dl',
            draft: draft,
            controller: controller,
            hint: '95',
          ),
          const SizedBox(height: HealthSpacing.sm),
          Text(
            'All optional — add what you know today, update the rest later from your Medical Profile.',
            style: HealthTypography.body(fontSize: 12.5, color: HealthColors.inkMuted),
          ),
        ],
      ),
    );
  }
}

class _LabScanStep extends ConsumerStatefulWidget {
  const _LabScanStep();

  @override
  ConsumerState<_LabScanStep> createState() => _LabScanStepState();
}

class _LabScanStepState extends ConsumerState<_LabScanStep> {
  final _testController = TextEditingController();
  final _valueController = TextEditingController();
  final _unitController = TextEditingController();
  bool _saving = false;
  bool _scanning = false;
  int _savedCount = 0;
  String? _scanMessage;

  @override
  void dispose() {
    _testController.dispose();
    _valueController.dispose();
    _unitController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_testController.text.trim().isEmpty || _valueController.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      await ref.read(medicalProfileRepositoryProvider).addLabResult(
            testName: _testController.text.trim(),
            value: _valueController.text.trim(),
            unit: _unitController.text.trim().isEmpty ? null : _unitController.text.trim(),
            takenAt: DateTime.now(),
          );
      if (mounted) {
        setState(() => _savedCount += 1);
        _testController.clear();
        _valueController.clear();
        _unitController.clear();
      }
    } catch (_) {
      // Non-blocking — onboarding continues either way.
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _scan() async {
    setState(() {
      _scanning = true;
      _scanMessage = null;
    });
    try {
      final results = await runLabScanFlow(context, ref);
      if (results == null) return; // cancelled before picking a photo
      if (mounted) {
        setState(() {
          _savedCount += results.length;
          _scanMessage = results.isEmpty
              ? "Couldn't read any values from that photo — try typing one in below instead."
              : 'Added ${results.length} value${results.length == 1 ? '' : 's'} from the photo.';
        });
      }
    } catch (_) {
      if (mounted) setState(() => _scanMessage = "Couldn't scan that photo — please try again.");
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(HealthSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Snap a photo and MeMe will pull out what it can read, or type one value in by hand. '
            'Either way, you can skip this entirely and add it later from your Medical Profile.',
            style: HealthTypography.body(color: HealthColors.inkMuted),
          ),
          const SizedBox(height: HealthSpacing.md),
          OutlinedButton.icon(
            onPressed: _scanning ? null : _scan,
            icon: const Icon(Icons.camera_alt_outlined, size: 18),
            label: Text(_scanning ? 'Scanning…' : 'Scan a lab report photo'),
          ),
          if (_scanMessage != null) ...[
            const SizedBox(height: HealthSpacing.sm),
            Text(_scanMessage!, style: HealthTypography.body(fontSize: 12.5, color: HealthColors.inkMuted)),
          ],
          const SizedBox(height: HealthSpacing.lg),
          Text('Or add one by hand', style: HealthTypography.label()),
          const SizedBox(height: HealthSpacing.sm),
          TextField(controller: _testController, decoration: const InputDecoration(labelText: 'Test name (e.g. HbA1c)')),
          const SizedBox(height: HealthSpacing.sm),
          Row(
            children: [
              Expanded(
                child: TextField(controller: _valueController, decoration: const InputDecoration(labelText: 'Value')),
              ),
              const SizedBox(width: HealthSpacing.sm),
              Expanded(
                child: TextField(controller: _unitController, decoration: const InputDecoration(labelText: 'Unit (optional)')),
              ),
            ],
          ),
          const SizedBox(height: HealthSpacing.md),
          OutlinedButton(onPressed: _saving ? null : _save, child: Text(_saving ? 'Saving…' : 'Add this value')),
          if (_savedCount > 0) ...[
            const SizedBox(height: HealthSpacing.sm),
            Text('$_savedCount value${_savedCount == 1 ? '' : 's'} saved to your medical profile.',
                style: HealthTypography.body(color: HealthColors.accentSecondary)),
          ],
        ],
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
