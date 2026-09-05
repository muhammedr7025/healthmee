import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  /// Bumped on every scroll frame so each row can re-evaluate where it sits
  /// in the viewport and scale/fade accordingly.
  final _scrollTick = ValueNotifier<int>(0);

  /// Rows are one "detent" apart, so a light tick every row-height of travel
  /// gives the Digital-Crown feel rather than a continuous buzz.
  static const _detent = 84.0;
  double _lastHapticOffset = 0;

  @override
  void dispose() {
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
                      child: GestureDetector(
                        onTap: () {
                          if (activeFilter == f.$1) return;
                          HapticFeedback.selectionClick();
                          ref.read(logbookTypeFilterProvider.notifier).state = f.$1;
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOutCubic,
                          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
                          decoration: BoxDecoration(
                            color: selected ? HealthColors.inkPrimary : HealthColors.chipIdle,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 220),
                            curve: Curves.easeOutCubic,
                            style: HealthTypography.body(
                              fontSize: 12.5,
                              weight: selected ? FontWeight.w700 : FontWeight.w500,
                              color: selected ? HealthColors.bgBase : HealthColors.inkMuted,
                            ),
                            child: Text(f.$2),
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
                              const MemeMascot(state: MascotState.idle, size: 96),
                              const SizedBox(height: HealthSpacing.md),
                              Text(
                                entries.isEmpty ? 'Nothing here yet — start a conversation with MeMe.' : 'No matches for "$query".',
                                style: HealthTypography.mascotSpeech(),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                    return NotificationListener<ScrollNotification>(
                      onNotification: _onScroll,
                      child: MemoryTrailTimeline(
                        itemCount: filtered.length,
                        itemBuilder: (context, index) => _FocalRow(
                          tick: _scrollTick,
                          index: index,
                          child: _LogRow(entry: filtered[index]),
                        ),
                      ),
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
    return TweenAnimationBuilder<double>(
      // Staggered entrance — capped so a long list doesn't crawl in.
      duration: Duration(milliseconds: 320 + math.min(index, 8) * 45),
      curve: Curves.easeOutCubic,
      tween: Tween(begin: 0, end: 1),
      builder: (context, entrance, child) => Opacity(
        opacity: entrance,
        child: Transform.translate(offset: Offset(0, (1 - entrance) * 18), child: child),
      ),
      child: AnimatedBuilder(
        animation: tick,
        builder: (context, child) {
          final focal = _focalAmount(context);
          return Opacity(
            opacity: _minOpacity + (1 - _minOpacity) * focal,
            child: Transform.scale(
              scale: _minScale + (1 - _minScale) * focal,
              child: child,
            ),
          );
        },
        child: child,
      ),
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
    final entry = widget.entry;
    final controller = TextEditingController(text: entry.summary ?? '');

    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: HealthColors.bgBase,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(
          HealthSpacing.lg,
          HealthSpacing.lg,
          HealthSpacing.lg,
          MediaQuery.of(context).viewInsets.bottom + HealthSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 4,
              margin: const EdgeInsets.only(bottom: HealthSpacing.md),
              decoration: BoxDecoration(color: HealthColors.divider, borderRadius: BorderRadius.circular(2)),
            ),
            Text(entry.type.toUpperCase(), style: HealthTypography.label()),
            const SizedBox(height: 4),
            Text(DateFormat('EEEE, MMM d · HH:mm').format(entry.timestamp),
                style: HealthTypography.body(fontSize: 12, color: HealthColors.inkMuted)),
            const SizedBox(height: HealthSpacing.md),
            TextField(controller: controller, maxLines: 3, autofocus: false),
            const SizedBox(height: HealthSpacing.md),
            Row(
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context, '__deleted__'),
                  child: Text('Delete', style: TextStyle(color: HealthColors.alertTrigger)),
                ),
                const Spacer(),
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, controller.text.trim()),
                  child: const Text('Save'),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    if (result == null) return;
    final repo = ref.read(logbookRepositoryProvider);
    if (result == '__deleted__') {
      await repo.deleteEntry(entry.id);
      HapticFeedback.mediumImpact();
    } else {
      await repo.editEntrySummary(entry.id, result);
      HapticFeedback.selectionClick();
    }
    ref.invalidate(logbookEntriesProvider);
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
                      Text(entry.summary?.isNotEmpty == true ? entry.summary! : entry.type,
                          style: HealthTypography.body(fontSize: 13.5)),
                      const SizedBox(height: 3),
                      Text(DateFormat('MMM d, HH:mm').format(entry.timestamp),
                          style: HealthTypography.body(fontSize: 11.5, color: HealthColors.inkMuted)),
                    ],
                  ),
                ),
                Text(entry.type.toUpperCase(), style: HealthTypography.data(fontSize: 10.5, color: HealthColors.inkFaint)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
