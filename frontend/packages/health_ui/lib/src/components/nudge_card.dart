import 'package:flutter/material.dart';

import '../mascot/mascot_state.dart';
import '../mascot/meme_mascot.dart';
import '../tokens/health_colors.dart';
import '../tokens/health_typography.dart';

/// MeMe says one thing in a warm bubble — Today's nudge, Trends' callout,
/// the entry detail comment. One shape for all three.
class NudgeCard extends StatelessWidget {
  const NudgeCard({super.key, required this.text, this.mascot = MascotState.curious, this.onTap});

  final String text;
  final MascotState mascot;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: HealthColors.reactionBubble,
        border: Border.all(color: HealthColors.accentPrimary.withValues(alpha: 0.25)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MemeMascot(state: mascot, size: 38),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: HealthTypography.body(fontSize: 14, color: HealthColors.reactionText))),
        ],
      ),
    );
    if (onTap == null) return Semantics(label: 'MeMe says: $text', child: card);
    return Semantics(
      button: true,
      label: 'MeMe says: $text',
      child: InkWell(borderRadius: BorderRadius.circular(20), onTap: onTap, child: card),
    );
  }
}
