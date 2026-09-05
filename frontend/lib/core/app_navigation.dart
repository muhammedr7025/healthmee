import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Which bottom-nav tab is active — a provider (not local State) so other
/// screens can switch tabs programmatically, e.g. Trends' "Ask MiMi about
/// this" jumping to Chat.
final activeTabProvider = StateProvider<int>((ref) => 0);

const chatTabIndex = 0;

/// A message queued to appear in the Chat input the next time it builds —
/// ChatScreen drains and clears this on init.
final pendingChatMessageProvider = StateProvider<String?>((ref) => null);
