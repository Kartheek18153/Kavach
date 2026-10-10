import 'package:flutter/material.dart';

import '../../lang.dart';
import '../../services/agnes.dart';
import '../../services/scan_history.dart';
import '../../services/scanners.dart';
import '../../widgets/cards.dart';
import '../../widgets/explain_widgets.dart';
import '../../widgets/scan_widgets.dart';

/// SMS & message scam analyzer: scores text plus any embedded links.
class SmsAnalyzerScreen extends StatefulWidget {
  const SmsAnalyzerScreen({super.key});

  @override
  State<SmsAnalyzerScreen> createState() => _SmsAnalyzerScreenState();
}

class _SmsAnalyzerScreenState extends State<SmsAnalyzerScreen> {
  final _ctrl = TextEditingController();
  ScanFinding? _finding;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _analyze() {
    final f = scoreSms(_ctrl.text);
    final level = levelNameFor(f.risk);
    setState(() => _finding = f);
    ScanHistoryStore.add(ScanRecord(
      kind: 'sms',
      input: previewOf(_ctrl.text),
      risk: f.risk,
      level: level,
      reasons: f.reasons,
      ts: DateTime.now().toIso8601String(),
    ));
  }

  String _langCode(BuildContext c) {
    final l = c.appLang;
    return l == AppLang.telugu ? 'te' : l == AppLang.hindi ? 'hi' : 'en';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('toolSms'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
        children: [
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(context.tr('scanSub'),
                    style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 13.5,
                        height: 1.5)),
                const SizedBox(height: 12),
                TextField(
                  controller: _ctrl,
                  maxLines: 6,
                  minLines: 3,
                  keyboardType: TextInputType.multiline,
                  decoration: InputDecoration(
                    hintText: context.tr('smsHint'),
                    prefixIcon: const Icon(Icons.sms_rounded),
                    suffixIcon: _ctrl.text.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.clear_rounded),
                            onPressed: () => setState(() {
                              _ctrl.clear();
                              _finding = null;
                            }),
                          ),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _ctrl.text.trim().isEmpty ? null : _analyze,
                    icon: const Icon(Icons.shield_rounded),
                    label: Text(context.tr('analyzeBtn')),
                  ),
                ),
              ],
            ),
          ),
          if (_finding != null) ...[
            const SizedBox(height: 14),
            ScanResultCard(finding: _finding!),
            const SizedBox(height: 10),
            AiInsightCard(
              available:
                  AgnesConfig.isConfigured && AgnesConsent.isOn,
              askLabel: context.tr('aiAskSms'),
              loadingLabel: context.tr('aiLoading'),
              failedText: context.tr('aiFailed'),
              noteText: context.tr('aiNote'),
              badgeLabel: context.tr('aiBadge'),
              onFetch: () => AgnesClient.analyzeSms(
                message: _ctrl.text,
                risk: _finding!.risk,
                band: levelNameFor(_finding!.risk),
                signals: _finding!.reasons,
                lang: _langCode(context),
              ),
            ),
          ],
          const SizedBox(height: 14),
          ToolTipCard(context.tr('tipSms')),
        ],
      ),
    );
  }
}
