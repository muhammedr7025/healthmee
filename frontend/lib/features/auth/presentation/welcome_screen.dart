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
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.4),
            radius: 0.9,
            colors: [HealthColors.chipIdle, HealthColors.bgBase],
            stops: [0.0, 0.62],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: HealthSpacing.lg),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 250,
                  height: 250,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 198,
                        height: 198,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [HealthColors.reactionBubble, Colors.transparent],
                          ),
                        ),
                      ),
                      const MemeMascot(state: MascotState.happy, size: 190),
                      Positioned(
                        left: 8,
                        top: 34,
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
                            boxShadow: [BoxShadow(color: HealthColors.inkPrimary.withValues(alpha: 0.08), blurRadius: 14, offset: const Offset(0, 4))],
                          ),
                          child: Text("Hi! I'm MeMe ♡", style: HealthTypography.body(fontSize: 13, color: const Color(0xFF2B5249))),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'A healthier you,\nbrighter tomorrows',
                  style: HealthTypography.display(fontSize: 31),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 11),
                Text(
                  "Tell me what you ate, how you slept, how you feel. Type it, snap it, or say it — "
                  "I'll do the filing.",
                  style: HealthTypography.body(fontSize: 14.5, color: HealthColors.inkMuted, weight: FontWeight.w400),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 18),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 7,
                  children: _valueChips
                      .map((label) => Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                            decoration: BoxDecoration(color: HealthColors.chipIdle, borderRadius: BorderRadius.circular(999)),
                            child: Text(label, style: HealthTypography.body(fontSize: 12, weight: FontWeight.w500, color: const Color(0xFF2F6156))),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 26),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(onPressed: onGetStarted, child: const Text("Let's get started")),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: TextButton(
                    onPressed: onSignIn,
                    child: Text.rich(
                      TextSpan(
                        text: 'Already have an account? ',
                        style: HealthTypography.body(fontSize: 12.5, color: HealthColors.inkFaint),
                        children: [
                          TextSpan(text: 'Sign in', style: HealthTypography.body(fontSize: 12.5, color: HealthColors.accentPrimary)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
