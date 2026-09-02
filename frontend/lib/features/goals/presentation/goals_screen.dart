import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:health_ui/health_ui.dart';

import '../../medical_profile/data/medical_profile_repository.dart';
import '../../today/data/today_repository.dart';
import '../../today/domain/streak.dart';
import '../../trends/data/trends_repository.dart';
import '../data/goals_repository.dart';
import '../domain/goal.dart';

const _goalTypeLabels = {
  'weight': 'Weight',
  'blood_pressure': 'Blood pressure',
  'activity': 'Activity',
  'calories': 'Calories',
  'custom': 'Custom',
};

class GoalsScreen extends ConsumerWidget {
  const GoalsScreen({super.key});

  Future<void> _addGoal(BuildContext context, WidgetRef ref) async {
    final typeController = ValueNotifier<String>('weight');
    final valueController = TextEditingController();

    final created = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New goal'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ValueListenableBuilder<String>(
              valueListenable: typeController,
              builder: (context, value, _) => DropdownButtonFormField<String>(
                initialValue: value,
                items: _goalTypeLabels.entries
                    .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                    .toList(),
                onChanged: (v) => typeController.value = v ?? value,
              ),
            ),
            TextField(
              controller: valueController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Target value'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final value = double.tryParse(valueController.text);
              if (value == null) return;
              await ref.read(goalsRepositoryProvider).createGoal(
                    type: typeController.value,
                    targetValue: {'value': value},
                  );
              if (context.mounted) Navigator.pop(context, true);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (created == true) {
      ref.invalidate(goalsProvider);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncGoals = ref.watch(goalsProvider);

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addGoal(context, ref),
        child: const Icon(Icons.add),
      ),
      body: SafeArea(
        child: asyncGoals.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Padding(
            padding: const EdgeInsets.all(HealthSpacing.lg),
            child: AlertBanner(message: "Couldn't load goals.", hard: false),
          ),
          data: (goals) => _GoalsBody(goals: goals),
        ),
      ),
    );
  }
}

class _GoalsBody extends ConsumerWidget {
  const _GoalsBody({required this.goals});
  final List<Goal> goals;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = goals.where((g) => g.status == 'active').toList();
    final asyncTrends = ref.watch(trendsDataProvider);

    return ListView(
      padding: const EdgeInsets.fromLTRB(HealthSpacing.md, HealthSpacing.sm, HealthSpacing.md, HealthSpacing.xl),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Goals', style: HealthTypography.display(fontSize: 27)),
                  Text(
                    active.isEmpty ? 'None active' : '${active.length} active',
                    style: HealthTypography.body(fontSize: 12, color: HealthColors.inkMuted),
                  ),
                ],
              ),
            ),
            const MoMascot(state: MascotState.celebrating, size: 46),
          ],
        ),
        const SizedBox(height: HealthSpacing.md),
        asyncTrends.when(
          loading: () => const SizedBox.shrink(),
          error: (e, _) => const SizedBox.shrink(),
          data: (trends) => _StreakCard(trends: trends),
        ),
        const SizedBox(height: HealthSpacing.md),
        if (goals.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(HealthSpacing.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const MoMascot(state: MascotState.idle, size: 96),
                  const SizedBox(height: HealthSpacing.md),
                  Text('No goals yet — tap + to set one with Mo.',
                      style: HealthTypography.mascotSpeech(), textAlign: TextAlign.center),
                ],
              ),
            ),
          )
        else
          ...goals.map((g) => Padding(
                padding: const EdgeInsets.only(bottom: HealthSpacing.sm),
                child: _GoalCard(goal: g),
              )),
        const SizedBox(height: HealthSpacing.lg),
        Text('MILESTONES', style: HealthTypography.label()),
        const SizedBox(height: HealthSpacing.sm),
        asyncTrends.when(
          loading: () => const SizedBox.shrink(),
          error: (e, _) => const SizedBox.shrink(),
          data: (trends) => _MilestonesList(streak: computeStreak(trends)),
        ),
      ],
    );
  }
}

class _StreakCard extends StatelessWidget {
  const _StreakCard({required this.trends});
  final TrendsData trends;

  @override
  Widget build(BuildContext context) {
    final streak = computeStreak(trends);
    if (streak == 0) return const SizedBox.shrink();

    final byDate = {for (final d in trends.days) d.date: d.logCount};
    final today = DateTime.now();
    final dots = List.generate(14, (i) {
      final day = today.subtract(Duration(days: 13 - i));
      final key = day.toIso8601String().split('T').first;
      return (byDate[key] ?? 0) > 0;
    });

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: HealthColors.inkPrimary, borderRadius: BorderRadius.circular(22)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('LOGGING STREAK', style: HealthTypography.label(color: HealthColors.accentTertiary)),
              Text('$streak days', style: HealthTypography.display(fontSize: 26).copyWith(color: HealthColors.bgBase)),
            ],
          ),
          const SizedBox(height: 15),
          Row(
            children: dots
                .map((filled) => Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2.5),
                        child: Container(
                          height: 26,
                          decoration: BoxDecoration(
                            color: filled ? HealthColors.accentPrimary : HealthColors.inkPrimary.withValues(alpha: 0.4),
                            border: filled ? null : Border.all(color: HealthColors.accentTertiary.withValues(alpha: 0.3)),
                            borderRadius: BorderRadius.circular(5),
                          ),
                        ),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 10),
          Text(
            'This counts days you told Mo something — not days you hit a number. Miss one and nothing resets to zero.',
            style: HealthTypography.body(fontSize: 12.5, color: HealthColors.accentTertiary),
          ),
        ],
      ),
    );
  }
}

class _MilestonesList extends ConsumerWidget {
  const _MilestonesList({required this.streak});
  final int streak;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncLabs = ref.watch(labResultsProvider);
    final hasLab = asyncLabs.maybeWhen(data: (labs) => labs.isNotEmpty, orElse: () => false);

    final milestones = [
      ('Logged 7 days in a row', streak >= 7),
      ('Logged 14 days in a row', streak >= 14),
      ('First lab result added', hasLab),
    ];

    return Column(
      children: milestones
          .map((m) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
                  decoration: BoxDecoration(
                    color: HealthColors.surface,
                    border: Border.all(color: HealthColors.inkPrimary.withValues(alpha: 0.09)),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      if (m.$2)
                        Container(
                          width: 22,
                          height: 22,
                          decoration: const BoxDecoration(color: HealthColors.accentPrimary, shape: BoxShape.circle),
                          child: const Center(child: Icon(Icons.check, size: 13, color: Colors.white)),
                        )
                      else
                        Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: HealthColors.inkFaint, width: 1.5),
                          ),
                        ),
                      const SizedBox(width: 11),
                      Expanded(child: Text(m.$1, style: HealthTypography.body(fontSize: 13.5))),
                    ],
                  ),
                ),
              ))
          .toList(),
    );
  }
}

class _GoalCard extends ConsumerStatefulWidget {
  const _GoalCard({required this.goal});
  final Goal goal;

  @override
  ConsumerState<_GoalCard> createState() => _GoalCardState();
}

class _GoalCardState extends ConsumerState<_GoalCard> {
  bool _celebrating = false;

  void _celebrate() {
    setState(() => _celebrating = true);
    Future.delayed(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _celebrating = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final goal = widget.goal;
    final target = goal.targetValue['value'];
    final targetLabel = target != null ? '$target' : '—';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: HealthColors.surface,
        border: Border.all(color: HealthColors.inkPrimary.withValues(alpha: 0.09)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              MoMascot(state: _celebrating ? MascotState.celebrating : MascotState.idle, size: 32),
              const SizedBox(width: 8),
              Expanded(child: Text(_goalTypeLabels[goal.type] ?? goal.type, style: HealthTypography.body(fontSize: 14.5, weight: FontWeight.w500))),
              if (goal.status == 'active')
                IconButton(
                  onPressed: _celebrate,
                  icon: const Icon(Icons.emoji_events_outlined, size: 20),
                  tooltip: 'Mark milestone reached',
                  color: HealthColors.accentSecondary,
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
          const SizedBox(height: 4),
          _GoalProgress(goal: goal, targetLabel: targetLabel),
        ],
      ),
    );
  }
}

/// Real progress where the data exists (today's/last-7-days actuals against
/// the target); a plain current-vs-target readout where it doesn't (no
/// server-side time series exists for weight/BP — only the latest medical
/// profile snapshot), rather than a fabricated percentage.
class _GoalProgress extends ConsumerWidget {
  const _GoalProgress({required this.goal, required this.targetLabel});
  final Goal goal;
  final String targetLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    switch (goal.type) {
      case 'calories':
        final asyncToday = ref.watch(todayAggregateProvider);
        return asyncToday.when(
          loading: () => const SizedBox.shrink(),
          error: (e, _) => const SizedBox.shrink(),
          data: (today) {
            final target = (goal.targetValue['value'] as num?)?.toDouble() ?? 1;
            final pct = (today.totalCalories / target).clamp(0.0, 1.0);
            return _Bar(pct: pct, now: '${today.totalCalories.round()} kcal today', target: '$targetLabel kcal');
          },
        );
      case 'activity':
        final asyncTrends = ref.watch(trendsDataProvider);
        return asyncTrends.when(
          loading: () => const SizedBox.shrink(),
          error: (e, _) => const SizedBox.shrink(),
          data: (trends) {
            final last7 = trends.days.length > 7 ? trends.days.sublist(trends.days.length - 7) : trends.days;
            final total = last7.fold(0.0, (sum, d) => sum + d.activityMinutes);
            final target = (goal.targetValue['value'] as num?)?.toDouble() ?? 1;
            final pct = (total / target).clamp(0.0, 1.0);
            return _Bar(pct: pct, now: '${total.round()} min this week', target: '$targetLabel min/wk');
          },
        );
      case 'weight':
        final asyncProfile = ref.watch(medicalProfileProvider);
        return asyncProfile.when(
          loading: () => const SizedBox.shrink(),
          error: (e, _) => const SizedBox.shrink(),
          data: (profile) {
            final current = profile.baselineVitals['weight_kg'];
            return _CurrentVsTarget(now: current != null ? '$current kg' : 'Not recorded', target: '$targetLabel kg');
          },
        );
      case 'blood_pressure':
        final asyncProfile = ref.watch(medicalProfileProvider);
        return asyncProfile.when(
          loading: () => const SizedBox.shrink(),
          error: (e, _) => const SizedBox.shrink(),
          data: (profile) {
            final sys = profile.baselineVitals['bp_systolic'];
            final dia = profile.baselineVitals['bp_diastolic'];
            final now = (sys != null && dia != null) ? '$sys/$dia' : 'Not recorded';
            return _CurrentVsTarget(now: now, target: targetLabel);
          },
        );
      default:
        return _CurrentVsTarget(now: 'Target', target: targetLabel);
    }
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.pct, required this.now, required this.target});
  final double pct;
  final String now;
  final String target;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct,
            minHeight: 8,
            backgroundColor: HealthColors.chipIdle,
            valueColor: const AlwaysStoppedAnimation(HealthColors.accentPrimary),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(now, style: HealthTypography.body(fontSize: 12, color: HealthColors.inkMuted)),
            Text(target, style: HealthTypography.body(fontSize: 12, color: HealthColors.inkMuted)),
          ],
        ),
      ],
    );
  }
}

class _CurrentVsTarget extends StatelessWidget {
  const _CurrentVsTarget({required this.now, required this.target});
  final String now;
  final String target;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Now: $now', style: HealthTypography.body(fontSize: 12.5, color: HealthColors.inkMuted)),
          Text('Target: $target', style: HealthTypography.body(fontSize: 12.5, color: HealthColors.inkMuted)),
        ],
      ),
    );
  }
}
