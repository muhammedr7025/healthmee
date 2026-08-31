import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:health_ui/health_ui.dart';

import '../data/medical_profile_repository.dart';

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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncProfile = ref.watch(medicalProfileProvider);
    final asyncAllergies = ref.watch(allergiesProvider);

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
          Text('Version history is kept automatically every time this profile changes.',
              style: HealthTypography.label()),
        ],
      ),
    );
  }
}
