import 'package:flutter/material.dart';

import '../services/risk_explain.dart';
import '../theme.dart';
import 'cards.dart';

IconData _familyIcon(String id) {
  switch (id) {
    case 'AUTHORITY_IMPERSONATION':
      return Icons.local_police_outlined;
    case 'ISOLATION_AND_SECRECY':
      return Icons.visibility_off_outlined;
    case 'URGENCY_AND_THREAT':
      return Icons.timer_off_outlined;
    case 'CREDENTIAL_EXTRACTION':
      return Icons.password_rounded;
    case 'REMOTE_ACCESS_AND_TRANSFER':
      return Icons.screen_share_outlined;
    default:
      return Icons.warning_amber_rounded;
  }
}

IconData _actionIcon(String id) {
  switch (id) {
    case 'end_call':
      return Icons.call_end_rounded;
    case 'no_otp':
      return Icons.pin_outlined;
    case 'no_apk':
      return Icons.app_blocking_rounded;
    case 'disable_access':
      return Icons.accessibility_new_rounded;
    case 'no_money':
      return Icons.money_off_rounded;
    case 'secure_accounts':
      return Icons.shield_outlined;
    case 'report_incident':
      return Icons.emergency_outlined;
    default:
      return Icons.check_circle_outline_rounded;
  }
}

String _prioLabel(int p, String lang) {
  switch (p) {
    case 0:
      return lang == 'te'
          ? 'ఇప్పుడే'
          : lang == 'hi'
              ? 'अभी'
              : 'NOW';
    case 1:
      return lang == 'te'
          ? 'తర్వాత'
          : lang == 'hi'
              ? 'आगे'
              : 'NEXT';
    default:
      return lang == 'te'
          ? 'తర్వాత'
          : lang == 'hi'
              ? 'बाद में'
              : 'LATER';
  }
}

Color _prioColor(int p) {
  switch (p) {
    case 0:
      return CyberSafeColors.danger;
    case 1:
      return CyberSafeColors.caution;
    default:
      return CyberSafeColors.teal;
  }
}

/// "Why am I at risk?" — explainable breakdown of the risk score.
///
/// Shows which signal families fired, how many points each added,
/// the exact matched phrases, and what suspicious behaviour that means.
class WhyAtRiskCard extends StatelessWidget {
  final int risk;
  final RiskLevel level;
  final Set<String> families;
  final Map<String, List<String>> evidence;
  final Map<String, double> cappedByFamily;
  final int diversityBonus;
  final double guardDelta;
  final String lang; // 'en' | 'te' | 'hi'
  final String title;
  final String emptyText;

  const WhyAtRiskCard({
    super.key,
    required this.risk,
    required this.level,
    required this.families,
    required this.evidence,
    required this.cappedByFamily,
    required this.diversityBonus,
    required this.guardDelta,
    required this.lang,
    required this.title,
    required this.emptyText,
  });

  @override
  Widget build(BuildContext context) {
    final color = CyberSafeColors.forLevel(level);
    final contribs = <FamilyContribution>[];
    var denom = 0.0;
    for (final v in cappedByFamily.values) {
      denom += v;
    }
    if (diversityBonus > 0) denom += diversityBonus.toDouble();
    for (final id in families) {
      final capped = cappedByFamily[id] ?? 0;
      if (capped <= 0) continue;
      contribs.add(FamilyContribution(
        familyId: id,
        raw: capped,
        capped: capped,
        sharePct: denom > 0 ? capped / denom * 100 : 0,
        spans: evidence[id] ?? const [],
      ));
    }
    contribs.sort((a, b) => b.capped.compareTo(a.capped));

    return GlassCard(
      borderColor: color.withValues(alpha: 0.5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.psychology_outlined, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 15)),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: CyberSafeColors.tintForLevel(level),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: color.withValues(alpha: 0.5)),
                ),
                child: Text('$risk/100',
                    style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w900,
                        fontSize: 13)),
              ),
            ],
          ),
          if (contribs.isEmpty) ...[
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.check_circle_rounded,
                    color: CyberSafeColors.safe, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(emptyText,
                      style: const TextStyle(
                          color: CyberSafeColors.sub,
                          fontSize: 13.5,
                          height: 1.5)),
                ),
              ],
            ),
          ] else ...[
            const SizedBox(height: 6),
            for (var i = 0; i < contribs.length; i++)
              _familyRow(contribs[i], i == contribs.length - 1),
            if (diversityBonus > 0 || guardDelta < 0) ...[
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  if (diversityBonus > 0)
                    _miniChip(
                      '+$diversityBonus ${lang == 'te' ? 'కలయిక' : lang == 'hi' ? 'संयोजन' : 'combo'}',
                      CyberSafeColors.caution,
                    ),
                  if (guardDelta < 0)
                    _miniChip(
                      '${guardDelta.toStringAsFixed(0)} ${lang == 'te' ? 'నమ్మక సంకేతం' : lang == 'hi' ? 'विश्वास संकेत' : 'trust signal'}',
                      CyberSafeColors.safe,
                    ),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _familyRow(FamilyContribution c, bool last) {
    final ex = explainFor(c.familyId);
    final title = ex?.inLang(ex.title, lang) ?? c.familyId;
    final behaviour = ex?.inLang(ex.behaviour, lang) ?? '';
    final frac = (c.sharePct / 100).clamp(0.0, 1.0);
    return Padding(
      padding: EdgeInsets.only(top: 10, bottom: last ? 0 : 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: CyberSafeColors.washDanger,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(_familyIcon(c.familyId),
                    color: CyberSafeColors.danger, size: 19),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(title,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14)),
                        ),
                        Text('+${c.capped.toStringAsFixed(0)}',
                            style: const TextStyle(
                                color: CyberSafeColors.danger,
                                fontWeight: FontWeight.w900,
                                fontSize: 14)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: frac,
                        minHeight: 6,
                        backgroundColor: CyberSafeColors.surface2,
                        valueColor: const AlwaysStoppedAnimation(
                            CyberSafeColors.danger),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (behaviour.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 44, top: 4),
              child: Text(behaviour,
                  style: const TextStyle(
                      color: CyberSafeColors.sub,
                      fontSize: 13,
                      height: 1.45)),
            ),
          if (c.spans.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 44, top: 6),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final s in c.spans.take(3))
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: CyberSafeColors.surface2,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: CyberSafeColors.line),
                      ),
                      child: Text('“$s”',
                          style: const TextStyle(
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                              color: CyberSafeColors.ink)),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _miniChip(String text, Color c) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: c.withValues(alpha: 0.4)),
      ),
      child: Text(text,
          style: TextStyle(
              color: c, fontSize: 12, fontWeight: FontWeight.w700)),
    );
  }
}

/// "What should I do?" — prioritized human decision support.
///
/// P0 NOW (red) → P1 NEXT (amber) → P2 LATER (blue), each with a
/// one-tap helper where one exists (1930 call, portal, family SMS).
class ActionPlanCard extends StatelessWidget {
  final List<SafetyAction> actions;
  final String lang;
  final String title;
  final VoidCallback? onCall1930;
  final VoidCallback? onOpenPortal;
  final VoidCallback? onSmsFamily;

  const ActionPlanCard({
    super.key,
    required this.actions,
    required this.lang,
    required this.title,
    this.onCall1930,
    this.onOpenPortal,
    this.onSmsFamily,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      borderColor: CyberSafeColors.teal.withValues(alpha: 0.4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.checklist_rounded,
                  color: CyberSafeColors.teal),
              const SizedBox(width: 8),
              Expanded(
                child: Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 15)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          for (var i = 0; i < actions.length; i++)
            _actionRow(actions[i], i + 1),
        ],
      ),
    );
  }

  Widget _actionRow(SafetyAction a, int n) {
    final c = _prioColor(a.priority);
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: c,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text('$n',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 14)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(_actionIcon(a.id), size: 17, color: c),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(a.t(lang),
                          style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: c.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: Text(_prioLabel(a.priority, lang),
                          style: TextStyle(
                              color: c,
                              fontSize: 11,
                              fontWeight: FontWeight.w900)),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(a.d(lang),
                    style: const TextStyle(
                        color: CyberSafeColors.sub,
                        fontSize: 13,
                        height: 1.45)),
                if (a.id == 'report_incident' &&
                    (onCall1930 != null || onOpenPortal != null))
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (onCall1930 != null)
                          ElevatedButton.icon(
                            onPressed: onCall1930,
                            icon: const Icon(Icons.call_rounded, size: 17),
                            label: Text(lang == 'te'
                                ? '1930కి కాల్'
                                : lang == 'hi'
                                    ? '1930 पर कॉल'
                                    : 'Call 1930'),
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size(0, 42),
                              backgroundColor: CyberSafeColors.danger,
                              foregroundColor: Colors.white,
                              textStyle: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800),
                            ),
                          ),
                        if (onOpenPortal != null)
                          OutlinedButton.icon(
                            onPressed: onOpenPortal,
                            icon: const Icon(Icons.open_in_new_rounded,
                                size: 17),
                            label: Text(lang == 'te'
                                ? 'పోర్టల్'
                                : lang == 'hi'
                                    ? 'पोर्टल'
                                    : 'Portal'),
                            style: OutlinedButton.styleFrom(
                                minimumSize: const Size(0, 42)),
                          ),
                      ],
                    ),
                  ),
                if (a.id == 'secure_accounts' && onSmsFamily != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: OutlinedButton.icon(
                      onPressed: onSmsFamily,
                      icon: const Icon(Icons.sms_rounded, size: 17),
                      label: Text(lang == 'te'
                          ? 'కుటుంబానికి SMS'
                          : lang == 'hi'
                              ? 'परिवार को SMS'
                              : 'Text family'),
                      style:
                          OutlinedButton.styleFrom(
                              minimumSize: const Size(0, 42)),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// On-demand AI insight for one AI feature (explain-risk or advise-steps).
///
/// Renders nothing when [available] is false (no key or no opt-in), so
/// the rule-based UI stays clean. Otherwise shows an ask button, a
/// loading state, then the AI text with badge + disclaimer — or a
/// failure note that leaves the rule-based result standing.
class AiInsightCard extends StatefulWidget {
  final Future<String?> Function() onFetch;
  final String askLabel;
  final String loadingLabel;
  final String failedText;
  final String noteText;
  final String badgeLabel;
  final bool available;

  const AiInsightCard({
    super.key,
    required this.onFetch,
    required this.askLabel,
    required this.loadingLabel,
    required this.failedText,
    required this.noteText,
    required this.badgeLabel,
    required this.available,
  });

  @override
  State<AiInsightCard> createState() => _AiInsightCardState();
}

class _AiInsightCardState extends State<AiInsightCard> {
  bool _busy = false;
  bool _failed = false;
  String? _text;

  Future<void> _ask() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _failed = false;
    });
    String? out;
    try {
      out = await widget.onFetch();
    } catch (_) {
      out = null;
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (out == null || out.isEmpty) {
        _failed = true;
      } else {
        _failed = false;
        _text = out;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.available) return const SizedBox.shrink();
    return GlassCard(
      borderColor: CyberSafeColors.violet.withValues(alpha: 0.45),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome_outlined,
                  color: CyberSafeColors.violet),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: CyberSafeColors.violet,
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Text(widget.badgeLabel,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w900)),
              ),
              const Spacer(),
              if (_text != null || _failed)
                TextButton.icon(
                  onPressed: _ask,
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: Text(widget.askLabel,
                      style: const TextStyle(fontSize: 12.5)),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (_busy)
            Row(
              children: [
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
                const SizedBox(width: 10),
                Text(widget.loadingLabel,
                    style: const TextStyle(
                        color: CyberSafeColors.sub, fontSize: 13.5)),
              ],
            )
          else if (_text != null)
            Text(_text!,
                style: const TextStyle(fontSize: 14.5, height: 1.55))
          else if (_failed)
            Text(widget.failedText,
                style: const TextStyle(
                    color: CyberSafeColors.sub,
                    fontSize: 13.5,
                    height: 1.5))
          else
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _ask,
                icon: const Icon(Icons.auto_awesome_outlined,
                    size: 18),
                label: Text(widget.askLabel),
              ),
            ),
          const SizedBox(height: 8),
          Text(widget.noteText,
              style: const TextStyle(
                  color: CyberSafeColors.sub,
                  fontSize: 12,
                  fontStyle: FontStyle.italic)),
        ],
      ),
    );
  }
}
