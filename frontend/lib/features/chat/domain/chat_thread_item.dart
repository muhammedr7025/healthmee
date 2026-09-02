enum ChatItemKind { userText, assistantReply, alert, extractCard }

class ChatThreadItem {
  const ChatThreadItem._({
    required this.kind,
    this.text,
    this.logType,
    this.summary,
    this.alertHard = true,
    this.entryId,
    this.rows = const [],
    this.confirmed = false,
  });

  factory ChatThreadItem.userText(String text) => ChatThreadItem._(kind: ChatItemKind.userText, text: text);

  factory ChatThreadItem.assistantReply(String text) =>
      ChatThreadItem._(kind: ChatItemKind.assistantReply, text: text);

  /// The "what I pulled out" extraction card (dev-prompt §7.2) — one row per
  /// structured field, with a "Looks right" / "Edit" pair. The entry is
  /// already saved server-side by the time this renders; "Looks right" just
  /// dismisses the actions, "Edit" calls PATCH `/log-entries/{id}`.
  factory ChatThreadItem.extractCard({
    required String entryId,
    required String logType,
    required String summary,
    required List<MapEntry<String, String>> rows,
  }) =>
      ChatThreadItem._(
        kind: ChatItemKind.extractCard,
        entryId: entryId,
        logType: logType,
        summary: summary,
        rows: rows,
      );

  factory ChatThreadItem.alert({required String message, required bool hard}) =>
      ChatThreadItem._(kind: ChatItemKind.alert, text: message, alertHard: hard);

  final ChatItemKind kind;
  final String? text;
  final String? logType;
  final String? summary;
  final bool alertHard;
  final String? entryId;
  final List<MapEntry<String, String>> rows;
  final bool confirmed;

  ChatThreadItem copyWith({String? summary, bool? confirmed}) => ChatThreadItem._(
        kind: kind,
        text: text,
        logType: logType,
        summary: summary ?? this.summary,
        alertHard: alertHard,
        entryId: entryId,
        rows: rows,
        confirmed: confirmed ?? this.confirmed,
      );
}
