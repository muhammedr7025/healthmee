import 'package:flutter/material.dart';
import 'package:health_ui/health_ui.dart';

/// Forgot-password flow. There's no universal-link/deep-link setup in this
/// app yet, so rather than a tap-through email link, the emailed message
/// carries a 6-digit code the user types back in here — same security
/// properties, no native platform config required to make it real.
class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({
    super.key,
    required this.onRequestCode,
    required this.onConfirmReset,
    required this.onBackToSignIn,
  });

  final Future<void> Function(String email) onRequestCode;
  final Future<void> Function(String email, String code, String newPassword) onConfirmReset;
  final VoidCallback onBackToSignIn;

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

enum _ResetStage { idle, sent, confirmed }

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _newPasswordController = TextEditingController();
  _ResetStage _stage = _ResetStage.idle;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    _newPasswordController.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await widget.onRequestCode(_emailController.text.trim());
      if (mounted) setState(() => _stage = _ResetStage.sent);
    } catch (e) {
      setState(() => _error = "Couldn't send that — please check the email and try again.");
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _confirm() async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await widget.onConfirmReset(_emailController.text.trim(), _codeController.text.trim(), _newPasswordController.text);
      if (mounted) setState(() => _stage = _ResetStage.confirmed);
    } catch (e) {
      setState(() => _error = "That code didn't work — check it and try again, or send a new one.");
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mood = _stage == _ResetStage.idle ? MascotState.thinking : MascotState.encouraging;
    final line = switch (_stage) {
      _ResetStage.idle => "Happens to everyone. Tell me the email you signed up with and I'll send a code.",
      _ResetStage.sent => 'Check your inbox — enter the code below along with a new password.',
      _ResetStage.confirmed => "Done. Your password's been changed — sign in with the new one.",
    };

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(HealthSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('RESET YOUR PASSWORD', style: HealthTypography.label()),
              const SizedBox(height: HealthSpacing.md),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MemeMascot(state: mood, size: 58),
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
                      child: Text(line, style: HealthTypography.body(fontSize: 14.5)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: HealthSpacing.lg),
              if (_stage == _ResetStage.idle) ...[
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email on your account', hintText: 'you@email.com'),
                ),
                const SizedBox(height: HealthSpacing.md),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _submitting ? null : _sendCode,
                    child: Text(_submitting ? 'Sending…' : 'Send reset code'),
                  ),
                ),
              ] else if (_stage == _ResetStage.sent) ...[
                Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F4EC),
                    border: Border.all(color: HealthColors.accentSecondary.withValues(alpha: 0.4)),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.check_circle_outline, color: HealthColors.accentSecondary, size: 18),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Text(
                          'Code sent to ${_emailController.text.trim()}. It works once and expires in 30 minutes.',
                          style: HealthTypography.body(fontSize: 13.5, color: HealthColors.accentSecondary),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: HealthSpacing.md),
                TextField(
                  controller: _codeController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: '6-digit code', hintText: '123456'),
                ),
                const SizedBox(height: HealthSpacing.sm),
                TextField(
                  controller: _newPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'New password', hintText: 'At least 8 characters'),
                ),
                const SizedBox(height: HealthSpacing.md),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _submitting ? null : _confirm,
                    child: Text(_submitting ? 'Saving…' : 'Set new password'),
                  ),
                ),
                const SizedBox(height: HealthSpacing.sm),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(onPressed: _submitting ? null : _sendCode, child: const Text('Send it again')),
                ),
              ] else ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(onPressed: widget.onBackToSignIn, child: const Text('Back to sign in')),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: HealthSpacing.sm),
                AlertBanner(message: _error!, hard: false),
              ],
              const SizedBox(height: HealthSpacing.lg),
              if (_stage != _ResetStage.confirmed)
                Center(
                  child: TextButton(onPressed: widget.onBackToSignIn, child: const Text('Back to sign in')),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
