import 'package:flutter/services.dart';

/// One haptic vocabulary for the whole app, so the same kind of action feels
/// the same everywhere: pick something, commit something, get something
/// back, destroy something, or hit a wall. Screens call these instead of
/// choosing a HapticFeedback method ad hoc.
class Haptics {
  Haptics._();

  /// Chips, tabs, nav, switches, pills, segment controls.
  static void select() => HapticFeedback.selectionClick();

  /// Send, save, add, mark taken — fire *after* the request succeeded.
  static void commit() => HapticFeedback.lightImpact();

  /// Something arrived or was achieved: a reply landed, a streak, a score band.
  static void reward() => HapticFeedback.mediumImpact();

  /// Delete / revoke / remove — after the confirmation, not on the first tap.
  static void destructive() => HapticFeedback.heavyImpact();

  /// Failed send, failed save, invalid field on submit.
  static void error() => HapticFeedback.vibrate();
}
