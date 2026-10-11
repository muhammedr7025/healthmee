import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:health_ui/health_ui.dart';
import 'package:intl/intl.dart';

import '../../../core/analytics/analytics.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../goals/data/goals_repository.dart';
import '../../medical_profile/data/medical_profile_repository.dart';
import '../../logbook/data/logbook_repository.dart';
import '../../logbook/domain/log_entry.dart';
import '../../logbook/presentation/entry_detail_screen.dart';
import '../../logbook/presentation/type_tag.dart';
import '../../medications/data/medications_repository.dart';
import '../../medications/domain/medication.dart';
import '../../medications/presentation/add_medication_sheet.dart';
import '../../trends/data/trends_repository.dart';
import '../data/today_repository.dart';
import '../domain/daily_aggregate.dart';
import '../domain/today_score.dart';

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
            ref.invalidate(todayScoreProvider);
            ref.invalidate(todayEntriesProvider);
            ref.invalidate(medicationsTodayProvider);
            ref.invalidate(trendsDataProvider);
          },
          child: asyncAggregate.when(skipLoadingOnReload: true, 
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

String _greetingFor(int hour) {
  if (hour < 5) return 'Still up';
  if (hour < 12) return 'Good morning';
  if (hour < 17) return 'Good afternoon';
  if (hour < 21) return 'Good evening';
  return 'Good night';
}

MascotState _mascotNamed(String? name) =>
    MascotState.values.firstWhere((s) => s.name == name, orElse: () => MascotState.happy);

class _TodayBody extends ConsumerWidget {
  const _TodayBody({required this.aggregate});
  final DailyAggregate aggregate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncGoals = ref.watch(goalsProvider);
    final asyncEntries = ref.watch(todayEntriesProvider);
    final asyncTrends = ref.watch(trendsDataProvider);
    final asyncScore = ref.watch(todayScoreProvider);
    final user = ref.watch(authControllerProvider).user;

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

    final now = DateTime.now();
    final firstName = (user?.fullName ?? '').trim().split(RegExp(r'\s+')).first;
    final greeting = firstName.isEmpty ? _greetingFor(now.hour) : '${_greetingFor(now.hour)}, $firstName';

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
                  Text(greeting, style: HealthTypography.display(fontSize: 26), maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(
                    '${DateFormat('EEEE, d MMMM').format(now)} · ${aggregate.logCount} log${aggregate.logCount == 1 ? '' : 's'}',
                    style: HealthTypography.body(fontSize: 12, color: HealthColors.inkMuted),
                  ),
                ],
              ),
            ),
            MemeMascot(state: _mascotNamed(asyncScore.valueOrNull?.mascot), size: 48),
          ],
        ),
        const SizedBox(height: HealthSpacing.md),
        _ScoreCard(score: asyncScore),
        const SizedBox(height: HealthSpacing.sm),
        _EnergyCard(aggregate: aggregate, goalCalories: calorieGoal),
        const SizedBox(height: HealthSpacing.sm),
        _TodayGrid(aggregate: aggregate),
        const SizedBox(height: HealthSpacing.sm),
        const _MedicinesCard(),
        if (callout != null) ...[
          const SizedBox(height: HealthSpacing.sm),
          NudgeCard(text: callout),
        ],
        const SizedBox(height: HealthSpacing.lg),
        Text("TODAY'S TIMELINE · TAP FOR DETAILS", style: HealthTypography.label()),
        const SizedBox(height: HealthSpacing.sm),
        asyncEntries.when(skipLoadingOnReload: true, 
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

class _ScoreCard extends ConsumerWidget {
  const _ScoreCard({required this.score});
  final AsyncValue<TodayScore> score;

  String _headline(TodayScore s) {
    if (s.score >= 80) return 'A great day of looking after yourself';
    if (s.score >= 60) return 'Solid — a couple of things left to tick';
    if (s.score >= 40) return 'Getting there';
    if (s.score > 0) return 'Just getting started';
    return "Tell MeMe how today's going";
  }

  void _showBreakdown(BuildContext context, WidgetRef ref, TodayScore s) {
    HapticFeedback.lightImpact();
    ref.read(analyticsProvider).track('score_breakdown_opened', {'score': s.score, 'achievable': s.achievable});
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: HealthColors.bgBase,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(HealthSpacing.lg, HealthSpacing.md, HealthSpacing.lg, HealthSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                margin: const EdgeInsets.only(bottom: HealthSpacing.md),
                decoration: BoxDecoration(color: HealthColors.divider, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            Text("How today's score is made", style: HealthTypography.display(fontSize: 20)),
            const SizedBox(height: 4),
            Text(
              '${s.earned} of ${s.achievable} points today → ${s.score}. Every point comes from one of these:',
              style: HealthTypography.body(fontSize: 12.5, color: HealthColors.inkMuted),
            ),
            const SizedBox(height: HealthSpacing.md),
            for (final c in s.components)
              Padding(
                padding: const EdgeInsets.only(bottom: 11),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(c.label, style: HealthTypography.body(fontSize: 13.5, weight: FontWeight.w500))),
                        Text(
                          c.max == 0 ? 'not counted' : '${c.points} / ${c.max}',
                          style: HealthTypography.data(fontSize: 12.5, color: c.max == 0 ? HealthColors.inkFaint : HealthColors.inkPrimary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: c.max == 0 ? 0 : c.points / c.max,
                        minHeight: 5,
                        backgroundColor: HealthColors.chipIdle,
                        valueColor: const AlwaysStoppedAnimation(HealthColors.accentPrimary),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(c.detail, style: HealthTypography.body(fontSize: 11.5, color: HealthColors.inkMuted)),
                  ],
                ),
              ),
            Text(
              'A habit score — how well you looked after yourself today — not a medical measure.',
              style: HealthTypography.body(fontSize: 11, color: HealthColors.inkFaint),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = score.valueOrNull;
    final value = s?.score ?? 0;

    return HealthCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(HealthSpacing.radiusMd),
        onTap: s == null ? null : () => _showBreakdown(context, ref, s),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              SizedBox(
                width: 72,
                height: 72,
                child: TweenAnimationBuilder<double>(
                  duration: const Duration(milliseconds: 700),
                  curve: Curves.easeOutCubic,
                  tween: Tween(begin: 0, end: value / 100),
                  builder: (context, fraction, _) => CustomPaint(
                    painter: _RingPainter(fraction: fraction, color: HealthColors.accentPrimary, track: HealthColors.chipIdle),
                    child: Center(
                      child: s == null
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : Text('$value', style: HealthTypography.display(fontSize: 22)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("TODAY'S SCORE", style: HealthTypography.label()),
                    const SizedBox(height: 4),
                    Text(
                      s == null ? 'Adding it up…' : _headline(s),
                      style: HealthTypography.body(fontSize: 14, weight: FontWeight.w500),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      "A habit score, not a medical one · tap to see how it's made",
                      style: HealthTypography.body(fontSize: 11, color: HealthColors.inkFaint),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({required this.fraction, required this.color, required this.track});
  final double fraction;
  final Color color;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 7.0;
    final rect = Rect.fromLTWH(stroke / 2, stroke / 2, size.width - stroke, size.height - stroke);
    final trackPaint = Paint()
      ..color = track
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    final arcPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, 0, 2 * math.pi, false, trackPaint);
    if (fraction > 0) canvas.drawArc(rect, -math.pi / 2, 2 * math.pi * fraction.clamp(0.0, 1.0), false, arcPaint);
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.fraction != fraction || old.color != color || old.track != track;
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
    final bp = aggregate.systolic == null
        ? null
        : (aggregate.diastolic == null
            ? '${aggregate.systolic!.round()}'
            : '${aggregate.systolic!.round()}/${aggregate.diastolic!.round()}');
    final tiles = [
      ('SLEEP', aggregate.sleepHours != null ? '${aggregate.sleepHours!.toStringAsFixed(1)}h' : '—', 'Last night'),
      ('WATER', '${(aggregate.waterMl / 1000).toStringAsFixed(1)} L', 'Goal 2.5 L'),
      ('ACTIVITY', '${aggregate.activityMinutes.round()} min', 'Today'),
      ('MOOD', aggregate.moodScore != null ? aggregate.moodScore!.toStringAsFixed(1) : '—', 'Steady'),
      if (bp != null) ('BLOOD PRESSURE', bp, 'mmHg · today'),
      if (aggregate.weightKg != null) ('WEIGHT', '${aggregate.weightKg!.toStringAsFixed(1)} kg', 'Latest weigh-in'),
      if (aggregate.glucoseMgDl != null) ('BLOOD SUGAR', '${aggregate.glucoseMgDl!.round()}', 'mg/dL · today'),
    ];
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: HealthSpacing.sm,
      crossAxisSpacing: HealthSpacing.sm,
      childAspectRatio: 1.7,
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

/// "2 of 3 taken" — today's doses with a tick each, from the schedules in
/// the medications module. Empty state invites adding one.
class _MedicinesCard extends ConsumerWidget {
  const _MedicinesCard();

  Future<void> _mark(WidgetRef ref, DoseItem item, String status) async {
    HapticFeedback.selectionClick();
    try {
      await ref.read(medicationsRepositoryProvider).markDose(item.scheduleId, time: item.time, status: status);
    } catch (_) {
      // The refresh below shows the real state either way.
    }
    ref.invalidate(medicationsTodayProvider);
    ref.invalidate(todayScoreProvider);
  }

  Future<void> _add(BuildContext context, WidgetRef ref, {String? initialName}) async {
    final added = await showAddMedicationSheet(context, ref, initialName: initialName);
    if (added == true) {
      ref.invalidate(medicationsTodayProvider);
      ref.invalidate(todayScoreProvider);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncPlan = ref.watch(medicationsTodayProvider);
    // Medicines typed during onboarding live on the profile as names only;
    // offer them here so the schedule isn't an empty list on day one.
    final profileMeds = ref.watch(medicalProfileProvider).valueOrNull?.medications ?? const <String>[];

    return HealthCard(
      padding: const EdgeInsets.all(16),
      child: asyncPlan.when(skipLoadingOnReload: true, 
        loading: () => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('MEDICINES', style: HealthTypography.label()),
            const SizedBox(height: 10),
            const LinearProgressIndicator(minHeight: 3),
          ],
        ),
        error: (e, _) => Row(
          children: [
            Text('MEDICINES', style: HealthTypography.label()),
            const Spacer(),
            Text("Couldn't load", style: HealthTypography.body(fontSize: 12, color: HealthColors.inkMuted)),
          ],
        ),
        data: (plan) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('MEDICINES', style: HealthTypography.label()),
                const Spacer(),
                if (plan.total > 0)
                  Text(
                    '${plan.taken} of ${plan.total} taken',
                    style: HealthTypography.body(
                      fontSize: 12,
                      weight: FontWeight.w500,
                      color: plan.taken == plan.total ? HealthColors.accentSecondary : HealthColors.inkMuted,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (plan.total == 0) ...[
              Text(
                profileMeds.isEmpty
                    ? 'Add what you take and MeMe keeps count each day — it feeds the score too.'
                    : 'You listed these on your profile — add the times and MeMe will keep count.',
                style: HealthTypography.body(fontSize: 13, color: HealthColors.inkMuted),
              ),
              const SizedBox(height: 8),
              if (profileMeds.isNotEmpty) ...[
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: [
                    for (final name in profileMeds.take(6))
                      _Pill(
                        label: '$name · add times',
                        bg: HealthColors.chipIdle,
                        fg: HealthColors.inkPrimary,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          _add(context, ref, initialName: name);
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: () => _add(context, ref),
                  icon: const Icon(Icons.add, size: 16),
                  label: Text(profileMeds.isEmpty ? 'Add a medicine' : 'Add another medicine'),
                ),
              ),
            ] else ...[
              for (final item in plan.items)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 44,
                        child: Text(item.time, style: HealthTypography.data(fontSize: 12, color: HealthColors.inkFaint)),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.name,
                              style: HealthTypography.body(
                                fontSize: 13.5,
                                color: item.status == 'skipped' ? HealthColors.inkFaint : HealthColors.inkPrimary,
                              ),
                            ),
                            if (item.dose != null && item.dose!.isNotEmpty)
                              Text(item.dose!, style: HealthTypography.body(fontSize: 11.5, color: HealthColors.inkMuted)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      _DoseToggle(item: item, onMark: (status) => _mark(ref, item, status)),
                    ],
                  ),
                ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => _add(context, ref),
                  style: TextButton.styleFrom(visualDensity: VisualDensity.compact, padding: EdgeInsets.zero),
                  icon: Icon(Icons.add, size: 15, color: HealthColors.accentPrimaryDark),
                  label: Text('Add another', style: HealthTypography.body(fontSize: 12, color: HealthColors.accentPrimaryDark)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DoseToggle extends StatelessWidget {
  const _DoseToggle({required this.item, required this.onMark});
  final DoseItem item;
  final void Function(String status) onMark;

  @override
  Widget build(BuildContext context) {
    switch (item.status) {
      case 'taken':
        return _Pill(
          label: 'Taken ✓',
          bg: HealthColors.accentSecondary,
          fg: HealthColors.bgBase,
          onTap: () => onMark('pending'),
        );
      case 'skipped':
        return _Pill(
          label: 'Skipped',
          bg: HealthColors.chipIdle,
          fg: HealthColors.inkMuted,
          onTap: () => onMark('taken'),
        );
      default:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Pill(label: 'Taken', bg: HealthColors.inkPrimary, fg: HealthColors.bgBase, onTap: () => onMark('taken')),
            const SizedBox(width: 6),
            _Pill(label: 'Skip', bg: HealthColors.chipIdle, fg: HealthColors.inkMuted, onTap: () => onMark('skipped')),
          ],
        );
    }
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.bg, required this.fg, required this.onTap});
  final String label;
  final Color bg;
  final Color fg;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
          child: Text(label, style: HealthTypography.body(fontSize: 12, weight: FontWeight.w600, color: fg)),
        ),
      ),
    );
  }
}

class _EntryRow extends ConsumerWidget {
  const _EntryRow({required this.entry});
  final LogEntryView entry;

  Future<void> _open(BuildContext context, WidgetRef ref) async {
    HapticFeedback.lightImpact();
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => EntryDetailScreen(entry: entry)),
    );
    if (changed == true) {
      ref.invalidate(todayEntriesProvider);
      ref.invalidate(todayAggregateProvider);
      ref.invalidate(todayScoreProvider);
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
          onTap: () => _open(context, ref),
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
                  child: Text(
                    entry.summary?.isNotEmpty == true ? entry.summary! : TypeTag.labelFor(entry.type),
                    style: HealthTypography.body(fontSize: 13.5),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                TypeTag(entry.type),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
