import 'package:flutter/material.dart';
import 'package:health_ui/health_ui.dart';

/// Three-bar password-strength indicator (mirrors the signup mockup): fill
/// count and color track length only — this is a nudge, not validation.
class PasswordStrengthBar extends StatelessWidget {
  const PasswordStrengthBar({super.key, required this.password});

  final String password;

  int get _filled => (password.length / 4).ceil().clamp(0, 3);

  Color get _fillColor {
    if (password.length < 8) return const Color(0xFFD3939B);
    if (password.length < 12) return const Color(0xFFE0C07A);
    return HealthColors.accentSecondary;
  }

  String get _label {
    if (password.isEmpty) return '';
    if (password.length < 8) return 'Too short';
    if (password.length < 12) return 'Okay';
    return 'Strong';
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < 3; i++)
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: i < 2 ? 6 : 0),
              child: Container(
                height: 4,
                decoration: BoxDecoration(
                  color: i < _filled ? _fillColor : HealthColors.chipIdle,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
        if (_label.isNotEmpty) ...[
          const SizedBox(width: 8),
          Text(_label, style: HealthTypography.body(fontSize: 11, color: HealthColors.inkFaint)),
        ],
      ],
    );
  }
}
