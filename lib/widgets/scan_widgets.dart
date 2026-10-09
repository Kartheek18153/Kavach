import 'package:flutter/material.dart';

import '../lang.dart';
import '../services/scanners.dart';
import '../theme.dart';
import 'cards.dart';
import 'danger_meter.dart';

RiskLevel _levelForFinding(ScanFinding f) => riskLevelFor(f.risk);

/// Shared verdict block: gauge + reasons + saved note.
class ScanResultCard extends StatelessWidget {
  final ScanFinding finding;

  const ScanResultCard({super.key, required this.finding});

  @override
  Widget build(BuildContext context) {
    final level = _levelForFinding(finding);
    return GlassCard(
      borderColor: KavachColors.forLevel(level).withValues(alpha: 0.5),
      child: Column(
        children: [
          DangerMeter(risk: finding.risk, level: level, size: 200),
          const SizedBox(height: 14),
          ReasonList(reasons: finding.reasons, level: level),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle_rounded,
                  size: 14, color: KavachColors.safe),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  context.tr('savedNote'),
                  style: const TextStyle(
                      color: KavachColors.sub, fontSize: 12.5),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Bullet list of reasons tinted by level.
class ReasonList extends StatelessWidget {
  final List<String> reasons;
  final RiskLevel level;

  const ReasonList({super.key, required this.reasons, required this.level});

  @override
  Widget build(BuildContext context) {
    final c = KavachColors.forLevel(level);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.tr('verdictTitle'),
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
        ),
        const SizedBox(height: 8),
        for (final r in reasons)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  level == RiskLevel.safe
                      ? Icons.check_circle_rounded
                      : Icons.warning_rounded,
                  size: 18,
                  color: c,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(r,
                      style: const TextStyle(
                          fontSize: 14, height: 1.45)),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Small tip strip used at the bottom of every tool screen.
class ToolTipCard extends StatelessWidget {
  final String text;

  const ToolTipCard(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: KavachColors.washTeal,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: KavachColors.teal.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lightbulb_rounded, color: KavachColors.teal),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text,
                style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13.5,
                    height: 1.5)),
          ),
        ],
      ),
    );
  }
}

/// Truncates long inputs for history previews.
String previewOf(String s, [int max = 80]) {
  final t = s.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (t.length <= max) return t;
  return '${t.substring(0, max)}…';
}

/// Tappable row safe to place inside [GlassCard]: Material sits above the
/// card background so ink splashes stay visible (plain ListTile asserts).
class TapRow extends StatelessWidget {
  final Widget? leading;
  final Widget title;
  final Widget? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const TapRow({
    super.key,
    this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          child: Row(
            children: [
              if (leading case final l?) ...[
                l,
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    title,
                    if (subtitle case final Widget s) s,
                  ],
                ),
              ),
              if (trailing case final t?) ...[
                const SizedBox(width: 8),
                t,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
