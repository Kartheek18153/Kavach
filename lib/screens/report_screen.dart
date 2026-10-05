import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../lang.dart';
import '../services/api.dart';
import '../theme.dart';
import '../widgets/cards.dart';

/// After-call report: verdict, 1930 helper, checklist, per-scam learning,
/// share, and browsable past scans.
class ReportScreen extends StatefulWidget {
  final Map<String, dynamic>? summary;
  final VoidCallback onNewScan;

  const ReportScreen({super.key, this.summary, required this.onNewScan});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  Map<String, dynamic>? _viewing;

  @override
  void didUpdateWidget(covariant ReportScreen old) {
    super.didUpdateWidget(old);
    if (!identical(widget.summary, old.summary)) _viewing = null;
  }

  Map<String, dynamic>? get _shown => _viewing ?? widget.summary;

  RiskLevel _levelFrom(Object? v) {
    if (v == 'danger') return RiskLevel.danger;
    if (v == 'caution') return RiskLevel.caution;
    return RiskLevel.safe;
  }

  Map<String, dynamic> _restore(Map<String, dynamic> e) {
    return {
      'risk': e['risk'] ?? 0,
      'level': e['level'] is RiskLevel ? e['level'] : _levelFrom(e['level']),
      'scamType': e['scamType'] ?? '-',
      'reasons': List.from(e['reasons'] ?? const []),
      'reasonsTelugu': e['reasonsTelugu'] ?? '',
      'alerted': e['alerted'] ?? false,
      'elapsedSec': e['elapsedSec'] ?? 0,
      'lines': e['lines'] ?? 0,
      'isDemo': e['demo'] ?? e['isDemo'] ?? false,
      'smsSent': e['smsSent'] ?? false,
    };
  }

  @override
  Widget build(BuildContext context) {
    final s = _shown;
    final history = HistoryStore.entries;
    return Scaffold(
      body: SafeArea(
        child: s == null && history.isEmpty
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
                      if (_viewing != null)
                        TextButton(
                          onPressed: () => setState(() => _viewing = null),
                          child: Text(context.tr('viewLatest')),
                        ),
                      const LangButton(),
                    ],
                  ),
                  if (s != null) ...[
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
                        onPressed: widget.onNewScan,
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
                  if (history.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    SectionTitle(context.tr('pastScans')),
                    _historyCard(history),
                  ],
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
    final origin = s['isDemo'] == true
        ? context.tr('originDemo')
        : context.tr('originLive');
    final sms = s['smsSent'] == true
        ? context.tr('smsYes')
        : context.tr('smsNo');
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
          const SizedBox(height: 4),
          Text(
            '$origin | SMS $sms',
            style: const TextStyle(
                color: KavachColors.sub,
                fontSize: 12.5,
                fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Future<void> _dial1930(BuildContext context) async {
    final uri = Uri(scheme: 'tel', path: '1930');
    try {
      if (await launchUrl(uri)) return;
    } catch (_) {
      // Fall through to clipboard fallback.
    }
    if (!context.mounted) return;
    await Clipboard.setData(const ClipboardData(text: '1930'));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('copied1930'))));
  }

  Future<void> _openPortal(BuildContext context) async {
    final uri = Uri.parse('https://cybercrime.gov.in');
    try {
      if (await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        return;
      }
    } catch (_) {
      // Fall through to clipboard fallback.
    }
    if (!context.mounted) return;
    await Clipboard.setData(
        const ClipboardData(text: 'https://cybercrime.gov.in'));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('portalCopied'))));
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
                  onPressed: () => _dial1930(context),
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
                  onPressed: () => _openPortal(context),
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
          Row(
            children: [
              Expanded(
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
              Expanded(
                child: TextButton.icon(
                  onPressed: () =>
                      SharePlus.instance.share(ShareParams(text: text)),
                  icon: const Icon(Icons.share_rounded),
                  label: Text(context.tr('shareReport')),
                ),
              ),
            ],
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

  String _learnKey(String scamType) {
    final t = scamType.toLowerCase();
    if (t.contains('screen')) return 'learnScreen';
    if (t.contains('otp') || t.contains('bank')) return 'learnOtp';
    if (t.contains('police') || t.contains('arrest') || t.contains('cbi')) {
      return 'learnBody';
    }
    return 'learnGeneric';
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
            context.tr(_learnKey('${s['scamType']}')),
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

  Widget _historyCard(List<Map<String, dynamic>> history) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        children: [
          for (var i = 0; i < history.length; i++)
            _historyRow(history[i], i == 0),
        ],
      ),
    );
  }

  Widget _historyRow(Map<String, dynamic> e, bool latest) {
    final level = _levelFrom(e['level']);
    final color = KavachColors.forLevel(level);
    final ts = '${e['ts'] ?? ''}';
    final when = ts.length >= 16 ? ts.substring(0, 16) : ts;
    return ListTile(
      dense: true,
      onTap: () => setState(() => _viewing = _restore(e)),
      leading: Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      title: Text('${e['scamType'] ?? '-'}${latest ? ' •' : ''}',
          style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600)),
      subtitle: Text(
        '$when • ${e['risk'] ?? 0}/100${e['demo'] == true ? ' • demo' : ''}',
        style: const TextStyle(color: KavachColors.sub, fontSize: 12.5),
      ),
      trailing: const Icon(Icons.chevron_right_rounded),
    );
  }
}
