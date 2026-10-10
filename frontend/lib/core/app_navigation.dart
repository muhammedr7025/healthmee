import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Which bottom-nav tab is active — a provider (not local State) so other
/// screens can switch tabs programmatically, e.g. Trends' "Ask MeMe about
/// this" jumping to Chat.
final activeTabProvider = StateProvider<int>((ref) => 0);

const chatTabIndex = 0;

/// A message queued to be *sent* to MeMe the next time Chat builds —
/// ChatScreen drains and clears this on init.
final pendingChatMessageProvider = StateProvider<String?>((ref) => null);

/// Text to put in the Chat input for the user to finish ("I had ", "BP ") —
/// the Logbook's quick-log chips use this. Placed, not sent.
final pendingChatDraftProvider = StateProvider<String?>((ref) => null);
