/// Turns a raw log entry's structured payload into the "what I pulled out"
/// row list shown on the chat extraction card — mirrors the VitaChat
/// mockup's per-type extraction summaries.
List<MapEntry<String, String>> formatLogRows(String type, Map<String, dynamic> payload) {
  String s(dynamic v) => v?.toString() ?? '';

  switch (type) {
    case 'food':
      final items = (payload['food_items'] as List?)?.join(', ') ?? '';
      final rows = <MapEntry<String, String>>[
        MapEntry(items.isEmpty ? 'Food' : items, payload['estimated_calories'] != null ? '≈ ${payload['estimated_calories']} kcal' : ''),
      ];
      if (payload['meal_type'] != null) rows.add(MapEntry('Meal', s(payload['meal_type'])));
      return rows;
    case 'sleep':
      final rows = <MapEntry<String, String>>[MapEntry('Hours', '${s(payload['hours'])}h')];
      if (payload['quality'] != null) rows.add(MapEntry('Quality', s(payload['quality'])));
      return rows;
    case 'mood':
      final rows = <MapEntry<String, String>>[MapEntry('Mood', s(payload['mood']))];
      if (payload['intensity'] != null) rows.add(MapEntry('Intensity', '${s(payload['intensity'])}/10'));
      return rows;
    case 'activity':
      final rows = <MapEntry<String, String>>[
        MapEntry(s(payload['activity_type']), payload['duration_minutes'] != null ? '${s(payload['duration_minutes'])} min' : ''),
      ];
      if (payload['estimated_calories_burned'] != null) {
        rows.add(MapEntry('Burned', '≈ ${payload['estimated_calories_burned']} kcal'));
      }
      return rows;
    case 'stress':
      final rows = <MapEntry<String, String>>[MapEntry('Level', '${s(payload['level'])}/10')];
      if (payload['trigger'] != null) rows.add(MapEntry('Trigger', s(payload['trigger'])));
      return rows;
    case 'symptom':
      final rows = <MapEntry<String, String>>[MapEntry(s(payload['description']), s(payload['body_area']))];
      return rows;
    default:
      return payload.entries.map((e) => MapEntry(e.key, s(e.value))).toList();
  }
}

const _typeLabels = {
  'food': 'Logged from your message',
  'sleep': 'Sleep logged',
  'mood': 'Mood logged',
  'activity': 'Activity logged',
  'stress': 'Stress logged',
  'symptom': 'Symptom noted',
};

String extractCardLabel(String type) => _typeLabels[type] ?? 'Logged';
