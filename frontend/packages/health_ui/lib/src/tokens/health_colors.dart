import 'package:flutter/material.dart';

/// Color tokens from the "Warm Paper" direction — the VitaChat design
/// (Sept 2026 redesign): warm cream/paper surfaces, charcoal ink, a single
/// confident terracotta accent. Deliberately not the generic cream+terracotta
/// "AI app" default taken further — everything here is pulled straight from
/// the shipped VitaChat prototype's palette.
///
/// Contrast on bgBase (#F7F2E9): inkPrimary ≈ 13:1, inkMuted ≈ 4.9:1 (body
/// text safe), inkFaint ≈ 3.5:1 (decoration and large text only).
class HealthColors {
  HealthColors._();

  static const Color bgBase = Color(0xFFF7F2E9);
  static const Color inkPrimary = Color(0xFF241F1A);
  static const Color accentPrimary = Color(0xFFB4633F); // terracotta
  static const Color accentPrimaryDark = Color(0xFF8F4B2C); // pressed/hover, and the only terracotta safe for small text
  static const Color accentSecondary = Color(0xFF5C7A4A); // moss green — goals, positive trends
  static const Color accentTertiary = Color(0xFFC9A189); // warm tan — mascot idle tint
  static const Color alertTrigger = Color(0xFFB4633F); // same terracotta the design uses for hard allergy flags

  static const Color surface = Color(0xFFFFFDF8);
  static const Color chipIdle = Color(0xFFEFE7D8);
  static const Color chipIdleHover = Color(0xFFE6DBC8);
  static const Color reactionBubble = Color(0xFFF0E2D6);
  static const Color reactionText = Color(0xFF5C4437);
  static const Color inkMuted = Color(0xFF6F665A); // was #8A7F70 (3.5:1) — darkened to pass AA for body text
  static const Color inkFaint = Color(0xFF8A7F70); // decorative only: dividers' text, large captions
  static const Color divider = Color(0xFFE7DDCD);

  // Semantic tints — previously hand-rolled as hex literals in six screens.
  static const Color warnBg = Color(0xFFFDEEE4); // behind terracotta warnings and "worth showing your doctor"
  static const Color mossBg = Color(0xFFEEF0E2); // behind achievements / "going well"
  static const Color mossInk = Color(0xFF3C4A33);
  static const Color softAlert = Color(0xFF8A6A1F); // turmeric gold: soft nudges and disclaimers, not allergy red
  static const Color softAlertBg = Color(0xFFF6EBD2);
}
