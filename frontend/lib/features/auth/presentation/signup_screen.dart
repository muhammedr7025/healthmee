import 'package:flutter/material.dart';
import 'package:health_ui/health_ui.dart';

import 'password_strength.dart';
import 'social_auth_button.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key, required this.onCreateAccount, required this.onSignIn});

  final Future<void> Function(String email, String password) onCreateAccount;
  final VoidCallback onSignIn;

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
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
      await widget.onCreateAccount(_emailController.text.trim(), _passwordController.text);
    } catch (e) {
      setState(() => _error = "Couldn't create that account — please check your details and try again.");
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
              Text('CREATE YOUR ACCOUNT', style: HealthTypography.label()),
              const SizedBox(height: HealthSpacing.md),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const MemeMascot(state: MascotState.excited, size: 58),
                  const SizedBox(width: HealthSpacing.sm),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
                      decoration: BoxDecoration(
                        color: HealthColors.surface,
                        border: Border.all(color: HealthColors.inkPrimary.withValues(alpha: 0.09)),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(18),
                          topRight: Radius.circular(18),
                          bottomRight: Radius.circular(18),
                          bottomLeft: Radius.circular(5),
                        ),
                      ),
                      child: Text('An email and a password, and your logs are safe with me.', style: HealthTypography.body(fontSize: 14.5)),
                    ),
                  ),
                ],
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
                  hintText: 'At least 8 characters',
                  suffixIcon: TextButton(
                    onPressed: () => setState(() => _showPassword = !_showPassword),
                    child: Text(_showPassword ? 'Hide' : 'Show'),
                  ),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 6),
              PasswordStrengthBar(password: _passwordController.text),
              const SizedBox(height: HealthSpacing.md),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  child: Text(_submitting ? 'Please wait…' : 'Create account'),
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
              const SizedBox(height: HealthSpacing.xl),
              Text(
                'By continuing you agree to the Terms and Privacy Policy. Your health data is never sold.',
                style: HealthTypography.body(fontSize: 11.5, color: HealthColors.inkFaint),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: HealthSpacing.sm),
              Center(
                child: TextButton(
                  onPressed: widget.onSignIn,
                  child: Text.rich(
                    TextSpan(
                      text: 'Already with us? ',
                      style: HealthTypography.body(fontSize: 13, color: HealthColors.inkMuted),
                      children: [TextSpan(text: 'Sign in', style: HealthTypography.body(fontSize: 13, color: HealthColors.accentPrimary))],
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
