import 'package:flutter/material.dart';

import '../tokens/health_colors.dart';
import '../tokens/health_spacing.dart';

/// The one shared card shape used across the app — rounded corners, soft
/// shadow, no hard edges (dev-prompt §2 iconography rule).
class HealthCard extends StatelessWidget {
  const HealthCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(HealthSpacing.md),
    this.color = HealthColors.surface,
    this.onTap,
  });

  final Widget child;
  final EdgeInsets padding;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(HealthSpacing.radiusMd),
        boxShadow: [
          BoxShadow(
            color: HealthColors.inkPrimary.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );

    if (onTap == null) return card;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(HealthSpacing.radiusMd),
        onTap: onTap,
        child: card,
      ),
    );
  }
}
