import 'package:flutter/material.dart';

import '../haptics.dart';
import '../tokens/health_colors.dart';
import '../tokens/health_typography.dart';

/// The one selectable pill (filters, metrics, time slots, choices). Selected
/// = ink on cream; idle = muted on chip. 44px tall tap target regardless of
/// its visual height; announces its selected state.
class HealthChip extends StatelessWidget {
  const HealthChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.outlined = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  /// Accent-outlined variant for "do something" chips (quick-log) rather than
  /// "pick something" chips.
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    final fg = selected
        ? HealthColors.bgBase
        : (outlined ? HealthColors.accentPrimaryDark : HealthColors.inkMuted);
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          Haptics.select();
          onTap();
        },
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
              decoration: BoxDecoration(
                color: selected ? HealthColors.inkPrimary : (outlined ? HealthColors.surface : HealthColors.chipIdle),
                border: outlined && !selected ? Border.all(color: HealthColors.accentPrimary.withValues(alpha: 0.35)) : null,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[Icon(icon, size: 13, color: fg), const SizedBox(width: 4)],
                  AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 180),
                    style: HealthTypography.body(fontSize: 12.5, weight: selected ? FontWeight.w700 : FontWeight.w500, color: fg),
                    child: Text(label),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
