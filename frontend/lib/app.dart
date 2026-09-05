import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:health_ui/health_ui.dart';

import 'core/app_shell.dart';
import 'features/auth/presentation/auth_controller.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/onboarding/presentation/onboarding_screen.dart';

class HealthApp extends ConsumerWidget {
  const HealthApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);

    return MaterialApp(
      title: 'Health MEE',
      debugShowCheckedModeBanner: false,
      theme: HealthTheme.light(),
      home: switch (auth.status) {
        AuthStatus.checking => const _SplashScreen(),
        AuthStatus.unauthenticated => const LoginScreen(),
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
      body: Center(child: MimiMascot(state: MascotState.idle, size: 120)),
    );
  }
}
