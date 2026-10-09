import 'package:flutter/material.dart';

import '../lang.dart';
import '../services/api.dart';
import '../services/scan_history.dart';
import '../theme.dart';
import '../widgets/cards.dart';

/// Threats tab: unified threat report (calls + scans) plus a static
/// threat-intelligence feed of current fraud alerts.
class ThreatsScreen extends StatelessWidget {
  const ThreatsScreen({super.key});

  int get _callScans => HistoryStore.entries.length;
  int get _callDangers => HistoryStore.entries
      .where((e) => e['level'] == 'danger')
      .length;

  String _topThreat() {
    final counts = <String, int>{};
    for (final e in HistoryStore.entries) {
      final t = '${e['scamType'] ?? '-'}';
      counts[t] = (counts[t] ?? 0) + 1;
    }
    for (final s in ScanHistoryStore.entries) {
      counts[s.kind] = (counts[s.kind] ?? 0) + 1;
    }
    if (counts.isEmpty) return '-';
    return counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }

  @override
  Widget build(BuildContext context) {
    final total =
        _callScans + ScanHistoryStore.entries.length + HistoryStore.monthDangers + ScanHistoryStore.monthDangers;
    final dangers = _callDangers +
        ScanHistoryStore.entries.where((e) => e.level == 'danger').length;
    var absoluteWorst = 0;
    for (final e in HistoryStore.entries) {
      final r = (e['risk'] as num? ?? 0).toInt();
      if (r > absoluteWorst) absoluteWorst = r;
    }
    for (final s in ScanHistoryStore.entries) {
      if (s.risk > absoluteWorst) absoluteWorst = s.risk;
    }

    final advisories = [
      ('adv1t', 'adv1b', RiskLevel.danger),
      ('adv2t', 'adv2b', RiskLevel.danger),
      ('adv3t', 'adv3b', RiskLevel.caution),
      ('adv4t', 'adv4b', RiskLevel.caution),
      ('adv5t', 'adv5b', RiskLevel.danger),
    ];

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
                Expanded(
                  child: Text(
                    context.tr('threatsTitle'),
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                ),
                const LangButton(),
              ],
            ),
            const SizedBox(height: 12),
            SectionTitle(context.tr('unifiedTitle')),
            GlassCard(
              borderColor:
                  (dangers > 0 ? KavachColors.danger : KavachColors.safe)
                      .withValues(alpha: 0.5),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                          child: _stat('$total',
                              context.tr('totalScansM'), KavachColors.teal)),
                      const SizedBox(width: 10),
                      Expanded(
                          child: _stat(
                              '$dangers',
                              context.tr('dangersCaught'),
                              dangers > 0
                                  ? KavachColors.danger
                                  : KavachColors.safe)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                          child: _stat(
                              absoluteWorst == 0
                                  ? context.tr('noneYet')
                                  : '$absoluteWorst/100',
                              context.tr('worstMonth'),
                              KavachColors.teal)),
                      const SizedBox(width: 10),
                      Expanded(
                          child: _stat(_topThreat(),
                              context.tr('topThreat'), KavachColors.caution)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            SectionTitle(context.tr('intelTitle')),
            for (final a in advisories) _advisory(context, a),
          ],
        ),
      ),
    );
  }

  Widget _stat(String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: KavachColors.surface2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: KavachColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value,
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: color)),
          Text(label,
              style: const TextStyle(
                  color: KavachColors.sub,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _advisory(
      BuildContext context, (String, String, RiskLevel) a) {
    final c = KavachColors.forLevel(a.$3);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        borderColor: c.withValues(alpha: 0.45),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: KavachColors.tintForLevel(a.$3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.warning_rounded, color: c, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(context.tr(a.$1),
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 15)),
                  const SizedBox(height: 4),
                  Text(context.tr(a.$2),
                      style: const TextStyle(
                          color: KavachColors.sub,
                          fontSize: 13.5,
                          height: 1.5)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
