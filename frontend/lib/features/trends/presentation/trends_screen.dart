import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:health_ui/health_ui.dart';
import 'package:intl/intl.dart';

import '../../today/domain/daily_aggregate.dart';
import '../data/trends_repository.dart';

class _Metric {
  const _Metric(this.key, this.label, this.unit, this.get, this.color);
  final String key;
  final String label;
  final String unit;
  final double? Function(DailyAggregate) get;
  final Color color;
}

final _metrics = [
  _Metric('calories', 'Calories', 'kcal', (d) => d.totalCalories, HealthColors.accentPrimary),
  _Metric('sleep', 'Sleep', 'h', (d) => d.sleepHours, HealthColors.inkPrimary),
  _Metric('activity', 'Activity', 'min', (d) => d.activityMinutes, HealthColors.accentSecondary),
  _Metric('mood', 'Mood', '/5', (d) => d.moodScore, HealthColors.accentTertiary),
  _Metric('water', 'Water', 'L', (d) => d.waterMl / 1000, HealthColors.accentTertiary),
];

final _selectedMetricProvider = StateProvider<String>((ref) => 'calories');

class TrendsScreen extends ConsumerWidget {
  const TrendsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncTrends = ref.watch(trendsDataProvider);

    return Scaffold(
      body: SafeArea(
        child: asyncTrends.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Padding(
            padding: const EdgeInsets.all(HealthSpacing.lg),
            child: AlertBanner(message: "Couldn't load trends.", hard: false),
          ),
          data: (trends) {
            if (trends.days.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(HealthSpacing.xl),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const MoMascot(state: MascotState.idle, size: 96),
                      const SizedBox(height: HealthSpacing.md),
                      Text('Log a few days and trends will start showing up here.',
                          style: HealthTypography.mascotSpeech(), textAlign: TextAlign.center),
                    ],
                  ),
                ),
              );
            }
            return _TrendsBody(trends: trends);
          },
        ),
      ),
    );
  }
}

class _TrendsBody extends ConsumerWidget {
  const _TrendsBody({required this.trends});
  final TrendsData trends;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedKey = ref.watch(_selectedMetricProvider);
    final metric = _metrics.firstWhere((m) => m.key == selectedKey);
    final recentDays = trends.days.length > 7 ? trends.days.sublist(trends.days.length - 7) : trends.days;
    final values = recentDays.map(metric.get).toList();
    final present = values.whereType<double>().toList();
    final delta = present.length >= 2 ? present.last - present.first : 0.0;

    return ListView(
      padding: const EdgeInsets.fromLTRB(HealthSpacing.md, HealthSpacing.sm, HealthSpacing.md, HealthSpacing.lg),
      children: [
        Text('Trends', style: HealthTypography.display(fontSize: 27)),
        const SizedBox(height: 4),
        Text('Last ${trends.days.length} days', style: HealthTypography.body(fontSize: 12, color: HealthColors.inkMuted)),
        const SizedBox(height: 13),
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: _metrics
                .map((m) => Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: _Pill(
                        label: m.label,
                        selected: m.key == selectedKey,
                        onTap: () => ref.read(_selectedMetricProvider.notifier).state = m.key,
                      ),
                    ))
                .toList(),
          ),
        ),
        const SizedBox(height: 16),
        HealthCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(metric.label, style: HealthTypography.body(fontSize: 13.5, weight: FontWeight.w500)),
                  Text(
                    delta == 0 ? '—' : '${delta > 0 ? '+' : ''}${delta.toStringAsFixed(1)} ${metric.unit}',
                    style: HealthTypography.body(fontSize: 12, color: HealthColors.accentPrimary),
                  ),
                ],
              ),
              SizedBox(
                height: 150,
                child: Padding(
                  padding: const EdgeInsets.only(top: 18),
                  child: BarChart(
                    BarChartData(
                      gridData: const FlGridData(show: false),
                      borderData: FlBorderData(show: false),
                      titlesData: FlTitlesData(
                        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 22,
                            getTitlesWidget: (value, meta) {
                              final i = value.toInt();
                              if (i < 0 || i >= recentDays.length) return const SizedBox.shrink();
                              final date = DateTime.parse(recentDays[i].date);
                              return Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(DateFormat('E').format(date).substring(0, 1), style: HealthTypography.label()),
                              );
                            },
                          ),
                        ),
                      ),
                      barGroups: [
                        for (int i = 0; i < recentDays.length; i++)
                          BarChartGroupData(
                            x: i,
                            barRods: [
                              BarChartRodData(
                                toY: values[i] ?? 0,
                                color: metric.color,
                                width: 18,
                                borderRadius: const BorderRadius.only(topLeft: Radius.circular(6), topRight: Radius.circular(6)),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (trends.callouts.isNotEmpty) ...[
          const SizedBox(height: HealthSpacing.sm),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: HealthColors.reactionBubble,
              border: Border.all(color: HealthColors.accentPrimary.withValues(alpha: 0.25)),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const MoMascot(state: MascotState.remembering, size: 38),
                const SizedBox(width: 12),
                Expanded(child: Text(trends.callouts.first, style: HealthTypography.body(fontSize: 14, color: HealthColors.reactionText))),
              ],
            ),
          ),
        ],
        if (trends.callouts.length > 1) ...[
          const SizedBox(height: HealthSpacing.lg),
          Text('CORRELATIONS I FOUND', style: HealthTypography.label()),
          const SizedBox(height: 9),
          ...trends.callouts.skip(1).map((c) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
                  decoration: BoxDecoration(
                    color: HealthColors.surface,
                    border: Border.all(color: HealthColors.inkPrimary.withValues(alpha: 0.09)),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(c, style: HealthTypography.body(fontSize: 12.5, color: HealthColors.inkMuted)),
                ),
              )),
        ],
        const SizedBox(height: HealthSpacing.lg),
        Text('DAY BY DAY', style: HealthTypography.label()),
        const SizedBox(height: HealthSpacing.sm),
        SizedBox(
          height: trends.days.length * 84.0,
          child: MemoryTrailTimeline(
            itemCount: trends.days.length,
            itemBuilder: (context, index) {
              final day = trends.days[trends.days.length - 1 - index];
              return _DayRow(day: day);
            },
          ),
        ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? HealthColors.inkPrimary : HealthColors.chipIdle,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Text(
            label,
            style: HealthTypography.body(fontSize: 12.5, weight: FontWeight.w500, color: selected ? HealthColors.bgBase : HealthColors.inkMuted),
          ),
        ),
      ),
    );
  }
}

class _DayRow extends StatelessWidget {
  const _DayRow({required this.day});
  final DailyAggregate day;

  @override
  Widget build(BuildContext context) {
    return HealthCard(
      padding: const EdgeInsets.symmetric(horizontal: HealthSpacing.md, vertical: HealthSpacing.sm),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(day.date, style: HealthTypography.label()),
                Text('${day.totalCalories.round()} kcal · ${day.activityMinutes.round()} min active',
                    style: HealthTypography.body(fontSize: 13)),
              ],
            ),
          ),
          if (day.sleepHours != null) Text('${day.sleepHours!.toStringAsFixed(1)}h sleep', style: HealthTypography.data(fontSize: 13)),
        ],
      ),
    );
  }
}
