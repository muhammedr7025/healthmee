import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:health_ui/health_ui.dart';

import '../../auth/presentation/auth_controller.dart';
import '../../billing/presentation/paywall_screen.dart';
import '../../caregiver/presentation/caregiver_screen.dart';
import '../../goals/presentation/goals_screen.dart';
import '../../medical_profile/presentation/medical_profile_screen.dart';
import '../../reports/presentation/reports_screen.dart';
import '../data/account_repository.dart';
import '../data/notification_preferences_repository.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _exportData(BuildContext context, WidgetRef ref) async {
    showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));
    try {
      final data = await ref.read(accountRepositoryProvider).exportData();
      final pretty = const JsonEncoder.withIndent('  ').convert(data);
      if (!context.mounted) return;
      Navigator.pop(context); // close the spinner
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Your data'),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: SingleChildScrollView(
              child: SelectableText(pretty, style: const TextStyle(fontFamily: 'monospace', fontSize: 11)),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: pretty));
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied to clipboard.')));
              },
              child: const Text('Copy'),
            ),
            ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text('Done')),
          ],
        ),
      );
    } catch (_) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Couldn't export your data — please try again.")));
      }
    }
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Delete my account and all data'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('This is immediate and irreversible. Type DELETE to confirm.'),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                decoration: const InputDecoration(hintText: 'DELETE'),
                onChanged: (_) => setDialogState(() {}),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: controller.text.trim() == 'DELETE' ? () => Navigator.pop(context, true) : null,
              child: const Text('Delete forever'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true) return;

    try {
      await ref.read(accountRepositoryProvider).deleteAccount();
      await ref.read(authControllerProvider.notifier).logout();
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Couldn't delete your account — please try again.")));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).user;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(HealthSpacing.md),
          children: [
            Text('Settings & privacy', style: HealthTypography.display(fontSize: 27)),
            const SizedBox(height: 16),
            Row(
              children: [
                const MimiMascot(state: MascotState.idle, size: 44),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user?.fullName?.isNotEmpty == true ? user!.fullName! : 'Your account',
                          style: HealthTypography.body(fontSize: 15, weight: FontWeight.w500)),
                      Text(user?.email ?? '', style: HealthTypography.body(fontSize: 12, color: HealthColors.inkMuted)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: HealthSpacing.md),
            _SettingsRow(icon: Icons.badge_outlined, label: 'Medical Profile', note: 'Conditions, allergies, medications, vitals',
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MedicalProfileScreen()))),
            _SettingsRow(icon: Icons.flag_outlined, label: 'Goals', note: 'Targets and your logging streak',
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GoalsScreen()))),
            _SettingsRow(icon: Icons.picture_as_pdf_outlined, label: 'Reports', note: 'One PDF with logs, trends and labs',
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReportsScreen()))),
            _SettingsRow(icon: Icons.people_outline, label: 'Caregiver mode', note: 'Invite or accept access to a profile',
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CaregiverScreen()))),
            _SettingsRow(icon: Icons.workspace_premium_outlined, label: 'Upgrade to Premium', note: 'Unlimited history and more',
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PaywallScreen()))),
            const SizedBox(height: HealthSpacing.lg),
            Text('REMINDERS', style: HealthTypography.label()),
            const SizedBox(height: 9),
            const _RemindersCard(),
            const SizedBox(height: HealthSpacing.lg),
            Text('DATA', style: HealthTypography.label()),
            const SizedBox(height: 9),
            _SettingsRow(
              icon: Icons.download_outlined,
              label: 'Export my data',
              note: 'JSON, shown on screen and copyable',
              onTap: () => _exportData(context, ref),
            ),
            _SettingsRow(
              icon: Icons.logout,
              label: 'Log out',
              onTap: () => ref.read(authControllerProvider.notifier).logout(),
            ),
            const SizedBox(height: HealthSpacing.md),
            GestureDetector(
              onTap: () => _confirmDelete(context, ref),
              child: Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  border: Border.all(color: HealthColors.accentPrimary.withValues(alpha: 0.45)),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Text(
                  'Delete my account and all data',
                  textAlign: TextAlign.center,
                  style: HealthTypography.body(fontSize: 14, color: HealthColors.accentPrimaryDark),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Deletion is immediate and irreversible. Export first if you want a copy.',
              textAlign: TextAlign.center,
              style: HealthTypography.body(fontSize: 11.5, color: HealthColors.inkFaint),
            ),
          ],
        ),
      ),
    );
  }
}

class _RemindersCard extends ConsumerWidget {
  const _RemindersCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncPrefs = ref.watch(notificationPreferencesProvider);

    return asyncPrefs.when(
      loading: () => const HealthCard(child: LinearProgressIndicator()),
      error: (e, _) => Text("Couldn't load reminder settings.", style: HealthTypography.body(color: HealthColors.inkMuted)),
      data: (prefs) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: HealthColors.surface,
          border: Border.all(color: HealthColors.inkPrimary.withValues(alpha: 0.09)),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            _ReminderToggle(
              label: 'Medication times',
              note: 'Nudge me when it\'s time to take something',
              value: prefs.medicationReminders,
              onChanged: (v) async {
                await ref.read(notificationPreferencesRepositoryProvider).update(medicationReminders: v);
                ref.invalidate(notificationPreferencesProvider);
              },
            ),
            const Divider(height: 24),
            _ReminderToggle(
              label: 'Nudge me if I go quiet',
              note: 'Once a day, never twice',
              value: prefs.quietNudges,
              onChanged: (v) async {
                await ref.read(notificationPreferencesRepositoryProvider).update(quietNudges: v);
                ref.invalidate(notificationPreferencesProvider);
              },
            ),
            const Divider(height: 24),
            _ReminderToggle(
              label: 'Streaks and milestones',
              note: 'Turn off for a quieter app',
              value: prefs.streakMilestones,
              onChanged: (v) async {
                await ref.read(notificationPreferencesRepositoryProvider).update(streakMilestones: v);
                ref.invalidate(notificationPreferencesProvider);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ReminderToggle extends StatelessWidget {
  const _ReminderToggle({required this.label, required this.note, required this.value, required this.onChanged});
  final String label;
  final String note;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        HealthSwitch(value: value, onChanged: onChanged),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: HealthTypography.body(fontSize: 13.5)),
              const SizedBox(height: 2),
              Text(note, style: HealthTypography.body(fontSize: 11, color: HealthColors.inkFaint)),
            ],
          ),
        ),
      ],
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({required this.icon, required this.label, this.note, this.onTap});
  final IconData icon;
  final String label;
  final String? note;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: HealthColors.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
            decoration: BoxDecoration(
              border: Border.all(color: HealthColors.inkPrimary.withValues(alpha: 0.09)),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Icon(icon, size: 20, color: HealthColors.inkMuted),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label, style: HealthTypography.body(fontSize: 14)),
                      if (note != null) ...[
                        const SizedBox(height: 3),
                        Text(note!, style: HealthTypography.body(fontSize: 11.5, color: HealthColors.inkMuted)),
                      ],
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: HealthColors.inkFaint, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
