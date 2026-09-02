import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:health_ui/health_ui.dart';

import '../data/medical_profile_repository.dart';

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

class MedicalProfileScreen extends ConsumerWidget {
  const MedicalProfileScreen({super.key});

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
                  .addAllergy(name: nameController.text.trim(), severity: 'moderate');
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

    return Scaffold(
      appBar: AppBar(title: Text('Medical Profile', style: HealthTypography.display(fontSize: 20))),
      body: ListView(
        padding: const EdgeInsets.all(HealthSpacing.md),
        children: [
          Text('Conditions', style: HealthTypography.label()),
          const SizedBox(height: HealthSpacing.sm),
          asyncProfile.when(
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text('Not set up yet — complete onboarding first.', style: HealthTypography.body()),
            data: (profile) => Wrap(
              spacing: HealthSpacing.sm,
              children: profile.conditions.isEmpty
                  ? [Text('None recorded', style: HealthTypography.body())]
                  : profile.conditions.map((c) => Chip(label: Text(c))).toList(),
            ),
          ),
          const SizedBox(height: HealthSpacing.lg),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Allergies', style: HealthTypography.label()),
              IconButton(onPressed: () => _addAllergy(context, ref), icon: const Icon(Icons.add_circle_outline)),
            ],
          ),
          asyncAllergies.when(
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text('Could not load allergies.', style: HealthTypography.body()),
            data: (allergies) => allergies.isEmpty
                ? Text('None recorded', style: HealthTypography.body())
                : Column(
                    children: allergies
                        .map((a) => ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.warning_amber_rounded, color: HealthColors.alertTrigger),
                              title: Text(a.name),
                              subtitle: Text(a.severity),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () async {
                                  await ref.read(medicalProfileRepositoryProvider).deleteAllergy(a.id);
                                  ref.invalidate(allergiesProvider);
                                },
                              ),
                            ))
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
                    Text('Medications', style: HealthTypography.label()),
                    IconButton(
                      onPressed: () => _addMedication(context, ref, profile.medications),
                      icon: const Icon(Icons.add_circle_outline),
                    ),
                  ],
                ),
                if (profile.medications.isEmpty)
                  Text('None recorded', style: HealthTypography.body())
                else
                  ...profile.medications.map((m) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.medication_outlined),
                        title: Text(m),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _removeMedication(ref, profile.medications, m),
                        ),
                      )),
                const SizedBox(height: HealthSpacing.lg),
                Text('Baseline vitals', style: HealthTypography.label()),
                const SizedBox(height: HealthSpacing.sm),
                if (profile.baselineVitals.isEmpty)
                  Text('None recorded', style: HealthTypography.body())
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Lab results', style: HealthTypography.label()),
              IconButton(onPressed: () => _addLabResult(context, ref), icon: const Icon(Icons.add_circle_outline)),
            ],
          ),
          asyncLabResults.when(
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text('Could not load lab results.', style: HealthTypography.body()),
            data: (results) => results.isEmpty
                ? Text('None recorded', style: HealthTypography.body())
                : Column(
                    children: results
                        .map((r) => ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.biotech_outlined),
                              title: Text(r.testName),
                              subtitle: Text('${r.value}${r.unit != null ? ' ${r.unit}' : ''} · ${r.source}'),
                            ))
                        .toList(),
                  ),
          ),
          const SizedBox(height: HealthSpacing.lg),
          Text('Version history is kept automatically every time this profile changes.',
              style: HealthTypography.label()),
        ],
      ),
    );
  }
}
