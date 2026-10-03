import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

/// Animated mic waveform whose color follows the current [RiskLevel].
class Waveform extends StatefulWidget {
  final RiskLevel level;
  final bool active;
  const Waveform({super.key, required this.level, this.active = true});

  @override
  State<Waveform> createState() => _WaveformState();
}

class _WaveformState extends State<Waveform> {
  Timer? _timer;
  double _phase = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 110), (_) {
      if (!mounted) return;
      setState(() => _phase += 0.55);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const bars = 30;
    final color = KavachColors.forLevel(widget.level);
    return SizedBox(
      height: 56,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(bars, (i) {
          final wave = widget.active
              ? (math.sin(i * 0.65 + _phase) * 0.5 + 0.5) *
                  (math.sin(i * 0.23 - _phase * 0.7) * 0.5 + 0.5)
              : 0.06;
          final h = 6 + wave * 48;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 110),
            width: 5,
            height: h,
            margin: const EdgeInsets.symmetric(horizontal: 2.5),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(3),
              color: color.withValues(alpha: 0.35 + wave * 0.65),
            ),
          );
        }),
      ),
    );
  }
}
