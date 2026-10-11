import 'package:flutter/material.dart';

import '../haptics.dart';
import '../tokens/health_colors.dart';
import '../tokens/health_typography.dart';

/// Two to four equal tabs in a cream track (Charts | Read, Timeline | Vitals
/// | Labs | Symptoms). The selected tab slides between positions.
class SegmentedControl extends StatelessWidget {
  const SegmentedControl({
    super.key,
    required this.segments,
    required this.selected,
    required this.onChanged,
  });

  /// value → label, in display order.
  final List<(String, String)> segments;
  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final index = segments.indexWhere((s) => s.$1 == selected).clamp(0, segments.length - 1);
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: HealthColors.chipIdle, borderRadius: BorderRadius.circular(14)),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final segmentWidth = constraints.maxWidth / segments.length;
          return SizedBox(
            height: 36,
            child: Stack(
              children: [
                AnimatedPositioned(
                  duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  left: index * segmentWidth,
                  top: 0,
                  bottom: 0,
                  width: segmentWidth,
                  child: Container(
                    decoration: BoxDecoration(color: HealthColors.inkPrimary, borderRadius: BorderRadius.circular(11)),
                  ),
                ),
                Row(
                  children: [
                    for (final segment in segments)
                      Expanded(
                        child: Semantics(
                          button: true,
                          selected: segment.$1 == selected,
                          label: segment.$2,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {
                              if (segment.$1 == selected) return;
                              Haptics.select();
                              onChanged(segment.$1);
                            },
                            child: Center(
                              child: AnimatedDefaultTextStyle(
                                duration: const Duration(milliseconds: 180),
                                style: HealthTypography.body(
                                  fontSize: 12.5,
                                  weight: FontWeight.w500,
                                  color: segment.$1 == selected ? HealthColors.bgBase : HealthColors.inkMuted,
                                ),
                                child: Text(segment.$2, maxLines: 1, overflow: TextOverflow.ellipsis),
                              ),
                            ),
                          ),
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
