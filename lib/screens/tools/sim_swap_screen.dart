import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../lang.dart';
import '../../services/api.dart';
import '../../services/scan_history.dart';
import '../../services/scanners.dart';
import '../../services/sim_swap_api.dart';
import '../../theme.dart';
import '../../widgets/cards.dart';
import '../../widgets/scan_widgets.dart';

/// SIM-swap security check, two layers:
/// 1. Telco network check (CAMARA SimSwap via our backend) — the strongest
///    signal: asks the operator if this SIM changed recently.
/// 2. The offline 5-question checklist (works with no network).
class SimSwapScreen extends StatefulWidget {
  const SimSwapScreen({super.key});

  @override
  State<SimSwapScreen> createState() => _SimSwapScreenState();
}

class _SimSwapScreenState extends State<SimSwapScreen> {
  final List<bool> _answers = List.filled(5, false);
  ScanFinding? _finding;

  late final TextEditingController _phone;
  int _lookback = 72;
  bool _telcoBusy = false;
  TelcoSimSwapResult? _telco;
  String? _telcoMsg;

  /// Last number the user actually typed (survives tab re-opens).
  /// The saved guardian number is only a first-run default.
  static String? _lastTyped;
  static const _kLastPhone = 'kavach_telco_last_phone';

  @override
  void initState() {
    super.initState();
    final saved = GuardianStore.phone.trim();
    final fallback = GuardianStore.isValidPhone(saved)
        ? '+91${GuardianStore.normalizePhone(saved)}'
        : '';
    _phone = TextEditingController(text: _lastTyped ?? fallback);
    if (_lastTyped == null && fallback.isNotEmpty) {
      // Load a previously typed number from disk (fresh app start).
      SharedPreferences.getInstance().then((prefs) {
        final stored = prefs.getString(_kLastPhone);
        if (stored != null && stored.isNotEmpty && mounted) {
          _lastTyped = stored;
          _phone.text = stored;
        }
      });
    }
  }

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  String _digits() => _phone.text.trim();

  Future<void> _runTelco(
      Future<TelcoSimSwapResult?> Function() call) async {
    final phone = _digits();
    if (!isValidE164Phone(phone)) {
      setState(() {
        _telco = null;
        _telcoMsg = context.tr('telcoInvalid');
      });
      return;
    }
    setState(() {
      _telcoBusy = true;
      _telcoMsg = null;
    });
    // Remember what the user typed so the field doesn't snap back to the
    // saved guardian number on the next visit.
    _lastTyped = phone;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kLastPhone, phone);
    } catch (_) {
      // Disk persistence is best-effort; in-memory value still applies.
    }
    TelcoSimSwapResult? out;
    try {
      out = await call();
    } catch (_) {
      out = null;
    }
    if (!mounted) return;
    setState(() {
      _telcoBusy = false;
      _telco = out;
      _telcoMsg = null;
      if (out == null) {
        _telcoMsg = context.tr('telcoUnavailable');
        return;
      }
      if (out.status != 'completed') return; // warning card, no gauge/history
      final f = telcoSimSwapFinding(out);
      ScanHistoryStore.add(ScanRecord(
        kind: 'sim',
        input: '${out.maskedPhone} telco',
        risk: f.risk,
        level: levelNameFor(f.risk),
        reasons: f.reasons,
        ts: DateTime.now().toIso8601String(),
      ));
    });
  }

  Future<void> _checkTelco() => _runTelco(() => SimSwapApi.check(
        phoneNumber: _digits(),
        lookbackHours: _lookback,
      ));

  Future<void> _lastChange() =>
      _runTelco(() => SimSwapApi.retrieveDate(phoneNumber: _digits()));

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
          _telcoCard(),
          if (_telcoBusy) ...[
            const SizedBox(height: 14),
            GlassCard(
              child: Row(
                children: [
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child:
                        CircularProgressIndicator(strokeWidth: 2.5),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Text('${context.tr('telcoCheck')}…')),
                ],
              ),
            ),
          ],
          if (_telcoMsg != null) ...[
            const SizedBox(height: 14),
            GlassCard(
              borderColor:
                  CyberSafeColors.caution.withValues(alpha: 0.5),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.cloud_off_rounded,
                      color: CyberSafeColors.caution),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(_telcoMsg!,
                        style: const TextStyle(
                            fontSize: 14, height: 1.5)),
                  ),
                ],
              ),
            ),
          ],
          if (_telco != null && _telco!.status == 'completed') ...[
            const SizedBox(height: 14),
            ScanResultCard(finding: telcoSimSwapFinding(_telco!)),
            const SizedBox(height: 8),
            Center(
              child: Text(
                '${_telco!.provider} • ${_telco!.lookbackHours ?? _lookback}h • ${_telco!.maskedPhone}',
                style: const TextStyle(
                    color: CyberSafeColors.sub, fontSize: 12.5),
              ),
            ),
          ],
          if (_telco != null && _telco!.status != 'completed') ...[
            const SizedBox(height: 14),
            GlassCard(
              borderColor:
                  CyberSafeColors.caution.withValues(alpha: 0.5),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline_rounded,
                      color: CyberSafeColors.caution),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _telco!.detail.isNotEmpty
                          ? _telco!.detail
                          : context.tr('telcoUnavailable'),
                      style: const TextStyle(
                          fontSize: 14, height: 1.5),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
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

  Widget _telcoCard() {
    return GlassCard(
      borderColor: CyberSafeColors.teal.withValues(alpha: 0.4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.cell_tower_rounded,
                  color: CyberSafeColors.teal),
              const SizedBox(width: 8),
              Expanded(
                child: Text(context.tr('telcoTitle'),
                    style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(context.tr('telcoSub'),
              style: const TextStyle(
                  color: CyberSafeColors.sub,
                  fontSize: 13.5,
                  height: 1.5)),
          const SizedBox(height: 12),
          TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _checkTelco(),
            decoration: InputDecoration(
              hintText: context.tr('telcoPhoneHint'),
              prefixIcon: const Icon(Icons.phone_rounded),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              for (final h in [24, 72, 720])
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text('${h}h'),
                    selected: _lookback == h,
                    selectedColor: CyberSafeColors.washTeal,
                    onSelected: (_) =>
                        setState(() => _lookback = h),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _telcoBusy ? null : _checkTelco,
                  icon: const Icon(Icons.cell_tower_rounded),
                  label: Text(context.tr('telcoCheck')),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _telcoBusy ? null : _lastChange,
                  icon: const Icon(Icons.history_rounded),
                  label: Text(context.tr('telcoLastChange')),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
