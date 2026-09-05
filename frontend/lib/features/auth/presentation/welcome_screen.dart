import 'package:flutter/material.dart';
import 'package:health_ui/health_ui.dart';

const _valueChips = ['Listen', 'Track', 'Guide', 'Care'];

/// The very first thing an unauthenticated user sees — sets up who MeMe is
/// before asking for an email and a password.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key, required this.onGetStarted, required this.onSignIn});

  final VoidCallback onGetStarted;
  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: HealthSpacing.lg),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                alignment: Alignment.topLeft,
                clipBehavior: Clip.none,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 28),
                    child: MemeMascot(state: MascotState.happy, size: 190),
                  ),
                  Positioned(
                    left: 4,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
                      decoration: BoxDecoration(
                        color: HealthColors.surface,
                        border: Border.all(color: HealthColors.inkPrimary.withValues(alpha: 0.1)),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(16),
                          topRight: Radius.circular(16),
                          bottomRight: Radius.circular(16),
                          bottomLeft: Radius.circular(5),
                        ),
                      ),
                      child: Text("Hi! I'm MeMe ♡", style: HealthTypography.body(fontSize: 13)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: HealthSpacing.sm),
              Text(
                'A healthier you,\nbrighter tomorrows',
                style: HealthTypography.display(fontSize: 30),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: HealthSpacing.sm),
              Text(
                "Tell me what you ate, how you slept, how you feel. Type it, snap it, or say it — "
                "I'll do the filing.",
                style: HealthTypography.body(fontSize: 14.5, color: HealthColors.inkMuted),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: HealthSpacing.md),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 7,
                children: _valueChips
                    .map((label) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(color: HealthColors.chipIdle, borderRadius: BorderRadius.circular(999)),
                          child: Text(label, style: HealthTypography.body(fontSize: 12, weight: FontWeight.w500)),
                        ))
                    .toList(),
              ),
              const SizedBox(height: HealthSpacing.xl),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(onPressed: onGetStarted, child: const Text("Let's get started")),
              ),
              const SizedBox(height: HealthSpacing.sm),
              Padding(
                padding: const EdgeInsets.only(bottom: HealthSpacing.lg),
                child: TextButton(
                  onPressed: onSignIn,
                  child: Text.rich(
                    TextSpan(
                      text: 'Already have an account? ',
                      style: HealthTypography.body(fontSize: 12.5, color: HealthColors.inkMuted),
                      children: [TextSpan(text: 'Sign in', style: HealthTypography.body(fontSize: 12.5, color: HealthColors.accentPrimary))],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
