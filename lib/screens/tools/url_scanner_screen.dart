import 'dart:async';

import 'package:flutter/material.dart';

import '../../lang.dart';
import '../../services/link_reputation.dart';
import '../../services/scan_history.dart';
import '../../services/scanners.dart';
import '../../theme.dart';
import '../../widgets/cards.dart';
import '../../widgets/danger_meter.dart';
import '../../widgets/scan_widgets.dart';

/// Phishing & URL scanner: offline heuristics instantly, then a live
/// domain-reputation lookup (WHOIS age, blacklists, health grade) merged in.
/// Reputation is fail-soft and labelled — offline means heuristics only.
class UrlScannerScreen extends StatefulWidget {
  const UrlScannerScreen({super.key});

  @override
  State<UrlScannerScreen> createState() => _UrlScannerScreenState();
}

class _UrlScannerScreenState extends State<UrlScannerScreen> {
  final _ctrl = TextEditingController();
  ScanFinding? _offline;
  ReputationResult? _rep;
  bool _checkingRep = false;
  int _repDone = 0;
  int _repTotal = 0;
  StreamSubscription<RepProgress>? _repSub;
  int _runId = 0;
  static const _maxAutoRetries = 4;
  static const _retryGap = Duration(seconds: 4);

  @override
  void dispose() {
    _repSub?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  String? _hostOf(String raw) {
    var text = raw.trim();
    if (!RegExp(r'^[a-zA-Z][a-zA-Z0-9+.-]*://').hasMatch(text)) {
      text = 'https://$text';
    }
    try {
      final host = Uri.parse(text).host.toLowerCase();
      if (host.isEmpty || !host.contains('.')) return null;
      if (RegExp(r'^\d{1,3}(\.\d{1,3}){3}$').hasMatch(host)) return null;
      return host;
    } catch (_) {
      return null;
    }
  }

  void _analyze() {
    final f = scoreUrl(_ctrl.text);
    final host = _hostOf(_ctrl.text);
    final run = ++_runId;
    setState(() {
      _offline = f;
      _rep = null;
      _checkingRep = host != null;
    });
    final level = levelNameFor(f.risk);
    ScanHistoryStore.add(ScanRecord(
      kind: 'url',
      input: previewOf(_ctrl.text),
      risk: f.risk,
      level: level,
      reasons: f.reasons,
      ts: DateTime.now().toIso8601String(),
    ));
    if (host == null) return;
    _fetchRep(host, run, logHistory: true);
  }

  void _retryRep() {
    final host = _hostOf(_ctrl.text);
    if (host == null || _offline == null) return;
    _repSub?.cancel();
    setState(() {
      _checkingRep = true;
    });
    _fetchRep(host, _runId,
        logHistory: false,
        base: _baseOffline(),
        forceRefresh: true,
        attempts: 0);
  }

  /// Offline baseline without reputation findings (for clean retries).
  ScanFinding _baseOffline() => scoreUrl(_ctrl.text);

  void _fetchRep(String host, int run,
      {required bool logHistory,
      ScanFinding? base,
      bool forceRefresh = false,
      int attempts = 0}) {
    _repSub?.cancel();
    _repSub = watchReputation(host, forceRefresh: forceRefresh).listen((p) {
      if (!mounted || run != _runId) return;
      final offline = base ?? _offline;
      if (offline == null) return;
      final merged = _merged(offline, p.result);
      final willRetry = p.finished &&
          p.result.facts.sectionsFailed.isNotEmpty &&
          attempts < _maxAutoRetries;
      setState(() {
        _rep = p.result;
        _repDone = p.done;
        _repTotal = p.total;
        _checkingRep = !p.finished || willRetry;
        _offline = merged;
      });
      if (p.finished && logHistory) {
        final mlevel = levelNameFor(merged.risk);
        ScanHistoryStore.add(ScanRecord(
          kind: 'url',
          input: '${previewOf(_ctrl.text)} +reputation',
          risk: merged.risk,
          level: mlevel,
          reasons: merged.reasons,
          ts: DateTime.now().toIso8601String(),
        ));
      }
      if (!willRetry) return;
      // Automatic retry after a gap: missing sections re-fire in the
      // background while the partial report stays on screen.
      Future.delayed(_retryGap).then((_) {
        if (!mounted || run != _runId) return;
        _fetchRep(host, run,
            logHistory: false,
            base: base ?? _baseOffline(),
            forceRefresh: true,
            attempts: attempts + 1);
      });
    });
  }

  ScanFinding _merged(ScanFinding offline, ReputationResult rep) {
    if (rep.findings.isEmpty) return offline;
    final risk = (offline.risk +
            rep.findings.fold<int>(0, (a, f) => a + f.points))
        .clamp(0, 100);
    final reasons = [
      ...offline.reasons.where((r) => !r.startsWith('No phishing signs')),
      ...rep.findings.map((f) => '[+${f.points}] ${f.label}'),
    ];
    return ScanFinding(risk, reasons);
  }

  @override
  Widget build(BuildContext context) {
    final finding = _offline;
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('toolUrl'))),
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
                  keyboardType: TextInputType.url,
                  decoration: InputDecoration(
                    hintText: context.tr('urlHint'),
                    prefixIcon: const Icon(Icons.link_rounded),
                    suffixIcon: _ctrl.text.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.clear_rounded),
                            onPressed: () {
                              _runId++;
                              setState(() {
                                _ctrl.clear();
                                _offline = null;
                                _rep = null;
                                _checkingRep = false;
                              });
                            },
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
          if (finding != null) ...[
            const SizedBox(height: 14),
            _resultCard(context, finding),
          ],
          const SizedBox(height: 14),
          ToolTipCard(context.tr('tipUrl')),
          const SizedBox(height: 10),
          ToolTipCard(context.tr('repPrivacy')),
        ],
      ),
    );
  }

  Widget _resultCard(BuildContext context, ScanFinding finding) {
    final level = riskLevelFor(finding.risk);
    final rep = _rep;
    return GlassCard(
      borderColor: KavachColors.forLevel(level).withValues(alpha: 0.5),
      child: Column(
        children: [
          DangerMeter(risk: finding.risk, level: level, size: 200),
          const SizedBox(height: 14),
          ReasonList(reasons: finding.reasons, level: level),
          const SizedBox(height: 10),
          _repStatus(context, rep),
          if (rep != null && rep.facts.online) ...[
            const SizedBox(height: 8),
            _facts(context, rep.facts),
          ],
          if (rep != null &&
              !_checkingRep &&
              rep.facts.sectionsFailed.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    context.trP('repPartial',
                        {'n': '${rep.facts.sectionsFailed.length}'}),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: KavachColors.caution, fontSize: 12.5),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: _checkingRep ? null : _retryRep,
                  child: Text(context.tr('repRetry')),
                ),
              ],
            ),
          ],
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

  Widget _repStatus(BuildContext context, ReputationResult? rep) {
    if (_checkingRep) {
      final label = _repTotal > 0
          ? context.trP('repProgress', {
              'd': '$_repDone',
              't': '$_repTotal',
            })
          : context.tr('repChecking');
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 8),
          Text(label,
              style: const TextStyle(
                  color: KavachColors.sub, fontSize: 12.5)),
        ],
      );
    }
    if (rep == null || !rep.facts.online) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.wifi_off_rounded,
              size: 14, color: KavachColors.sub),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              context.tr('repOffline'),
              style: const TextStyle(
                  color: KavachColors.sub, fontSize: 12.5),
            ),
          ),
        ],
      );
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.verified_rounded,
            size: 14, color: KavachColors.safe),
        const SizedBox(width: 6),
        Text(
          '${context.tr('repGrade')}: ${rep.facts.grade} (${rep.facts.healthScore})',
          style: const TextStyle(
              color: KavachColors.sub,
              fontSize: 12.5,
              fontWeight: FontWeight.w700),
        ),
      ],
    );
  }

  Widget _facts(BuildContext context, DomainFacts facts) {
    final rows = <(String, String)>[];
    if (facts.ageDays != null) {
      rows.add((context.tr('repAge'),
          '${facts.ageDays} days${facts.registered != null ? ' · ${facts.registered}' : ''}'));
    }
    if (facts.registrar != null) {
      rows.add((context.tr('repRegistrar'), facts.registrar!));
    }
    if (facts.expiryDays != null) {
      rows.add((context.tr('repExpiry'), '${facts.expiryDays} days left'));
    }
    if (facts.nameservers != null && facts.nameservers!.isNotEmpty) {
      final ns =
          facts.nameservers!.split(RegExp(r'\s+')).take(2).join(', ');
      rows.add((context.tr('repNameservers'), ns));
    }
    if (facts.dnssec != null && facts.dnssec!.isNotEmpty) {
      rows.add((context.tr('repDnssec'), facts.dnssec!));
    }
    if (facts.blacklistFail != null) {
      rows.add((context.tr('repBlacklist'),
          facts.blacklistFail! > 0
              ? '${facts.blacklistFail} (${facts.blacklistDetails.take(2).join(', ')})'
              : context.tr('repClean')));
    }
    if (facts.healthScore != null) {
      rows.add((context.tr('repChecks'),
          '${facts.healthPass}✓ ${facts.healthWarn}~ ${facts.healthFail}✗ · ${facts.fetchSecs.toStringAsFixed(1)}s'));
    }
    if (rows.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: KavachColors.surface2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: KavachColors.line),
      ),
      child: Column(
        children: [
          for (final r in rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(r.$1,
                        style: const TextStyle(
                            color: KavachColors.sub,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600)),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(r.$2,
                        textAlign: TextAlign.end,
                        style: const TextStyle(fontSize: 12.5)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
