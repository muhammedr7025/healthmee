import 'package:flutter/material.dart';

import '../tokens/health_colors.dart';

/// The pill toggle used throughout VitaChat's settings-style screens
/// (caregiver permissions, reminders) — a terracotta-filled track with a
/// sliding white knob, animated.
class HealthSwitch extends StatelessWidget {
  const HealthSwitch({super.key, required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 40,
        height: 24,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: value ? HealthColors.accentPrimary : HealthColors.divider,
          borderRadius: BorderRadius.circular(999),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 18,
            height: 18,
            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
          ),
        ),
      ),
    );
  }
}
