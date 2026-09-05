import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:health_ui/health_ui.dart';

import '../data/caregiver_repository.dart';
import '../domain/caregiver_link.dart';

class CaregiverScreen extends StatelessWidget {
  const CaregiverScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Caregiver mode', style: HealthTypography.display(fontSize: 22)),
          bottom: const TabBar(tabs: [
            Tab(text: 'My caregivers'),
            Tab(text: 'Invited to me'),
            Tab(text: 'I care for'),
          ]),
        ),
        body: const TabBarView(children: [_MyCaregiversTab(), _InvitationsTab(), _AccessTab()]),
      ),
    );
  }
}

class _MyCaregiversTab extends ConsumerWidget {
  const _MyCaregiversTab();

  Future<void> _invite(BuildContext context, WidgetRef ref) async {
    final emailController = TextEditingController();
    final canViewLogs = ValueNotifier(true);
    final canViewTrends = ValueNotifier(true);
    final canEditProfile = ValueNotifier(false);

    final invited = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Invite a caregiver'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: emailController, decoration: const InputDecoration(labelText: 'Their email')),
            const SizedBox(height: HealthSpacing.md),
            ValueListenableBuilder(
              valueListenable: canViewLogs,
              builder: (context, v, _) => _PermissionRow(
                label: 'Log food, vitals and medication',
                value: v,
                onChanged: (nv) => canViewLogs.value = nv,
              ),
            ),
            ValueListenableBuilder(
              valueListenable: canViewTrends,
              builder: (context, v, _) => _PermissionRow(
                label: 'See trends and reports',
                value: v,
                onChanged: (nv) => canViewTrends.value = nv,
              ),
            ),
            ValueListenableBuilder(
              valueListenable: canEditProfile,
              builder: (context, v, _) => _PermissionRow(
                label: 'Edit the medical profile',
                value: v,
                onChanged: (nv) => canEditProfile.value = nv,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (emailController.text.trim().isEmpty) return;
              try {
                await ref.read(caregiverRepositoryProvider).invite(
                      email: emailController.text.trim(),
                      canViewLogs: canViewLogs.value,
                      canViewTrendsReports: canViewTrends.value,
                      canEditProfile: canEditProfile.value,
                    );
                if (context.mounted) Navigator.pop(context, true);
              } catch (_) {
                if (context.mounted) Navigator.pop(context, false);
              }
            },
            child: const Text('Send invite'),
          ),
        ],
      ),
    );

    if (invited == true) ref.invalidate(caregiverLinksProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncLinks = ref.watch(caregiverLinksProvider);
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => _invite(context, ref),
        child: const Icon(Icons.person_add_alt_outlined),
      ),
      body: asyncLinks.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Padding(
          padding: const EdgeInsets.all(HealthSpacing.lg),
          child: AlertBanner(message: "Couldn't load caregivers.", hard: false),
        ),
        data: (links) {
          if (links.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(HealthSpacing.xl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const MemeMascot(state: MascotState.idle, size: 96),
                    const SizedBox(height: HealthSpacing.md),
                    Text('No one has access yet — invite a caregiver with +.',
                        style: HealthTypography.mascotSpeech(), textAlign: TextAlign.center),
                  ],
                ),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(HealthSpacing.md),
            itemCount: links.length,
            itemBuilder: (context, i) {
              final link = links[i];
              return Padding(
                padding: const EdgeInsets.only(bottom: HealthSpacing.sm),
                child: Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: HealthColors.surface,
                    border: Border.all(color: HealthColors.inkPrimary.withValues(alpha: 0.09)),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _AvatarInitial(text: link.caregiverEmail),
                          const SizedBox(width: 12),
                          Expanded(child: Text(link.caregiverEmail, style: HealthTypography.body(fontSize: 14.5))),
                          _StatusChip(status: link.status),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _PermissionRow(
                        label: 'Log food, vitals and medication',
                        value: link.canViewLogs,
                        onChanged: (v) async {
                          await ref.read(caregiverRepositoryProvider).updatePermissions(link.id, canViewLogs: v);
                          ref.invalidate(caregiverLinksProvider);
                        },
                      ),
                      _PermissionRow(
                        label: 'See trends and reports',
                        value: link.canViewTrendsReports,
                        onChanged: (v) async {
                          await ref.read(caregiverRepositoryProvider).updatePermissions(link.id, canViewTrendsReports: v);
                          ref.invalidate(caregiverLinksProvider);
                        },
                      ),
                      _PermissionRow(
                        label: 'Edit the medical profile',
                        value: link.canEditProfile,
                        onChanged: (v) async {
                          await ref.read(caregiverRepositoryProvider).updatePermissions(link.id, canEditProfile: v);
                          ref.invalidate(caregiverLinksProvider);
                        },
                      ),
                      if (link.status == 'active' || link.status == 'pending')
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () async {
                              await ref.read(caregiverRepositoryProvider).revoke(link.id);
                              ref.invalidate(caregiverLinksProvider);
                            },
                            child: const Text('Revoke'),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

}

class _InvitationsTab extends ConsumerWidget {
  const _InvitationsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncInvites = ref.watch(caregiverInvitationsProvider);
    return asyncInvites.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Padding(
        padding: const EdgeInsets.all(HealthSpacing.lg),
        child: AlertBanner(message: "Couldn't load invitations.", hard: false),
      ),
      data: (invites) {
        if (invites.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(HealthSpacing.xl),
              child: Text('No pending invitations.', style: HealthTypography.body(color: HealthColors.inkMuted)),
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(HealthSpacing.md),
          itemCount: invites.length,
          itemBuilder: (context, i) {
            final invite = invites[i];
            return Padding(
              padding: const EdgeInsets.only(bottom: HealthSpacing.sm),
              child: HealthCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(invite.ownerFullName?.isNotEmpty == true ? invite.ownerFullName! : (invite.ownerEmail ?? ''),
                        style: HealthTypography.body(weight: FontWeight.w600)),
                    Text('wants you as a caregiver', style: HealthTypography.label()),
                    const SizedBox(height: HealthSpacing.sm),
                    Row(
                      children: [
                        ElevatedButton(
                          onPressed: () async {
                            await ref.read(caregiverRepositoryProvider).acceptInvitation(invite.id);
                            ref.invalidate(caregiverInvitationsProvider);
                            ref.invalidate(caregiverAccessProvider);
                          },
                          child: const Text('Accept'),
                        ),
                        const SizedBox(width: HealthSpacing.sm),
                        TextButton(
                          onPressed: () async {
                            await ref.read(caregiverRepositoryProvider).declineInvitation(invite.id);
                            ref.invalidate(caregiverInvitationsProvider);
                          },
                          child: const Text('Decline'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _AccessTab extends ConsumerWidget {
  const _AccessTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncAccess = ref.watch(caregiverAccessProvider);
    return asyncAccess.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Padding(
        padding: const EdgeInsets.all(HealthSpacing.lg),
        child: AlertBanner(message: "Couldn't load access.", hard: false),
      ),
      data: (access) {
        if (access.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(HealthSpacing.xl),
              child: Text("You're not caring for anyone yet.", style: HealthTypography.body(color: HealthColors.inkMuted)),
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(HealthSpacing.md),
          itemCount: access.length,
          itemBuilder: (context, i) {
            final link = access[i];
            final name = link.ownerFullName?.isNotEmpty == true ? link.ownerFullName! : (link.ownerEmail ?? '');
            return Padding(
              padding: const EdgeInsets.only(bottom: HealthSpacing.sm),
              child: Material(
                color: HealthColors.surface,
                borderRadius: BorderRadius.circular(20),
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => _OwnerSummaryScreen(link: link))),
                  child: Container(
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      border: Border.all(color: HealthColors.inkPrimary.withValues(alpha: 0.09)),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        _AvatarInitial(text: name),
                        const SizedBox(width: 13),
                        Expanded(child: Text(name, style: HealthTypography.body(fontSize: 14.5))),
                        Icon(Icons.chevron_right, color: HealthColors.inkFaint),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _OwnerSummaryScreen extends ConsumerWidget {
  const _OwnerSummaryScreen({required this.link});
  final CaregiverLink link;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(caregiverRepositoryProvider);
    return Scaffold(
      appBar: AppBar(title: Text(link.ownerFullName?.isNotEmpty == true ? link.ownerFullName! : (link.ownerEmail ?? ''))),
      body: FutureBuilder<Map<String, dynamic>>(
        future: repo.fetchOwnerSummary(link.ownerUserId),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final summary = snapshot.data!;
          final logs = (summary['recent_logs'] as List?) ?? [];
          final profile = summary['medical_profile'] as Map<String, dynamic>?;
          return ListView(
            padding: const EdgeInsets.all(HealthSpacing.lg),
            children: [
              if (profile != null) ...[
                Text('Medical profile', style: HealthTypography.label()),
                const SizedBox(height: HealthSpacing.sm),
                HealthCard(
                  child: Text(
                    'Conditions: ${(profile['conditions'] as List?)?.join(', ') ?? 'None'}',
                    style: HealthTypography.body(),
                  ),
                ),
                const SizedBox(height: HealthSpacing.lg),
              ],
              Text('Recent logs', style: HealthTypography.label()),
              const SizedBox(height: HealthSpacing.sm),
              if (logs.isEmpty)
                Text('Nothing logged yet.', style: HealthTypography.body(color: HealthColors.inkMuted))
              else
                ...logs.map((l) => Padding(
                      padding: const EdgeInsets.only(bottom: HealthSpacing.sm),
                      child: HealthCard(
                        child: Text((l as Map)['summary']?.toString() ?? l['type'].toString(), style: HealthTypography.body()),
                      ),
                    )),
            ],
          );
        },
      ),
    );
  }
}

class _PermissionRow extends StatelessWidget {
  const _PermissionRow({required this.label, required this.value, required this.onChanged});
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          HealthSwitch(value: value, onChanged: onChanged),
          const SizedBox(width: 11),
          Expanded(child: Text(label, style: HealthTypography.body(fontSize: 13.5))),
        ],
      ),
    );
  }
}

class _AvatarInitial extends StatelessWidget {
  const _AvatarInitial({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final initial = text.trim().isNotEmpty ? text.trim()[0].toUpperCase() : '?';
    return Container(
      width: 40,
      height: 40,
      decoration: const BoxDecoration(color: HealthColors.chipIdle, shape: BoxShape.circle),
      child: Center(child: Text(initial, style: HealthTypography.display(fontSize: 16))),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'active' => HealthColors.accentSecondary,
      'pending' => HealthColors.inkMuted,
      _ => HealthColors.alertTrigger,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(999)),
      child: Text(status, style: HealthTypography.label(color: color)),
    );
  }
}
