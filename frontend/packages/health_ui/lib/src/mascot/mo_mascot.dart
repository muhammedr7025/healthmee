import 'package:flutter/material.dart';

import '../tokens/health_colors.dart';
import 'mo_painter.dart';
import 'mascot_state.dart';

/// Mo, the app's baby-elephant mascot, as a reusable animated widget.
/// Every appearance reinforces one idea: memory, gentleness, trust (dev-prompt
/// §1) — so animation is tied to *meaning* (dev-prompt §3), not decoration:
/// idle/thinking loop while the extraction pipeline runs, celebrating plays
/// once on a goal milestone, alerting is deliberately firmer-feeling than the
/// others (a safety signal), remembering plays before a recall answer renders.
class MoMascot extends StatefulWidget {
  const MoMascot({super.key, required this.state, this.size = 96});

  final MascotState state;
  final double size;

  @override
  State<MoMascot> createState() => _MoMascotState();
}

class _MoMascotState extends State<MoMascot> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  static const _durations = {
    MascotState.idle: Duration(milliseconds: 2200),
    MascotState.thinking: Duration(milliseconds: 900),
    MascotState.celebrating: Duration(milliseconds: 900),
    MascotState.alerting: Duration(milliseconds: 420),
    MascotState.remembering: Duration(milliseconds: 700),
  };

  static const _looping = {MascotState.idle, MascotState.thinking};

  bool _dependenciesReady = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _durations[widget.state]);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_dependenciesReady) {
      _dependenciesReady = true;
      _playForState(widget.state);
    }
  }

  @override
  void didUpdateWidget(covariant MoMascot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state != widget.state) {
      _controller.duration = _durations[widget.state];
      _playForState(widget.state);
    }
  }

  void _playForState(MascotState state) {
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    _controller.stop();
    _controller.reset();
    if (reduceMotion) return;
    if (_looping.contains(state)) {
      _controller.repeat();
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = reduceMotion ? 0.0 : _controller.value;
        final params = _paramsForState(widget.state, t);
        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: CustomPaint(
            painter: MoPainter(
              earAngle: params.earAngle,
              trunkCurl: params.trunkCurl,
              bodyBounce: params.bodyBounce,
              shakeX: params.shakeX,
              tint: params.tint,
            ),
          ),
        );
      },
    );
  }

  _MascotFrameParams _paramsForState(MascotState state, double t) {
    switch (state) {
      case MascotState.idle:
        return _MascotFrameParams(
          earAngle: 0.06 * gentleWave(t),
          trunkCurl: 0,
          bodyBounce: 0.15 * (0.5 + 0.5 * gentleWave(t)),
          shakeX: 0,
          tint: HealthColors.accentTertiary,
        );
      case MascotState.thinking:
        return _MascotFrameParams(
          earAngle: 0.12 * gentleWave(t),
          trunkCurl: 0.15 * (0.5 + 0.5 * gentleWave(t)),
          bodyBounce: 0,
          shakeX: 0,
          tint: HealthColors.accentTertiary,
        );
      case MascotState.celebrating:
        return _MascotFrameParams(
          earAngle: 0.18 * gentleWave(t * 2),
          trunkCurl: 0,
          bodyBounce: (t < 1.0) ? (1 - t) * gentleWave(t * 3).abs() : 0,
          shakeX: 0,
          tint: HealthColors.accentSecondary,
        );
      case MascotState.alerting:
        return _MascotFrameParams(
          earAngle: 0.05 * gentleWave(t * 6),
          trunkCurl: 0,
          bodyBounce: 0,
          shakeX: gentleWave(t * 8),
          tint: Color.lerp(HealthColors.accentTertiary, HealthColors.alertTrigger, (1 - (t - 0.5).abs() * 2).clamp(0, 1))!,
        );
      case MascotState.remembering:
        return _MascotFrameParams(
          earAngle: 0,
          trunkCurl: t.clamp(0, 1),
          bodyBounce: 0,
          shakeX: 0,
          tint: HealthColors.accentTertiary,
        );
    }
  }
}

class _MascotFrameParams {
  const _MascotFrameParams({
    required this.earAngle,
    required this.trunkCurl,
    required this.bodyBounce,
    required this.shakeX,
    required this.tint,
  });

  final double earAngle;
  final double trunkCurl;
  final double bodyBounce;
  final double shakeX;
  final Color tint;
}
