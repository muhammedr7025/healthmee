import 'package:flutter/material.dart';
import 'package:health_ui/health_ui.dart';

import 'social_auth_button.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.onSignIn, required this.onForgotPassword, required this.onSignUp});

  final Future<void> Function(String email, String password) onSignIn;
  final VoidCallback onForgotPassword;
  final VoidCallback onSignUp;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _showPassword = false;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await widget.onSignIn(_emailController.text.trim(), _passwordController.text);
    } catch (e) {
      setState(() => _error = 'Something went wrong — please check your details and try again.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _comingSoon(String label) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$label is coming soon.')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(HealthSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('WELCOME BACK', style: HealthTypography.label()),
              const SizedBox(height: HealthSpacing.sm),
              Center(
                child: Column(
                  children: [
                    const MascotHalo(state: MascotState.love, size: 140),
                    const SizedBox(height: 4),
                    Text('I missed you', style: HealthTypography.display(fontSize: 26)),
                    const SizedBox(height: 8),
                    Text(
                      'Your logs are exactly where you left them.',
                      style: HealthTypography.body(fontSize: 14, color: HealthColors.inkMuted),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: HealthSpacing.lg),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email', hintText: 'you@email.com'),
              ),
              const SizedBox(height: HealthSpacing.sm),
              TextField(
                controller: _passwordController,
                obscureText: !_showPassword,
                decoration: InputDecoration(
                  labelText: 'Password',
                  suffixIcon: TextButton(
                    onPressed: () => setState(() => _showPassword = !_showPassword),
                    child: Text(_showPassword ? 'Hide' : 'Show'),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: widget.onForgotPassword,
                  child: Text('Forgot password?', style: HealthTypography.body(fontSize: 12.5, color: HealthColors.accentPrimary)),
                ),
              ),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  child: Text(_submitting ? 'Please wait…' : 'Sign in'),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: HealthSpacing.sm),
                AlertBanner(message: _error!, hard: false),
              ],
              const SizedBox(height: HealthSpacing.lg),
              Row(
                children: [
                  Expanded(child: Divider(color: HealthColors.divider)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Text('or', style: HealthTypography.body(fontSize: 11, color: HealthColors.inkFaint)),
                  ),
                  Expanded(child: Divider(color: HealthColors.divider)),
                ],
              ),
              const SizedBox(height: HealthSpacing.md),
              SocialAuthButton(mark: 'G', label: 'Continue with Google', onTap: () => _comingSoon('Google sign-in')),
              const SizedBox(height: HealthSpacing.sm),
              SocialAuthButton(mark: 'A', label: 'Continue with Apple', onTap: () => _comingSoon('Apple sign-in')),
              const SizedBox(height: HealthSpacing.lg),
              Center(
                child: TextButton(
                  onPressed: widget.onSignUp,
                  child: Text.rich(
                    TextSpan(
                      text: 'New here? ',
                      style: HealthTypography.body(fontSize: 13, color: HealthColors.inkMuted),
                      children: [
                        TextSpan(text: 'Create an account', style: HealthTypography.body(fontSize: 13, color: HealthColors.accentPrimary)),
                      ],
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
