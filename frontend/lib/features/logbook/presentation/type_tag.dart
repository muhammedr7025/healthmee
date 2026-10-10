import 'package:flutter/material.dart';
import 'package:health_ui/health_ui.dart';

/// The small coloured label that tells a food log from a BP reading at a
/// glance — one colour per log type, used on Today, the Logbook and the
/// entry detail screen so they read the same everywhere.
class TypeTag extends StatelessWidget {
  const TypeTag(this.type, {super.key});

  final String type;

  static const _labels = {
    'food': 'Food',
    'hydration': 'Water',
    'sleep': 'Sleep',
    'mood': 'Mood',
    'activity': 'Activity',
    'stress': 'Stress',
    'symptom': 'Symptom',
    'vital': 'Vital',
  };

  static String labelFor(String type) => _labels[type] ?? type;

  static Color colorFor(String type) => switch (type) {
        'food' => HealthColors.accentPrimary,
        'hydration' => const Color(0xFF4F7C8A), // a cool blue-grey — the one non-warm note, so water reads as water
        'sleep' => HealthColors.inkPrimary,
        'mood' => HealthColors.accentSecondary,
        'activity' => HealthColors.accentSecondary,
        'stress' => HealthColors.reactionText,
        'symptom' => HealthColors.alertTrigger,
        'vital' => HealthColors.accentPrimaryDark,
        _ => HealthColors.inkMuted,
      };

  @override
  Widget build(BuildContext context) {
    final color = colorFor(type);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.13), borderRadius: BorderRadius.circular(8)),
      child: Text(labelFor(type).toUpperCase(), style: HealthTypography.label(fontSize: 9.5, color: color)),
    );
  }
}
