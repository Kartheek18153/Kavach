import 'package:flutter/material.dart';

import '../lang.dart';
import '../theme.dart';
import '../widgets/cards.dart';

import '../services/api.dart';

/// Home: hero shield, big Protect button, language picker, status, 1930 strip.
class HomeScreen extends StatefulWidget {
  final VoidCallback onProtect;
  final VoidCallback onPractice;
  final VoidCallback onSetupFamily;
  final VoidCallback onViewReport;
  final bool familySet;
  final String? lastResult;

  const HomeScreen({
    super.key,
    required this.onProtect,
    required this.onPractice,
    required this.onSetupFamily,
    required this.onViewReport,
    required this.familySet,
    this.lastResult,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: KavachColors.bg0,
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 110),
            children: [
              _header(),
              const SizedBox(height: 14),
              if (!widget.familySet && HistoryStore.entries.isEmpty)
                _firstRunCard(),
              if (!widget.familySet && HistoryStore.entries.isEmpty)
                const SizedBox(height: 14),
              _heroCard(),
              const SizedBox(height: 14),
              _languageCard(),
              const SizedBox(height: 14),
              _statusRow(),
              const SizedBox(height: 14),
              _memoryCard(),
              const SizedBox(height: 14),
              _privacyCard(),
              const SizedBox(height: 14),
              SectionTitle(context.tr('howItWorks')),
              _stepsCard(),
              const SizedBox(height: 14),
              _emergencyStrip(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Row(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: KavachColors.blue,
            boxShadow: [
              BoxShadow(
                color: KavachColors.blue.withValues(alpha: 0.45),
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('KAVACH',
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 3)),
              Text(context.tr('brandSub'),
                  style: const TextStyle(
                      color: KavachColors.sub, fontSize: 13)),
            ],
          ),
        ),
        const LangButton(),
        const SizedBox(width: 8),
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: KavachColors.tintForLevel(RiskLevel.safe),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: KavachColors.safe.withValues(alpha: 0.5)),
          ),
          child: Row(
            children: [
              const Icon(Icons.circle,
                  size: 8, color: KavachColors.safe),
              const SizedBox(width: 6),
              Text(context.tr('ready'),
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: KavachColors.safe)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _heroCard() {
    return GlassCard(
      borderColor: KavachColors.blue.withValues(alpha: 0.35),
      padding: const EdgeInsets.fromLTRB(22, 26, 22, 24),
      child: Column(
        children: [
          Container(
            width: 118,
            height: 118,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: KavachColors.blue,
              boxShadow: [
                BoxShadow(
                  color: KavachColors.blue.withValues(alpha: 0.45),
                  blurRadius: 32,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Icon(Icons.shield_rounded,
                size: 58, color: Colors.white),
          ),
          const SizedBox(height: 16),
          Text(
            context.tr('heroTitle'),
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            context.tr('heroSub'),
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: KavachColors.sub, fontSize: 14, height: 1.5),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: widget.onProtect,
              icon: const Icon(Icons.phone_in_talk_rounded),
              label: Text(context.tr('protectBtn')),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_rounded,
                  size: 14, color: KavachColors.teal),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  context.tr('privacyNote'),
                  textAlign: TextAlign.center,
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

  Widget _languageCard() {
    final scope = LangScope.of(context);
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.tr('langTitle'),
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          Row(
            children: AppLang.values.map((l) {
              final selected = scope.lang == l;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: SizedBox(
                      height: 22,
                      child: Center(
                        child: Text(l.nativeName,
                            style: TextStyle(
                              color: selected
                                  ? KavachColors.teal
                                  : KavachColors.sub,
                              fontWeight: FontWeight.w700,
                            )),
                      ),
                    ),
                    selected: selected,
                    selectedColor: KavachColors.washTeal,
                    onSelected: (_) => scope.onLang(l),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _statusRow() {
    return Row(
      children: [
        Expanded(
          child: GlassCard(
            borderColor: widget.familySet
                ? KavachColors.safe.withValues(alpha: 0.5)
                : KavachColors.caution.withValues(alpha: 0.5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  widget.familySet
                      ? Icons.family_restroom_rounded
                      : Icons.family_restroom_outlined,
                  color: widget.familySet
                      ? KavachColors.safe
                      : KavachColors.caution,
                ),
                const SizedBox(height: 8),
                Text(context.tr('familyAlert'),
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 14)),
                Text(
                  widget.familySet
                      ? context.tr('connected')
                      : context.tr('notSet'),
                  style: TextStyle(
                    color: widget.familySet
                        ? KavachColors.safe
                        : KavachColors.caution,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: GlassCard(
            onTap: widget.lastResult == null ? null : widget.onViewReport,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.history_rounded,
                    color: KavachColors.teal),
                const SizedBox(height: 8),
                Text(context.tr('lastScan'),
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 14)),
                Text(
                  widget.lastResult ?? context.tr('noCalls'),
                  style: const TextStyle(
                    color: KavachColors.sub,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _firstRunCard() {
    return GlassCard(
      borderColor: KavachColors.teal.withValues(alpha: 0.4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.tr('firstTitle'),
              style:
                  const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 6),
          Text(context.tr('firstBody'),
              style: const TextStyle(
                  color: KavachColors.sub, fontSize: 13.5, height: 1.5)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: widget.onSetupFamily,
                  child: Text(context.tr('goFamily')),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: widget.onPractice,
                  child: Text(context.tr('tryDemo')),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _memoryCard() {
    final caught = HistoryStore.monthDangers;
    final worst = HistoryStore.monthWorst;
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.tr('memoryTitle'),
              style:
                  const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _stat(
                    '$caught', context.tr('caughtMonth'), KavachColors.danger),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _stat(
                    worst == 0 ? context.tr('noneYet') : '$worst/100',
                    context.tr('worstMonth'),
                    KavachColors.teal),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stat(String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: KavachColors.surface2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: KavachColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value,
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: color)),
          Text(label,
              style: const TextStyle(
                  color: KavachColors.sub,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _privacyCard() {
    return GlassCard(
      borderColor: KavachColors.teal.withValues(alpha: 0.4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: KavachColors.washTeal,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.lock_rounded,
                color: KavachColors.teal, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(context.tr('privacyTitle'),
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 15)),
                const SizedBox(height: 4),
                Text(context.tr('privacyBody'),
                    style: const TextStyle(
                        color: KavachColors.sub,
                        fontSize: 13.5,
                        height: 1.55)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _stepsCard() {
    final steps = [
      ('1', context.tr('step1t'), context.tr('step1s')),
      ('2', context.tr('step2t'), context.tr('step2s')),
      ('3', context.tr('step3t'), context.tr('step3s')),
    ];
    return GlassCard(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: steps
            .map(
              (s) => ListTile(
                leading: Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: KavachColors.washTeal,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(s.$1,
                      style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          color: KavachColors.teal)),
                ),
                title: Text(s.$2,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 15)),
                subtitle: Text(s.$3,
                    style: const TextStyle(
                        color: KavachColors.sub, fontSize: 13)),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _emergencyStrip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: KavachColors.washCaution,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: KavachColors.caution.withValues(alpha: 0.45)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x260D47A1),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
          BoxShadow(
            color: Color(0x1F0D47A1),
            blurRadius: 24,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.sos_rounded, color: KavachColors.caution),
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
