import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:health_ui/health_ui.dart';

import 'auth_controller.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  bool _isRegister = false;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final controller = ref.read(authControllerProvider.notifier);
      if (_isRegister) {
        await controller.register(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          fullName: _nameController.text.trim(),
        );
      } else {
        await controller.login(email: _emailController.text.trim(), password: _passwordController.text);
      }
    } catch (e) {
      setState(() => _error = 'Something went wrong — please check your details and try again.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(HealthSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const MemeMascot(state: MascotState.idle, size: 120),
                const SizedBox(height: HealthSpacing.md),
                Text(
                  _isRegister ? "Hi, I'm MeMe." : 'Welcome back.',
                  style: HealthTypography.display(fontSize: 32),
                ),
                const SizedBox(height: HealthSpacing.xs),
                Text(
                  _isRegister
                      ? 'Tell me what you ate, how you slept, how you feel. Type it, snap it, or say it. '
                          "I'll do the filing."
                      : 'MeMe remembers where you left off.',
                  style: HealthTypography.body(fontSize: 15, color: HealthColors.inkMuted),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: HealthSpacing.xl),
                if (_isRegister)
                  Padding(
                    padding: const EdgeInsets.only(bottom: HealthSpacing.sm),
                    child: TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(labelText: 'Full name (optional)'),
                    ),
                  ),
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email'),
                ),
                const SizedBox(height: HealthSpacing.sm),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Password'),
                ),
                if (_error != null) ...[
                  const SizedBox(height: HealthSpacing.sm),
                  AlertBanner(message: _error!, hard: false),
                ],
                const SizedBox(height: HealthSpacing.lg),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _submitting ? null : _submit,
                    child: Text(_submitting ? 'Please wait…' : (_isRegister ? 'Create account' : 'Log in')),
                  ),
                ),
                const SizedBox(height: HealthSpacing.sm),
                TextButton(
                  onPressed: () => setState(() => _isRegister = !_isRegister),
                  child: Text(_isRegister ? 'Already have an account? Log in' : "New here? Create an account"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
