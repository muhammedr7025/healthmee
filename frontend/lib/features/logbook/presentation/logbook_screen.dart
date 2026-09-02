import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:health_ui/health_ui.dart';
import 'package:intl/intl.dart';

import '../data/logbook_repository.dart';
import '../domain/log_entry.dart';

const _typeFilters = [null, 'food', 'sleep', 'mood', 'activity', 'stress', 'symptom'];

class LogbookScreen extends ConsumerWidget {
  const LogbookScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncEntries = ref.watch(logbookEntriesProvider);
    final activeFilter = ref.watch(logbookTypeFilterProvider);

    return Scaffold(
      appBar: AppBar(title: Text('Logbook', style: HealthTypography.display(fontSize: 22))),
      body: Column(
        children: [
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: HealthSpacing.md),
              children: _typeFilters.map((type) {
                final selected = activeFilter == type;
                return Padding(
                  padding: const EdgeInsets.only(right: HealthSpacing.sm),
                  child: ChoiceChip(
                    label: Text(type ?? 'All'),
                    selected: selected,
                    onSelected: (_) => ref.read(logbookTypeFilterProvider.notifier).state = type,
                  ),
                );
              }).toList(),
            ),
          ),
          Expanded(
            child: asyncEntries.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Padding(
                padding: const EdgeInsets.all(HealthSpacing.lg),
                child: AlertBanner(message: "Couldn't load the logbook.", hard: false),
              ),
              data: (entries) {
                if (entries.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(HealthSpacing.xl),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const MoMascot(state: MascotState.idle, size: 96),
                          const SizedBox(height: HealthSpacing.md),
                          Text('Nothing here yet — start a conversation with Mo.',
                              style: HealthTypography.mascotSpeech(), textAlign: TextAlign.center),
                        ],
                      ),
                    ),
                  );
                }
                return MemoryTrailTimeline(
                  itemCount: entries.length,
                  itemBuilder: (context, index) => _LogRow(entry: entries[index]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _LogRow extends StatelessWidget {
  const _LogRow({required this.entry});
  final LogEntryView entry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: HealthSpacing.md, top: 4),
      child: HealthCard(
        padding: const EdgeInsets.symmetric(horizontal: HealthSpacing.md, vertical: HealthSpacing.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(entry.type.toUpperCase(), style: HealthTypography.label()),
                  Text(entry.summary ?? '', style: HealthTypography.body(fontSize: 13)),
                ],
              ),
            ),
            Text(DateFormat('MMM d, HH:mm').format(entry.timestamp), style: HealthTypography.data(fontSize: 11)),
          ],
        ),
      ),
    );
  }
}
