import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:health_ui/health_ui.dart';
import 'package:intl/intl.dart';

import '../../../core/app_navigation.dart';
import '../../reports/presentation/reports_screen.dart';
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
final _trendsViewProvider = StateProvider.autoDispose<String>((ref) => 'charts'); // charts|read

class TrendsScreen extends ConsumerWidget {
  const TrendsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncTrends = ref.watch(trendsDataProvider);
    final view = ref.watch(_trendsViewProvider);

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
                      const MemeMascot(state: MascotState.idle, size: 96),
                      const SizedBox(height: HealthSpacing.md),
                      Text('Log a few days and trends will start showing up here.',
                          style: HealthTypography.mascotSpeech(), textAlign: TextAlign.center),
                    ],
                  ),
                ),
              );
            }
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(HealthSpacing.md, HealthSpacing.sm, HealthSpacing.md, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Trends', style: HealthTypography.display(fontSize: 27)),
                      const SizedBox(height: 4),
                      Text('Last ${trends.days.length} days', style: HealthTypography.body(fontSize: 12, color: HealthColors.inkMuted)),
                      const SizedBox(height: 13),
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(color: HealthColors.chipIdle, borderRadius: BorderRadius.circular(14)),
                        child: Row(
                          children: [
                            Expanded(
                              child: _ViewTab(
                                label: 'Charts',
                                selected: view == 'charts',
                                onTap: () => ref.read(_trendsViewProvider.notifier).state = 'charts',
                              ),
                            ),
                            Expanded(
                              child: _ViewTab(
                                label: 'Read',
                                selected: view == 'read',
                                onTap: () => ref.read(_trendsViewProvider.notifier).state = 'read',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(child: view == 'charts' ? _TrendsBody(trends: trends) : const _ReadView()),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ViewTab extends StatelessWidget {
  const _ViewTab({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? HealthColors.inkPrimary : Colors.transparent,
      borderRadius: BorderRadius.circular(11),
      child: InkWell(
        borderRadius: BorderRadius.circular(11),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 9),
          child: Center(
            child: Text(
              label,
              style: HealthTypography.body(fontSize: 12.5, weight: FontWeight.w500, color: selected ? HealthColors.bgBase : HealthColors.inkMuted),
            ),
          ),
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
      padding: const EdgeInsets.fromLTRB(HealthSpacing.md, HealthSpacing.md, HealthSpacing.md, HealthSpacing.lg),
      children: [
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
                const MemeMascot(state: MascotState.remembering, size: 38),
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

const _periods = [('today', 'Today'), ('week', 'Week'), ('month', 'Month')];

class _ReadView extends ConsumerWidget {
  const _ReadView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(narrativePeriodProvider);
    final asyncNarrative = ref.watch(narrativeProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(HealthSpacing.md, HealthSpacing.md, HealthSpacing.md, 0),
          child: Row(
            children: _periods
                .map((p) => Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 5),
                        child: _ViewTab(
                          label: p.$2,
                          selected: period == p.$1,
                          onTap: () => ref.read(narrativePeriodProvider.notifier).state = p.$1,
                        ),
                      ),
                    ))
                .toList(),
          ),
        ),
        Expanded(
          child: asyncNarrative.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Padding(
              padding: const EdgeInsets.all(HealthSpacing.lg),
              child: AlertBanner(message: "Couldn't load your summary.", hard: false),
            ),
            data: (narrative) => ListView(
              padding: const EdgeInsets.fromLTRB(HealthSpacing.md, HealthSpacing.md, HealthSpacing.md, HealthSpacing.lg),
              children: [
                Container(
                  padding: const EdgeInsets.all(17),
                  decoration: BoxDecoration(
                    color: HealthColors.surface,
                    border: Border.all(color: HealthColors.inkPrimary.withValues(alpha: 0.09)),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const MemeMascot(state: MascotState.remembering, size: 42),
                          const SizedBox(width: 11),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Your ${period == 'today' ? "today" : period} in review',
                                    style: HealthTypography.body(fontSize: 14, weight: FontWeight.w500)),
                                Text('${narrative.start} to ${narrative.end}',
                                    style: HealthTypography.body(fontSize: 11, color: HealthColors.inkFaint)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 13),
                      Text(narrative.summary, style: HealthTypography.body(fontSize: 14, color: const Color(0xFF332C25))),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  mainAxisSpacing: 9,
                  crossAxisSpacing: 9,
                  childAspectRatio: 2.1,
                  children: [
                    _StatTile(label: 'Days logged', value: '${narrative.stats.daysLogged}/${narrative.stats.daysTotal}'),
                    _StatTile(label: 'Entries', value: '${narrative.stats.logCount}'),
                    if (narrative.stats.avgSleep != null)
                      _StatTile(label: 'Avg sleep', value: '${narrative.stats.avgSleep!.toStringAsFixed(1)}h'),
                    if (narrative.stats.avgMood != null)
                      _StatTile(label: 'Avg mood', value: '${narrative.stats.avgMood!.toStringAsFixed(1)}/5'),
                  ],
                ),
                if (narrative.wins.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _CalloutBox(
                    label: 'GOING WELL',
                    labelColor: HealthColors.accentSecondary,
                    bg: const Color(0xFFEEF0E2),
                    borderColor: HealthColors.accentSecondary.withValues(alpha: 0.35),
                    textColor: const Color(0xFF3C4A33),
                    items: narrative.wins,
                  ),
                ],
                if (narrative.watch.isNotEmpty) ...[
                  const SizedBox(height: 9),
                  _CalloutBox(
                    label: 'WORTH A LOOK',
                    labelColor: HealthColors.accentPrimaryDark,
                    bg: const Color(0xFFFDEEE4),
                    borderColor: HealthColors.accentPrimary.withValues(alpha: 0.3),
                    textColor: HealthColors.reactionText,
                    items: narrative.watch,
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          ref.read(pendingChatMessageProvider.notifier).state =
                              'Explain my ${period == 'today' ? "today's" : "$period's"} summary';
                          ref.read(activeTabProvider.notifier).state = chatTabIndex;
                        },
                        child: const Text('Ask MeMe about this'),
                      ),
                    ),
                    const SizedBox(width: 9),
                    OutlinedButton(
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReportsScreen())),
                      child: const Text('Export'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'MeMe reads patterns in your own logs. It is not a diagnosis, and it doesn\'t replace your doctor.',
                  style: HealthTypography.body(fontSize: 11, color: HealthColors.inkFaint),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
      decoration: BoxDecoration(
        color: HealthColors.surface,
        border: Border.all(color: HealthColors.inkPrimary.withValues(alpha: 0.09)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: HealthTypography.label(fontSize: 10)),
          const SizedBox(height: 3),
          Text(value, style: HealthTypography.display(fontSize: 19)),
        ],
      ),
    );
  }
}

class _CalloutBox extends StatelessWidget {
  const _CalloutBox({
    required this.label,
    required this.labelColor,
    required this.bg,
    required this.borderColor,
    required this.textColor,
    required this.items,
  });
  final String label;
  final Color labelColor;
  final Color bg;
  final Color borderColor;
  final Color textColor;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: bg, border: Border.all(color: borderColor), borderRadius: BorderRadius.circular(18)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: HealthTypography.label(color: labelColor)),
          const SizedBox(height: 8),
          ...items.map((w) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(w, style: HealthTypography.body(fontSize: 13, color: textColor)),
              )),
        ],
      ),
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
