import 'package:flutter/material.dart';
import 'package:health_ui/health_ui.dart';

import '../../billing/presentation/paywall_screen.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Reports', style: HealthTypography.display(fontSize: 22))),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(HealthSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const MoMascot(state: MascotState.thinking, size: 96),
              const SizedBox(height: HealthSpacing.lg),
              Text('Doctor-ready reports', style: HealthTypography.display(fontSize: 22), textAlign: TextAlign.center),
              const SizedBox(height: HealthSpacing.sm),
              Text(
                'One-tap PDF export of your logs, trends and lab history — for your next appointment '
                'or a caregiver. This is coming in a future update; your data is already being kept '
                'ready for it.',
                style: HealthTypography.body(color: HealthColors.inkMuted),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: HealthSpacing.lg),
              OutlinedButton(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PaywallScreen())),
                child: const Text('See what Premium unlocks'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
