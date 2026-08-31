import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:health_ui/health_ui.dart';

import '../../auth/presentation/auth_controller.dart';
import '../../goals/presentation/goals_screen.dart';
import '../../medical_profile/presentation/medical_profile_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).user;

    return Scaffold(
      appBar: AppBar(title: Text('Settings', style: HealthTypography.display(fontSize: 22))),
      body: ListView(
        children: [
          ListTile(
            leading: const KunjanMascot(state: MascotState.idle, size: 40),
            title: Text(user?.fullName?.isNotEmpty == true ? user!.fullName! : (user?.email ?? '')),
            subtitle: Text(user?.email ?? ''),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.badge_outlined),
            title: const Text('Medical Profile'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MedicalProfileScreen())),
          ),
          ListTile(
            leading: const Icon(Icons.flag_outlined),
            title: const Text('Goals'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GoalsScreen())),
          ),
          ListTile(
            leading: const Icon(Icons.picture_as_pdf_outlined),
            title: const Text('Reports'),
            subtitle: const Text('Coming in a future update'),
            onTap: () => ScaffoldMessenger.of(context)
                .showSnackBar(const SnackBar(content: Text('PDF report export is planned for Phase 2.'))),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.download_outlined),
            title: const Text('Export my data'),
            onTap: () => ScaffoldMessenger.of(context)
                .showSnackBar(const SnackBar(content: Text('Data export is coming soon.'))),
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline, color: HealthColors.alertTrigger),
            title: const Text('Delete my account', style: TextStyle(color: HealthColors.alertTrigger)),
            onTap: () => ScaffoldMessenger.of(context)
                .showSnackBar(const SnackBar(content: Text('Account deletion is coming soon.'))),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Log out'),
            onTap: () => ref.read(authControllerProvider.notifier).logout(),
          ),
        ],
      ),
    );
  }
}
