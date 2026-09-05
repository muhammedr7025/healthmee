import 'dart:typed_data';

enum ChatItemKind { userText, userPhoto, assistantReply, alert, extractCard }

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
    this.photoBytes,
    this.photoUrl,
  });

  factory ChatThreadItem.userText(String text) => ChatThreadItem._(kind: ChatItemKind.userText, text: text);

  /// [bytes] is set for a photo just taken/picked this session; a photo
  /// restored from history instead carries [photoUrl] (a presigned download
  /// link) since raw bytes aren't kept around client-side between launches.
  factory ChatThreadItem.userPhoto({Uint8List? bytes, String? photoUrl, String? caption}) =>
      ChatThreadItem._(kind: ChatItemKind.userPhoto, photoBytes: bytes, photoUrl: photoUrl, text: caption);

  factory ChatThreadItem.assistantReply(String text) =>
      ChatThreadItem._(kind: ChatItemKind.assistantReply, text: text);

  /// The "what I pulled out" extraction card (dev-prompt §7.2) — one row per
  /// structured field, with a "Looks right" / "Edit" pair. The entry is
  /// already saved server-side by the time this renders; "Looks right" just
  /// dismisses the actions, "Edit" calls PATCH `/log-entries/{id}`.
  /// [confirmed] defaults to false for a card that just got created in this
  /// session; a card restored from history is passed in already confirmed,
  /// since there's no pending action left to take on something from the past.
  factory ChatThreadItem.extractCard({
    required String entryId,
    required String logType,
    required String summary,
    required List<MapEntry<String, String>> rows,
    bool confirmed = false,
  }) =>
      ChatThreadItem._(
        kind: ChatItemKind.extractCard,
        entryId: entryId,
        logType: logType,
        summary: summary,
        rows: rows,
        confirmed: confirmed,
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
  final Uint8List? photoBytes;
  final String? photoUrl;

  ChatThreadItem copyWith({String? summary, bool? confirmed}) => ChatThreadItem._(
        kind: kind,
        text: text,
        logType: logType,
        summary: summary ?? this.summary,
        alertHard: alertHard,
        entryId: entryId,
        rows: rows,
        confirmed: confirmed ?? this.confirmed,
        photoBytes: photoBytes,
        photoUrl: photoUrl,
      );
}
