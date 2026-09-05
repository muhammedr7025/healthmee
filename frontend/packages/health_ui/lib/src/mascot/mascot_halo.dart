import 'package:flutter/material.dart';

import '../tokens/health_colors.dart';
import 'mascot_state.dart';
import 'meme_mascot.dart';

/// MeMe framed in a soft radial halo — the recurring "avatar" treatment
/// behind every mascot appearance next to a speech bubble (onboarding
/// steps, signup, login, the reset flow), as opposed to [MemeMascot] alone,
/// which is used bare in chat bubbles and empty states.
class MascotHalo extends StatelessWidget {
  const MascotHalo({super.key, required this.state, this.size = 74});

  final MascotState state;
  final double size;

  @override
  Widget build(BuildContext context) {
    final stage = size * 1.05;
    return SizedBox(
      width: stage,
      height: stage,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: size,
            height: size,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [HealthColors.reactionBubble, Colors.transparent]),
            ),
          ),
          MemeMascot(state: state, size: size),
        ],
      ),
    );
  }
}
