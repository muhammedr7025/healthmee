import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:health_ui/health_ui.dart';

import '../../billing/presentation/paywall_screen.dart';
import '../../logbook/data/logbook_repository.dart';
import '../../medical_profile/data/medical_profile_repository.dart';
import '../../trends/data/trends_repository.dart';
import '../data/reports_repository.dart';

enum _ReportStatus { idle, busy, unavailable }

const _ranges = [(7, '7 days'), (30, '30 days'), (90, '90 days')];
final _rangeDaysProvider = StateProvider.autoDispose<int>((ref) => 30);

/// Real, range-scoped checks — not a decorative always-on checklist.
final _reportChecklistProvider = FutureProvider.autoDispose((ref) async {
  final days = ref.watch(_rangeDaysProvider);
  final since = DateTime.now().subtract(Duration(days: days));

  final entries = await ref.read(logbookRepositoryProvider).fetchEntries(start: since);
  final trends = await ref.read(trendsRepositoryProvider).fetchTrends(start: since);
  final labs = await ref.read(medicalProfileRepositoryProvider).fetchLabResults();

  final labsInRange = labs.where((l) => l.takenAt.isAfter(since)).toList();

  return {
    'hasLogs': entries.isNotEmpty,
    'hasTrends': trends.days.isNotEmpty,
    'hasLabs': labsInRange.isNotEmpty,
    'logCount': entries.length,
  };
});

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  _ReportStatus _status = _ReportStatus.idle;
  String? _message;

  Future<void> _generate() async {
    setState(() {
      _status = _ReportStatus.busy;
      _message = null;
    });
    try {
      await ref.read(reportsRepositoryProvider).requestExport();
    } catch (e) {
      String? serverMessage;
      if (e is DioException) {
        final data = e.response?.data;
        if (data is Map && data['message'] is String) serverMessage = data['message'] as String;
      }
      setState(() {
        _status = _ReportStatus.unavailable;
        _message = serverMessage ?? "PDF export isn't available yet.";
      });
      return;
    }
    setState(() => _status = _ReportStatus.idle);
  }

  @override
  Widget build(BuildContext context) {
    final range = ref.watch(_rangeDaysProvider);

    return Scaffold(
      appBar: AppBar(title: Text('Doctor report', style: HealthTypography.display(fontSize: 22))),
      body: ListView(
        padding: const EdgeInsets.all(HealthSpacing.md),
        children: [
          Text(
            'One PDF with your logs, trends and lab history. Built to hand over, not to decode.',
            style: HealthTypography.body(fontSize: 13, color: HealthColors.inkMuted),
          ),
          const SizedBox(height: HealthSpacing.md),
          Row(
            children: _ranges
                .map((r) => Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 7),
                        child: _RangeChip(
                          label: 'Last ${r.$2}',
                          selected: range == r.$1,
                          onTap: () => ref.read(_rangeDaysProvider.notifier).state = r.$1,
                        ),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: HealthSpacing.md),
          Text('WHAT GOES IN', style: HealthTypography.label()),
          const SizedBox(height: 11),
          const _ContentChecklist(),
          const SizedBox(height: HealthSpacing.md),
          _PreviewCard(range: range),
          const SizedBox(height: HealthSpacing.md),
          if (_status == _ReportStatus.unavailable && _message != null) ...[
            AlertBanner(message: _message!, hard: false),
            const SizedBox(height: HealthSpacing.sm),
          ],
          if (_status == _ReportStatus.busy)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: HealthColors.chipIdle, borderRadius: BorderRadius.circular(18)),
              child: Center(child: Text('Building your report…', style: HealthTypography.body(color: HealthColors.inkMuted))),
            )
          else
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(onPressed: _generate, child: const Text('Generate PDF')),
            ),
          const SizedBox(height: HealthSpacing.sm),
          Text(
            'Shared links expire after 7 days and can be revoked any time.',
            style: HealthTypography.body(fontSize: 11.5, color: HealthColors.inkFaint),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: HealthSpacing.lg),
          Center(
            child: OutlinedButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PaywallScreen())),
              child: const Text('See what Premium unlocks'),
            ),
          ),
        ],
      ),
    );
  }
}

class _RangeChip extends StatelessWidget {
  const _RangeChip({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? HealthColors.inkPrimary : HealthColors.chipIdle,
      borderRadius: BorderRadius.circular(13),
      child: InkWell(
        borderRadius: BorderRadius.circular(13),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 11),
          child: Center(
            child: Text(label,
                style: HealthTypography.body(fontSize: 12.5, weight: FontWeight.w500, color: selected ? HealthColors.bgBase : HealthColors.inkMuted)),
          ),
        ),
      ),
    );
  }
}

/// Each row reflects whether that section actually has data in the selected
/// range — not a decorative always-on checklist.
class _ContentChecklist extends ConsumerWidget {
  const _ContentChecklist();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncChecklist = ref.watch(_reportChecklistProvider);

    return asyncChecklist.when(
      loading: () => const HealthCard(child: LinearProgressIndicator()),
      error: (e, _) => Text("Couldn't check what's available.", style: HealthTypography.body(color: HealthColors.inkMuted)),
      data: (data) {
        final rows = [
          ('Daily logs and calories', data['hasLogs'] as bool),
          ('Trends over time', data['hasTrends'] as bool),
          ('Lab history', data['hasLabs'] as bool),
          ('Symptom photos', false),
        ];
        return HealthCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: rows
                .map((r) => Padding(
                      padding: const EdgeInsets.only(bottom: 9),
                      child: Row(
                        children: [
                          if (r.$2)
                            Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(color: HealthColors.accentPrimary, borderRadius: BorderRadius.circular(6)),
                              child: const Icon(Icons.check, size: 13, color: Colors.white),
                            )
                          else
                            Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: HealthColors.inkFaint, width: 1.5),
                              ),
                            ),
                          const SizedBox(width: 10),
                          Text(r.$1, style: HealthTypography.body(fontSize: 13.5)),
                        ],
                      ),
                    ))
                .toList(),
          ),
        );
      },
    );
  }
}

class _PreviewCard extends ConsumerWidget {
  const _PreviewCard({required this.range});
  final int range;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncChecklist = ref.watch(_reportChecklistProvider);
    final logCount = asyncChecklist.maybeWhen(data: (d) => d['logCount'] as int, orElse: () => 0);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: HealthColors.bgBase,
        border: Border.all(color: HealthColors.inkPrimary.withValues(alpha: 0.12)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 70,
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: HealthColors.surface,
              border: Border.all(color: HealthColors.inkPrimary.withValues(alpha: 0.14)),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(height: 5, color: const Color(0xFFE0D6C4)),
                const SizedBox(height: 3),
                Container(height: 3, color: HealthColors.chipIdle),
                const SizedBox(height: 3),
                Container(height: 3, width: 28, color: HealthColors.chipIdle),
                const SizedBox(height: 4),
                Container(height: 16, decoration: BoxDecoration(color: HealthColors.reactionBubble, borderRadius: BorderRadius.circular(3))),
              ],
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Text(
              'Preview · $logCount ${logCount == 1 ? 'entry' : 'entries'} from the last $range days. '
              'Symptom photos appear with the "not a diagnosis" note attached.',
              style: HealthTypography.body(fontSize: 12.5, color: HealthColors.inkMuted),
            ),
          ),
        ],
      ),
    );
  }
}
