import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'health_colors.dart';

/// Type scale per the VitaChat redesign: Newsreader (display — headlines,
/// the "Hi, I'm Mo." welcome line), DM Sans (body/UI), IBM Plex Mono
/// (data/numbers — calories, BP, timestamps; not in the source mockup but
/// kept for numeric legibility, in the same spirit as the mono data style
/// it replaces).
class HealthTypography {
  HealthTypography._();

  static TextStyle display({double fontSize = 28, FontWeight weight = FontWeight.w500}) =>
      GoogleFonts.newsreader(fontSize: fontSize, fontWeight: weight, color: HealthColors.inkPrimary);

  static TextStyle mascotSpeech({double fontSize = 16}) => GoogleFonts.dmSans(
        fontSize: fontSize,
        fontWeight: FontWeight.w400,
        color: HealthColors.inkPrimary,
        height: 1.5,
      );

  static TextStyle body({double fontSize = 15, FontWeight weight = FontWeight.w400, Color? color}) =>
      GoogleFonts.dmSans(fontSize: fontSize, fontWeight: weight, color: color ?? HealthColors.inkPrimary);

  static TextStyle label({double fontSize = 11, Color? color}) => GoogleFonts.dmSans(
        fontSize: fontSize,
        fontWeight: FontWeight.w500,
        letterSpacing: 1.0,
        color: color ?? HealthColors.inkFaint,
      );

  static TextStyle data({double fontSize = 20, FontWeight weight = FontWeight.w600, Color? color}) =>
      GoogleFonts.ibmPlexMono(fontSize: fontSize, fontWeight: weight, color: color ?? HealthColors.inkPrimary);
}
