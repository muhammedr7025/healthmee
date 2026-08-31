import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../tokens/health_colors.dart';

/// A simple, stylized baby-elephant silhouette. Intentionally a placeholder
/// painter (not final character art) — swap for illustrated/Lottie frames
/// later without changing KunjanMascot's animation-state contract.
class KunjanPainter extends CustomPainter {
  KunjanPainter({
    required this.earAngle,
    required this.trunkCurl,
    required this.bodyBounce,
    required this.tint,
    this.shakeX = 0,
  });

  /// Radians, ear flap rotation.
  final double earAngle;

  /// 0 = trunk hanging loose, 1 = curled up toward the temple ("remembering").
  final double trunkCurl;

  /// Vertical offset fraction for the celebratory bounce/stomp.
  final double bodyBounce;

  /// Horizontal offset fraction — the firmer "alerting" shake.
  final double shakeX;

  final Color tint;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final bodyPaint = Paint()..color = tint;
    final earPaint = Paint()..color = tint.withValues(alpha: 0.55);

    canvas.save();
    canvas.translate(shakeX * w * 0.05, -bodyBounce * h * 0.08);

    // Ears (behind body), rotated around their outer edge for the flap.
    for (final side in [-1.0, 1.0]) {
      canvas.save();
      final pivot = Offset(w * 0.5 + side * w * 0.28, h * 0.38);
      canvas.translate(pivot.dx, pivot.dy);
      canvas.rotate(side * earAngle);
      canvas.translate(-pivot.dx, -pivot.dy);
      canvas.drawOval(
        Rect.fromCenter(center: pivot, width: w * 0.34, height: h * 0.42),
        earPaint,
      );
      canvas.restore();
    }

    // Body.
    final bodyRect = Rect.fromCenter(center: Offset(w * 0.5, h * 0.55), width: w * 0.62, height: h * 0.56);
    canvas.drawRRect(RRect.fromRectAndRadius(bodyRect, Radius.circular(w * 0.22)), bodyPaint);

    // Head.
    final headCenter = Offset(w * 0.5, h * 0.34);
    canvas.drawCircle(headCenter, w * 0.24, bodyPaint);

    // Eyes.
    final eyePaint = Paint()..color = HealthColors.inkPrimary;
    canvas.drawCircle(Offset(w * 0.42, h * 0.32), w * 0.02, eyePaint);
    canvas.drawCircle(Offset(w * 0.58, h * 0.32), w * 0.02, eyePaint);

    // Trunk — a quadratic curve whose control point swings from "hanging
    // down" (trunkCurl = 0) to "curled toward the temple" (trunkCurl = 1).
    final trunkStart = Offset(w * 0.5, h * 0.42);
    final hangControl = Offset(w * 0.5, h * 0.62);
    final hangEnd = Offset(w * 0.46, h * 0.72);
    final curlControl = Offset(w * 0.66, h * 0.30);
    final curlEnd = Offset(w * 0.58, h * 0.22);

    final control = Offset.lerp(hangControl, curlControl, trunkCurl)!;
    final end = Offset.lerp(hangEnd, curlEnd, trunkCurl)!;

    final trunkPath = Path()..moveTo(trunkStart.dx, trunkStart.dy)..quadraticBezierTo(control.dx, control.dy, end.dx, end.dy);
    canvas.drawPath(
      trunkPath,
      Paint()
        ..color = tint
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.09
        ..strokeCap = StrokeCap.round,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant KunjanPainter oldDelegate) {
    return oldDelegate.earAngle != earAngle ||
        oldDelegate.trunkCurl != trunkCurl ||
        oldDelegate.bodyBounce != bodyBounce ||
        oldDelegate.shakeX != shakeX ||
        oldDelegate.tint != tint;
  }
}

double gentleWave(double t) => math.sin(t * math.pi * 2);
