import 'package:health_ui/health_ui.dart';

import 'log_entry.dart';

/// MeMe's one-line reaction on an entry's detail screen. Rules, not a
/// model call — the same offline, instant, and never a diagnosis.
String memeCommentFor(LogEntryView entry) {
  final p = entry.payload;
  num? n(String key) => p[key] is num ? p[key] as num : num.tryParse('${p[key]}');

  switch (entry.type) {
    case 'food':
      final kcal = n('estimated_calories');
      return kcal != null
          ? 'Logged at about ${kcal.round()} kcal. One meal never makes or breaks a day — the week\'s pattern is what I watch.'
          : 'Logged. If you tell me roughly what was in it next time, I can estimate the calories too.';
    case 'hydration':
      return 'Every glass counts — this one goes straight into today\'s water total.';
    case 'sleep':
      final hours = n('hours') ?? 0;
      if (hours >= 7) return 'A solid night. Days after 7h+ of sleep tend to go better — let\'s see if yours does.';
      if (hours >= 6) return 'A little short of 7h. Nothing dramatic, just worth an earlier night when you can.';
      return 'A short night. Be gentle with yourself today, and I\'ll keep an eye on whether it becomes a pattern.';
    case 'mood':
      final mood = '${p['mood']}';
      if (mood == 'happy' || mood == 'calm') return 'Love seeing that. I\'ll look for what else lines up with days like this.';
      return 'Thanks for telling me — that takes honesty. If you want, add a line about what\'s behind it; it helps me spot patterns.';
    case 'activity':
      return 'Movement logged — it counts toward today\'s score and the 150 active minutes a week that make the biggest difference.';
    case 'stress':
      return 'Logged. A short walk or a few slow breaths takes the edge off more than it sounds like it should.';
    case 'symptom':
      return 'Noted, not diagnosed. If it sticks around or gets worse, that\'s one for your doctor — I\'ll keep the record so you can show them.';
    case 'vital':
      return _vitalComment(p, n);
    default:
      return 'Logged. I\'ll keep it with the rest of your day.';
  }
}

String _vitalComment(Map<String, dynamic> p, num? Function(String) n) {
  final value = n('value');
  switch ('${p['kind']}') {
    case 'blood_pressure':
      final dia = n('diastolic');
      if (value != null && (value >= 140 || (dia != null && dia >= 90))) {
        return 'That\'s above the usual range. One reading isn\'t a diagnosis — keep tracking, and share the trend with your doctor.';
      }
      return 'Noted. Blood pressure moves around during the day; readings over a few weeks tell the real story.';
    case 'blood_glucose':
      final unit = '${p['unit'] ?? ''}'.toLowerCase();
      final mgDl = value == null ? null : (unit.startsWith('mmol') ? value * 18 : value);
      final fasting = p['context'] == 'fasting';
      if (mgDl != null && fasting && mgDl >= 126) {
        return 'A fasting reading that high is worth a conversation with your doctor. Keep logging — the pattern matters more than one number.';
      }
      if (mgDl != null && fasting && mgDl >= 100) {
        return 'A touch above the usual fasting range. Worth keeping an eye on across the week.';
      }
      return 'Noted. Fasting and after-meal readings tell different stories, so saying which one helps me read it right.';
    case 'weight':
      return 'Weigh-ins are most useful at the same time of day — mornings, before breakfast, keep the trend honest.';
    case 'heart_rate':
      return 'Noted. Resting pulse drifts down as fitness builds — that\'s one of the nicest trends to watch.';
    case 'spo2':
      return 'Noted. Normal oxygen saturation sits at 95% or above — if you see readings under that at rest, mention it to your doctor.';
    case 'temperature':
      return 'Noted. If a fever lingers past a couple of days, that\'s one for your doctor.';
    default:
      return 'Reading saved.';
  }
}

/// Which face MeMe makes next to the comment.
MascotState mascotFor(LogEntryView entry) {
  final p = entry.payload;
  switch (entry.type) {
    case 'mood':
      final mood = '${p['mood']}';
      return mood == 'happy' || mood == 'calm' ? MascotState.love : MascotState.concerned;
    case 'symptom':
      return MascotState.concerned;
    case 'activity':
      return MascotState.celebrating;
    case 'sleep':
      final hours = p['hours'] is num ? p['hours'] as num : 0;
      return hours >= 7 ? MascotState.proud : MascotState.sleepy;
    case 'vital':
      return MascotState.thinking;
    default:
      return MascotState.happy;
  }
}
