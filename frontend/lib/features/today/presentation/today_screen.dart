import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:health_ui/health_ui.dart';

import '../data/today_repository.dart';
import '../domain/daily_aggregate.dart';

class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncAggregate = ref.watch(todayAggregateProvider);

    return Scaffold(
      appBar: AppBar(title: Text('Today', style: HealthTypography.display(fontSize: 22))),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(todayAggregateProvider.future),
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
          data: (aggregate) => _TodayGrid(aggregate: aggregate),
        ),
      ),
    );
  }
}

class _TodayGrid extends StatelessWidget {
  const _TodayGrid({required this.aggregate});
  final DailyAggregate aggregate;

  @override
  Widget build(BuildContext context) {
    final tiles = [
      _Tile(icon: Icons.local_fire_department_outlined, label: 'Calories', value: aggregate.totalCalories.round().toString(), color: HealthColors.accentPrimary),
      _Tile(icon: Icons.water_drop_outlined, label: 'Water', value: '${(aggregate.waterMl / 1000).toStringAsFixed(1)} L', color: HealthColors.accentTertiary),
      _Tile(icon: Icons.directions_run, label: 'Activity', value: '${aggregate.activityMinutes.round()} min', color: HealthColors.accentSecondary),
      _Tile(icon: Icons.mood_outlined, label: 'Mood', value: aggregate.moodScore != null ? aggregate.moodScore!.toStringAsFixed(1) : '—', color: HealthColors.accentTertiary),
      _Tile(icon: Icons.bedtime_outlined, label: 'Sleep', value: aggregate.sleepHours != null ? '${aggregate.sleepHours!.toStringAsFixed(1)}h' : '—', color: HealthColors.inkPrimary),
    ];

    return GridView.count(
      padding: const EdgeInsets.all(HealthSpacing.md),
      crossAxisCount: 2,
      mainAxisSpacing: HealthSpacing.sm,
      crossAxisSpacing: HealthSpacing.sm,
      childAspectRatio: 1.3,
      children: tiles,
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.icon, required this.label, required this.value, required this.color});
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return HealthCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const Spacer(),
          Text(value, style: HealthTypography.data(fontSize: 24)),
          Text(label, style: HealthTypography.label()),
        ],
      ),
    );
  }
}
