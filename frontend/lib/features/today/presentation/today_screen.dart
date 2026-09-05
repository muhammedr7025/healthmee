import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:health_ui/health_ui.dart';
import 'package:intl/intl.dart';

import '../../goals/data/goals_repository.dart';
import '../../logbook/data/logbook_repository.dart';
import '../../logbook/domain/log_entry.dart';
import '../../trends/data/trends_repository.dart';
import '../data/today_repository.dart';
import '../domain/daily_aggregate.dart';

class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncAggregate = ref.watch(todayAggregateProvider);

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(todayAggregateProvider);
            ref.invalidate(todayEntriesProvider);
            ref.invalidate(trendsDataProvider);
          },
          child: asyncAggregate.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => ListView(
              children: [
                Padding(
                  padding: const EdgeInsets.all(HealthSpacing.lg),
                  child: AlertBanner(message: "Couldn't load today's summary.", hard: false),
                ),
              ],
            ),
            data: (aggregate) => _TodayBody(aggregate: aggregate),
          ),
        ),
      ),
    );
  }
}

class _TodayBody extends ConsumerWidget {
  const _TodayBody({required this.aggregate});
  final DailyAggregate aggregate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncGoals = ref.watch(goalsProvider);
    final asyncEntries = ref.watch(todayEntriesProvider);
    final asyncTrends = ref.watch(trendsDataProvider);

    final calorieGoal = asyncGoals.maybeWhen(
      data: (goals) {
        final matches = goals.where((g) => g.type == 'calories');
        if (matches.isEmpty) return null;
        final v = matches.first.targetValue['value'];
        return v is num ? v.toDouble() : null;
      },
      orElse: () => null,
    );

    final callout = asyncTrends.maybeWhen(
      data: (t) => t.callouts.isNotEmpty ? t.callouts.first : null,
      orElse: () => null,
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(HealthSpacing.md, HealthSpacing.sm, HealthSpacing.md, HealthSpacing.lg),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(DateFormat('EEEE').format(DateTime.now()), style: HealthTypography.display(fontSize: 27)),
                  Text(
                    '${DateFormat('d MMMM').format(DateTime.now())} · ${aggregate.logCount} logs',
                    style: HealthTypography.body(fontSize: 12, color: HealthColors.inkMuted),
                  ),
                ],
              ),
            ),
            const MemeMascot(state: MascotState.idle, size: 44),
          ],
        ),
        const SizedBox(height: HealthSpacing.md),
        _EnergyCard(aggregate: aggregate, goalCalories: calorieGoal),
        const SizedBox(height: HealthSpacing.sm),
        _TodayGrid(aggregate: aggregate),
        if (callout != null) ...[
          const SizedBox(height: HealthSpacing.sm),
          _NudgeCard(text: callout),
        ],
        const SizedBox(height: HealthSpacing.lg),
        Text('ENTRIES · TAP TO EDIT', style: HealthTypography.label()),
        const SizedBox(height: HealthSpacing.sm),
        asyncEntries.when(
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => Text('Could not load entries.', style: HealthTypography.body()),
          data: (entries) => entries.isEmpty
              ? Text('Nothing logged yet today.', style: HealthTypography.body(color: HealthColors.inkMuted))
              : Column(
                  children: entries.map((e) => _EntryRow(entry: e)).toList(),
                ),
        ),
      ],
    );
  }
}

class _EnergyCard extends StatelessWidget {
  const _EnergyCard({required this.aggregate, this.goalCalories});
  final DailyAggregate aggregate;
  final double? goalCalories;

  @override
  Widget build(BuildContext context) {
    final goal = goalCalories ?? 2000;
    final pct = (aggregate.totalCalories / goal).clamp(0.0, 1.0);

    return HealthCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('ENERGY', style: HealthTypography.label()),
              Text(
                '${aggregate.totalCalories.round()} / ${goal.round()} kcal',
                style: HealthTypography.body(fontSize: 12, color: HealthColors.inkMuted),
              ),
            ],
          ),
          const SizedBox(height: 11),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 8,
              backgroundColor: HealthColors.chipIdle,
              valueColor: const AlwaysStoppedAnimation(HealthColors.accentPrimary),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _MiniStat(label: 'Activity', value: '${aggregate.activityMinutes.round()} min'),
              ),
              Expanded(
                child: _MiniStat(label: 'Water', value: '${(aggregate.waterMl / 1000).toStringAsFixed(1)} L'),
              ),
              Expanded(
                child: _MiniStat(label: 'Mood', value: aggregate.moodScore != null ? aggregate.moodScore!.toStringAsFixed(1) : '—'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: HealthTypography.body(fontSize: 11, color: HealthColors.inkFaint)),
        const SizedBox(height: 2),
        Text(value, style: HealthTypography.body(fontSize: 15, weight: FontWeight.w500)),
      ],
    );
  }
}

class _TodayGrid extends StatelessWidget {
  const _TodayGrid({required this.aggregate});
  final DailyAggregate aggregate;

  @override
  Widget build(BuildContext context) {
    final tiles = [
      ('SLEEP', aggregate.sleepHours != null ? '${aggregate.sleepHours!.toStringAsFixed(1)}h' : '—', 'Last night'),
      ('WATER', '${(aggregate.waterMl / 1000).toStringAsFixed(1)} L', 'Goal 2.5 L'),
      ('ACTIVITY', '${aggregate.activityMinutes.round()} min', 'Today'),
      ('MOOD', aggregate.moodScore != null ? aggregate.moodScore!.toStringAsFixed(1) : '—', 'Steady'),
    ];
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: HealthSpacing.sm,
      crossAxisSpacing: HealthSpacing.sm,
      childAspectRatio: 1.85,
      children: tiles
          .map((t) => Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: HealthColors.surface,
                  border: Border.all(color: HealthColors.inkPrimary.withValues(alpha: 0.09)),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t.$1, style: HealthTypography.label()),
                    const SizedBox(height: 4),
                    Text(t.$2, style: HealthTypography.display(fontSize: 22)),
                    const SizedBox(height: 2),
                    Text(t.$3, style: HealthTypography.body(fontSize: 11, color: HealthColors.inkMuted)),
                  ],
                ),
              ))
          .toList(),
    );
  }
}

class _NudgeCard extends StatelessWidget {
  const _NudgeCard({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: HealthColors.reactionBubble,
        border: Border.all(color: HealthColors.accentPrimary.withValues(alpha: 0.25)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const MemeMascot(state: MascotState.remembering, size: 38),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: HealthTypography.body(fontSize: 14, color: HealthColors.reactionText))),
        ],
      ),
    );
  }
}

class _EntryRow extends ConsumerWidget {
  const _EntryRow({required this.entry});
  final LogEntryView entry;

  Future<void> _edit(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController(text: entry.summary ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit entry'),
        content: TextField(controller: controller, maxLines: 3, autofocus: true),
        actions: [
          TextButton(
            onPressed: () async {
              await ref.read(logbookRepositoryProvider).deleteEntry(entry.id);
              if (context.mounted) Navigator.pop(context, '__deleted__');
            },
            child: Text('Delete', style: TextStyle(color: HealthColors.alertTrigger)),
          ),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Save')),
        ],
      ),
    );
    if (result != null) {
      if (result != '__deleted__') {
        await ref.read(logbookRepositoryProvider).editEntrySummary(entry.id, result);
      }
      ref.invalidate(todayEntriesProvider);
      ref.invalidate(todayAggregateProvider);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: HealthColors.surface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _edit(context, ref),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              border: Border.all(color: HealthColors.inkPrimary.withValues(alpha: 0.09)),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Text(DateFormat('HH:mm').format(entry.timestamp), style: HealthTypography.data(fontSize: 10.5, color: HealthColors.inkFaint)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(entry.summary ?? entry.type, style: HealthTypography.body(fontSize: 13.5)),
                      Text(entry.type, style: HealthTypography.body(fontSize: 11.5, color: HealthColors.inkMuted)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
