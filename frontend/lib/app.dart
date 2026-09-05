import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:health_ui/health_ui.dart';

import 'core/app_shell.dart';
import 'features/auth/presentation/auth_controller.dart';
import 'features/auth/presentation/auth_gate.dart';
import 'features/onboarding/presentation/onboarding_screen.dart';

class HealthApp extends ConsumerWidget {
  const HealthApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);

    // A little tap the moment the splash screen hands off to whatever's
    // next (welcome, onboarding, or straight into the app) — fires exactly
    // once per launch, not on every subsequent auth-state change.
    ref.listen<AuthStatus>(authControllerProvider.select((s) => s.status), (previous, next) {
      if (previous == AuthStatus.checking && next != AuthStatus.checking) {
        HapticFeedback.mediumImpact();
      }
    });

    return MaterialApp(
      title: 'Health MEE',
      debugShowCheckedModeBanner: false,
      theme: HealthTheme.light(),
      home: switch (auth.status) {
        AuthStatus.checking => const _SplashScreen(),
        AuthStatus.unauthenticated => const AuthGate(),
        AuthStatus.authenticated =>
          (auth.user?.onboardingCompleted ?? false) ? const AppShell() : const OnboardingScreen(),
      },
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: MemeMascot(state: MascotState.happy, size: 120)),
    );
  }
}
