import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:health_ui/health_ui.dart';

import '../data/medications_repository.dart';

/// "Add a medicine": name, dose, and the times of day it's due. Returns true
/// when one was saved.
Future<bool?> showAddMedicationSheet(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: HealthColors.bgBase,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (_) => _AddMedicationSheet(ref: ref),
  );
}

const _presetSlots = [('Morning', '08:00'), ('Midday', '13:00'), ('Evening', '20:00')];

class _AddMedicationSheet extends StatefulWidget {
  const _AddMedicationSheet({required this.ref});
  final WidgetRef ref;

  @override
  State<_AddMedicationSheet> createState() => _AddMedicationSheetState();
}

class _AddMedicationSheetState extends State<_AddMedicationSheet> {
  final _name = TextEditingController();
  final _dose = TextEditingController();
  final _times = <String>{'08:00'};
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _dose.dispose();
    super.dispose();
  }

  Future<void> _addCustomTime() async {
    final picked = await showTimePicker(context: context, initialTime: const TimeOfDay(hour: 9, minute: 0));
    if (picked == null) return;
    final hh = picked.hour.toString().padLeft(2, '0');
    final mm = picked.minute.toString().padLeft(2, '0');
    setState(() => _times.add('$hh:$mm'));
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty || _times.isEmpty) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.ref.read(medicationsRepositoryProvider).addSchedule(
            name: name,
            dose: _dose.text.trim().isEmpty ? null : _dose.text.trim(),
            times: _times.toList()..sort(),
          );
      HapticFeedback.mediumImpact();
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = "Couldn't save that — check your connection and try again.";
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final customTimes = _times.where((t) => !_presetSlots.any((p) => p.$2 == t)).toList()..sort();

    return Padding(
      padding: EdgeInsets.fromLTRB(
        HealthSpacing.lg,
        HealthSpacing.md,
        HealthSpacing.lg,
        MediaQuery.of(context).viewInsets.bottom + HealthSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 38,
              height: 4,
              margin: const EdgeInsets.only(bottom: HealthSpacing.md),
              decoration: BoxDecoration(color: HealthColors.divider, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          Text('Add a medicine', style: HealthTypography.display(fontSize: 22)),
          const SizedBox(height: 4),
          Text(
            'MeMe will list it on Today at these times so you can tick it off.',
            style: HealthTypography.body(fontSize: 12.5, color: HealthColors.inkMuted),
          ),
          const SizedBox(height: HealthSpacing.md),
          TextField(
            controller: _name,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            onChanged: (_) => setState(() {}), // the Add button enables as soon as there's a name
            decoration: const InputDecoration(labelText: 'Name', hintText: 'Metformin'),
          ),
          const SizedBox(height: HealthSpacing.sm),
          TextField(
            controller: _dose,
            decoration: const InputDecoration(labelText: 'Dose (optional)', hintText: '500 mg · 1 tablet'),
          ),
          const SizedBox(height: HealthSpacing.md),
          Text('WHEN', style: HealthTypography.label()),
          const SizedBox(height: 8),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              for (final slot in _presetSlots)
                _SlotChip(
                  label: '${slot.$1} · ${slot.$2}',
                  selected: _times.contains(slot.$2),
                  onTap: () => setState(() => _times.contains(slot.$2) ? _times.remove(slot.$2) : _times.add(slot.$2)),
                ),
              for (final t in customTimes)
                _SlotChip(label: t, selected: true, onTap: () => setState(() => _times.remove(t))),
              _SlotChip(label: '+ Other time', selected: false, onTap: _addCustomTime),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: HealthSpacing.sm),
            AlertBanner(message: _error!, hard: false),
          ],
          const SizedBox(height: HealthSpacing.lg),
          Row(
            children: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: _saving || _name.text.trim().isEmpty || _times.isEmpty ? null : _save,
                  child: Text(_saving ? 'Saving…' : 'Add medicine'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SlotChip extends StatelessWidget {
  const _SlotChip({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? HealthColors.inkPrimary : HealthColors.chipIdle,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: HealthTypography.body(
            fontSize: 12.5,
            weight: selected ? FontWeight.w600 : FontWeight.w500,
            color: selected ? HealthColors.bgBase : HealthColors.inkMuted,
          ),
        ),
      ),
    );
  }
}
