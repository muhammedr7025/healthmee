import 'package:flutter/material.dart';

import '../mascot/mascot_state.dart';
import '../mascot/meme_mascot.dart';
import '../tokens/health_spacing.dart';
import '../tokens/health_typography.dart';

/// Nothing here yet (or it couldn't load): MeMe, one line, optionally one
/// action. The same shape on every screen.
class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.message, this.mascot = MascotState.happy, this.actionLabel, this.onAction});

  final String message;
  final MascotState mascot;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(HealthSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            MemeMascot(state: mascot, size: 96),
            const SizedBox(height: HealthSpacing.md),
            Text(message, style: HealthTypography.mascotSpeech(), textAlign: TextAlign.center),
            if (actionLabel != null) ...[
              const SizedBox(height: HealthSpacing.sm),
              TextButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
