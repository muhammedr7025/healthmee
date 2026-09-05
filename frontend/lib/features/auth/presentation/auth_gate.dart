import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/auth_repository.dart';
import 'auth_controller.dart';
import 'login_screen.dart';
import 'reset_password_screen.dart';
import 'signup_screen.dart';
import 'welcome_screen.dart';

enum _AuthScreen { welcome, signup, login, reset }

/// Everything shown before the user is signed in: welcome → signup/login →
/// (optionally) forgot-password, all as one small local state machine
/// rather than named routes, since none of these screens are ever deep-
/// linked into directly.
class AuthGate extends ConsumerStatefulWidget {
  const AuthGate({super.key});

  @override
  ConsumerState<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends ConsumerState<AuthGate> {
  _AuthScreen _screen = _AuthScreen.welcome;

  void _go(_AuthScreen screen) => setState(() => _screen = screen);

  @override
  Widget build(BuildContext context) {
    final authController = ref.read(authControllerProvider.notifier);
    final authRepo = ref.read(authRepositoryProvider);

    switch (_screen) {
      case _AuthScreen.welcome:
        return WelcomeScreen(
          onGetStarted: () => _go(_AuthScreen.signup),
          onSignIn: () => _go(_AuthScreen.login),
        );
      case _AuthScreen.signup:
        return SignupScreen(
          onCreateAccount: (email, password) => authController.register(email: email, password: password),
          onSignIn: () => _go(_AuthScreen.login),
        );
      case _AuthScreen.login:
        return LoginScreen(
          onSignIn: (email, password) => authController.login(email: email, password: password),
          onForgotPassword: () => _go(_AuthScreen.reset),
          onSignUp: () => _go(_AuthScreen.signup),
        );
      case _AuthScreen.reset:
        return ResetPasswordScreen(
          onRequestCode: (email) => authRepo.requestPasswordReset(email: email),
          onConfirmReset: (email, code, newPassword) =>
              authRepo.confirmPasswordReset(email: email, code: code, newPassword: newPassword),
          onBackToSignIn: () => _go(_AuthScreen.login),
        );
    }
  }
}
