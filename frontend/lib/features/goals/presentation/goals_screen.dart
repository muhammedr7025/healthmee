import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:health_ui/health_ui.dart';

import '../data/goals_repository.dart';
import '../domain/goal.dart';

const _goalTypeLabels = {
  'weight': 'Weight',
  'blood_pressure': 'Blood pressure',
  'activity': 'Activity',
  'calories': 'Calories',
  'custom': 'Custom',
};

class GoalsScreen extends ConsumerWidget {
  const GoalsScreen({super.key});

  Future<void> _addGoal(BuildContext context, WidgetRef ref) async {
    final typeController = ValueNotifier<String>('weight');
    final valueController = TextEditingController();

    final created = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New goal'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ValueListenableBuilder<String>(
              valueListenable: typeController,
              builder: (context, value, _) => DropdownButtonFormField<String>(
                initialValue: value,
                items: _goalTypeLabels.entries
                    .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                    .toList(),
                onChanged: (v) => typeController.value = v ?? value,
              ),
            ),
            TextField(
              controller: valueController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Target value'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final value = double.tryParse(valueController.text);
              if (value == null) return;
              await ref.read(goalsRepositoryProvider).createGoal(
                    type: typeController.value,
                    targetValue: {'value': value},
                  );
              if (context.mounted) Navigator.pop(context, true);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (created == true) {
      ref.invalidate(goalsProvider);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncGoals = ref.watch(goalsProvider);

    return Scaffold(
      appBar: AppBar(title: Text('Goals', style: HealthTypography.display(fontSize: 22))),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addGoal(context, ref),
        child: const Icon(Icons.add),
      ),
      body: asyncGoals.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Padding(
          padding: const EdgeInsets.all(HealthSpacing.lg),
          child: AlertBanner(message: "Couldn't load goals.", hard: false),
        ),
        data: (goals) {
          if (goals.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(HealthSpacing.xl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const MoMascot(state: MascotState.idle, size: 96),
                    const SizedBox(height: HealthSpacing.md),
                    Text('No goals yet — tap + to set one with Mo.',
                        style: HealthTypography.mascotSpeech(), textAlign: TextAlign.center),
                  ],
                ),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(HealthSpacing.md),
            itemCount: goals.length,
            itemBuilder: (context, index) => Padding(
              padding: const EdgeInsets.only(bottom: HealthSpacing.sm),
              child: _GoalCard(goal: goals[index]),
            ),
          );
        },
      ),
    );
  }
}

class _GoalCard extends StatefulWidget {
  const _GoalCard({required this.goal});
  final Goal goal;

  @override
  State<_GoalCard> createState() => _GoalCardState();
}

class _GoalCardState extends State<_GoalCard> {
  bool _celebrating = false;

  void _celebrate() {
    setState(() => _celebrating = true);
    Future.delayed(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _celebrating = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final goal = widget.goal;
    return HealthCard(
      child: Row(
        children: [
          MoMascot(state: _celebrating ? MascotState.celebrating : MascotState.idle, size: 40),
          const SizedBox(width: HealthSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_goalTypeLabels[goal.type] ?? goal.type, style: HealthTypography.body(weight: FontWeight.w600)),
                Text('Target: ${goal.targetValue}', style: HealthTypography.label()),
              ],
            ),
          ),
          if (goal.status == 'active')
            IconButton(
              onPressed: _celebrate,
              icon: const Icon(Icons.emoji_events_outlined),
              tooltip: 'Mark milestone reached',
              color: HealthColors.accentSecondary,
            ),
        ],
      ),
    );
  }
}
