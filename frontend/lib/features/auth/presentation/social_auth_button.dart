import 'package:flutter/material.dart';
import 'package:health_ui/health_ui.dart';

/// Google/Apple sign-in buttons on the signup and login screens. Neither
/// provider is wired up yet, so callers should show a "coming soon" nudge
/// rather than silently doing nothing.
class SocialAuthButton extends StatelessWidget {
  const SocialAuthButton({super.key, required this.mark, required this.label, required this.onTap});

  final String mark;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: HealthColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: HealthColors.inkPrimary.withValues(alpha: 0.12)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 18,
                height: 18,
                decoration: const BoxDecoration(color: HealthColors.chipIdle, shape: BoxShape.circle),
                child: Center(child: Text(mark, style: HealthTypography.body(fontSize: 10, weight: FontWeight.w700))),
              ),
              const SizedBox(width: 10),
              Text(label, style: HealthTypography.body(fontSize: 14.5)),
            ],
          ),
        ),
      ),
    );
  }
}
