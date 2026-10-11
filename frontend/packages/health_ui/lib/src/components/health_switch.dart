import 'package:flutter/material.dart';

import '../haptics.dart';
import '../tokens/health_colors.dart';

/// The pill toggle used throughout VitaChat's settings-style screens
/// (caregiver permissions, reminders) — a terracotta-filled track with a
/// sliding white knob, animated. The visual is 40×24; the tap target is 44.
class HealthSwitch extends StatelessWidget {
  const HealthSwitch({super.key, required this.value, required this.onChanged, this.label});

  final bool value;
  final ValueChanged<bool> onChanged;

  /// What this switch controls, for screen readers.
  final String? label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      toggled: value,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          Haptics.select();
          onChanged(!value);
        },
        child: SizedBox(
          width: 48,
          height: 44,
          child: Center(
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
          ),
        ),
      ),
    );
  }
}
