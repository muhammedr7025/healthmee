import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/chat_repository.dart';
import '../domain/chat_thread_item.dart';

class ChatState {
  const ChatState({this.items = const [], this.isThinking = false});

  final List<ChatThreadItem> items;
  final bool isThinking;

  ChatState copyWith({List<ChatThreadItem>? items, bool? isThinking}) =>
      ChatState(items: items ?? this.items, isThinking: isThinking ?? this.isThinking);
}

class ChatController extends StateNotifier<ChatState> {
  ChatController(this._repo) : super(const ChatState());

  final ChatRepository _repo;

  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    state = state.copyWith(items: [...state.items, ChatThreadItem.userText(text)], isThinking: true);

    try {
      final result = await _repo.sendMessage(text);
      final newItems = <ChatThreadItem>[
        for (final entry in result.entries)
          ChatThreadItem.logCard(logType: entry['type'] as String, summary: entry['summary'] as String? ?? ''),
        for (final alert in result.alerts)
          ChatThreadItem.alert(message: alert['message'] as String, hard: alert['severity'] == 'hard'),
        if (result.reply.isNotEmpty) ChatThreadItem.assistantReply(result.reply),
      ];
      state = state.copyWith(items: [...state.items, ...newItems], isThinking: false);
    } catch (e) {
      state = state.copyWith(
        items: [...state.items, ChatThreadItem.assistantReply("I couldn't reach the server — please try again.")],
        isThinking: false,
      );
    }
  }
}

final chatControllerProvider = StateNotifierProvider<ChatController, ChatState>((ref) {
  return ChatController(ref.watch(chatRepositoryProvider));
});
