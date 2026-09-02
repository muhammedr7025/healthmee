import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:health_ui/health_ui.dart';
import 'package:intl/intl.dart';

import '../data/medical_profile_repository.dart';
import '../domain/medical_profile.dart';
import 'lab_scan_flow.dart';

const _vitalLabels = {
  'age': 'Age',
  'height_cm': 'Height (cm)',
  'weight_kg': 'Weight (kg)',
  'waking_hours': 'Waking hours',
  'bp_systolic': 'BP systolic',
  'bp_diastolic': 'BP diastolic',
  'glucose_mg_dl': 'Glucose (mg/dL)',
};

String _vitalLabel(String key) => _vitalLabels[key] ?? key;

class MedicalProfileScreen extends StatelessWidget {
  const MedicalProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Medical profile', style: HealthTypography.display(fontSize: 20)),
          bottom: const TabBar(tabs: [Tab(text: 'Profile'), Tab(text: 'Tracking')]),
        ),
        body: const TabBarView(children: [_ProfileTab(), _TrackingTab()]),
      ),
    );
  }
}

class _ProfileTab extends ConsumerWidget {
  const _ProfileTab();

  Future<void> _addAllergy(BuildContext context, WidgetRef ref) async {
    final nameController = TextEditingController();
    final added = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add allergy'),
        content: TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Name')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.trim().isEmpty) return;
              await ref
                  .read(medicalProfileRepositoryProvider)
                  .addAllergy(name: nameController.text.trim(), severity: 'severe');
              if (context.mounted) Navigator.pop(context, true);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (added == true) ref.invalidate(allergiesProvider);
  }

  Future<void> _addMedication(BuildContext context, WidgetRef ref, List<String> current) async {
    final nameController = TextEditingController();
    final added = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add medication'),
        content: TextField(controller: nameController, decoration: const InputDecoration(labelText: 'e.g. Metformin 500mg')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isEmpty) return;
              await ref.read(medicalProfileRepositoryProvider).updateProfile(medications: [...current, name]);
              if (context.mounted) Navigator.pop(context, true);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (added == true) ref.invalidate(medicalProfileProvider);
  }

  Future<void> _removeMedication(WidgetRef ref, List<String> current, String name) async {
    await ref
        .read(medicalProfileRepositoryProvider)
        .updateProfile(medications: current.where((m) => m != name).toList());
    ref.invalidate(medicalProfileProvider);
  }

  Future<void> _scanLabReport(BuildContext context, WidgetRef ref) async {
    final results = await runLabScanFlow(context, ref);
    if (results == null) return; // user cancelled before picking a photo
    ref.invalidate(labResultsProvider);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(
        results.isEmpty
            ? "Couldn't read any values from that photo — try adding them by hand instead."
            : 'Added ${results.length} value${results.length == 1 ? '' : 's'} from the photo.',
      ),
    ));
  }

  Future<void> _addLabResult(BuildContext context, WidgetRef ref) async {
    final testController = TextEditingController();
    final valueController = TextEditingController();
    final unitController = TextEditingController();
    final added = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add a lab value'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: testController, decoration: const InputDecoration(labelText: 'Test name')),
            TextField(controller: valueController, decoration: const InputDecoration(labelText: 'Value')),
            TextField(controller: unitController, decoration: const InputDecoration(labelText: 'Unit (optional)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (testController.text.trim().isEmpty || valueController.text.trim().isEmpty) return;
              await ref.read(medicalProfileRepositoryProvider).addLabResult(
                    testName: testController.text.trim(),
                    value: valueController.text.trim(),
                    unit: unitController.text.trim().isEmpty ? null : unitController.text.trim(),
                    takenAt: DateTime.now(),
                  );
              if (context.mounted) Navigator.pop(context, true);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (added == true) ref.invalidate(labResultsProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncProfile = ref.watch(medicalProfileProvider);
    final asyncAllergies = ref.watch(allergiesProvider);
    final asyncLabResults = ref.watch(labResultsProvider);

    return ListView(
      padding: const EdgeInsets.all(HealthSpacing.md),
      children: [
        asyncAllergies.when(
          loading: () => const SizedBox.shrink(),
          error: (e, _) => const SizedBox.shrink(),
          data: (allergies) => allergies.isEmpty
              ? const SizedBox.shrink()
              : Container(
                  padding: const EdgeInsets.all(15),
                  margin: const EdgeInsets.only(bottom: HealthSpacing.lg),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFDEEE4),
                    border: Border.all(color: HealthColors.accentPrimary.withValues(alpha: 0.35)),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('HARD FLAGS · ALWAYS CHECKED', style: HealthTypography.label(color: HealthColors.accentPrimaryDark)),
                      const SizedBox(height: 9),
                      Wrap(
                        spacing: 7,
                        runSpacing: 7,
                        children: [
                          ...allergies.map((a) => Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(color: HealthColors.accentPrimary, borderRadius: BorderRadius.circular(999)),
                                child: Text(a.name, style: HealthTypography.body(fontSize: 12.5, weight: FontWeight.w500, color: Colors.white)),
                              )),
                          GestureDetector(
                            onTap: () => _addAllergy(context, ref),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(color: HealthColors.accentPrimaryDark.withValues(alpha: 0.5), style: BorderStyle.solid),
                              ),
                              child: Text('+ Add', style: HealthTypography.body(fontSize: 12.5, color: HealthColors.accentPrimaryDark)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
        ),
        if (asyncAllergies.maybeWhen(data: (a) => a.isEmpty, orElse: () => true)) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('ALLERGIES', style: HealthTypography.label()),
              IconButton(onPressed: () => _addAllergy(context, ref), icon: const Icon(Icons.add_circle_outline)),
            ],
          ),
          Text('None recorded', style: HealthTypography.body(color: HealthColors.inkMuted)),
          const SizedBox(height: HealthSpacing.lg),
        ],
        Text('CONDITIONS', style: HealthTypography.label()),
        const SizedBox(height: HealthSpacing.sm),
        asyncProfile.when(
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => Text('Not set up yet — complete onboarding first.', style: HealthTypography.body()),
          data: (profile) => profile.conditions.isEmpty
              ? Text('None recorded', style: HealthTypography.body(color: HealthColors.inkMuted))
              : Column(
                  children: profile.conditions
                      .map((c) => _ProfileRow(title: c, trailing: 'managed'))
                      .toList(),
                ),
        ),
        const SizedBox(height: HealthSpacing.lg),
        asyncProfile.when(
          loading: () => const SizedBox.shrink(),
          error: (e, _) => const SizedBox.shrink(),
          data: (profile) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('MEDICATIONS', style: HealthTypography.label()),
                  IconButton(onPressed: () => _addMedication(context, ref, profile.medications), icon: const Icon(Icons.add_circle_outline)),
                ],
              ),
              if (profile.medications.isEmpty)
                Text('None recorded', style: HealthTypography.body(color: HealthColors.inkMuted))
              else
                ...profile.medications.map((m) => _ProfileRow(
                      title: m,
                      onDelete: () => _removeMedication(ref, profile.medications, m),
                    )),
              const SizedBox(height: HealthSpacing.lg),
              Text('BASELINE VITALS', style: HealthTypography.label()),
              const SizedBox(height: HealthSpacing.sm),
              if (profile.baselineVitals.isEmpty)
                Text('None recorded', style: HealthTypography.body(color: HealthColors.inkMuted))
              else
                Wrap(
                  spacing: HealthSpacing.md,
                  runSpacing: HealthSpacing.sm,
                  children: profile.baselineVitals.entries
                      .map((e) => Text('${_vitalLabel(e.key)}: ${e.value}', style: HealthTypography.data(fontSize: 15)))
                      .toList(),
                ),
            ],
          ),
        ),
        const SizedBox(height: HealthSpacing.lg),
        Text('LAB HISTORY', style: HealthTypography.label()),
        const SizedBox(height: HealthSpacing.sm),
        asyncLabResults.when(
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => Text('Could not load lab results.', style: HealthTypography.body()),
          data: (results) => results.isEmpty
              ? Text('None recorded', style: HealthTypography.body(color: HealthColors.inkMuted))
              : Column(
                  children: results
                      .map((r) => _ProfileRow(title: r.testName, trailing: '${r.value}${r.unit != null ? ' ${r.unit}' : ''}'))
                      .toList(),
                ),
        ),
        const SizedBox(height: HealthSpacing.sm),
        GestureDetector(
          onTap: () => _addLabResult(context, ref),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              border: Border.all(color: HealthColors.inkPrimary.withValues(alpha: 0.22)),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(color: HealthColors.chipIdle, borderRadius: BorderRadius.circular(11)),
                  child: Icon(Icons.add, color: HealthColors.accentPrimaryDark, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text('Add a lab value by hand', style: HealthTypography.body(fontSize: 13, color: HealthColors.inkMuted))),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () => _scanLabReport(context, ref),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              border: Border.all(color: HealthColors.inkPrimary.withValues(alpha: 0.22), style: BorderStyle.solid),
              borderRadius: BorderRadius.circular(16),
              color: HealthColors.surface,
            ),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(color: HealthColors.chipIdle, borderRadius: BorderRadius.circular(11)),
                  child: Icon(Icons.document_scanner_outlined, color: HealthColors.accentPrimaryDark, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    "Snap a new report — I'll extract the values for you to confirm.",
                    style: HealthTypography.body(fontSize: 13, color: HealthColors.inkMuted),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: HealthSpacing.lg),
        Text('Version history is kept automatically every time this profile changes.',
            style: HealthTypography.body(fontSize: 11, color: HealthColors.inkFaint)),
      ],
    );
  }
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({required this.title, this.trailing, this.onDelete});
  final String title;
  final String? trailing;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Padding(
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
            Expanded(child: Text(title, style: HealthTypography.body(fontSize: 14))),
            if (trailing != null) Text(trailing!, style: HealthTypography.body(fontSize: 11.5, color: HealthColors.inkMuted)),
            if (onDelete != null)
              IconButton(icon: const Icon(Icons.delete_outline, size: 18), onPressed: onDelete, visualDensity: VisualDensity.compact),
          ],
        ),
      ),
    );
  }
}

final _selectedParamProvider = StateProvider.autoDispose<String?>((ref) => null);

class _TrackingTab extends ConsumerWidget {
  const _TrackingTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncLabs = ref.watch(labResultsProvider);

    return asyncLabs.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Padding(
        padding: const EdgeInsets.all(HealthSpacing.lg),
        child: AlertBanner(message: "Couldn't load lab history.", hard: false),
      ),
      data: (results) {
        if (results.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(HealthSpacing.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const MoMascot(state: MascotState.idle, size: 96),
                  const SizedBox(height: HealthSpacing.md),
                  Text('Add a lab value on the Profile tab and it\'ll show up here over time.',
                      style: HealthTypography.mascotSpeech(), textAlign: TextAlign.center),
                ],
              ),
            ),
          );
        }

        final testNames = results.map((r) => r.testName).toSet().toList();
        final selected = ref.watch(_selectedParamProvider) ?? testNames.first;
        final rows = results.where((r) => r.testName == selected).toList()..sort((a, b) => a.takenAt.compareTo(b.takenAt));
        final numeric = rows.map((r) => double.tryParse(r.value)).toList();
        final hasChart = numeric.every((v) => v != null) && numeric.length > 1;

        return ListView(
          padding: const EdgeInsets.all(HealthSpacing.md),
          children: [
            SizedBox(
              height: 38,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: testNames
                    .map((t) => Padding(
                          padding: const EdgeInsets.only(right: 7),
                          child: Material(
                            color: t == selected ? HealthColors.inkPrimary : HealthColors.chipIdle,
                            borderRadius: BorderRadius.circular(999),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(999),
                              onTap: () => ref.read(_selectedParamProvider.notifier).state = t,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
                                child: Text(t,
                                    style: HealthTypography.body(
                                        fontSize: 12, color: t == selected ? HealthColors.bgBase : HealthColors.inkMuted)),
                              ),
                            ),
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
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(selected, style: HealthTypography.body(fontSize: 14, weight: FontWeight.w500)),
                          Text('${rows.length} reading${rows.length == 1 ? '' : 's'}',
                              style: HealthTypography.body(fontSize: 11, color: HealthColors.inkFaint)),
                        ],
                      ),
                      Text('${rows.last.value}${rows.last.unit != null ? ' ${rows.last.unit}' : ''}',
                          style: HealthTypography.data(fontSize: 16)),
                    ],
                  ),
                  if (hasChart) ...[
                    SizedBox(
                      height: 132,
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
                                    if (i < 0 || i >= rows.length) return const SizedBox.shrink();
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 6),
                                      child: Text(DateFormat('M/d').format(rows[i].takenAt), style: HealthTypography.label(fontSize: 9.5)),
                                    );
                                  },
                                ),
                              ),
                            ),
                            barGroups: [
                              for (int i = 0; i < rows.length; i++)
                                BarChartGroupData(x: i, barRods: [
                                  BarChartRodData(
                                    toY: numeric[i]!,
                                    color: HealthColors.accentPrimary,
                                    width: 22,
                                    borderRadius: const BorderRadius.only(topLeft: Radius.circular(6), topRight: Radius.circular(6)),
                                  ),
                                ]),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ] else
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text('one bar per numeric reading · add more to see a trend', style: HealthTypography.label()),
                    ),
                ],
              ),
            ),
            const SizedBox(height: HealthSpacing.lg),
            Text('READING BY READING', style: HealthTypography.label()),
            const SizedBox(height: HealthSpacing.sm),
            ...rows.reversed.map((r) => _ReadingRow(reading: r)),
          ],
        );
      },
    );
  }
}

class _ReadingRow extends StatelessWidget {
  const _ReadingRow({required this.reading});
  final LabResultData reading;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: HealthColors.surface,
          border: Border.all(color: HealthColors.inkPrimary.withValues(alpha: 0.09)),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('${reading.value}${reading.unit != null ? ' ${reading.unit}' : ''}', style: HealthTypography.body(fontSize: 13.5)),
            Text(DateFormat('MMM d, yyyy').format(reading.takenAt), style: HealthTypography.body(fontSize: 12, color: HealthColors.inkMuted)),
          ],
        ),
      ),
    );
  }
}
