import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../lang.dart';
import '../theme.dart';
import '../widgets/cards.dart';

/// After-call report: verdict, 1930 helper, checklist, learning card.
class ReportScreen extends StatelessWidget {
  final Map<String, dynamic>? summary;
  final VoidCallback onNewScan;

  const ReportScreen({super.key, this.summary, required this.onNewScan});

  @override
  Widget build(BuildContext context) {
    final s = summary;
    return Scaffold(
      body: SafeArea(
        child: s == null
            ? _empty(context)
            : ListView(
                padding:
                    const EdgeInsets.fromLTRB(18, 6, 18, 110),
                children: [
                  Row(
                    children: [
                      Text(
                        context.tr('reportTitle'),
                        style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800),
                      ),
                      const Spacer(),
                      const LangButton(),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _verdictHeader(context, s),
                const SizedBox(height: 14),
                SectionTitle(context.tr('reportHelp')),
                _reportHelper(context, s),
                const SizedBox(height: 14),
                SectionTitle(context.tr('checklist')),
                _checklist(context),
                const SizedBox(height: 14),
                SectionTitle(context.tr('learnTitle')),
                _learningCard(context, s),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: onNewScan,
                    icon: const Icon(Icons.shield_rounded),
                    label: Text(context.tr('startScan')),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.lock_rounded,
                        size: 14, color: KavachColors.sub),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        context.tr('privacyReport'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: KavachColors.sub, fontSize: 12.5),
                      ),
                    ),
                  ],
                ),
              ],
            ),
      ),
    );
  }

  Widget _empty(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          context.tr('reportEmpty'),
          textAlign: TextAlign.center,
          style: const TextStyle(
              color: KavachColors.sub, fontSize: 15, height: 1.7),
        ),
      ),
    );
  }

  Widget _verdictHeader(BuildContext context, Map<String, dynamic> s) {
    final level = s['level'] as RiskLevel;
    final color = KavachColors.forLevel(level);
    final alerted = s['alerted'] == true
        ? context.tr('alertedYes')
        : context.tr('alertedNo');
    return GlassCard(
      borderColor: color.withValues(alpha: 0.5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              StatusChip(level),
              const Spacer(),
              Text('${context.tr('riskWord')} ${s['risk']}',
                  style: TextStyle(
                      color: color,
                      fontSize: 20,
                      fontWeight: FontWeight.w900)),
            ],
          ),
          const SizedBox(height: 12),
          Text('${s['scamType']}',
              style:
                  const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
          if ((s['reasonsTelugu'] as String).isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('${s['reasonsTelugu']}',
                style: const TextStyle(
                    color: KavachColors.sub, fontSize: 14, height: 1.5)),
          ],
          const SizedBox(height: 8),
          Text(
            '${context.tr('durationWord')} ${s['elapsedSec']}s | ${s['lines']} ${context.tr('linesWord')} | ${context.tr('familyWord')} $alerted',
            style: const TextStyle(
                color: KavachColors.sub,
                fontSize: 12.5,
                fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _reportHelper(BuildContext context, Map<String, dynamic> s) {
    final text =
        'Kavach report - ${DateTime.now().toLocal().toString().substring(0, 16)}\nType: ${s['scamType']}\nRisk: ${s['risk']}/100\nReasons: ${(s['reasons'] as List).join('; ')}';
    return GlassCard(
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Clipboard.setData(
                        const ClipboardData(text: '1930'));
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content:
                                Text(context.tr('copied1930'))));
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        KavachColors.danger.withValues(alpha: 0.9),
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.call_rounded),
                  label: Text(context.tr('call1930')),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Clipboard.setData(const ClipboardData(
                        text: 'https://cybercrime.gov.in'));
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content:
                                Text(context.tr('portalCopied'))));
                  },
                  icon: const Icon(Icons.open_in_new_rounded),
                  label: Text(context.tr('cyberPortal')),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: KavachColors.surface2,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: KavachColors.line),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x1F0D47A1),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Text(text,
                style: const TextStyle(fontSize: 13, height: 1.6)),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: text));
                ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(context.tr('summaryCopied'))));
              },
              icon: const Icon(Icons.copy_rounded),
              label: Text(context.tr('copySummary')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _checklist(BuildContext context) {
    final items = [
      context.tr('check1'),
      context.tr('check2'),
      context.tr('check3'),
      context.tr('check4'),
    ];
    return GlassCard(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        children: items
            .map(
              (t) => ListTile(
                dense: true,
                leading: const Icon(Icons.check_circle_rounded,
                    color: KavachColors.safe),
                title: Text(t,
                    style: const TextStyle(
                        fontSize: 14.5, fontWeight: FontWeight.w600)),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _learningCard(BuildContext context, Map<String, dynamic> s) {
    return GlassCard(
      borderColor: KavachColors.violet.withValues(alpha: 0.45),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.school_rounded,
                  color: KavachColors.violet),
              const SizedBox(width: 8),
              Expanded(
                child: Text(context.tr('learnTitle'),
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 15)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            context.tr('learnBody'),
            style: const TextStyle(
                color: KavachColors.sub, fontSize: 14, height: 1.6),
          ),
          const SizedBox(height: 8),
          Text(
            context.trP('learnNote', {
              'r': (s['reasons'] as List).isNotEmpty
                  ? s['reasons'].first as String
                  : 'authority + OTP = scam'
            }),
            style: const TextStyle(
                fontSize: 14, fontWeight: FontWeight.w700, height: 1.5),
          ),
        ],
      ),
    );
  }
}
