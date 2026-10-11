import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:health_ui/health_ui.dart';
import 'package:intl/intl.dart';

import '../../../core/analytics/analytics.dart';
import '../../chat/domain/log_row_formatter.dart';
import '../data/logbook_repository.dart';
import '../domain/log_entry.dart';
import '../domain/meme_comment.dart';
import 'edit_entry_sheet.dart';
import 'type_tag.dart';

/// One entry in full: when, what MeMe pulled out of it, MeMe's take, and
/// the summary to edit or the whole thing to delete. Pops `true` when
/// something changed so the caller can refresh.
class EntryDetailScreen extends ConsumerStatefulWidget {
  const EntryDetailScreen({super.key, required this.entry});

  final LogEntryView entry;

  @override
  ConsumerState<EntryDetailScreen> createState() => _EntryDetailScreenState();
}

class _EntryDetailScreenState extends ConsumerState<EntryDetailScreen> {
  late final _summary = TextEditingController(text: widget.entry.summary ?? '');
  late LogEntryView _entry = widget.entry;
  bool _busy = false;
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    ref.read(analyticsProvider).track('entry_detail_opened', {'type': widget.entry.type});
  }

  @override
  void dispose() {
    _summary.dispose();
    super.dispose();
  }

  Future<void> _editDetails() async {
    final updated = await showEditEntrySheet(context, ref, _entry, source: 'detail');
    if (updated != null && mounted) {
      setState(() {
        _entry = updated;
        _changed = true;
        if (updated.summary != null) _summary.text = updated.summary!;
      });
    }
  }

  Future<void> _save() async {
    final text = _summary.text.trim();
    if (text == (_entry.summary ?? '').trim()) {
      Navigator.pop(context, _changed);
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(logbookRepositoryProvider).editEntrySummary(widget.entry.id, text);
      HapticFeedback.selectionClick();
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Couldn't save — try again.")));
      }
    }
  }

  Future<void> _delete() async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this entry?'),
        content: const Text("It comes out of today's totals and the trends. This can't be undone."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep it')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete', style: TextStyle(color: HealthColors.alertTrigger)),
          ),
        ],
      ),
    );
    if (sure != true) return;
    setState(() => _busy = true);
    try {
      await ref.read(logbookRepositoryProvider).deleteEntry(widget.entry.id);
      HapticFeedback.mediumImpact();
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Couldn't delete — try again.")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final entry = _entry;
    final rows = formatLogRows(entry.type, entry.payload);

    return Scaffold(
      backgroundColor: HealthColors.bgBase,
      appBar: AppBar(
        backgroundColor: HealthColors.bgBase,
        surfaceTintColor: Colors.transparent,
        foregroundColor: HealthColors.inkPrimary,
        elevation: 0,
        title: Text(TypeTag.labelFor(entry.type), style: HealthTypography.body(fontSize: 16, weight: FontWeight.w500)),
        actions: [
          IconButton(
            tooltip: 'Delete',
            onPressed: _busy ? null : _delete,
            icon: Icon(Icons.delete_outline, color: HealthColors.alertTrigger),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(HealthSpacing.md, HealthSpacing.sm, HealthSpacing.md, HealthSpacing.xl),
          children: [
            Row(
              children: [
                TypeTag(entry.type),
                const SizedBox(width: 10),
                Text(
                  DateFormat('EEEE, d MMM · HH:mm').format(entry.timestamp),
                  style: HealthTypography.body(fontSize: 12.5, color: HealthColors.inkMuted),
                ),
              ],
            ),
            const SizedBox(height: HealthSpacing.md),
            Text('SUMMARY', style: HealthTypography.label()),
            const SizedBox(height: 6),
            TextField(
              controller: _summary,
              maxLines: 3,
              minLines: 1,
              style: HealthTypography.body(fontSize: 15),
              decoration: InputDecoration(
                filled: true,
                fillColor: HealthColors.surface,
                hintText: 'What happened, in your words',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: HealthColors.inkPrimary.withValues(alpha: 0.12)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: HealthColors.inkPrimary.withValues(alpha: 0.12)),
                ),
              ),
            ),
            const SizedBox(height: HealthSpacing.md),
            Row(
              children: [
                Expanded(child: Text('WHAT MEME PULLED OUT', style: HealthTypography.label())),
                TextButton.icon(
                  onPressed: _busy ? null : _editDetails,
                  style: TextButton.styleFrom(visualDensity: VisualDensity.compact, padding: const EdgeInsets.symmetric(horizontal: 8)),
                  icon: Icon(Icons.tune, size: 15, color: HealthColors.accentPrimaryDark),
                  label: Text('Fix the details', style: HealthTypography.body(fontSize: 12, weight: FontWeight.w500, color: HealthColors.accentPrimaryDark)),
                ),
              ],
            ),
            const SizedBox(height: 2),
            HealthCard(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
              child: Column(
                children: [
                  for (final row in rows)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: Text(row.key, style: HealthTypography.body(fontSize: 14))),
                          if (row.value.isNotEmpty)
                            Text(row.value, style: HealthTypography.data(fontSize: 14, color: HealthColors.inkMuted)),
                        ],
                      ),
                    ),
                  if (rows.isEmpty)
                    Text('Nothing structured on this one.', style: HealthTypography.body(fontSize: 13, color: HealthColors.inkMuted)),
                ],
              ),
            ),
            const SizedBox(height: HealthSpacing.md),
            NudgeCard(text: memeCommentFor(entry), mascot: mascotFor(entry)),
            const SizedBox(height: HealthSpacing.lg),
            Row(
              children: [
                TextButton(onPressed: _busy ? null : () => Navigator.pop(context, _changed), child: const Text('Back')),
                const Spacer(),
                ElevatedButton(onPressed: _busy ? null : _save, child: Text(_busy ? 'Saving…' : 'Save')),
              ],
            ),
            const SizedBox(height: HealthSpacing.sm),
            Text(
              'MeMe\'s notes are reflections on your own logs, not medical advice.',
              style: HealthTypography.body(fontSize: 11, color: HealthColors.inkFaint),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
