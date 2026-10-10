import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../lang.dart';
import '../theme.dart';
import 'cards.dart';

/// Semicircular danger gauge: 0-30 green, 31-60 amber, 61-100 red.
class DangerMeter extends StatelessWidget {
  final int risk;
  final RiskLevel level;
  final double size;

  const DangerMeter({
    super.key,
    required this.risk,
    required this.level,
    this.size = 240,
  });

  @override
  Widget build(BuildContext context) {
    final color = CyberSafeColors.forLevel(level);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: size,
          height: size * 0.62,
          child: CustomPaint(
            painter: _GaugePainter(
              progress: (risk.clamp(0, 100)) / 100,
              color: color,
            ),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: risk.toDouble()),
                      duration: const Duration(milliseconds: 500),
                      builder: (context, value, _) => Text(
                        value.round().toString(),
                        style: TextStyle(
                          fontSize: 52,
                          fontWeight: FontWeight.w900,
                          height: 1,
                          color: color,
                        ),
                      ),
                    ),
                    const Text(
                      '/ 100 RISK',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2,
                        color: CyberSafeColors.sub,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        StatusChip(level, text: riskLabel(level, context.appLang)),
      ],
    );
  }
}

class _GaugePainter extends CustomPainter {
  final double progress;
  final Color color;

  _GaugePainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height - 6);
    final radius = size.width / 2 - 16;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Track with three faint zone segments.
    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 16
      ..strokeCap = StrokeCap.round;
    const zones = [0.0, 0.3, 0.6, 1.0];
    const zoneColors = [
      CyberSafeColors.safe,
      CyberSafeColors.caution,
      CyberSafeColors.danger
    ];
    for (var i = 0; i < 3; i++) {
      trackPaint.color = zoneColors[i].withValues(alpha: 0.18);
      canvas.drawArc(
        rect,
        math.pi + math.pi * zones[i] + 0.03,
        math.pi * (zones[i + 1] - zones[i]) - 0.06,
        false,
        trackPaint,
      );
    }

    // Progress arc.
    if (progress > 0.005) {
      final main = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 16
        ..strokeCap = StrokeCap.round
        ..color = color;
      canvas.drawArc(rect, math.pi, math.pi * progress, false, main);
    }

    // Needle.
    final angle = math.pi + math.pi * progress.clamp(0.0, 1.0);
    final needleEnd = center +
        Offset(math.cos(angle), math.sin(angle)) * (radius - 26);
    canvas.drawLine(
      center,
      needleEnd,
      Paint()
        ..color = CyberSafeColors.ink.withValues(alpha: 0.85)
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(center, 7, Paint()..color = CyberSafeColors.surface);
    canvas.drawCircle(center, 7, Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 3);
  }

  @override
  bool shouldRepaint(covariant _GaugePainter old) =>
      old.progress != progress || old.color != color;
}
