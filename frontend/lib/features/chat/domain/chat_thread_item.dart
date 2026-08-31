enum ChatItemKind { userText, assistantReply, logCard, alert }

class ChatThreadItem {
  const ChatThreadItem._({
    required this.kind,
    this.text,
    this.logType,
    this.summary,
    this.alertHard = true,
  });

  factory ChatThreadItem.userText(String text) => ChatThreadItem._(kind: ChatItemKind.userText, text: text);

  factory ChatThreadItem.assistantReply(String text) =>
      ChatThreadItem._(kind: ChatItemKind.assistantReply, text: text);

  factory ChatThreadItem.logCard({required String logType, required String summary}) =>
      ChatThreadItem._(kind: ChatItemKind.logCard, logType: logType, summary: summary);

  factory ChatThreadItem.alert({required String message, required bool hard}) =>
      ChatThreadItem._(kind: ChatItemKind.alert, text: message, alertHard: hard);

  final ChatItemKind kind;
  final String? text;
  final String? logType;
  final String? summary;
  final bool alertHard;
}
