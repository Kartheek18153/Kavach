import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

/// Orb states mirroring the `thinking-orbs` API.
enum OrbState {
  working,
  searching,
  solving,
  listening,
  connecting,
  weaving,
  composing,
  breathing,
  shaping,
}

/// Maps the current risk level to an orb state.
OrbState orbStateForLevel(RiskLevel level, {required bool running}) {
  if (!running) return OrbState.breathing;
  switch (level) {
    case RiskLevel.safe:
      return OrbState.listening;
    case RiskLevel.caution:
      return OrbState.searching;
    case RiskLevel.danger:
      return OrbState.solving;
  }
}

class _OrbSpec {
  const _OrbSpec({
    required this.a,
    required this.b,
    required this.blobs,
    required this.orbit,
    required this.pulse,
    required this.period,
    required this.spin,
  });

  final Color a;
  final Color b;
  final int blobs;
  final double orbit;
  final double pulse;
  final Duration period;
  final double spin;
}

/// Flutter port of the ThinkingOrb effect: layered orbiting blobs with a
/// glowing core. Colors follow the Kavach theme; motion per state.
class ThinkingOrb extends StatefulWidget {
  final OrbState state;
  final double size;
  final double speed;
  final bool dark;
  final bool paused;

  const ThinkingOrb({
    super.key,
    this.state = OrbState.listening,
    this.size = 64,
    this.speed = 1,
    this.dark = false,
    this.paused = false,
  });

  @override
  State<ThinkingOrb> createState() => _ThinkingOrbState();
}

class _ThinkingOrbState extends State<ThinkingOrb>
    with SingleTickerProviderStateMixin {
  late AnimationController _clock;

  static _OrbSpec _specFor(OrbState state, bool dark) {
    const teal = KavachColors.teal;
    const blue = KavachColors.blue;
    const navy = KavachColors.violet;
    const amber = KavachColors.caution;
    const danger = KavachColors.danger;
    switch (state) {
      case OrbState.listening:
        return _OrbSpec(
            a: teal,
            b: blue,
            blobs: 4,
            orbit: 0.52,
            pulse: 0.25,
            period: const Duration(milliseconds: 3200),
            spin: 1);
      case OrbState.searching:
        return _OrbSpec(
            a: blue,
            b: navy,
            blobs: 5,
            orbit: 0.62,
            pulse: 0.3,
            period: const Duration(milliseconds: 2400),
            spin: 1.4);
      case OrbState.solving:
        return _OrbSpec(
            a: danger,
            b: amber,
            blobs: 5,
            orbit: 0.45,
            pulse: 0.4,
            period: const Duration(milliseconds: 1400),
            spin: 2);
      case OrbState.working:
        return _OrbSpec(
            a: blue,
            b: teal,
            blobs: 4,
            orbit: 0.55,
            pulse: 0.3,
            period: const Duration(milliseconds: 2200),
            spin: 1.2);
      case OrbState.connecting:
        return _OrbSpec(
            a: amber,
            b: teal,
            blobs: 3,
            orbit: 0.6,
            pulse: 0.45,
            period: const Duration(milliseconds: 1800),
            spin: 1);
      case OrbState.weaving:
        return _OrbSpec(
            a: teal,
            b: navy,
            blobs: 6,
            orbit: 0.58,
            pulse: 0.35,
            period: const Duration(milliseconds: 2600),
            spin: -1.2);
      case OrbState.composing:
        return _OrbSpec(
            a: navy,
            b: blue,
            blobs: 4,
            orbit: 0.4,
            pulse: 0.5,
            period: const Duration(milliseconds: 3600),
            spin: 0.7);
      case OrbState.breathing:
        return _OrbSpec(
            a: dark ? blue : teal,
            b: dark ? navy : blue,
            blobs: 3,
            orbit: 0.35,
            pulse: 0.55,
            period: const Duration(milliseconds: 4800),
            spin: 0.4);
      case OrbState.shaping:
        return _OrbSpec(
            a: blue,
            b: teal,
            blobs: 6,
            orbit: 0.5,
            pulse: 0.45,
            period: const Duration(milliseconds: 2000),
            spin: 1.8);
    }
  }

  @override
  void initState() {
    super.initState();
    _clock = AnimationController(
      vsync: this,
      duration: _scaledPeriod(),
    );
    if (!widget.paused) _clock.repeat();
  }

  Duration _scaledPeriod() {
    final base = _specFor(widget.state, widget.dark).period;
    final speed = widget.speed <= 0 ? 1 : widget.speed;
    return Duration(
        milliseconds: (base.inMilliseconds / speed).round().clamp(200, 30000));
  }

  @override
  void didUpdateWidget(covariant ThinkingOrb old) {
    super.didUpdateWidget(old);
    if (old.state != widget.state ||
        old.speed != widget.speed ||
        old.dark != widget.dark) {
      _clock.duration = _scaledPeriod();
      if (!widget.paused) _clock.repeat();
    }
    if (old.paused != widget.paused) {
      if (widget.paused) {
        _clock.stop();
      } else {
        _clock.repeat();
      }
    }
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final spec = _specFor(widget.state, widget.dark);
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _clock,
        builder: (context, _) => CustomPaint(
          painter: _OrbPainter(
            t: _clock.value,
            spec: spec,
            size: widget.size,
          ),
        ),
      ),
    );
  }
}

class _OrbPainter extends CustomPainter {
  _OrbPainter({required this.t, required this.spec, required this.size});

  final double t;
  final _OrbSpec spec;
  final double size;

  @override
  void paint(Canvas canvas, Size _) {
    final center = Offset(size / 2, size / 2);
    final maxR = size / 2;

    // Orbiting soft blobs.
    for (var i = 0; i < spec.blobs; i++) {
      final phase = i * 2 * math.pi / spec.blobs;
      final angle = t * 2 * math.pi * spec.spin + phase;
      final wobble = 1 + spec.pulse * math.sin(t * 4 * math.pi + i * 1.7);
      final r = maxR * 0.34 * wobble;
      final dist = maxR * spec.orbit;
      final pos = center +
          Offset(math.cos(angle) * dist, math.sin(angle) * dist * 0.82);
      final color = Color.lerp(spec.a, spec.b, i / spec.blobs) ?? spec.a;
      final paint = Paint()
        ..shader = RadialGradient(
          colors: [color.withValues(alpha: 0.85), color.withValues(alpha: 0)],
        ).createShader(Rect.fromCircle(center: pos, radius: r));
      canvas.drawCircle(pos, r, paint);
    }

    // Glowing core.
    final coreR = maxR * 0.3 * (1 + 0.08 * math.sin(t * 2 * math.pi));
    final corePaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.white,
          Color.lerp(Colors.white, spec.a, 0.55) ?? spec.a,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: coreR));
    canvas.drawCircle(center, coreR, corePaint);
  }

  @override
  bool shouldRepaint(covariant _OrbPainter old) =>
      old.t != t || old.spec != spec || old.size != size;
}
