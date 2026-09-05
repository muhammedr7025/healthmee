import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../media/data/media_repository.dart';
import '../data/chat_repository.dart';
import '../domain/chat_thread_item.dart';
import '../domain/log_row_formatter.dart';

class ChatState {
  const ChatState({this.items = const [], this.isThinking = false, this.isLoadingHistory = true});

  final List<ChatThreadItem> items;
  final bool isThinking;
  // True only for the brief window while the persisted thread is being
  // fetched on launch — lets the screen hold off on showing the "nothing
  // logged yet" empty state, which would otherwise flash before a returning
  // user's real history arrives and looks exactly like the history-loss bug.
  final bool isLoadingHistory;

  ChatState copyWith({List<ChatThreadItem>? items, bool? isThinking, bool? isLoadingHistory}) => ChatState(
        items: items ?? this.items,
        isThinking: isThinking ?? this.isThinking,
        isLoadingHistory: isLoadingHistory ?? this.isLoadingHistory,
      );
}

class ChatController extends StateNotifier<ChatState> {
  ChatController(this._repo, this._mediaRepo) : super(const ChatState()) {
    _loadHistory();
  }

  final ChatRepository _repo;
  final MediaRepository _mediaRepo;

  /// Restores the thread on launch so closing and reopening the app doesn't
  /// wipe it — plus MiMi's "we missed you" nudge when the thread's been
  /// quiet long enough, tacked on as the newest bubble.
  Future<void> _loadHistory() async {
    try {
      final history = await _repo.fetchHistory();
      state = state.copyWith(
        items: [
          for (final raw in history.items) _fromHistoryJson(raw),
          if (history.welcomeBackMessage != null) ChatThreadItem.assistantReply(history.welcomeBackMessage!),
        ],
        isLoadingHistory: false,
      );
    } catch (_) {
      // Offline, or the token isn't ready yet — thread just starts empty,
      // same as before this existed; sending a message still works.
      state = state.copyWith(isLoadingHistory: false);
    }
  }

  ChatThreadItem _fromHistoryJson(Map<String, dynamic> json) {
    switch (json['kind'] as String?) {
      case 'user_text':
        return ChatThreadItem.userText(json['text'] as String? ?? '');
      case 'user_photo':
        return ChatThreadItem.userPhoto(photoUrl: json['photo_url'] as String?, caption: json['text'] as String?);
      case 'alert':
        return ChatThreadItem.alert(message: json['message'] as String? ?? '', hard: json['severity'] == 'hard');
      case 'extract_card':
        final logType = json['log_type'] as String? ?? '';
        return ChatThreadItem.extractCard(
          entryId: json['entry_id'] as String,
          logType: logType,
          summary: extractCardLabel(logType),
          rows: formatLogRows(logType, Map<String, dynamic>.from(json['payload'] as Map? ?? {})),
          confirmed: true,
        );
      case 'assistant_reply':
      default:
        return ChatThreadItem.assistantReply(json['text'] as String? ?? '');
    }
  }

  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty) return;
    state = state.copyWith(items: [...state.items, ChatThreadItem.userText(text)], isThinking: true);
    await _sendAndHandle(text, mediaAssetId: null);
  }

  /// Photo logging (VitaChat's chat photo bubble). Uploads first, shows the
  /// real image immediately, then sends for extraction — a vision-capable
  /// provider (Anthropic/OpenAI/Gemini with a key set) analyzes it for real;
  /// mock mode honestly says it can't see it.
  Future<void> sendPhoto(Uint8List bytes, {String caption = ''}) async {
    state = state.copyWith(
      items: [...state.items, ChatThreadItem.userPhoto(bytes: bytes, caption: caption.isEmpty ? null : caption)],
      isThinking: true,
    );
    try {
      final mediaAssetId = await _mediaRepo.uploadPhoto(bytes);
      await _sendAndHandle(caption, mediaAssetId: mediaAssetId);
    } catch (e) {
      state = state.copyWith(
        items: [...state.items, ChatThreadItem.assistantReply("Couldn't upload that photo — please try again.")],
        isThinking: false,
      );
    }
  }

  Future<void> _sendAndHandle(String text, {required String? mediaAssetId}) async {
    try {
      final result = await _repo.sendMessage(text, mediaAssetId: mediaAssetId);
      final newItems = <ChatThreadItem>[
        for (final entry in result.entries)
          ChatThreadItem.extractCard(
            entryId: entry['id'] as String,
            logType: entry['type'] as String,
            summary: extractCardLabel(entry['type'] as String),
            rows: formatLogRows(entry['type'] as String, Map<String, dynamic>.from(entry['payload'] as Map? ?? {})),
          ),
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

  void confirmEntry(String entryId) {
    state = state.copyWith(
      items: [
        for (final item in state.items)
          if (item.entryId == entryId) item.copyWith(confirmed: true) else item,
      ],
    );
  }

  Future<void> editEntry(String entryId, String newSummaryLine) async {
    await _repo.editEntrySummary(entryId, newSummaryLine);
    state = state.copyWith(
      items: [
        for (final item in state.items)
          if (item.entryId == entryId)
            ChatThreadItem.extractCard(
              entryId: entryId,
              logType: item.logType ?? '',
              summary: item.summary ?? '',
              rows: [MapEntry(newSummaryLine, '')],
            ).copyWith(confirmed: true)
          else
            item,
      ],
    );
  }
}

final chatControllerProvider = StateNotifierProvider<ChatController, ChatState>((ref) {
  return ChatController(ref.watch(chatRepositoryProvider), ref.watch(mediaRepositoryProvider));
});
