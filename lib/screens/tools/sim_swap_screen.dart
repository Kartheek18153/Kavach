import 'package:flutter/material.dart';

import '../../lang.dart';
import '../../services/scan_history.dart';
import '../../services/scanners.dart';
import '../../widgets/cards.dart';
import '../../widgets/scan_widgets.dart';

/// SIM-swap security check: 5 yes/no questions scored into a verdict.
class SimSwapScreen extends StatefulWidget {
  const SimSwapScreen({super.key});

  @override
  State<SimSwapScreen> createState() => _SimSwapScreenState();
}

class _SimSwapScreenState extends State<SimSwapScreen> {
  final List<bool> _answers = List.filled(5, false);
  ScanFinding? _finding;

  void _analyze() {
    final f = scoreSimSwap(_answers);
    final level = levelNameFor(f.risk);
    final yesCount = _answers.where((a) => a).length;
    setState(() => _finding = f);
    ScanHistoryStore.add(ScanRecord(
      kind: 'sim',
      input: '$yesCount/5 signs',
      risk: f.risk,
      level: level,
      reasons: f.reasons,
      ts: DateTime.now().toIso8601String(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final questions = [
      context.tr('simQ1'),
      context.tr('simQ2'),
      context.tr('simQ3'),
      context.tr('simQ4'),
      context.tr('simQ5'),
    ];
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('toolSim'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
        children: [
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(context.tr('simSub'),
                    style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 13.5,
                        height: 1.5)),
                const SizedBox(height: 6),
              ],
            ),
          ),
          const SizedBox(height: 14),
          GlassCard(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              children: [
                for (var i = 0; i < questions.length; i++)
                  TapRow(
                    title: Text(questions[i],
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600)),
                    trailing: Switch(
                      value: _answers[i],
                      onChanged: (v) => setState(() {
                        _answers[i] = v;
                        _finding = null;
                      }),
                    ),
                    onTap: () => setState(() {
                      _answers[i] = !_answers[i];
                      _finding = null;
                    }),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _analyze,
              icon: const Icon(Icons.shield_rounded),
              label: Text(context.tr('analyzeBtn')),
            ),
          ),
          if (_finding != null) ...[
            const SizedBox(height: 14),
            ScanResultCard(finding: _finding!),
          ],
          const SizedBox(height: 14),
          ToolTipCard(context.tr('tipSim')),
        ],
      ),
    );
  }
}
