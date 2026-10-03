import 'package:flutter/material.dart';

import '../lang.dart';
import '../theme.dart';

/// Frosted-glass style card used across all screens.
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? borderColor;
  final VoidCallback? onTap;

  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.borderColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: KavachColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: borderColor ?? KavachColors.line,
        ),
        boxShadow: const [
          // Tight key shadow — grounds the card.
          BoxShadow(
            color: Color(0x260D47A1),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
          // Soft ambient lift — the 3D float.
          BoxShadow(
            color: Color(0x1F0D47A1),
            blurRadius: 24,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: child,
    );
    if (onTap == null) return card;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: card,
    );
  }
}

/// Small caps section heading.
class SectionTitle extends StatelessWidget {
  final String text;
  const SectionTitle(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8, top: 4),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.4,
          color: KavachColors.sub,
        ),
      ),
    );
  }
}

/// Colored status pill bound to a [RiskLevel].
class StatusChip extends StatelessWidget {
  final RiskLevel level;
  final String? text;
  const StatusChip(this.level, {super.key, this.text});

  @override
  Widget build(BuildContext context) {
    final c = KavachColors.forLevel(level);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: KavachColors.tintForLevel(level),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.withValues(alpha: 0.55)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1F0D47A1),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: c, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            text ?? riskLabel(level, context.appLang),
            style: TextStyle(
              color: c,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
