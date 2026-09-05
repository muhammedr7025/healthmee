import '../../trends/data/trends_repository.dart';

/// Consecutive days (ending today) with at least one log — computed from
/// real trend data, not a separate backend counter. "This counts days you
/// told MeMe something, not days you hit a number" (VitaChat copy).
int computeStreak(TrendsData trends) {
  final byDate = {for (final d in trends.days) d.date: d.logCount};
  var streak = 0;
  var day = DateTime.now();
  while (true) {
    final key = day.toIso8601String().split('T').first;
    final count = byDate[key] ?? 0;
    if (count <= 0) break;
    streak++;
    day = day.subtract(const Duration(days: 1));
  }
  return streak;
}
