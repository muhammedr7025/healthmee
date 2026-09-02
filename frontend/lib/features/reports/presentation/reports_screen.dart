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
    return Scaffold(
      appBar: AppBar(title: Text('Doctor report', style: HealthTypography.display(fontSize: 22))),
      body: ListView(
        padding: const EdgeInsets.all(HealthSpacing.md),
        children: [
          Text(
            'One PDF with your logs, trends and lab history. Built to hand over, not to decode.',
            style: HealthTypography.body(fontSize: 13, color: HealthColors.inkMuted),
          ),
          const SizedBox(height: HealthSpacing.lg),
          Text('WHAT GOES IN', style: HealthTypography.label()),
          const SizedBox(height: 11),
          const _ContentChecklist(),
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

/// Each row reflects whether that section actually has data today — not a
/// decorative always-on checklist.
class _ContentChecklist extends ConsumerWidget {
  const _ContentChecklist();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncEntries = ref.watch(logbookEntriesProvider);
    final asyncTrends = ref.watch(trendsDataProvider);
    final asyncLabs = ref.watch(labResultsProvider);

    final hasLogs = asyncEntries.maybeWhen(data: (e) => e.isNotEmpty, orElse: () => false);
    final hasTrends = asyncTrends.maybeWhen(data: (t) => t.days.isNotEmpty, orElse: () => false);
    final hasLabs = asyncLabs.maybeWhen(data: (l) => l.isNotEmpty, orElse: () => false);

    final rows = [
      ('Daily logs and calories', hasLogs),
      ('Trends over time', hasTrends),
      ('Lab history', hasLabs),
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
  }
}
