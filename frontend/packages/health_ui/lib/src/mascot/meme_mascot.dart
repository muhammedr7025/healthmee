import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'mascot_state.dart';

/// MeMe, the app's illustrated baby-elephant mascot. Every appearance
/// reinforces one idea: memory, gentleness, trust — so which mood renders is
/// tied to *meaning* (dev-prompt §3), not decoration.
///
/// Renders the real illustrated artwork (one PNG per [MascotState]) rather
/// than a procedural drawing, with a slow float-and-tilt loop matching the
/// mockup's `mimiFloat` keyframe animation.
class MemeMascot extends StatefulWidget {
  const MemeMascot({super.key, required this.state, this.size = 96});

  final MascotState state;
  final double size;

  @override
  State<MemeMascot> createState() => _MemeMascotState();
}

class _MemeMascotState extends State<MemeMascot> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 4600))..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  static const _assetNames = {
    MascotState.happy: 'happy',
    MascotState.excited: 'excited',
    MascotState.curious: 'curious',
    MascotState.thinking: 'thinking',
    MascotState.proud: 'proud',
    MascotState.love: 'love',
    MascotState.sleepy: 'sleepy',
    MascotState.sad: 'sad',
    MascotState.concerned: 'concerned',
    MascotState.surprised: 'surprised',
    MascotState.encouraging: 'encouraging',
    MascotState.celebrating: 'celebrating',
  };

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final image = Image.asset(
      'assets/mascot/${_assetNames[widget.state]}.png',
      package: 'health_ui',
      width: widget.size,
      height: widget.size,
      fit: BoxFit.contain,
    );
    final sized = SizedBox(width: widget.size, height: widget.size, child: image);

    if (reduceMotion) return sized;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final phase = _controller.value * 2 * math.pi;
        return Transform.translate(
          offset: Offset(0, -4 * math.sin(phase)),
          child: Transform.rotate(angle: 0.021 * math.sin(phase), child: child),
        );
      },
      child: sized,
    );
  }
}
