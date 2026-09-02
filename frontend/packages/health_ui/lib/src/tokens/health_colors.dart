import 'package:flutter/material.dart';

/// Color tokens from the "Warm Paper" direction — the VitaChat design
/// (Sept 2026 redesign): warm cream/paper surfaces, charcoal ink, a single
/// confident terracotta accent. Deliberately not the generic cream+terracotta
/// "AI app" default taken further — everything here is pulled straight from
/// the shipped VitaChat prototype's palette.
class HealthColors {
  HealthColors._();

  static const Color bgBase = Color(0xFFF7F2E9);
  static const Color inkPrimary = Color(0xFF241F1A);
  static const Color accentPrimary = Color(0xFFB4633F); // terracotta
  static const Color accentPrimaryDark = Color(0xFF8F4B2C); // pressed/hover
  static const Color accentSecondary = Color(0xFF5C7A4A); // moss green — goals, positive trends
  static const Color accentTertiary = Color(0xFFC9A189); // warm tan — mascot idle tint
  static const Color alertTrigger = Color(0xFFB4633F); // same terracotta the design uses for hard allergy flags

  static const Color surface = Color(0xFFFFFDF8);
  static const Color chipIdle = Color(0xFFEFE7D8);
  static const Color chipIdleHover = Color(0xFFE6DBC8);
  static const Color reactionBubble = Color(0xFFF0E2D6);
  static const Color reactionText = Color(0xFF5C4437);
  static const Color inkMuted = Color(0xFF8A7F70);
  static const Color inkFaint = Color(0xFFA2988A);
  static const Color divider = Color(0xFFE7DDCD);
}
