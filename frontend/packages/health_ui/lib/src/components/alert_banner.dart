import 'package:flutter/material.dart';

import '../tokens/health_colors.dart';
import '../tokens/health_spacing.dart';
import '../tokens/health_typography.dart';

/// Allergy/trigger warnings (PRD §7.3). Deliberately a different weight from
/// [LogConfirmationCard]'s entrance — a firmer double-shake, not a swoosh —
/// since this is a safety signal, not a positive confirmation (dev-prompt §3).
class AlertBanner extends StatefulWidget {
  const AlertBanner({super.key, required this.message, this.hard = true});

  final String message;

  /// Hard = allergy-severity warning (terracotta-red). Soft = goal-conflict
  /// nudge or disclaimer (turmeric-gold), a lighter touch.
  final bool hard;

  @override
  State<AlertBanner> createState() => _AlertBannerState();
}

class _AlertBannerState extends State<AlertBanner> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 360));
  }

  bool _played = false;

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
    final color = widget.hard ? HealthColors.alertTrigger : HealthColors.accentPrimary;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        final shake = widget.hard ? (1 - t) * 6 * ((t * 6).truncate().isEven ? 1 : -1) : 0.0;
        return Opacity(
          opacity: t,
          child: Transform.translate(offset: Offset(shake, 0), child: child),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: HealthSpacing.md, vertical: HealthSpacing.sm + 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(HealthSpacing.radiusSm),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            Icon(widget.hard ? Icons.warning_rounded : Icons.info_outline_rounded, color: color, size: 20),
            const SizedBox(width: HealthSpacing.sm),
            Expanded(child: Text(widget.message, style: HealthTypography.body(color: HealthColors.inkPrimary))),
          ],
        ),
      ),
    );
  }
}
