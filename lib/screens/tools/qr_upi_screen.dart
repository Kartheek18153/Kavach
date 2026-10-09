import 'package:flutter/material.dart';

import '../../lang.dart';
import '../../services/scan_history.dart';
import '../../services/scanners.dart';
import '../../widgets/cards.dart';
import '../../widgets/scan_widgets.dart';

/// Combined QR + UPI checker: one field, auto-detects payment vs QR
/// content, runs the matching engine, and says which one it checked.
class QrUpiScreen extends StatefulWidget {
  const QrUpiScreen({super.key});

  @override
  State<QrUpiScreen> createState() => _QrUpiScreenState();
}

class _QrUpiScreenState extends State<QrUpiScreen> {
  final _ctrl = TextEditingController();
  ScanFinding? _finding;
  String _kind = 'qr';

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _analyze() {
    final r = scoreQrUpi(_ctrl.text);
    final level = levelNameFor(r.finding.risk);
    setState(() {
      _finding = r.finding;
      _kind = r.kind;
    });
    ScanHistoryStore.add(ScanRecord(
      kind: r.kind,
      input: previewOf(_ctrl.text),
      risk: r.finding.risk,
      level: level,
      reasons: r.finding.reasons,
      ts: DateTime.now().toIso8601String(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('toolQrUpi'))),
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
                  maxLines: 3,
                  minLines: 1,
                  keyboardType: TextInputType.multiline,
                  decoration: InputDecoration(
                    hintText: context.tr('qrUpiHint'),
                    prefixIcon: const Icon(Icons.qr_code_2_rounded),
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
            const SizedBox(height: 10),
            Center(
              child: Text(
                context.trP('autoKind',
                    {'kind': _kind == 'upi' ? 'UPI' : 'QR'}),
                style: const TextStyle(
                    color: Colors.black54,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(height: 4),
            ScanResultCard(finding: _finding!),
          ],
          const SizedBox(height: 14),
          ToolTipCard(context.tr(_kind == 'upi' ? 'tipUpi' : 'tipQr')),
        ],
      ),
    );
  }
}
