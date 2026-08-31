import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../tokens/health_colors.dart';

/// The app's one deliberate structural signature (dev-prompt §2): a soft,
/// hand-drawn-feeling curved path — echoing a wandering elephant trail / a
/// trunk's curve — threading through Logbook/Trends entries chronologically.
/// Used once, with restraint, not repeated as decoration everywhere.
class MemoryTrailPainter extends CustomPainter {
  MemoryTrailPainter({required this.rowCount, required this.rowHeight, this.gutterWidth = 40});

  final int rowCount;
  final double rowHeight;
  final double gutterWidth;

  /// The x-offset (within the gutter) of the trail at [row], used to align
  /// each row's marker dot to the curve.
  static double xAtRow(int row, double gutterWidth) => gutterWidth * 0.5 + math.sin(row * 0.9) * gutterWidth * 0.22;

  @override
  void paint(Canvas canvas, Size size) {
    if (rowCount == 0) return;

    final path = Path();
    for (int row = 0; row <= rowCount; row++) {
      final x = xAtRow(row, gutterWidth);
      final y = row * rowHeight;
      if (row == 0) {
        path.moveTo(x, y);
      } else {
        final prevX = xAtRow(row - 1, gutterWidth);
        final prevY = (row - 1) * rowHeight;
        final midY = (prevY + y) / 2;
        path.cubicTo(prevX, midY, x, midY, x, y);
      }
    }

    canvas.drawPath(
      path,
      Paint()
        ..color = HealthColors.accentTertiary.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant MemoryTrailPainter oldDelegate) =>
      oldDelegate.rowCount != rowCount || oldDelegate.rowHeight != rowHeight;
}
