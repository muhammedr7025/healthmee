import 'dart:typed_data';

enum ChatItemKind { userText, userPhoto, assistantReply, alert, extractCard }

/// Delivery state of something the user sent. Restored history is always
/// `sent`; a message typed this session is `pending` until the server has
/// it and `failed` if it never got there — shown on the bubble with a
/// tap-to-retry, never silently dropped.
enum SendStatus { sent, pending, failed }

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
    this.status = SendStatus.sent,
    this.clientId,
    this.payload = const {},
    this.degraded = false,
  });

  factory ChatThreadItem.userText(String text, {SendStatus status = SendStatus.sent, String? clientId}) =>
      ChatThreadItem._(kind: ChatItemKind.userText, text: text, status: status, clientId: clientId);

  /// [bytes] is set for a photo just taken/picked this session; a photo
  /// restored from history instead carries [photoUrl] (a presigned download
  /// link) since raw bytes aren't kept around client-side between launches.
  factory ChatThreadItem.userPhoto({
    Uint8List? bytes,
    String? photoUrl,
    String? caption,
    SendStatus status = SendStatus.sent,
    String? clientId,
  }) =>
      ChatThreadItem._(
        kind: ChatItemKind.userPhoto,
        photoBytes: bytes,
        photoUrl: photoUrl,
        text: caption,
        status: status,
        clientId: clientId,
      );

  factory ChatThreadItem.assistantReply(String text) =>
      ChatThreadItem._(kind: ChatItemKind.assistantReply, text: text);

  /// The "what I pulled out" extraction card (dev-prompt §7.2) — one row per
  /// structured field, a "Saved to today" line and an Edit action that calls
  /// PATCH `/log-entries/{id}`. The entry is already saved server-side by the
  /// time this renders, so there is deliberately no confirm step: a tap that
  /// changed nothing taught people the opposite of what was true.
  /// [confirmed] is kept for history replay (cards restored from the server
  /// are marked confirmed) but no longer changes what the card shows.
  factory ChatThreadItem.extractCard({
    required String entryId,
    required String logType,
    required String summary,
    required List<MapEntry<String, String>> rows,
    Map<String, dynamic> payload = const {},
    bool confirmed = false,
    bool degraded = false,
  }) =>
      ChatThreadItem._(
        kind: ChatItemKind.extractCard,
        entryId: entryId,
        logType: logType,
        summary: summary,
        rows: rows,
        payload: payload,
        confirmed: confirmed,
        degraded: degraded,
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
  final SendStatus status;

  /// Identifies a message sent this session so its bubble can be updated
  /// (pending → sent/failed) and retried.
  final String? clientId;

  /// The raw structured payload behind an extraction card — what the typed
  /// correction sheet edits.
  final Map<String, dynamic> payload;

  /// This card came from the offline extractor because the model failed.
  final bool degraded;

  ChatThreadItem copyWith({
    String? summary,
    bool? confirmed,
    SendStatus? status,
    List<MapEntry<String, String>>? rows,
    Map<String, dynamic>? payload,
    bool? degraded,
  }) =>
      ChatThreadItem._(
        kind: kind,
        text: text,
        logType: logType,
        summary: summary ?? this.summary,
        alertHard: alertHard,
        entryId: entryId,
        rows: rows ?? this.rows,
        confirmed: confirmed ?? this.confirmed,
        photoBytes: photoBytes,
        photoUrl: photoUrl,
        status: status ?? this.status,
        clientId: clientId,
        payload: payload ?? this.payload,
        degraded: degraded ?? this.degraded,
      );
}
