import 'package:flutter/material.dart';

import '../tokens/health_colors.dart';
import '../tokens/health_spacing.dart';
import '../tokens/health_typography.dart';
import 'health_card.dart';

/// The inline confirmation card that appears in the chat thread after an
/// entry is extracted (PRD §7.2). Entrance follows the "Memory Trail" motif —
/// a gentle curved trunk-swoosh, not a flat fade (dev-prompt §3) — degrading
/// to a plain fade when reduced-motion is on.
class LogConfirmationCard extends StatefulWidget {
  const LogConfirmationCard({
    super.key,
    required this.icon,
    required this.summary,
    required this.typeLabel,
    this.onEdit,
  });

  final IconData icon;
  final String summary;
  final String typeLabel;
  final VoidCallback? onEdit;

  @override
  State<LogConfirmationCard> createState() => _LogConfirmationCardState();
}

class _LogConfirmationCardState extends State<LogConfirmationCard> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _curve;

  bool _played = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 420));
    _curve = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_played) return;
    _played = true;
    if (!(MediaQuery.maybeOf(context)?.disableAnimations ?? false)) {
      _controller.forward();
    } else {
      _controller.value = 1;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _curve,
      builder: (context, child) {
        final t = _curve.value;
        // A slight arc: slide in from the right while dipping down then
        // settling — evokes a trunk swoosh rather than a straight slide.
        final dx = (1 - t) * 48;
        final dy = 12 * (1 - t) * (1 + (1 - t));
        return Opacity(
          opacity: t,
          child: Transform.translate(offset: Offset(dx, dy), child: child),
        );
      },
      child: HealthCard(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(HealthSpacing.sm),
              decoration: BoxDecoration(
                color: HealthColors.accentSecondary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(HealthSpacing.radiusSm),
              ),
              child: Icon(widget.icon, color: HealthColors.accentSecondary, size: 20),
            ),
            const SizedBox(width: HealthSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.typeLabel.toUpperCase(), style: HealthTypography.label()),
                  const SizedBox(height: 2),
                  Text(widget.summary, style: HealthTypography.body()),
                ],
              ),
            ),
            if (widget.onEdit != null)
              IconButton(
                onPressed: widget.onEdit,
                icon: const Icon(Icons.edit_outlined, size: 18),
                color: HealthColors.inkMuted,
                tooltip: 'Edit',
              ),
          ],
        ),
      ),
    );
  }
}
