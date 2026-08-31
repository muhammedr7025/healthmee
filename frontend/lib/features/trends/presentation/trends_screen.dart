import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:health_ui/health_ui.dart';

import '../../today/domain/daily_aggregate.dart';
import '../data/trends_repository.dart';

class TrendsScreen extends ConsumerWidget {
  const TrendsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncTrends = ref.watch(trendsDataProvider);

    return Scaffold(
      appBar: AppBar(title: Text('Trends', style: HealthTypography.display(fontSize: 22))),
      body: asyncTrends.when(
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
                    const KunjanMascot(state: MascotState.idle, size: 96),
                    const SizedBox(height: HealthSpacing.md),
                    Text('Log a few days and trends will start showing up here.',
                        style: HealthTypography.mascotSpeech(), textAlign: TextAlign.center),
                  ],
                ),
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(HealthSpacing.md),
            children: [
              if (trends.callouts.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: HealthSpacing.sm),
                  child: Row(
                    children: [
                      const KunjanMascot(state: MascotState.remembering, size: 40),
                      const SizedBox(width: HealthSpacing.sm),
                      Expanded(child: Text(trends.callouts.first, style: HealthTypography.mascotSpeech(fontSize: 14))),
                    ],
                  ),
                ),
              HealthCard(
                child: SizedBox(
                  height: 200,
                  child: LineChart(_caloriesChartData(trends.days)),
                ),
              ),
              const SizedBox(height: HealthSpacing.lg),
              Text('Day by day', style: HealthTypography.label()),
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
        },
      ),
    );
  }

  LineChartData _caloriesChartData(List<DailyAggregate> days) {
    final spots = [
      for (int i = 0; i < days.length; i++) FlSpot(i.toDouble(), days[i].totalCalories),
    ];
    return LineChartData(
      gridData: const FlGridData(show: false),
      titlesData: const FlTitlesData(show: false),
      borderData: FlBorderData(show: false),
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          isCurved: true,
          color: HealthColors.accentPrimary,
          barWidth: 3,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(show: true, color: HealthColors.accentPrimary.withValues(alpha: 0.12)),
        ),
      ],
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
