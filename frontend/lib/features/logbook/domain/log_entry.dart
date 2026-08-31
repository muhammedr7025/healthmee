class LogEntryView {
  const LogEntryView({
    required this.id,
    required this.type,
    required this.timestamp,
    required this.payload,
    this.summary,
  });

  final String id;
  final String type;
  final DateTime timestamp;
  final Map<String, dynamic> payload;
  final String? summary;

  factory LogEntryView.fromJson(Map<String, dynamic> json) => LogEntryView(
        id: json['id'] as String,
        type: json['type'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String),
        payload: Map<String, dynamic>.from(json['payload'] as Map? ?? {}),
        summary: json['summary'] as String?,
      );
}
