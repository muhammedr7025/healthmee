import 'package:flutter/material.dart';
import 'package:health_ui/health_ui.dart';

import '../features/chat/presentation/chat_screen.dart';
import '../features/logbook/presentation/logbook_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../features/today/presentation/today_screen.dart';
import '../features/trends/presentation/trends_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  static const _screens = [ChatScreen(), TodayScreen(), TrendsScreen(), LogbookScreen(), SettingsScreen()];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        backgroundColor: HealthColors.bgBase,
        elevation: 0,
        indicatorColor: HealthColors.chipIdle,
        surfaceTintColor: Colors.transparent,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => HealthTypography.body(
            fontSize: 11.5,
            weight: FontWeight.w500,
            color: states.contains(WidgetState.selected) ? HealthColors.inkPrimary : HealthColors.inkMuted,
          ),
        ),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.chat_bubble_outline), selectedIcon: Icon(Icons.chat_bubble), label: 'Chat'),
          NavigationDestination(icon: Icon(Icons.today_outlined), selectedIcon: Icon(Icons.today), label: 'Today'),
          NavigationDestination(icon: Icon(Icons.show_chart_outlined), selectedIcon: Icon(Icons.show_chart), label: 'Trends'),
          NavigationDestination(icon: Icon(Icons.menu_book_outlined), selectedIcon: Icon(Icons.menu_book), label: 'Logbook'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}
