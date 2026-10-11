import 'dart:collection';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/analytics/analytics.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../logbook/domain/log_entry.dart';
import '../../media/data/media_repository.dart';
import '../../today/data/today_repository.dart';
import '../../trends/data/trends_repository.dart';
import '../data/chat_repository.dart';
import '../domain/chat_thread_item.dart';
import '../domain/log_row_formatter.dart';

class ChatState {
  const ChatState({
    this.items = const [],
    this.isThinking = false,
    this.isLoadingHistory = true,
    this.historyFailed = false,
    this.hasEarlier = false,
    this.loadingEarlier = false,
  });

  final List<ChatThreadItem> items;
  final bool isThinking;
  /// Older messages exist on the server beyond what's loaded.
  final bool hasEarlier;
  final bool loadingEarlier;
  // True only for the brief window while the persisted thread is being
  // fetched on launch — lets the screen hold off on showing the "nothing
  // logged yet" empty state, which would otherwise flash before a returning
  // user's real history arrives and looks exactly like the history-loss bug.
  final bool isLoadingHistory;
  // History couldn't be fetched (offline, token not ready). The screen says
  // so instead of showing an empty state that reads as "your logs are gone".
  final bool historyFailed;

  ChatState copyWith({
    List<ChatThreadItem>? items,
    bool? isThinking,
    bool? isLoadingHistory,
    bool? historyFailed,
    bool? hasEarlier,
    bool? loadingEarlier,
  }) =>
      ChatState(
        items: items ?? this.items,
        isThinking: isThinking ?? this.isThinking,
        isLoadingHistory: isLoadingHistory ?? this.isLoadingHistory,
        historyFailed: historyFailed ?? this.historyFailed,
        hasEarlier: hasEarlier ?? this.hasEarlier,
        loadingEarlier: loadingEarlier ?? this.loadingEarlier,
      );
}

class _Outgoing {
  _Outgoing({required this.clientId, required this.text, this.bytes, this.source = 'typed', this.attempt = 1});
  final String clientId;
  final String text;
  final Uint8List? bytes;

  /// typed | quick_reply | quick_log | nudge — where the message came from.
  final String source;
  final int attempt;
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
  // created_at of the oldest row loaded so far — the cursor for "load earlier".
  DateTime? _oldestLoaded;

  Future<void> _loadHistory() async {
    try {
      final history = await _repo.fetchHistory();
      _oldestLoaded = _createdAt(history.items.firstOrNull);
      state = state.copyWith(
        items: [
          for (final raw in history.items) ?_fromHistoryJson(raw),
          if (history.welcomeBackMessage != null) ChatThreadItem.assistantReply(history.welcomeBackMessage!),
        ],
        isLoadingHistory: false,
        historyFailed: false,
        hasEarlier: history.hasMore,
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

  static DateTime? _createdAt(Map<String, dynamic>? raw) {
    final value = raw?['created_at'];
    if (value is! String) return null;
    // Server timestamps are naive UTC.
    final parsed = DateTime.tryParse(value.endsWith('Z') ? value : '${value}Z');
    return parsed;
  }

  /// "Load earlier" at the top of the thread: one page of older rows,
  /// prepended, without touching the live end.
  Future<void> loadEarlier() async {
    if (!state.hasEarlier || state.loadingEarlier || _oldestLoaded == null) return;
    state = state.copyWith(loadingEarlier: true);
    try {
      final page = await _repo.fetchHistory(before: _oldestLoaded);
      _oldestLoaded = _createdAt(page.items.firstOrNull) ?? _oldestLoaded;
      state = state.copyWith(
        items: [for (final raw in page.items) ?_fromHistoryJson(raw), ...state.items],
        hasEarlier: page.hasMore,
        loadingEarlier: false,
      );
      _ref.read(analyticsProvider).track('history_loaded_earlier', {'rows': page.items.length});
    } catch (_) {
      state = state.copyWith(loadingEarlier: false);
    }
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
        final payload = Map<String, dynamic>.from(json['payload'] as Map? ?? {});
        return ChatThreadItem.extractCard(
          entryId: entryId,
          logType: logType,
          summary: extractCardLabel(logType),
          rows: formatLogRows(logType, payload),
          payload: payload,
          confirmed: true,
        );
      case 'assistant_reply':
      default:
        return ChatThreadItem.assistantReply(json['text'] as String? ?? '');
    }
  }

  Future<void> sendMessage(String text, {String source = 'typed'}) async {
    if (text.trim().isEmpty) return;
    final clientId = 'c${++_clientSeq}';
    state = state.copyWith(items: [...state.items, ChatThreadItem.userText(text, status: SendStatus.pending, clientId: clientId)]);
    _queue.add(_Outgoing(clientId: clientId, text: text, source: source));
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
    _queue.add(_Outgoing(clientId: clientId, text: caption, bytes: bytes, source: 'photo'));
    _drain();
  }

  /// Tap-to-retry on a failed bubble: back into the queue, same bubble.
  void retry(String clientId) {
    final item = state.items.where((i) => i.clientId == clientId).firstOrNull;
    if (item == null || item.status != SendStatus.failed) return;
    _setStatus(clientId, SendStatus.pending);
    _attempts[clientId] = (_attempts[clientId] ?? 1) + 1;
    _ref.read(analyticsProvider).track('message_retried', {'attempt': _attempts[clientId]});
    _queue.add(_Outgoing(clientId: clientId, text: item.text ?? '', bytes: item.photoBytes, source: 'retry', attempt: _attempts[clientId]!));
    _drain();
  }

  final _attempts = <String, int>{};

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
    final analytics = _ref.read(analyticsProvider);
    final started = DateTime.now();
    try {
      String? mediaAssetId;
      if (outgoing.bytes != null) {
        mediaAssetId = await _mediaRepo.uploadPhoto(outgoing.bytes!);
        analytics.track('photo_logged', {'bytes': outgoing.bytes!.length, 'upload_ms': DateTime.now().difference(started).inMilliseconds});
      }
      final result = await _repo.sendMessage(outgoing.text, mediaAssetId: mediaAssetId);
      final newItems = <ChatThreadItem>[
        for (final entry in result.entries)
          ChatThreadItem.extractCard(
            entryId: entry['id'] as String,
            logType: entry['type'] as String,
            summary: extractCardLabel(entry['type'] as String),
            rows: formatLogRows(entry['type'] as String, Map<String, dynamic>.from(entry['payload'] as Map? ?? {})),
            payload: Map<String, dynamic>.from(entry['payload'] as Map? ?? {}),
            degraded: result.degraded,
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
      analytics.track('message_sent', {
        'chars': outgoing.text.length,
        'has_photo': outgoing.bytes != null,
        'source': outgoing.source,
        'attempt': outgoing.attempt,
        'entries': result.entries.length,
        'alerts': result.alerts.length,
        'degraded': result.degraded,
        'round_trip_ms': DateTime.now().difference(started).inMilliseconds,
      });
      if (result.entries.isNotEmpty) _refreshDerivedViews();
    } catch (e) {
      // The bubble says "not sent" with a retry; no MeMe apology that makes
      // it look like the conversation moved on without the message.
      _setStatus(outgoing.clientId, SendStatus.failed);
      analytics.track('message_failed', {'reason': e.runtimeType.toString(), 'has_photo': outgoing.bytes != null, 'attempt': outgoing.attempt});
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

  /// After the typed correction sheet saved: redraw the card from the real
  /// payload (not a free-text line) and refresh the totals it feeds.
  void applyEntryUpdate(LogEntryView updated) {
    state = state.copyWith(
      items: [
        for (final item in state.items)
          if (item.entryId == updated.id)
            item.copyWith(
              rows: formatLogRows(updated.type, updated.payload),
              payload: updated.payload,
              confirmed: true,
              degraded: false, // a human has checked it now
            )
          else
            item,
      ],
    );
    _refreshDerivedViews();
  }

  /// A card the user removed from the detail screen.
  void removeEntry(String entryId) {
    state = state.copyWith(items: [for (final item in state.items) if (item.entryId != entryId) item]);
    _refreshDerivedViews();
  }
}

final chatControllerProvider = StateNotifierProvider<ChatController, ChatState>((ref) {
  // Rebuilt per signed-in user: a different account must never open onto
  // the previous person's thread.
  ref.watch(currentUserIdProvider);
  return ChatController(ref.watch(chatRepositoryProvider), ref.watch(mediaRepositoryProvider), ref);
});
