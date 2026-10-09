import 'package:flutter/material.dart';

import '../lang.dart';
import '../services/api.dart';
import '../services/scan_history.dart';
import '../theme.dart';
import '../widgets/cards.dart';

/// History tab: unified timeline of call scans + tool scans, newest first.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  int _filter = 0; // 0 all, 1 calls, 2 scans

  RiskLevel _levelFrom(String v) {
    if (v == 'danger') return RiskLevel.danger;
    if (v == 'caution') return RiskLevel.caution;
    return RiskLevel.safe;
  }

  String _kindLabel(String kind) {
    switch (kind) {
      case 'url':
        return context.tr('toolUrl');
      case 'qr':
      case 'upi':
        return context.tr('toolQrUpi');
      case 'sim':
        return context.tr('toolSim');
      case 'sms':
        return context.tr('toolSms');
      default:
        return kind;
    }
  }

  String _dateOf(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return '';
    return '${d.day}/${d.month}/${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final showCalls = _filter != 2;
    final showScans = _filter != 0;
    final calls = showCalls ? HistoryStore.entries : const [];
    final scans = showScans ? ScanHistoryStore.entries : const [];
    final empty = calls.isEmpty && scans.isEmpty;

    return Scaffold(
      body: SafeArea(
        child: empty
            ? _empty(context)
            : ListView(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
                children: [
                  _header(context),
                  const SizedBox(height: 12),
                  _filters(context),
                  const SizedBox(height: 12),
                  if (showScans)
                    for (final s in scans) _scanTile(context, s),
                  if (showCalls)
                    for (final e in calls) _callTile(context, e),
                  if (showScans && scans.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () async {
                        await ScanHistoryStore.clear();
                        setState(() {});
                      },
                      icon: const Icon(Icons.delete_outline_rounded),
                      label: Text(context.tr('clearScansBtn')),
                    ),
                  ],
                ],
              ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        Expanded(
          child: Text(
            context.tr('historyTitle'),
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
        ),
        const LangButton(),
      ],
    );
  }

  Widget _filters(BuildContext context) {
    final labels = [
      context.tr('filterAll'),
      context.tr('filterCalls'),
      context.tr('filterScans'),
    ];
    return Row(
      children: [
        for (var i = 0; i < labels.length; i++)
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: i < 2 ? 8 : 0),
              child: ChoiceChip(
                label: SizedBox(
                  height: 22,
                  child: Center(child: Text(labels[i])),
                ),
                selected: _filter == i,
                selectedColor: KavachColors.washTeal,
                onSelected: (_) => setState(() => _filter = i),
              ),
            ),
          ),
      ],
    );
  }

  Widget _scanTile(BuildContext context, ScanRecord s) {
    final level = _levelFrom(s.level);
    final c = KavachColors.forLevel(level);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        borderColor: c.withValues(alpha: 0.4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: KavachColors.tintForLevel(level),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text('${s.risk}',
                  style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 17,
                      color: c)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_kindLabel(s.kind),
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 14)),
                  Text(s.input,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: KavachColors.sub, fontSize: 12.5)),
                  Text(_dateOf(s.ts),
                      style: const TextStyle(
                          color: KavachColors.sub, fontSize: 11.5)),
                ],
              ),
            ),
            StatusChip(level),
          ],
        ),
      ),
    );
  }

  Widget _callTile(BuildContext context, Map<String, dynamic> e) {
    final level = _levelFrom('${e['level'] ?? 'safe'}');
    final c = KavachColors.forLevel(level);
    final risk = (e['risk'] as num? ?? 0).toInt();
    final demo = e['demo'] == true;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        borderColor: c.withValues(alpha: 0.4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: KavachColors.tintForLevel(level),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text('$risk',
                  style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 17,
                      color: c)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${e['scamType'] ?? '-'}',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 14)),
                  Text(
                      demo
                          ? context.tr('originDemo')
                          : context.tr('originLive'),
                      style: const TextStyle(
                          color: KavachColors.sub, fontSize: 12.5)),
                  Text(_dateOf('${e['ts'] ?? ''}'),
                      style: const TextStyle(
                          color: KavachColors.sub, fontSize: 11.5)),
                ],
              ),
            ),
            StatusChip(level),
          ],
        ),
      ),
    );
  }

  Widget _empty(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
        children: [
          _header(context),
          const SizedBox(height: 12),
          GlassCard(
            child: Column(
              children: [
                const Icon(Icons.history_rounded,
                    size: 48, color: KavachColors.sky),
                const SizedBox(height: 12),
                Text(context.tr('emptyHistory'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: KavachColors.sub, fontSize: 14, height: 1.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
