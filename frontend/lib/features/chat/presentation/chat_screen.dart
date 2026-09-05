import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:health_ui/health_ui.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/app_navigation.dart';
import '../../goals/presentation/goals_screen.dart';
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

  void _send([String? text]) {
    final message = text ?? _textController.text;
    _textController.clear();
    ref.read(chatControllerProvider.notifier).sendMessage(message);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 160,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
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
                      child: const _EmptyState(),
                    )
                  : ListView(
                      controller: _scrollController,
                      // Swiping the thread dismisses the keyboard — the main
                      // way back out to the nav bar while typing.
                      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.fromLTRB(HealthSpacing.md, HealthSpacing.sm, HealthSpacing.md, HealthSpacing.sm),
                      children: [
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: HealthSpacing.sm),
                            child: Text('TODAY', style: HealthTypography.label()),
                          ),
                        ),
                        for (final item in chatState.items)
                          Padding(
                            padding: const EdgeInsets.only(bottom: HealthSpacing.sm + 4),
                            child: _ThreadItemView(item: item),
                          ),
                        if (chatState.isThinking) const _TypingBubble(),
                      ],
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
            GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GoalsScreen())),
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
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(HealthSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const MemeMascot(state: MascotState.happy, size: 96),
            const SizedBox(height: HealthSpacing.md),
            Text(
              'Nothing logged yet today — tell MeMe what you had for breakfast.',
              style: HealthTypography.mascotSpeech(),
              textAlign: TextAlign.center,
            ),
          ],
        ),
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
          child: Container(
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
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
        );

      case ChatItemKind.userPhoto:
        return Align(
          alignment: Alignment.centerRight,
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
                    ? Image.memory(item.photoBytes!, width: 206, height: 206, fit: BoxFit.cover)
                    : Image.network(item.photoUrl!, width: 206, height: 206, fit: BoxFit.cover),
              ),
              if (item.text != null) ...[
                const SizedBox(height: 6),
                Container(
                  constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
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
        );

      case ChatItemKind.assistantReply:
        return Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const SizedBox(width: 32, child: Center(child: MemeMascot(state: MascotState.happy, size: 30))),
            const SizedBox(width: HealthSpacing.sm),
            Flexible(
              child: Container(
                constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.68),
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
                  color: item.alertHard ? const Color(0xFFFDEEE4) : HealthColors.reactionBubble,
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

class _ExtractCard extends ConsumerWidget {
  const _ExtractCard({required this.item});
  final ChatThreadItem item;

  Future<void> _editDialog(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController(text: item.rows.map((r) => '${r.key} ${r.value}').join(' · '));
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit entry'),
        content: TextField(controller: controller, maxLines: 3, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save')),
        ],
      ),
    );
    if (saved == true && item.entryId != null) {
      await ref.read(chatControllerProvider.notifier).editEntry(item.entryId!, controller.text.trim());
    }
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
                if (!item.confirmed)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: _CardButton(
                            label: 'Looks right',
                            dark: true,
                            onTap: () => ref.read(chatControllerProvider.notifier).confirmEntry(item.entryId ?? ''),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(child: _CardButton(label: 'Edit', dark: false, onTap: () => _editDialog(context, ref))),
                      ],
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Row(
                      children: [
                        const Icon(Icons.check, size: 14, color: HealthColors.accentSecondary),
                        const SizedBox(width: 6),
                        Text('Saved to today', style: HealthTypography.body(fontSize: 12, color: HealthColors.accentSecondary)),
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

class _CardButton extends StatelessWidget {
  const _CardButton({required this.label, required this.dark, required this.onTap});
  final String label;
  final bool dark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: dark ? HealthColors.inkPrimary : HealthColors.chipIdle,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 11),
          child: Center(
            child: Text(
              label,
              style: HealthTypography.body(fontSize: 13, weight: FontWeight.w500, color: dark ? HealthColors.bgBase : HealthColors.inkPrimary),
            ),
          ),
        ),
      ),
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
          child: SizedBox(width: 38, height: 38, child: Icon(icon, size: 18, color: foreground)),
        ),
      ),
    );
  }
}
