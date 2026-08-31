import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'health_colors.dart';

/// Type scale per dev-prompt §2: Fraunces (display/mascot speech), Inter
/// (body/UI), IBM Plex Mono (data/numbers — calories, BP, timestamps).
class HealthTypography {
  HealthTypography._();

  static TextStyle display({double fontSize = 28, FontWeight weight = FontWeight.w600}) =>
      GoogleFonts.fraunces(fontSize: fontSize, fontWeight: weight, color: HealthColors.inkPrimary);

  static TextStyle mascotSpeech({double fontSize = 16}) => GoogleFonts.fraunces(
        fontSize: fontSize,
        fontWeight: FontWeight.w500,
        fontStyle: FontStyle.italic,
        color: HealthColors.inkPrimary,
      );

  static TextStyle body({double fontSize = 15, FontWeight weight = FontWeight.w400, Color? color}) =>
      GoogleFonts.inter(fontSize: fontSize, fontWeight: weight, color: color ?? HealthColors.inkPrimary);

  static TextStyle label({double fontSize = 13, Color? color}) => GoogleFonts.inter(
        fontSize: fontSize,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
        color: color ?? HealthColors.inkMuted,
      );

  static TextStyle data({double fontSize = 20, FontWeight weight = FontWeight.w600, Color? color}) =>
      GoogleFonts.ibmPlexMono(fontSize: fontSize, fontWeight: weight, color: color ?? HealthColors.inkPrimary);
}
