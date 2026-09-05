import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_ui/health_ui.dart';

import 'package:health/features/auth/presentation/login_screen.dart';
import 'package:health/features/auth/presentation/reset_password_screen.dart';
import 'package:health/features/auth/presentation/signup_screen.dart';
import 'package:health/features/auth/presentation/welcome_screen.dart';

Widget _wrap(Widget child) => MaterialApp(theme: HealthTheme.light(), home: child);

void main() {
  testWidgets('welcome screen routes to signup and to login', (tester) async {
    var gotStarted = false;
    var signedIn = false;
    await tester.pumpWidget(_wrap(WelcomeScreen(
      onGetStarted: () => gotStarted = true,
      onSignIn: () => signedIn = true,
    )));
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.text("Let's get started"));
    expect(gotStarted, isTrue);

    await tester.tap(find.textContaining('Sign in'));
    expect(signedIn, isTrue);
  });

  testWidgets('signup screen submits email and password, not a name', (tester) async {
    String? capturedEmail;
    String? capturedPassword;
    await tester.pumpWidget(_wrap(SignupScreen(
      onCreateAccount: (email, password) async {
        capturedEmail = email;
        capturedPassword = password;
      },
      onSignIn: () {},
    )));
    await tester.pump(const Duration(milliseconds: 100));

    await tester.enterText(find.widgetWithText(TextField, 'Email'), 'new@example.com');
    await tester.enterText(find.widgetWithText(TextField, 'Password'), 'supersecret1');
    await tester.tap(find.text('Create account'));
    await tester.pump();

    expect(capturedEmail, 'new@example.com');
    expect(capturedPassword, 'supersecret1');
  });

  testWidgets('login screen has a forgot-password link that fires its callback', (tester) async {
    var wentToReset = false;
    await tester.pumpWidget(_wrap(LoginScreen(
      onSignIn: (_, _) async {},
      onForgotPassword: () => wentToReset = true,
      onSignUp: () {},
    )));
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.text('Forgot password?'));
    expect(wentToReset, isTrue);
  });

  testWidgets('reset password screen moves from request to confirm after sending a code', (tester) async {
    await tester.pumpWidget(_wrap(ResetPasswordScreen(
      onRequestCode: (_) async {},
      onConfirmReset: (_, _, _) async {},
      onBackToSignIn: () {},
    )));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Send reset code'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, 'Email on your account'), 'me@example.com');
    await tester.tap(find.text('Send reset code'));
    await tester.pump();

    expect(find.text('Set new password'), findsOneWidget);
    expect(find.textContaining('Code sent to me@example.com'), findsOneWidget);
  });
}
