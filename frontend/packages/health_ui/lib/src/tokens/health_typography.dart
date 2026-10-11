import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'health_colors.dart';

/// Type scale per the VitaChat redesign: Newsreader (display — headlines,
/// the "Hi, I'm Mo." welcome line), DM Sans (body/UI), IBM Plex Mono
/// (data/numbers — calories, BP, timestamps; not in the source mockup but
/// kept for numeric legibility, in the same spirit as the mono data style
/// it replaces).
///
/// Styles are memoised: GoogleFonts.* builds a fresh TextStyle (and looks up
/// the font) on every call, and these getters run hundreds of times per
/// frame in long lists.
class HealthTypography {
  HealthTypography._();

  static final _cache = <String, TextStyle>{};

  static TextStyle _memo(String key, TextStyle Function() build) => _cache.putIfAbsent(key, build);

  static TextStyle display({double fontSize = 28, FontWeight weight = FontWeight.w500}) => _memo(
        'd$fontSize${weight.value}',
        () => GoogleFonts.newsreader(fontSize: fontSize, fontWeight: weight, color: HealthColors.inkPrimary),
      );

  static TextStyle mascotSpeech({double fontSize = 16}) => _memo(
        'm$fontSize',
        () => GoogleFonts.dmSans(fontSize: fontSize, fontWeight: FontWeight.w400, color: HealthColors.inkPrimary, height: 1.5),
      );

  static TextStyle body({double fontSize = 15, FontWeight weight = FontWeight.w400, Color? color}) => _memo(
        'b$fontSize${weight.value}${(color ?? HealthColors.inkPrimary).toARGB32()}',
        () => GoogleFonts.dmSans(fontSize: fontSize, fontWeight: weight, color: color ?? HealthColors.inkPrimary),
      );

  /// Uppercase eyebrow labels. Default colour is inkMuted (4.9:1 on cream) —
  /// inkFaint failed contrast at 11px.
  static TextStyle label({double fontSize = 11, Color? color}) => _memo(
        'l$fontSize${(color ?? HealthColors.inkMuted).toARGB32()}',
        () => GoogleFonts.dmSans(fontSize: fontSize, fontWeight: FontWeight.w500, letterSpacing: 1.0, color: color ?? HealthColors.inkMuted),
      );

  static TextStyle data({double fontSize = 20, FontWeight weight = FontWeight.w600, Color? color}) => _memo(
        'n$fontSize${weight.value}${(color ?? HealthColors.inkPrimary).toARGB32()}',
        () => GoogleFonts.ibmPlexMono(fontSize: fontSize, fontWeight: weight, color: color ?? HealthColors.inkPrimary),
      );
}
