import 'package:flutter/material.dart';

/// Color tokens from the "savanna dawn / Kerala spice" palette
/// (Development-Prompt-Health-App.md §2) — deliberately not the generic
/// cream+terracotta or near-black+neon "AI app" defaults.
class HealthColors {
  HealthColors._();

  static const Color bgBase = Color(0xFFFBF7F0);
  static const Color inkPrimary = Color(0xFF3D4451);
  static const Color accentPrimary = Color(0xFFE2A63B); // turmeric gold
  static const Color accentSecondary = Color(0xFF7A9B76); // sage green
  static const Color accentTertiary = Color(0xFF8C96C6); // dusty periwinkle
  static const Color alertTrigger = Color(0xFFC65D4B); // muted terracotta-red

  static const Color surface = Colors.white;
  static const Color inkMuted = Color(0xFF8A8F99);
  static const Color divider = Color(0xFFE7E0D4);
}
