import 'package:flutter/material.dart';

import 'demo/simulator.dart';
import 'lang.dart';
import 'screens/family_screen.dart';
import 'screens/home_screen.dart';
import 'screens/live_screen.dart';
import 'screens/report_screen.dart';
import 'theme.dart';

void main() {
  runApp(const KavachApp());
}

/// Kavach — Telugu-first scam-call shield (hackathon UI build).
class KavachApp extends StatefulWidget {
  const KavachApp({super.key});

  @override
  State<KavachApp> createState() => _KavachAppState();
}

class _KavachAppState extends State<KavachApp> {
  int _tab = 0;
  late final DemoSession _session;
  bool _familySet = false;
  Map<String, dynamic>? _lastSummary;
  AppLang _lang = AppLang.english;

  @override
  void initState() {
    super.initState();
    _session = DemoSession();
  }

  @override
  void dispose() {
    _session.dispose();
    super.dispose();
  }

  void _protect() {
    setState(() => _tab = 1);
    _session.startScam();
  }

  void _finish(Map<String, dynamic> summary) {
    final level = summary['level'] as RiskLevel;
    setState(() {
      _lastSummary = summary;
      _tab = 3;
    });
    summary['label'] = '${summary['scamType']} | ${riskLabel(level, _lang)}';
  }

  String? get _lastResult {
    final s = _lastSummary;
    if (s == null) return null;
    return '${s['scamType']} | ${(s['level'] as RiskLevel).label}';
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kavach',
      debugShowCheckedModeBanner: false,
      theme: kavachTheme(),
      home: LangScope(
        lang: _lang,
        onLang: (l) => setState(() => _lang = l),
        child: Builder(
          builder: (context) => Scaffold(
            body: IndexedStack(
              index: _tab,
              children: [
                HomeScreen(
                  onProtect: _protect,
                  familySet: _familySet,
                  lastResult: _lastResult,
                ),
                LiveScreen(session: _session, onFinish: _finish),
                FamilyScreen(
                    onSaved: () => setState(() => _familySet = true)),
                ReportScreen(
                  summary: _lastSummary,
                  onNewScan: () => setState(() => _tab = 1),
                ),
              ],
            ),
            bottomNavigationBar: null,
            floatingActionButton: _FloatingNav(
              index: _tab,
              onSelect: (i) => setState(() => _tab = i),
            ),
            floatingActionButtonLocation:
                FloatingActionButtonLocation.centerFloat,
          ),
        ),
      ),
    );
  }
}

/// Floating pill navigator with all four routes.
class _FloatingNav extends StatelessWidget {
  final int index;
  final ValueChanged<int> onSelect;

  const _FloatingNav({required this.index, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    const items = [
      (Icons.shield_outlined, Icons.shield_rounded, 'tabHome'),
      (
        Icons.phone_in_talk_outlined,
        Icons.phone_in_talk_rounded,
        'tabLive'
      ),
      (
        Icons.family_restroom_outlined,
        Icons.family_restroom_rounded,
        'tabFamily'
      ),
      (Icons.summarize_outlined, Icons.summarize_rounded, 'tabReport'),
    ];
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: KavachColors.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: KavachColors.line),
        boxShadow: const [
          BoxShadow(
            color: Color(0x260D47A1),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
          BoxShadow(
            color: Color(0x330D47A1),
            blurRadius: 28,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < items.length; i++)
            _pillItem(context, i, items[i]),
        ],
      ),
    );
  }

  Widget _pillItem(
      BuildContext context,
      int i,
      (IconData, IconData, String) item,
    ) {
    final selected = i == index;
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: () => onSelect(i),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color:
              selected ? KavachColors.washTeal : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              selected ? item.$2 : item.$1,
              color: selected ? KavachColors.teal : KavachColors.sub,
              size: 24,
            ),
            const SizedBox(height: 2),
            Text(
              context.tr(item.$3),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color:
                    selected ? KavachColors.teal : KavachColors.sub,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
