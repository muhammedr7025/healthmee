import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:health_ui/health_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/billing_repository.dart';

const _premiumFeatures = [
  'Photo and video logging — plates, lab reports, workouts',
  'Unlimited history instead of 30 days',
  'Doctor-ready PDF reports and share links',
  'Correlations and weekly check-ins from MeMe',
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
      body: SafeArea(
        child: asyncSub.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Padding(
            padding: const EdgeInsets.all(HealthSpacing.lg),
            child: AlertBanner(message: "Couldn't load your subscription.", hard: false),
          ),
          data: (sub) => ListView(
            padding: const EdgeInsets.fromLTRB(HealthSpacing.lg, 0, HealthSpacing.lg, HealthSpacing.lg),
            children: [
              Align(
                alignment: Alignment.topRight,
                child: TextButton(
                  onPressed: () => Navigator.maybePop(context),
                  child: Text('Not now', style: HealthTypography.body(fontSize: 13, color: HealthColors.inkMuted)),
                ),
              ),
              Center(child: MemeMascot(state: sub.isPremium ? MascotState.celebrating : MascotState.happy, size: 96)),
              const SizedBox(height: 14),
              Text(
                sub.isPremium ? "You're on Premium" : 'Let MeMe see everything',
                style: HealthTypography.display(fontSize: 27),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                sub.isPremium
                    ? 'Thanks for supporting Health MEE — everything below is unlocked.'
                    : 'Photos, video, full history and the doctor report.',
                style: HealthTypography.body(fontSize: 13.5, color: HealthColors.inkMuted),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ..._premiumFeatures.map((f) => Padding(
                    padding: const EdgeInsets.only(bottom: 9),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 18,
                          height: 18,
                          margin: const EdgeInsets.only(top: 1),
                          decoration: const BoxDecoration(color: HealthColors.reactionBubble, shape: BoxShape.circle),
                          child: Icon(Icons.check, size: 11, color: HealthColors.accentPrimaryDark),
                        ),
                        const SizedBox(width: 11),
                        Expanded(child: Text(f, style: HealthTypography.body(fontSize: 13.5))),
                      ],
                    ),
                  )),
              const SizedBox(height: 16),
              if (!sub.isPremium)
                Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFDEEE4),
                    border: Border.all(color: HealthColors.accentPrimary, width: 1.5),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('PREMIUM', style: HealthTypography.label(color: HealthColors.accentPrimaryDark)),
                            const SizedBox(height: 4),
                            Text(
                              sub.billingMode == 'mock' ? 'Free in preview' : 'See pricing at checkout',
                              style: HealthTypography.display(fontSize: 19),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        sub.billingMode == 'mock' ? 'No card needed' : 'Cancel anytime',
                        style: HealthTypography.body(fontSize: 11.5, color: HealthColors.inkMuted),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              if (_message != null) ...[
                AlertBanner(message: _message!, hard: false),
                const SizedBox(height: HealthSpacing.sm),
              ],
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _working ? null : (sub.isPremium ? _manage : _upgrade),
                  child: Text(_working ? 'Please wait…' : (sub.isPremium ? 'Manage subscription' : 'Upgrade to Premium')),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Cancel anytime; your logs stay yours either way.',
                style: HealthTypography.body(fontSize: 11.5, color: HealthColors.inkFaint),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
