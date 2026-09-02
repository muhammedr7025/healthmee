import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:health_ui/health_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/billing_repository.dart';

const _premiumFeatures = [
  'Photo and video logging — plates, lab reports, workouts',
  'Unlimited history instead of 30 days',
  'Doctor-ready PDF reports and share links',
  'Correlations and weekly check-ins from Mo',
];

class PaywallScreen extends ConsumerStatefulWidget {
  const PaywallScreen({super.key});

  @override
  ConsumerState<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends ConsumerState<PaywallScreen> {
  bool _working = false;
  String? _message;

  Future<void> _upgrade() async {
    setState(() {
      _working = true;
      _message = null;
    });
    try {
      final url = await ref.read(billingRepositoryProvider).startCheckout();
      if (url != null) {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      } else {
        // Mock billing mode: the account is already premium server-side.
        setState(() => _message = "You're on Premium now — no card needed in this preview build.");
      }
      ref.invalidate(subscriptionProvider);
    } catch (_) {
      setState(() => _message = "Couldn't start checkout — please try again.");
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _manage() async {
    setState(() {
      _working = true;
      _message = null;
    });
    try {
      final url = await ref.read(billingRepositoryProvider).startPortal();
      if (url != null) {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      } else {
        setState(() => _message = 'Moved back to the free plan.');
      }
      ref.invalidate(subscriptionProvider);
    } catch (_) {
      setState(() => _message = "Couldn't open billing — please try again.");
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncSub = ref.watch(subscriptionProvider);

    return Scaffold(
      appBar: AppBar(title: Text('Upgrade', style: HealthTypography.display(fontSize: 22))),
      body: asyncSub.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Padding(
          padding: const EdgeInsets.all(HealthSpacing.lg),
          child: AlertBanner(message: "Couldn't load your subscription.", hard: false),
        ),
        data: (sub) => SingleChildScrollView(
          padding: const EdgeInsets.all(HealthSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: MoMascot(state: sub.isPremium ? MascotState.celebrating : MascotState.idle, size: 96)),
              const SizedBox(height: HealthSpacing.md),
              Text(
                sub.isPremium ? "You're on Premium" : 'More room to remember',
                style: HealthTypography.display(fontSize: 26),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: HealthSpacing.sm),
              Text(
                sub.isPremium
                    ? 'Thanks for supporting VitaChat — everything below is unlocked.'
                    : 'Unlock full history, richer logging and doctor-ready reports.',
                style: HealthTypography.body(color: HealthColors.inkMuted),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: HealthSpacing.lg),
              ..._premiumFeatures.map((f) => Padding(
                    padding: const EdgeInsets.only(bottom: HealthSpacing.sm),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.check_circle, size: 18, color: HealthColors.accentSecondary),
                        const SizedBox(width: HealthSpacing.sm),
                        Expanded(child: Text(f, style: HealthTypography.body())),
                      ],
                    ),
                  )),
              const SizedBox(height: HealthSpacing.lg),
              if (_message != null) ...[
                AlertBanner(message: _message!, hard: false),
                const SizedBox(height: HealthSpacing.sm),
              ],
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _working ? null : (sub.isPremium ? _manage : _upgrade),
                  child: Text(_working
                      ? 'Please wait…'
                      : (sub.isPremium ? 'Manage subscription' : 'Upgrade to Premium')),
                ),
              ),
              if (sub.billingMode == 'mock') ...[
                const SizedBox(height: HealthSpacing.sm),
                Text(
                  'Running in preview billing mode — no real payment provider connected yet.',
                  style: HealthTypography.label(),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
