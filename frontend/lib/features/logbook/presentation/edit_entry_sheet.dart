import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:health_ui/health_ui.dart';

import '../../../core/analytics/analytics.dart';
import '../data/log_types_repository.dart';
import '../data/logbook_repository.dart';
import '../domain/log_entry.dart';
import 'type_tag.dart';

/// Correct what MeMe understood, field by field: numbers on a number
/// keypad, choices as chips, lists as comma-separated text. Built from the
/// server's type catalog so a new log type gets an editor for free.
/// Returns the updated entry, or null if nothing was saved.
Future<LogEntryView?> showEditEntrySheet(BuildContext context, WidgetRef ref, LogEntryView entry, {String source = 'detail'}) {
  ref.read(analyticsProvider).track('correction_sheet_opened', {'type': entry.type, 'source': source});
  return showModalBottomSheet<LogEntryView>(
    context: context,
    isScrollControlled: true,
    backgroundColor: HealthColors.bgBase,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (_) => _EditEntrySheet(entry: entry, ref: ref),
  );
}

class _EditEntrySheet extends StatefulWidget {
  const _EditEntrySheet({required this.entry, required this.ref});
  final LogEntryView entry;
  final WidgetRef ref;

  @override
  State<_EditEntrySheet> createState() => _EditEntrySheetState();
}

class _EditEntrySheetState extends State<_EditEntrySheet> {
  final _controllers = <String, TextEditingController>{};
  final _choices = <String, String?>{};
  final _flags = <String, bool>{};
  late final _summary = TextEditingController(text: widget.entry.summary ?? '');
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    _summary.dispose();
    super.dispose();
  }

  TextEditingController _controllerFor(LogTypeField field) => _controllers.putIfAbsent(field.name, () {
        final value = widget.entry.payload[field.name];
        final text = switch (value) {
          null => '',
          List list => list.join(', '),
          num n => n == n.roundToDouble() ? n.toInt().toString() : n.toString(),
          _ => value.toString(),
        };
        return TextEditingController(text: text);
      });

  Map<String, dynamic> _buildPayload(LogType type) {
    final payload = <String, dynamic>{};
    for (final field in type.fields) {
      if (field.enumValues != null) {
        final chosen = _choices.containsKey(field.name) ? _choices[field.name] : widget.entry.payload[field.name]?.toString();
        if (chosen != null) payload[field.name] = chosen;
        continue;
      }
      switch (field.type) {
        case 'bool':
          payload[field.name] = _flags[field.name] ?? (widget.entry.payload[field.name] == true);
        case 'number':
          final text = _controllerFor(field).text.trim();
          if (text.isNotEmpty) payload[field.name] = double.tryParse(text.replaceAll(',', '.'));
        case 'list[str]':
          final text = _controllerFor(field).text.trim();
          if (text.isNotEmpty) payload[field.name] = text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
        case 'list[number]':
          final text = _controllerFor(field).text.trim();
          if (text.isNotEmpty) payload[field.name] = text.split(',').map((s) => double.tryParse(s.trim())).whereType<double>().toList();
        case 'dict':
          break; // not editable here
        default:
          final text = _controllerFor(field).text.trim();
          if (text.isNotEmpty) payload[field.name] = text;
      }
    }
    return payload;
  }

  String? _validate(LogType type, Map<String, dynamic> payload) {
    for (final field in type.fields) {
      if (field.required && payload[field.name] == null) return '${field.label} is needed for a ${TypeTag.labelFor(type.name).toLowerCase()} entry.';
      if (field.type == 'number' && _controllerFor(field).text.trim().isNotEmpty && payload[field.name] == null) {
        return '${field.label} should be a number.';
      }
    }
    return null;
  }

  Future<void> _save(LogType type) async {
    final payload = _buildPayload(type);
    final problem = _validate(type, payload);
    if (problem != null) {
      HapticFeedback.vibrate();
      setState(() => _error = problem);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final summary = _summary.text.trim();
      final updated = await widget.ref.read(logbookRepositoryProvider).updateEntry(
            widget.entry.id,
            payload: payload,
            summary: summary.isEmpty ? null : summary,
          );
      HapticFeedback.lightImpact();
      widget.ref.read(analyticsProvider).track('entry_correction_saved', {
        'type': type.name,
        'fields_changed': [for (final f in type.fields) if (payload[f.name] != widget.entry.payload[f.name]) f.name],
      });
      if (mounted) Navigator.pop(context, updated);
    } catch (_) {
      HapticFeedback.vibrate();
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
    final asyncTypes = widget.ref.watch(logTypesProvider);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        HealthSpacing.lg,
        HealthSpacing.md,
        HealthSpacing.lg,
        MediaQuery.viewInsetsOf(context).bottom + HealthSpacing.lg,
      ),
      child: asyncTypes.when(
        loading: () => const SizedBox(height: 120, child: Center(child: CircularProgressIndicator())),
        error: (e, _) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AlertBanner(message: "Couldn't load the editor — try again in a moment.", hard: false),
            TextButton(onPressed: () => widget.ref.invalidate(logTypesProvider), child: const Text('Retry')),
          ],
        ),
        data: (types) {
          final type = types[widget.entry.type];
          if (type == null) {
            return Text('This entry type can\'t be edited here.', style: HealthTypography.body());
          }
          return SingleChildScrollView(
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
                Row(
                  children: [
                    TypeTag(type.name),
                    const SizedBox(width: 10),
                    Expanded(child: Text('Fix what MeMe got wrong', style: HealthTypography.display(fontSize: 20))),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Your corrections update today\'s totals straight away, and teach us where MeMe misreads.',
                  style: HealthTypography.body(fontSize: 12.5, color: HealthColors.inkMuted),
                ),
                const SizedBox(height: HealthSpacing.md),
                for (final field in type.fields) ...[
                  _FieldEditor(
                    field: field,
                    controller: field.enumValues == null && field.type != 'bool' && field.type != 'dict' ? _controllerFor(field) : null,
                    choice: _choices.containsKey(field.name) ? _choices[field.name] : widget.entry.payload[field.name]?.toString(),
                    flag: _flags[field.name] ?? (widget.entry.payload[field.name] == true),
                    onChoice: (v) => setState(() => _choices[field.name] = v),
                    onFlag: (v) => setState(() => _flags[field.name] = v),
                  ),
                  const SizedBox(height: HealthSpacing.sm),
                ],
                TextField(
                  controller: _summary,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(labelText: 'Summary (optional)', hintText: 'In your own words'),
                ),
                if (_error != null) ...[
                  const SizedBox(height: HealthSpacing.sm),
                  AlertBanner(message: _error!, hard: false),
                ],
                const SizedBox(height: HealthSpacing.lg),
                Row(
                  children: [
                    TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _saving ? null : () => _save(type),
                        child: Text(_saving ? 'Saving…' : 'Save corrections'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _FieldEditor extends StatelessWidget {
  const _FieldEditor({
    required this.field,
    required this.controller,
    required this.choice,
    required this.flag,
    required this.onChoice,
    required this.onFlag,
  });

  final LogTypeField field;
  final TextEditingController? controller;
  final String? choice;
  final bool flag;
  final void Function(String?) onChoice;
  final void Function(bool) onFlag;

  @override
  Widget build(BuildContext context) {
    final label = field.required ? field.label : '${field.label} (optional)';

    if (field.enumValues != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: HealthTypography.label()),
          const SizedBox(height: 6),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              for (final value in field.enumValues!)
                _ChoiceChip(
                  label: value.replaceAll('_', ' '),
                  selected: choice == value,
                  onTap: () => onChoice(choice == value && !field.required ? null : value),
                ),
            ],
          ),
        ],
      );
    }

    if (field.type == 'bool') {
      return Row(
        children: [
          Expanded(child: Text(label, style: HealthTypography.body(fontSize: 14))),
          HealthSwitch(value: flag, onChanged: onFlag),
        ],
      );
    }

    if (field.type == 'dict' || controller == null) return const SizedBox.shrink();

    final numeric = field.type == 'number' || field.type == 'list[number]';
    return TextField(
      controller: controller,
      keyboardType: numeric ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
      inputFormatters: field.type == 'number' ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))] : null,
      textCapitalization: numeric ? TextCapitalization.none : TextCapitalization.sentences,
      textInputAction: TextInputAction.next,
      decoration: InputDecoration(
        labelText: label,
        hintText: switch (field.type) { 'list[str]' => 'Comma-separated', 'list[number]' => 'Comma-separated numbers', _ => null },
      ),
    );
  }
}

class _ChoiceChip extends StatelessWidget {
  const _ChoiceChip({required this.label, required this.selected, required this.onTap});
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
