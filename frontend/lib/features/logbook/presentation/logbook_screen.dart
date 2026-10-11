import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:health_ui/health_ui.dart';
import 'package:intl/intl.dart';

import '../../../core/analytics/analytics.dart';
import '../../../core/app_navigation.dart';
import '../../chat/domain/log_row_formatter.dart';
import '../../medical_profile/data/medical_profile_repository.dart';
import '../../medical_profile/domain/medical_profile.dart';
import '../../medical_profile/presentation/lab_scan_flow.dart';
import '../data/logbook_repository.dart';
import '../domain/log_entry.dart';
import 'entry_detail_screen.dart';
import 'type_tag.dart';

const _tabs = [('timeline', 'Timeline'), ('vitals', 'Vitals'), ('labs', 'Labs'), ('symptoms', 'Symptoms')];

const _typeFilters = [
  (null, 'All'),
  ('food', 'Food'),
  ('vital', 'Vitals'),
  ('sleep', 'Sleep'),
  ('hydration', 'Water'),
  ('mood', 'Mood'),
  ('activity', 'Activity'),
  ('stress', 'Stress'),
  ('symptom', 'Symptom'),
];

/// One tap, one half-written message in the chat box — the fastest way to
/// log the usual things without typing them from scratch.
const _quickLogs = [
  ('Water', 'Drank a glass of water'),
  ('Meal', 'I had '),
  ('Sleep', 'Slept  hours'),
  ('BP', 'BP '),
  ('Weight', 'Weight  kg'),
  ('Mood', 'Feeling '),
];

final _searchQueryProvider = StateProvider.autoDispose<String>((ref) => '');

class LogbookScreen extends ConsumerStatefulWidget {
  const LogbookScreen({super.key});

  @override
  ConsumerState<LogbookScreen> createState() => _LogbookScreenState();
}

class _LogbookScreenState extends ConsumerState<LogbookScreen> {
  final _searchController = TextEditingController();
  Timer? _searchDebounce;

  /// Filtering re-runs on every keystroke otherwise; 250ms after the last
  /// one is indistinguishable to the user and far cheaper.
  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 250), () {
      if (mounted) ref.read(_searchQueryProvider.notifier).state = value;
    });
  }

  /// Bumped on every scroll frame so each row can re-evaluate where it sits
  /// in the viewport and scale/fade accordingly.
  final _scrollTick = ValueNotifier<int>(0);

  /// Rows are one "detent" apart, so a light tick every row-height of travel
  /// gives the Digital-Crown feel rather than a continuous buzz.
  static const _detent = 84.0;
  double _lastHapticOffset = 0;

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _scrollTick.dispose();
    super.dispose();
  }

  bool _onScroll(ScrollNotification notification) {
    _scrollTick.value++;
    if (notification is ScrollUpdateNotification) {
      final offset = notification.metrics.pixels;
      if ((offset - _lastHapticOffset).abs() >= _detent) {
        _lastHapticOffset = offset;
        HapticFeedback.selectionClick();
      }
    }
    return false;
  }

  void _quickLog(String label, String draft) {
    ref.read(analyticsProvider).track('quick_log_tap', {'template': label.toLowerCase()});
    ref.read(pendingChatDraftProvider.notifier).state = draft;
    ref.read(activeTabProvider.notifier).state = chatTabIndex;
  }

  @override
  Widget build(BuildContext context) {
    final tab = ref.watch(logbookTabProvider);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(HealthSpacing.md, HealthSpacing.sm, HealthSpacing.md, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Logbook', style: HealthTypography.display(fontSize: 27)),
              const SizedBox(height: 12),
              SegmentedControl(
                segments: _tabs,
                selected: tab,
                onChanged: (value) {
                  ref.read(analyticsProvider).track('logbook_tab', {'tab': value});
                  ref.read(logbookTabProvider.notifier).state = value;
                },
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (final q in _quickLogs)
                      Padding(
                        padding: const EdgeInsets.only(right: 7),
                        child: HealthChip(label: q.$1, icon: Icons.add, outlined: true, selected: false, onTap: () => _quickLog(q.$1, q.$2)),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              if (tab != 'labs') const _DayNavigator(),
              const SizedBox(height: 8),
              Expanded(
                child: switch (tab) {
                  'labs' => const _LabsTab(),
                  'vitals' => _EntriesList(tick: _scrollTick, onScroll: _onScroll, header: const _LatestReadings()),
                  'symptoms' => _EntriesList(tick: _scrollTick, onScroll: _onScroll),
                  _ => _TimelineTab(
                      searchController: _searchController,
                      onSearchChanged: _onSearchChanged,
                      tick: _scrollTick,
                      onScroll: _onScroll,
                    ),
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ‹ All days / Today / Yesterday / 9 Oct ›. Stepping back from "all days"
/// lands on today; stepping forward from today returns to all days.
class _DayNavigator extends ConsumerWidget {
  const _DayNavigator();

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  String _label(DateTime? day) {
    if (day == null) return 'All days';
    final today = _dateOnly(DateTime.now());
    final diff = today.difference(_dateOnly(day)).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return DateFormat(day.year == today.year ? 'EEE, d MMM' : 'd MMM yyyy').format(day);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final day = ref.watch(logbookDayProvider);
    final today = _dateOnly(DateTime.now());
    final isToday = day != null && _dateOnly(day) == today;

    void set(DateTime? next) {
      HapticFeedback.selectionClick();
      ref.read(logbookDayProvider.notifier).state = next;
    }

    return Row(
      children: [
        IconButton(
          visualDensity: VisualDensity.compact,
          onPressed: () => set(day == null ? today : _dateOnly(day).subtract(const Duration(days: 1))),
          icon: Icon(Icons.chevron_left, color: HealthColors.inkMuted),
        ),
        Expanded(
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: day ?? today,
                firstDate: DateTime(2020),
                lastDate: today,
              );
              if (picked != null) set(picked);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.event_outlined, size: 15, color: HealthColors.inkMuted),
                  const SizedBox(width: 6),
                  Text(_label(day), style: HealthTypography.body(fontSize: 13.5, weight: FontWeight.w500)),
                ],
              ),
            ),
          ),
        ),
        if (day != null)
          TextButton(
            onPressed: () => set(null),
            style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
            child: Text('All', style: HealthTypography.body(fontSize: 12, color: HealthColors.accentPrimaryDark)),
          ),
        IconButton(
          visualDensity: VisualDensity.compact,
          onPressed: day == null ? null : () => set(isToday ? null : _dateOnly(day).add(const Duration(days: 1))),
          icon: Icon(Icons.chevron_right, color: day == null ? HealthColors.divider : HealthColors.inkMuted),
        ),
      ],
    );
  }
}

class _TimelineTab extends ConsumerWidget {
  const _TimelineTab({required this.searchController, required this.onSearchChanged, required this.tick, required this.onScroll});
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final ValueNotifier<int> tick;
  final bool Function(ScrollNotification) onScroll;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeFilter = ref.watch(logbookTypeFilterProvider);
    final query = ref.watch(_searchQueryProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
                  controller: searchController,
                  onChanged: onSearchChanged,
                  textInputAction: TextInputAction.search,
                  decoration: const InputDecoration(
                    hintText: 'Search your logbook…',
                    border: InputBorder.none,
                    isCollapsed: true,
                  ),
                  style: HealthTypography.body(fontSize: 13.5),
                ),
              ),
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: searchController,
                builder: (context, value, _) => value.text.isEmpty
                    ? const SizedBox.shrink()
                    : IconButton(
                        visualDensity: VisualDensity.compact,
                        tooltip: 'Clear search',
                        icon: Icon(Icons.close, size: 16, color: HealthColors.inkMuted),
                        onPressed: () {
                          searchController.clear();
                          onSearchChanged('');
                        },
                      ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (final f in _typeFilters)
                Padding(
                  padding: const EdgeInsets.only(right: 7),
                  child: HealthChip(
                    label: f.$2,
                    selected: activeFilter == f.$1,
                    onTap: () {
                      if (activeFilter == f.$1) return;
                      ref.read(logbookTypeFilterProvider.notifier).state = f.$1;
                    },
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Expanded(child: _EntriesList(tick: tick, onScroll: onScroll, query: query)),
      ],
    );
  }
}

class _EntriesList extends ConsumerWidget {
  const _EntriesList({required this.tick, required this.onScroll, this.query = '', this.header});
  final ValueNotifier<int> tick;
  final bool Function(ScrollNotification) onScroll;
  final String query;
  final Widget? header;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncPage = ref.watch(logbookPagerProvider);
    final tab = ref.watch(logbookTabProvider);
    final day = ref.watch(logbookDayProvider);

    return asyncPage.when(
      skipLoadingOnReload: true,
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => EmptyState(
        message: "Couldn't load the logbook.",
        mascot: MascotState.concerned,
        actionLabel: 'Try again',
        onAction: () => ref.read(logbookPagerProvider.notifier).refresh(),
      ),
      data: (page) {
        final entries = page.items;
        final q = query.trim().toLowerCase();
        final filtered = q.isEmpty
            ? entries
            : entries
                .where((e) => (e.summary ?? '').toLowerCase().contains(q) || e.type.toLowerCase().contains(q))
                .toList();

        if (filtered.isEmpty) {
          final what = switch (tab) { 'vitals' => 'readings', 'symptoms' => 'symptoms', _ => 'entries' };
          final hint = switch (tab) {
            'vitals' => 'Tell MeMe "BP 120/80" or "weight 72 kg" and it lands here.',
            'symptoms' => 'Mention a headache or a sore throat to MeMe and it\'s kept here for your doctor.',
            _ => 'Start a conversation with MeMe.',
          };
          return ListView(
            children: [
              ?header,
              EmptyState(
                message: entries.isEmpty ? 'No $what ${day == null ? 'yet' : 'on this day'} — $hint' : 'No matches for "$query".',
              ),
            ],
          );
        }

        // One extra row at the end for "Show older" while the server has more.
        final showMore = page.hasMore && q.isEmpty;
        final list = NotificationListener<ScrollNotification>(
          onNotification: onScroll,
          child: MemoryTrailTimeline(
            itemCount: filtered.length + (showMore ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == filtered.length) {
                return Center(
                  child: page.loadingMore
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : TextButton(
                          onPressed: () => ref.read(logbookPagerProvider.notifier).loadMore(),
                          child: Text('Show older entries', style: HealthTypography.body(fontSize: 13, color: HealthColors.accentPrimaryDark)),
                        ),
                );
              }
              return _FocalRow(tick: tick, index: index, child: _LogRow(entry: filtered[index]));
            },
          ),
        );
        if (header == null) return list;
        return Column(children: [header!, const SizedBox(height: 8), Expanded(child: list)]);
      },
    );
  }
}

/// Vitals tab header: the most recent reading of each kind, so the number
/// you'd tell a doctor is one glance away.
class _LatestReadings extends ConsumerWidget {
  const _LatestReadings();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(logbookPagerProvider).valueOrNull?.items ?? const <LogEntryView>[];
    final latest = <String, LogEntryView>{};
    for (final e in entries) {
      final kind = '${e.payload['kind']}';
      final current = latest[kind];
      if (current == null || e.timestamp.isAfter(current.timestamp)) latest[kind] = e;
    }
    if (latest.isEmpty) return const SizedBox.shrink();

    const order = ['blood_pressure', 'blood_glucose', 'weight', 'heart_rate', 'spo2', 'temperature'];
    final shown = order.where(latest.containsKey).toList();

    return HealthCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('LATEST READINGS', style: HealthTypography.label()),
          const SizedBox(height: 8),
          Wrap(
            spacing: 18,
            runSpacing: 8,
            children: [
              for (final kind in shown)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(vitalKindLabel(kind), style: HealthTypography.body(fontSize: 11, color: HealthColors.inkFaint)),
                    Text(formatVitalValue(latest[kind]!.payload), style: HealthTypography.data(fontSize: 16)),
                    Text(
                      DateFormat('d MMM').format(latest[kind]!.timestamp),
                      style: HealthTypography.body(fontSize: 10.5, color: HealthColors.inkFaint),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LabsTab extends ConsumerWidget {
  const _LabsTab();

  Future<void> _scan(BuildContext context, WidgetRef ref) async {
    final results = await runLabScanFlow(context, ref);
    if (results == null) return;
    ref.invalidate(labResultsProvider);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(
        results.isEmpty
            ? "Couldn't read any values from that report — add them from your Medical Profile instead."
            : 'Added ${results.length} value${results.length == 1 ? '' : 's'} from the report.',
      ),
    ));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncLabs = ref.watch(labResultsProvider);

    return asyncLabs.when(skipLoadingOnReload: true, 
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Padding(
        padding: const EdgeInsets.all(HealthSpacing.lg),
        child: AlertBanner(message: "Couldn't load lab results.", hard: false),
      ),
      data: (labs) {
        // Newest report first; rows grouped by the day the sample was taken.
        final groups = <String, List<LabResultData>>{};
        for (final lab in labs) {
          groups.putIfAbsent(DateFormat('yyyy-MM-dd').format(lab.takenAt.toLocal()), () => []).add(lab);
        }
        final dates = groups.keys.toList()..sort((a, b) => b.compareTo(a));

        return ListView(
          padding: const EdgeInsets.only(bottom: HealthSpacing.lg),
          children: [
            OutlinedButton.icon(
              onPressed: () => _scan(context, ref),
              icon: const Icon(Icons.document_scanner_outlined, size: 18),
              label: const Text('Scan or upload a lab report'),
            ),
            const SizedBox(height: 12),
            if (labs.isEmpty)
              Padding(
                padding: const EdgeInsets.all(HealthSpacing.xl),
                child: Column(
                  children: [
                    const MemeMascot(state: MascotState.curious, size: 96),
                    const SizedBox(height: HealthSpacing.md),
                    Text(
                      'No lab results yet. Snap the printout or upload the PDF and I\'ll read it for you to check.',
                      style: HealthTypography.mascotSpeech(),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            for (final date in dates) ...[
              Padding(
                padding: const EdgeInsets.only(top: 6, bottom: 6),
                child: Text(
                  DateFormat('EEEE, d MMM yyyy').format(DateTime.parse(date)).toUpperCase(),
                  style: HealthTypography.label(),
                ),
              ),
              HealthCard(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                child: Column(
                  children: [
                    for (final lab in groups[date]!)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 7),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(lab.testName, style: HealthTypography.body(fontSize: 13.5)),
                                  if (lab.referenceRange != null)
                                    Text('Range ${lab.referenceRange}', style: HealthTypography.body(fontSize: 11, color: HealthColors.inkFaint)),
                                ],
                              ),
                            ),
                            Text(
                              lab.unit == null || lab.unit!.isEmpty ? lab.value : '${lab.value} ${lab.unit}',
                              style: HealthTypography.data(fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
            ],
          ],
        );
      },
    );
  }
}

/// Apple Watch-style focal scrolling: a row is full size and fully opaque in
/// the middle of the list and eases down in scale/opacity as it approaches
/// either edge, so whatever you're looking at is always the emphasised one.
/// Also carries a one-time entrance animation, staggered by position.
class _FocalRow extends StatelessWidget {
  const _FocalRow({required this.tick, required this.index, required this.child});

  final Listenable tick;
  final int index;
  final Widget child;

  // Shorter band at the top so the first row still reads clearly at rest,
  // longer at the bottom where rows are on their way in.
  static const _topBand = 90.0;
  static const _bottomBand = 150.0;
  static const _minScale = 0.90;
  static const _minOpacity = 0.35;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final focalChild = AnimatedBuilder(
      animation: tick,
      builder: (context, child) {
        if (reduceMotion) return child!;
        final focal = _focalAmount(context);
        // Rows comfortably in view skip the opacity layer entirely — that's
        // most rows, most of the time, and each layer is a saveLayer.
        if (focal >= 0.995) return child!;
        return Opacity(
          opacity: _minOpacity + (1 - _minOpacity) * focal,
          child: Transform.scale(
            scale: _minScale + (1 - _minScale) * focal,
            child: child,
          ),
        );
      },
      child: child,
    );
    if (reduceMotion) return focalChild;
    return TweenAnimationBuilder<double>(
      // Staggered entrance — capped so a long list doesn't crawl in.
      duration: Duration(milliseconds: 320 + math.min(index, 8) * 45),
      curve: Curves.easeOutCubic,
      tween: Tween(begin: 0, end: 1),
      builder: (context, entrance, child) => entrance >= 1
          ? child!
          : Opacity(
              opacity: entrance,
              child: Transform.translate(offset: Offset(0, (1 - entrance) * 18), child: child),
            ),
      child: focalChild,
    );
  }

  /// 1.0 when the row sits comfortably inside the list, easing to 0 at the
  /// top and bottom edges. Measured against the actual scroll viewport rather
  /// than guessed screen offsets, so it lands the same on any device.
  double _focalAmount(BuildContext context) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return 1;

    final viewportBox = Scrollable.maybeOf(context)?.context.findRenderObject() as RenderBox?;
    if (viewportBox == null || !viewportBox.hasSize) return 1;

    final centre = box.localToGlobal(Offset.zero, ancestor: viewportBox).dy + box.size.height / 2;
    final fromTop = centre / _topBand;
    final fromBottom = (viewportBox.size.height - centre) / _bottomBand;
    return math.min(fromTop, fromBottom).clamp(0.0, 1.0);
  }
}

class _LogRow extends ConsumerStatefulWidget {
  const _LogRow({required this.entry});
  final LogEntryView entry;

  @override
  ConsumerState<_LogRow> createState() => _LogRowState();
}

class _LogRowState extends ConsumerState<_LogRow> {
  bool _pressed = false;

  Future<void> _openEntry() async {
    HapticFeedback.lightImpact();
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => EntryDetailScreen(entry: widget.entry)),
    );
    if (changed == true) ref.read(logbookPagerProvider.notifier).refresh();
  }

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: _openEntry,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedScale(
          scale: _pressed ? 0.97 : 1,
          duration: const Duration(milliseconds: 130),
          curve: Curves.easeOut,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 130),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: _pressed ? HealthColors.chipIdle : HealthColors.surface,
              border: Border.all(
                color: _pressed
                    ? HealthColors.accentPrimary.withValues(alpha: 0.35)
                    : HealthColors.inkPrimary.withValues(alpha: 0.09),
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(entry.summary?.isNotEmpty == true ? entry.summary! : TypeTag.labelFor(entry.type),
                          style: HealthTypography.body(fontSize: 13.5), maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 3),
                      Text(DateFormat('MMM d, HH:mm').format(entry.timestamp),
                          style: HealthTypography.body(fontSize: 11.5, color: HealthColors.inkMuted)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                TypeTag(entry.type),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
