import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:health_ui/health_ui.dart';

import '../domain/chat_thread_item.dart';
import 'chat_controller.dart';

IconData _iconForLogType(String type) {
  switch (type) {
    case 'food':
      return Icons.restaurant_outlined;
    case 'sleep':
      return Icons.bedtime_outlined;
    case 'mood':
      return Icons.mood_outlined;
    case 'activity':
      return Icons.directions_run_outlined;
    case 'stress':
      return Icons.self_improvement_outlined;
    case 'symptom':
      return Icons.healing_outlined;
    default:
      return Icons.check_circle_outline;
  }
}

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();

  void _send() {
    final text = _textController.text;
    _textController.clear();
    ref.read(chatControllerProvider.notifier).sendMessage(text);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 120,
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

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const MoMascot(state: MascotState.idle, size: 32),
            const SizedBox(width: HealthSpacing.sm),
            Text('Mo', style: HealthTypography.display(fontSize: 20)),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: chatState.items.isEmpty
                ? _EmptyState()
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(HealthSpacing.md),
                    itemCount: chatState.items.length,
                    itemBuilder: (context, index) => Padding(
                      padding: const EdgeInsets.only(bottom: HealthSpacing.sm),
                      child: _ThreadItemView(item: chatState.items[index]),
                    ),
                  ),
          ),
          if (chatState.isThinking)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: HealthSpacing.md),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  const MoMascot(state: MascotState.thinking, size: 36),
                  const SizedBox(width: HealthSpacing.sm),
                  Text('Mo is thinking…', style: HealthTypography.label()),
                ],
              ),
            ),
          _InputBar(controller: _textController, onSend: _send),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(HealthSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const MoMascot(state: MascotState.idle, size: 96),
            const SizedBox(height: HealthSpacing.md),
            Text(
              'Nothing logged yet today — tell Mo what you had for breakfast.',
              style: HealthTypography.mascotSpeech(),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ThreadItemView extends StatelessWidget {
  const _ThreadItemView({required this.item});
  final ChatThreadItem item;

  @override
  Widget build(BuildContext context) {
    switch (item.kind) {
      case ChatItemKind.userText:
        return Align(
          alignment: Alignment.centerRight,
          child: Container(
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
            padding: const EdgeInsets.symmetric(horizontal: HealthSpacing.md, vertical: HealthSpacing.sm),
            decoration: BoxDecoration(
              color: HealthColors.accentPrimary,
              borderRadius: BorderRadius.circular(HealthSpacing.radiusMd),
            ),
            child: Text(item.text ?? '', style: HealthTypography.body(color: Colors.white)),
          ),
        );
      case ChatItemKind.assistantReply:
        return Align(
          alignment: Alignment.centerLeft,
          child: Container(
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
            padding: const EdgeInsets.symmetric(horizontal: HealthSpacing.md, vertical: HealthSpacing.sm),
            decoration: BoxDecoration(
              color: HealthColors.surface,
              borderRadius: BorderRadius.circular(HealthSpacing.radiusMd),
            ),
            child: Text(item.text ?? '', style: HealthTypography.mascotSpeech(fontSize: 15)),
          ),
        );
      case ChatItemKind.logCard:
        return LogConfirmationCard(
          icon: _iconForLogType(item.logType ?? ''),
          summary: item.summary ?? '',
          typeLabel: item.logType ?? '',
        );
      case ChatItemKind.alert:
        return AlertBanner(message: item.text ?? '', hard: item.alertHard);
    }
  }
}

class _InputBar extends StatelessWidget {
  const _InputBar({required this.controller, required this.onSend});
  final TextEditingController controller;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(HealthSpacing.sm),
        child: Row(
          children: [
            IconButton(
              onPressed: null,
              tooltip: 'Photo logging — coming soon',
              icon: const Icon(Icons.camera_alt_outlined),
              color: HealthColors.inkMuted,
            ),
            IconButton(
              onPressed: null,
              tooltip: 'Video logging — coming soon',
              icon: const Icon(Icons.videocam_outlined),
              color: HealthColors.inkMuted,
            ),
            Expanded(
              child: TextField(
                controller: controller,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                decoration: const InputDecoration(hintText: 'Tell Mo about your day…'),
              ),
            ),
            const SizedBox(width: HealthSpacing.xs),
            IconButton.filled(onPressed: onSend, icon: const Icon(Icons.send_rounded)),
          ],
        ),
      ),
    );
  }
}
