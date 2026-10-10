import 'package:flutter/material.dart';

import '../lang.dart';
import '../services/api.dart';
import '../services/scan_history.dart';
import '../theme.dart';
import '../widgets/cards.dart';
import '../widgets/scan_widgets.dart';
import 'history_screen.dart';
import 'safety_screen.dart';
import 'settings_screen.dart';
import 'threats_screen.dart';
import 'tools/qr_upi_screen.dart';
import 'tools/sim_swap_screen.dart';
import 'tools/sms_analyzer_screen.dart';
import 'tools/url_scanner_screen.dart';

/// Home = overall security dashboard: shield score, call protection,
/// tool shortcuts, recent activity, family status, 1930 strip.
class DashboardScreen extends StatelessWidget {
  final VoidCallback onProtect;
  final VoidCallback onPractice;
  final VoidCallback onSetupFamily;
  final VoidCallback onViewReport;
  final bool familySet;
  final String? lastResult;

  const DashboardScreen({
    super.key,
    required this.onProtect,
    required this.onPractice,
    required this.onSetupFamily,
    required this.onViewReport,
    required this.familySet,
    this.lastResult,
  });

  /// 0-100 protection score from on-device state (no uploads).
  int _shieldScore() {
    var score = 40;
    if (familySet) score += 25;
    final checks =
        HistoryStore.entries.length + ScanHistoryStore.entries.length;
    score += (checks * 5).clamp(0, 25);
    final dangers = HistoryStore.entries
            .where((e) => e['level'] == 'danger')
            .length +
        ScanHistoryStore.entries.where((e) => e.level == 'danger').length;
    if (dangers > 0) score += 10;
    return score.clamp(0, 100);
  }

  void _openTool(BuildContext context, Widget page) {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    final score = _shieldScore();
    final scoreLevel = riskLevelFor(100 - score);
    return Scaffold(
      body: Container(
        color: CyberSafeColors.bg0,
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
            children: [
              _header(context),
              const SizedBox(height: 14),
              _shieldCard(context, score, scoreLevel),
              const SizedBox(height: 14),
              _protectCard(context),
              const SizedBox(height: 14),
              _toolsCard(context),
              const SizedBox(height: 14),
              _threatCard(context),
              const SizedBox(height: 14),
              _recentCard(context),
              const SizedBox(height: 14),
              _safetyCard(context),
              const SizedBox(height: 14),
              _familyRow(context),
              const SizedBox(height: 14),
              _emergencyStrip(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: CyberSafeColors.blue,
            boxShadow: [
              BoxShadow(
                color: CyberSafeColors.blue.withValues(alpha: 0.45),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(Icons.shield_rounded,
              color: Colors.white, size: 28),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('CYBERSAFE',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                      height: 1.1,
                      color: CyberSafeColors.ink)),
              const SizedBox(height: 2),
              Text(context.tr('brandSub'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: CyberSafeColors.sub, fontSize: 12)),
            ],
          ),
        ),
        const LangButton(),
        IconButton(
          tooltip: context.tr('settingsTitle'),
          onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen())),
          icon: const Icon(Icons.settings_rounded,
              color: CyberSafeColors.sub),
        ),
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: CyberSafeColors.tintForLevel(RiskLevel.safe),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: CyberSafeColors.safe.withValues(alpha: 0.5)),
          ),
          child: Row(
            children: [
              const Icon(Icons.circle,
                  size: 8, color: CyberSafeColors.safe),
              const SizedBox(width: 6),
              Text(context.tr('ready'),
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: CyberSafeColors.safe)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _shieldCard(BuildContext context, int score, RiskLevel level) {
    final c = CyberSafeColors.forLevel(level);
    final checks =
        HistoryStore.entries.length + ScanHistoryStore.entries.length;
    final dangers = HistoryStore.entries
            .where((e) => e['level'] == 'danger')
            .length +
        ScanHistoryStore.entries.where((e) => e.level == 'danger').length;
    return GlassCard(
      borderColor: c.withValues(alpha: 0.5),
      child: Row(
        children: [
          Container(
            width: 84,
            height: 84,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: CyberSafeColors.tintForLevel(level),
              border: Border.all(color: c, width: 3),
            ),
            child: Text('$score',
                style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    color: c)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(context.tr('shieldTitle'),
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(context.tr('shieldSub'),
                    style: const TextStyle(
                        color: CyberSafeColors.sub,
                        fontSize: 12.5,
                        height: 1.45)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                        child: _miniStat('$checks',
                            context.tr('scansMonth'))),
                    const SizedBox(width: 8),
                    Expanded(
                        child: _miniStat('$dangers',
                            context.tr('dangersCaught'))),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniStat(String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: CyberSafeColors.surface2,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: CyberSafeColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value,
              style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: CyberSafeColors.teal)),
          Text(label,
              style: const TextStyle(
                  color: CyberSafeColors.sub,
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _protectCard(BuildContext context) {
    return GlassCard(
      borderColor: CyberSafeColors.blue.withValues(alpha: 0.35),
      child: Column(
        children: [
          Text(
            context.tr('heroTitle'),
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            context.tr('heroSub'),
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: CyberSafeColors.sub, fontSize: 13.5, height: 1.5),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onProtect,
              icon: const Icon(Icons.phone_in_talk_rounded),
              label: Text(context.tr('protectBtn')),
            ),
          ),
          TextButton(
            onPressed: onPractice,
            child: Text(context.tr('tryDemo')),
          ),
        ],
      ),
    );
  }

  Widget _toolsCard(BuildContext context) {
    final tools = [
      (Icons.sim_card_rounded, 'toolSim', 'toolSimSub',
          const SimSwapScreen()),
      (Icons.link_rounded, 'toolUrl', 'toolUrlSub',
          const UrlScannerScreen()),
      (Icons.qr_code_2_rounded, 'toolQrUpi', 'toolQrUpiSub',
          const QrUpiScreen()),
      (Icons.sms_rounded, 'toolSms', 'toolSmsSub',
          const SmsAnalyzerScreen()),
    ];
    return GlassCard(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 4),
            child: Text(context.tr('toolsTitle'),
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w800)),
          ),
          for (var i = 0; i < tools.length; i++)
            TapRow(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: CyberSafeColors.washTeal,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(tools[i].$1,
                    color: CyberSafeColors.teal, size: 22),
              ),
              title: Text(context.tr(tools[i].$2),
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 14.5)),
              subtitle: Text(context.tr(tools[i].$3),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: CyberSafeColors.sub, fontSize: 12.5)),
              trailing: const Icon(Icons.chevron_right_rounded,
                  color: CyberSafeColors.sub),
              onTap: () => _openTool(context, tools[i].$4),
            ),
        ],
      ),
    );
  }

  Widget _threatCard(BuildContext context) {
    final dangers = HistoryStore.entries
            .where((e) => e['level'] == 'danger')
            .length +
        ScanHistoryStore.entries.where((e) => e.level == 'danger').length;
    final c = dangers > 0 ? CyberSafeColors.danger : CyberSafeColors.safe;
    return GlassCard(
      borderColor: c.withValues(alpha: 0.45),
      onTap: () => _openTool(context, const ThreatsScreen()),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: CyberSafeColors.tintForLevel(
                  dangers > 0 ? RiskLevel.danger : RiskLevel.safe),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.warning_amber_rounded, color: c, size: 26),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(context.tr('threatsTitle'),
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 15)),
                Text(
                  '$dangers ${context.tr('dangersCaught')}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: CyberSafeColors.sub, fontSize: 12.5),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded,
              color: CyberSafeColors.sub),
        ],
      ),
    );
  }

  Widget _safetyCard(BuildContext context) {
    return GlassCard(
      onTap: () => _openTool(
          context, SafetyScreen(onSetupFamily: onSetupFamily)),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: CyberSafeColors.washTeal,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.health_and_safety_rounded,
                color: CyberSafeColors.teal, size: 26),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(context.tr('safetyTitle'),
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 15)),
                Text(
                  context.tr('safetySub'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: CyberSafeColors.sub, fontSize: 12.5),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded,
              color: CyberSafeColors.sub),
        ],
      ),
    );
  }

  List<_Activity> _recent() {
    final out = <_Activity>[];
    for (final e in HistoryStore.entries) {
      out.add(_Activity(
        '${e['scamType'] ?? '-'}',
        '${e['risk'] ?? 0}/100',
        '${e['level'] ?? 'safe'}',
        '${e['ts'] ?? ''}',
      ));
    }
    const kindIcons = {
      'url': 'Link',
      'qr': 'QR',
      'upi': 'UPI',
      'sim': 'SIM',
      'sms': 'SMS',
    };
    for (final s in ScanHistoryStore.entries) {
      out.add(_Activity(
        '${kindIcons[s.kind] ?? s.kind}: ${s.input}',
        '${s.risk}/100',
        s.level,
        s.ts,
      ));
    }
    out.sort((a, b) => b.ts.compareTo(a.ts));
    return out.take(3).toList();
  }

  Widget _recentCard(BuildContext context) {
    final items = _recent();
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(context.tr('recentTitle'),
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w800)),
              ),
              if (items.isNotEmpty)
                TextButton(
                  onPressed: () =>
                      _openTool(context, const HistoryScreen()),
                  child: Text(context.tr('viewAll')),
                ),
            ],
          ),
          if (items.isEmpty)
            Text(context.tr('noActivity'),
                style: const TextStyle(
                    color: CyberSafeColors.sub, fontSize: 13.5))
          else
            InkWell(
              onTap: () =>
                  _openTool(context, const HistoryScreen()),
              child: Column(
                children: [
                  for (final a in items)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        children: [
                          _dot(a.level),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(a.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13.5)),
                          ),
                          Text(a.sub,
                              style: const TextStyle(
                                  color: CyberSafeColors.sub,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _dot(String level) {
    final lv = level == 'danger'
        ? RiskLevel.danger
        : level == 'caution'
            ? RiskLevel.caution
            : RiskLevel.safe;
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: CyberSafeColors.forLevel(lv),
        shape: BoxShape.circle,
      ),
    );
  }

  Widget _familyRow(BuildContext context) {
    return GlassCard(
      onTap: familySet ? null : onSetupFamily,
      borderColor: familySet
          ? CyberSafeColors.safe.withValues(alpha: 0.5)
          : CyberSafeColors.caution.withValues(alpha: 0.5),
      child: Row(
        children: [
          Icon(
            familySet
                ? Icons.family_restroom_rounded
                : Icons.family_restroom_outlined,
            color: familySet
                ? CyberSafeColors.safe
                : CyberSafeColors.caution,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(context.tr('familyAlert'),
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 14)),
                Text(
                  familySet
                      ? context.tr('connected')
                      : context.tr('notSet'),
                  style: TextStyle(
                    color: familySet
                        ? CyberSafeColors.safe
                        : CyberSafeColors.caution,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (lastResult != null)
            Expanded(
              child: InkWell(
                onTap: onViewReport,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(context.tr('lastScan'),
                        style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13)),
                    Text(lastResult!,
                        textAlign: TextAlign.end,
                        style: const TextStyle(
                            color: CyberSafeColors.sub,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _emergencyStrip(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: CyberSafeColors.washCaution,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: CyberSafeColors.caution.withValues(alpha: 0.45)),
      ),
      child: Row(
        children: [
          const Icon(Icons.sos_rounded, color: CyberSafeColors.caution),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              context.tr('emergency'),
              style: const TextStyle(
                  fontWeight: FontWeight.w700, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}

class _Activity {
  final String title;
  final String sub;
  final String level;
  final String ts;
  const _Activity(this.title, this.sub, this.level, this.ts);
}
