import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:health_ui/health_ui.dart';
import 'package:intl/intl.dart';

import '../data/logbook_repository.dart';
import '../domain/log_entry.dart';

const _typeFilters = [
  (null, 'All'),
  ('food', 'Food'),
  ('sleep', 'Sleep'),
  ('mood', 'Mood'),
  ('activity', 'Activity'),
  ('stress', 'Stress'),
  ('symptom', 'Symptom'),
];

final _searchQueryProvider = StateProvider.autoDispose<String>((ref) => '');

class LogbookScreen extends ConsumerStatefulWidget {
  const LogbookScreen({super.key});

  @override
  ConsumerState<LogbookScreen> createState() => _LogbookScreenState();
}

class _LogbookScreenState extends ConsumerState<LogbookScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final asyncEntries = ref.watch(logbookEntriesProvider);
    final activeFilter = ref.watch(logbookTypeFilterProvider);
    final query = ref.watch(_searchQueryProvider);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(HealthSpacing.md, HealthSpacing.sm, HealthSpacing.md, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Logbook', style: HealthTypography.display(fontSize: 27)),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
                decoration: BoxDecoration(
                  color: HealthColors.surface,
                  border: Border.all(color: HealthColors.inkPrimary.withValues(alpha: 0.12)),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Icon(Icons.search, size: 18, color: HealthColors.inkFaint),
                    const SizedBox(width: 9),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        onChanged: (v) => ref.read(_searchQueryProvider.notifier).state = v,
                        decoration: const InputDecoration(
                          hintText: 'Search your logbook…',
                          border: InputBorder.none,
                          isCollapsed: true,
                        ),
                        style: HealthTypography.body(fontSize: 13.5),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: _typeFilters.map((f) {
                    final selected = activeFilter == f.$1;
                    return Padding(
                      padding: const EdgeInsets.only(right: 7),
                      child: Material(
                        color: selected ? HealthColors.inkPrimary : HealthColors.chipIdle,
                        borderRadius: BorderRadius.circular(999),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(999),
                          onTap: () => ref.read(logbookTypeFilterProvider.notifier).state = f.$1,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
                            child: Text(
                              f.$2,
                              style: HealthTypography.body(
                                fontSize: 12.5,
                                weight: FontWeight.w500,
                                color: selected ? HealthColors.bgBase : HealthColors.inkMuted,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: asyncEntries.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (err, _) => Padding(
                    padding: const EdgeInsets.all(HealthSpacing.lg),
                    child: AlertBanner(message: "Couldn't load the logbook.", hard: false),
                  ),
                  data: (entries) {
                    final filtered = query.trim().isEmpty
                        ? entries
                        : entries
                            .where((e) =>
                                (e.summary ?? '').toLowerCase().contains(query.toLowerCase()) ||
                                e.type.toLowerCase().contains(query.toLowerCase()))
                            .toList();

                    if (filtered.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(HealthSpacing.xl),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const MoMascot(state: MascotState.idle, size: 96),
                              const SizedBox(height: HealthSpacing.md),
                              Text(
                                entries.isEmpty ? 'Nothing here yet — start a conversation with Mo.' : 'No matches for "$query".',
                                style: HealthTypography.mascotSpeech(),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                    return MemoryTrailTimeline(
                      itemCount: filtered.length,
                      itemBuilder: (context, index) => _LogRow(entry: filtered[index]),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
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
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: HealthColors.surface,
          border: Border.all(color: HealthColors.inkPrimary.withValues(alpha: 0.09)),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(entry.summary?.isNotEmpty == true ? entry.summary! : entry.type, style: HealthTypography.body(fontSize: 13.5)),
                  const SizedBox(height: 3),
                  Text(DateFormat('MMM d, HH:mm').format(entry.timestamp), style: HealthTypography.body(fontSize: 11.5, color: HealthColors.inkMuted)),
                ],
              ),
            ),
            Text(entry.type.toUpperCase(), style: HealthTypography.data(fontSize: 10.5, color: HealthColors.inkFaint)),
          ],
        ),
      ),
    );
  }
}
