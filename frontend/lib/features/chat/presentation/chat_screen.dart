import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:health_ui/health_ui.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/analytics/analytics.dart';
import '../../../core/app_navigation.dart';
import '../../goals/presentation/goals_screen.dart';
import '../../logbook/domain/log_entry.dart';
import '../../logbook/presentation/edit_entry_sheet.dart';
import '../../today/domain/streak.dart';
import '../../trends/data/trends_repository.dart';
import '../domain/chat_thread_item.dart';
import 'chat_controller.dart';

const _quickReplies = ['Slept 7h', 'Feeling low', '30m walk', 'Drank water'];

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();

  // Set when a quick-log chip filled the box, so the send is attributed to it.
  bool _draftFromQuickLog = false;

  void _send([String? text]) {
    final message = (text ?? _textController.text).trim();
    if (message.isEmpty) return;
    HapticFeedback.lightImpact();
    final source = text != null ? 'quick_reply' : (_draftFromQuickLog ? 'quick_log' : 'typed');
    _draftFromQuickLog = false;
    _textController.clear();
    ref.read(chatControllerProvider.notifier).sendMessage(message, source: source);
    _scrollToNewest();
  }

  /// The thread is reversed, so the newest bubble lives at offset 0. When a
  /// reply arrives while the user is reading older messages, leave them be.
  void _scrollToNewest({bool onlyIfNearBottom = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      if (onlyIfNearBottom && _scrollController.offset > 240) return;
      _scrollController.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    });
  }

  @override
  void initState() {
    super.initState();
    // A draft queued before this screen existed (first visit via a quick-log chip).
    WidgetsBinding.instance.addPostFrameCallback((_) => _takeDraft(ref.read(pendingChatDraftProvider)));
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// Puts a Logbook quick-log line in the box to finish, cursor on the gap
  /// ("Slept | hours") when there is one.
  void _takeDraft(String? draft) {
    if (draft == null) return;
    ref.read(pendingChatDraftProvider.notifier).state = null;
    _draftFromQuickLog = true;
    _textController.text = draft;
    final gap = draft.indexOf('  ');
    _textController.selection = TextSelection.collapsed(offset: gap >= 0 ? gap + 1 : draft.length);
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatControllerProvider);
    final asyncTrends = ref.watch(trendsDataProvider);
    final streak = asyncTrends.maybeWhen(data: computeStreak, orElse: () => 0);

    // Other tabs (e.g. Trends' "Ask MeMe about this") queue a message here.
    ref.listen<String?>(pendingChatMessageProvider, (previous, next) {
      if (next != null) {
        ref.read(pendingChatMessageProvider.notifier).state = null;
        WidgetsBinding.instance.addPostFrameCallback((_) => _send(next));
      }
    });
    // ...and the Logbook's quick-log chips queue a half-written line here.
    ref.listen<String?>(pendingChatDraftProvider, (previous, next) => _takeDraft(next));

    // A reply landing is the one moment worth a tap — and only while Chat
    // is the tab on screen, not from a background send.
    ref.listen<int>(chatControllerProvider.select((s) => s.items.length), (previous, next) {
      if (previous == null || next <= previous) return;
      final items = ref.read(chatControllerProvider).items;
      if (items.isNotEmpty && items.last.kind == ChatItemKind.assistantReply && ref.read(activeTabProvider) == chatTabIndex) {
        HapticFeedback.mediumImpact();
      }
      _scrollToNewest(onlyIfNearBottom: true);
    });

    return Scaffold(
      // AppShell's Scaffold already shrinks this screen's box for the
      // keyboard; applying the inset again here too pushed the input bar and
      // bottom nav up by double the keyboard height, which read as the nav
      // bar vanishing with no way back.
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: Column(
          children: [
            _ChatHeader(streak: streak, thinking: chatState.isThinking),
            Expanded(
              child: chatState.isLoadingHistory
                  ? const SizedBox.shrink()
                  : chatState.items.isEmpty
                  ? GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => FocusScope.of(context).unfocus(),
                      child: EmptyState(
                        mascot: chatState.historyFailed ? MascotState.concerned : MascotState.happy,
                        message: chatState.historyFailed
                            ? "I couldn't load our conversation just now. Everything you've logged is safe on the server."
                            : 'Nothing logged yet today — tell MeMe what you had for breakfast.',
                        actionLabel: chatState.historyFailed ? 'Try again' : null,
                        onAction: () => ref.read(chatControllerProvider.notifier).reloadHistory(),
                      ),
                    )
                  // Lazy and reversed: history restores up to a few hundred
                  // bubbles, so only what's on screen is built — and index 0
                  // is the *newest* item, which is where a chat opens and
                  // where new bubbles appear without any scrolling logic.
                  // Slot 0 is the typing bubble; the last slot is the label
                  // at the very top of the thread.
                  : ListView.builder(
                      controller: _scrollController,
                      reverse: true,
                      // Swiping the thread dismisses the keyboard — the main
                      // way back out to the nav bar while typing.
                      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.fromLTRB(HealthSpacing.md, HealthSpacing.sm, HealthSpacing.md, HealthSpacing.sm),
                      itemCount: chatState.items.length + 2,
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          return chatState.isThinking ? const _TypingBubble() : const SizedBox.shrink();
                        }
                        if (index == chatState.items.length + 1) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: HealthSpacing.sm),
                              child: chatState.hasEarlier
                                  ? (chatState.loadingEarlier
                                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                                      : TextButton(
                                          onPressed: () => ref.read(chatControllerProvider.notifier).loadEarlier(),
                                          child: Text('Load earlier messages', style: HealthTypography.body(fontSize: 12.5, color: HealthColors.accentPrimaryDark)),
                                        ))
                                  : Text('YOUR THREAD WITH MEME', style: HealthTypography.label()),
                            ),
                          );
                        }
                        return Padding(
                          padding: const EdgeInsets.only(bottom: HealthSpacing.sm + 4),
                          child: _ThreadItemView(item: chatState.items[chatState.items.length - index]),
                        );
                      },
                    ),
            ),
            _QuickRepliesAndInput(controller: _textController, onSend: _send),
          ],
        ),
      ),
    );
  }
}

class _ChatHeader extends StatelessWidget {
  const _ChatHeader({required this.streak, required this.thinking});
  final int streak;
  final bool thinking;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(HealthSpacing.md, HealthSpacing.sm, HealthSpacing.md, HealthSpacing.sm),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(color: HealthColors.chipIdle, shape: BoxShape.circle),
            child: MemeMascot(state: thinking ? MascotState.thinking : MascotState.happy, size: 40),
          ),
          const SizedBox(width: HealthSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('MeMe', style: HealthTypography.display(fontSize: 21)),
                Text(thinking ? 'thinking…' : 'here whenever you are', style: HealthTypography.body(fontSize: 11.5, color: HealthColors.inkMuted)),
              ],
            ),
          ),
          if (streak > 0)
            Semantics(
              button: true,
              label: '$streak day logging streak. Open goals',
              child: GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(settings: const RouteSettings(name: 'goals'), builder: (_) => const GoalsScreen())),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
                decoration: BoxDecoration(
                  color: HealthColors.reactionBubble,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: HealthColors.accentPrimary.withValues(alpha: 0.28)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(width: 7, height: 7, decoration: const BoxDecoration(color: HealthColors.accentPrimary, shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Text('$streak', style: HealthTypography.body(fontSize: 12.5, weight: FontWeight.w700, color: HealthColors.accentPrimaryDark)),
                  ],
                ),
              ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TypingBubble extends StatefulWidget {
  const _TypingBubble();

  @override
  State<_TypingBubble> createState() => _TypingBubbleState();
}

class _TypingBubbleState extends State<_TypingBubble> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        const SizedBox(width: 32, child: Center(child: MemeMascot(state: MascotState.thinking, size: 30))),
        const SizedBox(width: HealthSpacing.sm),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
          decoration: BoxDecoration(
            color: HealthColors.surface,
            border: Border.all(color: HealthColors.inkPrimary.withValues(alpha: 0.09)),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
              bottomRight: Radius.circular(20),
              bottomLeft: Radius.circular(6),
            ),
          ),
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) => Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (i) {
                final t = ((_controller.value - i * 0.2) % 1.0).clamp(0.0, 1.0);
                final scale = 0.6 + 0.4 * (t < 0.5 ? t * 2 : (1 - t) * 2);
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2.5),
                  child: Transform.scale(
                    scale: scale,
                    child: Container(width: 6, height: 6, decoration: const BoxDecoration(color: HealthColors.inkFaint, shape: BoxShape.circle)),
                  ),
                );
              }),
            ),
          ),
        ),
      ],
    );
  }
}

class _ThreadItemView extends ConsumerWidget {
  const _ThreadItemView({required this.item});
  final ChatThreadItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    switch (item.kind) {
      case ChatItemKind.userText:
        return Align(
          alignment: Alignment.centerRight,
          child: _SendStatusWrap(
            item: item,
            child: Container(
              constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.72),
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
              decoration: const BoxDecoration(
                color: HealthColors.inkPrimary,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(18),
                  topRight: Radius.circular(18),
                  bottomLeft: Radius.circular(18),
                  bottomRight: Radius.circular(6),
                ),
              ),
              child: Text(item.text ?? '', style: HealthTypography.body(color: HealthColors.bgBase, fontSize: 14.5)),
            ),
          ),
        );

      case ChatItemKind.userPhoto:
        return Align(
          alignment: Alignment.centerRight,
          child: _SendStatusWrap(
            item: item,
            child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(6),
                ),
                child: item.photoBytes != null
                    ? Image.memory(
                        item.photoBytes!,
                        width: 206,
                        height: 206,
                        fit: BoxFit.cover,
                        // A 1600px capture decoded at bubble size, not full resolution.
                        cacheWidth: (206 * MediaQuery.devicePixelRatioOf(context)).round(),
                        gaplessPlayback: true,
                      )
                    : Image.network(
                        item.photoUrl!,
                        width: 206,
                        height: 206,
                        fit: BoxFit.cover,
                        cacheWidth: (206 * MediaQuery.devicePixelRatioOf(context)).round(),
                        loadingBuilder: (context, child, progress) => progress == null
                            ? child
                            : Container(width: 206, height: 206, color: HealthColors.chipIdle),
                        errorBuilder: (context, error, stack) => Container(
                          width: 206,
                          height: 206,
                          color: HealthColors.chipIdle,
                          alignment: Alignment.center,
                          child: Icon(Icons.broken_image_outlined, color: HealthColors.inkFaint),
                        ),
                      ),
              ),
              if (item.text != null) ...[
                const SizedBox(height: 6),
                Container(
                  constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.72),
                  padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
                  decoration: const BoxDecoration(
                    color: HealthColors.inkPrimary,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(18),
                      topRight: Radius.circular(18),
                      bottomLeft: Radius.circular(18),
                      bottomRight: Radius.circular(6),
                    ),
                  ),
                  child: Text(item.text!, style: HealthTypography.body(color: HealthColors.bgBase, fontSize: 14.5)),
                ),
              ],
            ],
          ),
          ),
        );

      case ChatItemKind.assistantReply:
        return Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const SizedBox(width: 32, child: Center(child: MemeMascot(state: MascotState.happy, size: 30))),
            const SizedBox(width: HealthSpacing.sm),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.68),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                    decoration: BoxDecoration(
                      color: HealthColors.surface,
                      border: Border.all(color: HealthColors.inkPrimary.withValues(alpha: 0.09)),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(20),
                        topRight: Radius.circular(20),
                        bottomRight: Radius.circular(20),
                        bottomLeft: Radius.circular(6),
                      ),
                    ),
                    child: Text(item.text ?? '', style: HealthTypography.body(fontSize: 14.5)),
                  ),
                  // Quiet thumbs under every reply: the cheapest signal of
                  // whether MeMe's tone and substance land.
                  Padding(
                    padding: const EdgeInsets.only(left: 6, top: 2),
                    child: _RatingButtons(
                      onRate: (up) => ref.read(analyticsProvider).track('reply_rated', {'kind': 'reply', 'rating': up ? 'up' : 'down'}),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );

      case ChatItemKind.alert:
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(width: 32, child: Center(child: MemeMascot(state: MascotState.concerned, size: 30))),
            const SizedBox(width: HealthSpacing.sm),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: item.alertHard ? HealthColors.warnBg : HealthColors.reactionBubble,
                  border: Border.all(color: HealthColors.accentPrimary.withValues(alpha: 0.35)),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                    bottomLeft: Radius.circular(6),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(color: HealthColors.accentPrimary, borderRadius: BorderRadius.circular(5)),
                          child: const Center(child: Text('!', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold))),
                        ),
                        const SizedBox(width: 8),
                        Text('CHECK THIS ONE', style: HealthTypography.label(color: HealthColors.accentPrimaryDark)),
                      ],
                    ),
                    const SizedBox(height: 7),
                    Text(item.text ?? '', style: HealthTypography.body(fontSize: 14.5)),
                    const SizedBox(height: 9),
                    Text(
                      'Not a medical diagnosis. If something feels off, talk to your doctor.',
                      style: HealthTypography.body(fontSize: 11, color: HealthColors.inkFaint),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );

      case ChatItemKind.extractCard:
        return _ExtractCard(item: item);
    }
  }
}

/// 👍 / 👎, faint until tapped; the choice sticks for the life of the bubble.
class _RatingButtons extends StatefulWidget {
  const _RatingButtons({required this.onRate});
  final void Function(bool up) onRate;

  @override
  State<_RatingButtons> createState() => _RatingButtonsState();
}

class _RatingButtonsState extends State<_RatingButtons> {
  bool? _rated;

  Widget _button(bool up) {
    final active = _rated == up;
    final dimmed = _rated != null && !active;
    return Tooltip(
      message: up ? 'Helpful' : 'Not quite right',
      child: InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: _rated != null
          ? null
          : () {
              HapticFeedback.selectionClick();
              setState(() => _rated = up);
              widget.onRate(up);
            },
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Icon(
          up ? (active ? Icons.thumb_up : Icons.thumb_up_outlined) : (active ? Icons.thumb_down : Icons.thumb_down_outlined),
          size: 14,
          color: active ? HealthColors.accentPrimaryDark : (dimmed ? HealthColors.divider : HealthColors.inkFaint),
        ),
      ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [_button(true), _button(false)]);
  }
}

/// Pending bubbles sit at reduced opacity with "Sending…"; failed ones get a
/// terracotta "Not sent · Tap to retry" that re-queues the same message.
class _SendStatusWrap extends ConsumerWidget {
  const _SendStatusWrap({required this.item, required this.child});
  final ChatThreadItem item;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = item.status == SendStatus.pending;
    final failed = item.status == SendStatus.failed;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedOpacity(duration: const Duration(milliseconds: 200), opacity: pending ? 0.6 : 1, child: child),
        if (pending)
          Padding(
            padding: const EdgeInsets.only(top: 3, right: 4),
            child: Text('Sending…', style: HealthTypography.body(fontSize: 10.5, color: HealthColors.inkFaint)),
          ),
        if (failed)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: item.clientId == null
                  ? null
                  : () {
                      HapticFeedback.selectionClick();
                      ref.read(chatControllerProvider.notifier).retry(item.clientId!);
                    },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline, size: 13, color: HealthColors.accentPrimaryDark),
                    const SizedBox(width: 4),
                    Text(
                      'Not sent · Tap to retry',
                      style: HealthTypography.body(fontSize: 11.5, weight: FontWeight.w500, color: HealthColors.accentPrimaryDark),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _ExtractCard extends ConsumerWidget {
  const _ExtractCard({required this.item});
  final ChatThreadItem item;

  /// Field-by-field correction from the type catalog — numbers stay numbers,
  /// enums stay choices — then the card redraws from the saved payload.
  Future<void> _editDialog(BuildContext context, WidgetRef ref, {String source = 'chat_card'}) async {
    if (item.entryId == null) return;
    HapticFeedback.lightImpact();
    final entry = LogEntryView(
      id: item.entryId!,
      type: item.logType ?? '',
      timestamp: DateTime.now(),
      payload: item.payload,
      summary: null,
    );
    final updated = await showEditEntrySheet(context, ref, entry, source: source);
    if (updated != null) ref.read(chatControllerProvider.notifier).applyEntryUpdate(updated);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(width: 32),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
            decoration: BoxDecoration(
              color: HealthColors.surface,
              border: Border.all(color: HealthColors.inkPrimary.withValues(alpha: 0.09)),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.summary ?? '', style: HealthTypography.label()),
                const SizedBox(height: 9),
                for (final row in item.rows)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 7),
                    child: Row(
                      children: [
                        Expanded(child: Text(row.key, style: HealthTypography.body(fontSize: 14))),
                        if (row.value.isNotEmpty)
                          Text(row.value, style: HealthTypography.body(fontSize: 14, color: HealthColors.inkMuted)),
                      ],
                    ),
                  ),
                if (item.degraded)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.wifi_tethering_off, size: 13, color: HealthColors.accentPrimaryDark),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            "MeMe's offline brain logged this — worth a quick check.",
                            style: HealthTypography.body(fontSize: 11.5, color: HealthColors.accentPrimaryDark),
                          ),
                        ),
                      ],
                    ),
                  ),
                // The entry is already saved by the time this card renders,
                // so there's nothing to confirm — just say so, and offer Edit.
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Row(
                    children: [
                      const Icon(Icons.check, size: 14, color: HealthColors.accentSecondary),
                      const SizedBox(width: 6),
                      Text('Saved to today', style: HealthTypography.body(fontSize: 12, color: HealthColors.accentSecondary)),
                      const Spacer(),
                      _RatingButtons(
                        onRate: (up) {
                          ref.read(analyticsProvider).track('reply_rated', {'kind': 'card', 'rating': up ? 'up' : 'down', 'log_type': item.logType});
                          if (!up) _editDialog(context, ref, source: 'thumbs_down');
                        },
                      ),
                      const SizedBox(width: 4),
                      InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () => _editDialog(context, ref),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.edit_outlined, size: 13, color: HealthColors.accentPrimaryDark),
                              const SizedBox(width: 4),
                              Text(
                                'Edit',
                                style: HealthTypography.body(fontSize: 12, weight: FontWeight.w500, color: HealthColors.accentPrimaryDark),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _QuickRepliesAndInput extends ConsumerWidget {
  const _QuickRepliesAndInput({required this.controller, required this.onSend});
  final TextEditingController controller;
  final void Function([String?]) onSend;

  Future<void> _pickPhoto(BuildContext context, WidgetRef ref) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from library'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    final picked = await ImagePicker().pickImage(source: source, maxWidth: 1600, imageQuality: 85);
    if (picked == null) return;

    final bytes = await picked.readAsBytes();
    if (context.mounted) {
      ref.read(chatControllerProvider.notifier).sendPhoto(bytes, caption: controller.text.trim());
      controller.clear();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(HealthSpacing.md, 0, HealthSpacing.md, HealthSpacing.sm),
      child: Column(
        children: [
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: _quickReplies
                  .map((q) => Padding(
                        padding: const EdgeInsets.only(right: 7),
                        child: Material(
                          color: HealthColors.chipIdle,
                          borderRadius: BorderRadius.circular(999),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(999),
                            onTap: () => onSend(q),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
                              child: Text(q, style: HealthTypography.body(fontSize: 12.5, color: HealthColors.inkMuted.withValues(alpha: 0.9))),
                            ),
                          ),
                        ),
                      ))
                  .toList(),
            ),
          ),
          const SizedBox(height: 9),
          Container(
            padding: const EdgeInsets.fromLTRB(17, 8, 8, 8),
            decoration: BoxDecoration(
              color: HealthColors.surface,
              border: Border.all(color: HealthColors.inkPrimary.withValues(alpha: 0.12)),
              borderRadius: BorderRadius.circular(26),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    minLines: 1,
                    maxLines: 4, // long messages wrap instead of scrolling sideways
                    keyboardType: TextInputType.multiline,
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => onSend(),
                    decoration: const InputDecoration(
                      hintText: 'Tell MeMe anything…',
                      border: InputBorder.none,
                      isCollapsed: true,
                      filled: false,
                    ),
                    style: HealthTypography.body(fontSize: 14.5),
                  ),
                ),
                const SizedBox(width: 9),
                _RoundIconButton(
                  icon: Icons.camera_alt_outlined,
                  background: HealthColors.chipIdle,
                  foreground: HealthColors.inkMuted,
                  tooltip: 'Log with a photo',
                  onTap: () => _pickPhoto(context, ref),
                ),
                const SizedBox(width: 6),
                _RoundIconButton(
                  icon: Icons.arrow_upward_rounded,
                  background: HealthColors.accentPrimary,
                  foreground: Colors.white,
                  tooltip: 'Send',
                  onTap: () => onSend(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({required this.icon, required this.background, required this.foreground, required this.tooltip, required this.onTap});
  final IconData icon;
  final Color background;
  final Color foreground;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: background,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(width: 44, height: 44, child: Icon(icon, size: 18, color: foreground)),
        ),
      ),
    );
  }
}
