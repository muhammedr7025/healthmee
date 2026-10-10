import 'dart:collection';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_controller.dart';
import '../../media/data/media_repository.dart';
import '../../today/data/today_repository.dart';
import '../../trends/data/trends_repository.dart';
import '../data/chat_repository.dart';
import '../domain/chat_thread_item.dart';
import '../domain/log_row_formatter.dart';

class ChatState {
  const ChatState({this.items = const [], this.isThinking = false, this.isLoadingHistory = true, this.historyFailed = false});

  final List<ChatThreadItem> items;
  final bool isThinking;
  // True only for the brief window while the persisted thread is being
  // fetched on launch — lets the screen hold off on showing the "nothing
  // logged yet" empty state, which would otherwise flash before a returning
  // user's real history arrives and looks exactly like the history-loss bug.
  final bool isLoadingHistory;
  // History couldn't be fetched (offline, token not ready). The screen says
  // so instead of showing an empty state that reads as "your logs are gone".
  final bool historyFailed;

  ChatState copyWith({List<ChatThreadItem>? items, bool? isThinking, bool? isLoadingHistory, bool? historyFailed}) => ChatState(
        items: items ?? this.items,
        isThinking: isThinking ?? this.isThinking,
        isLoadingHistory: isLoadingHistory ?? this.isLoadingHistory,
        historyFailed: historyFailed ?? this.historyFailed,
      );
}

class _Outgoing {
  _Outgoing({required this.clientId, required this.text, this.bytes});
  final String clientId;
  final String text;
  final Uint8List? bytes;
}

class ChatController extends StateNotifier<ChatState> {
  ChatController(this._repo, this._mediaRepo, this._ref) : super(const ChatState()) {
    _loadHistory();
  }

  final ChatRepository _repo;
  final MediaRepository _mediaRepo;
  final Ref _ref;

  // Sends go out one at a time, in order, so two quick messages can't have
  // their replies interleave — and a message typed while MeMe is thinking
  // waits its turn instead of being refused.
  final _queue = Queue<_Outgoing>();
  bool _draining = false;
  int _clientSeq = 0;

  /// Restores the thread on launch so closing and reopening the app doesn't
  /// wipe it — plus MeMe's "we missed you" nudge when the thread's been
  /// quiet long enough, tacked on as the newest bubble.
  Future<void> _loadHistory() async {
    try {
      final history = await _repo.fetchHistory();
      state = state.copyWith(
        items: [
          for (final raw in history.items) ?_fromHistoryJson(raw),
          if (history.welcomeBackMessage != null) ChatThreadItem.assistantReply(history.welcomeBackMessage!),
        ],
        isLoadingHistory: false,
        historyFailed: false,
      );
    } catch (_) {
      // Offline, or the token isn't ready yet — the thread starts empty but
      // the screen says why; sending a message still works.
      state = state.copyWith(isLoadingHistory: false, historyFailed: true);
    }
  }

  Future<void> reloadHistory() async {
    state = state.copyWith(isLoadingHistory: true);
    await _loadHistory();
  }

  ChatThreadItem? _fromHistoryJson(Map<String, dynamic> json) {
    switch (json['kind'] as String?) {
      case 'user_text':
        return ChatThreadItem.userText(json['text'] as String? ?? '');
      case 'user_photo':
        return ChatThreadItem.userPhoto(photoUrl: json['photo_url'] as String?, caption: json['text'] as String?);
      case 'alert':
        return ChatThreadItem.alert(message: json['message'] as String? ?? '', hard: json['severity'] == 'hard');
      case 'extract_card':
        final entryId = json['entry_id'] as String?;
        if (entryId == null) return null; // the entry was deleted; nothing to show
        final logType = json['log_type'] as String? ?? '';
        return ChatThreadItem.extractCard(
          entryId: entryId,
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
    final clientId = 'c${++_clientSeq}';
    state = state.copyWith(items: [...state.items, ChatThreadItem.userText(text, status: SendStatus.pending, clientId: clientId)]);
    _queue.add(_Outgoing(clientId: clientId, text: text));
    _drain();
  }

  /// Photo logging (VitaChat's chat photo bubble). Shows the real image
  /// immediately, then uploads and sends for extraction in turn — a
  /// vision-capable provider analyzes it for real; mock mode honestly says
  /// it can't see it.
  Future<void> sendPhoto(Uint8List bytes, {String caption = ''}) async {
    final clientId = 'c${++_clientSeq}';
    state = state.copyWith(
      items: [
        ...state.items,
        ChatThreadItem.userPhoto(bytes: bytes, caption: caption.isEmpty ? null : caption, status: SendStatus.pending, clientId: clientId),
      ],
    );
    _queue.add(_Outgoing(clientId: clientId, text: caption, bytes: bytes));
    _drain();
  }

  /// Tap-to-retry on a failed bubble: back into the queue, same bubble.
  void retry(String clientId) {
    final item = state.items.where((i) => i.clientId == clientId).firstOrNull;
    if (item == null || item.status != SendStatus.failed) return;
    _setStatus(clientId, SendStatus.pending);
    _queue.add(_Outgoing(clientId: clientId, text: item.text ?? '', bytes: item.photoBytes));
    _drain();
  }

  Future<void> _drain() async {
    if (_draining) return;
    _draining = true;
    try {
      while (_queue.isNotEmpty) {
        final outgoing = _queue.removeFirst();
        state = state.copyWith(isThinking: true);
        await _deliver(outgoing);
      }
    } finally {
      _draining = false;
      state = state.copyWith(isThinking: false);
    }
  }

  Future<void> _deliver(_Outgoing outgoing) async {
    try {
      String? mediaAssetId;
      if (outgoing.bytes != null) {
        mediaAssetId = await _mediaRepo.uploadPhoto(outgoing.bytes!);
      }
      final result = await _repo.sendMessage(outgoing.text, mediaAssetId: mediaAssetId);
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
      state = state.copyWith(
        items: [
          for (final item in state.items)
            if (item.clientId == outgoing.clientId) item.copyWith(status: SendStatus.sent) else item,
          ...newItems,
        ],
      );
      if (result.entries.isNotEmpty) _refreshDerivedViews();
    } catch (_) {
      // The bubble says "not sent" with a retry; no MeMe apology that makes
      // it look like the conversation moved on without the message.
      _setStatus(outgoing.clientId, SendStatus.failed);
    }
  }

  void _setStatus(String clientId, SendStatus status) {
    state = state.copyWith(
      items: [
        for (final item in state.items)
          if (item.clientId == clientId) item.copyWith(status: status) else item,
      ],
    );
  }

  /// The server recomputes the day inline now, so Today/Trends can refetch
  /// immediately and be right — no waiting for a tab switch.
  void _refreshDerivedViews() {
    _ref.invalidate(todayAggregateProvider);
    _ref.invalidate(todayScoreProvider);
    _ref.invalidate(trendsDataProvider);
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
  // Rebuilt per signed-in user: a different account must never open onto
  // the previous person's thread.
  ref.watch(currentUserIdProvider);
  return ChatController(ref.watch(chatRepositoryProvider), ref.watch(mediaRepositoryProvider), ref);
});
