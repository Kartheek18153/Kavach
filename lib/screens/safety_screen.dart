import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../lang.dart';
import '../theme.dart';
import '../widgets/cards.dart';

/// Safety tab: incident-response steps + 1930 help + checklist + learning.
class SafetyScreen extends StatelessWidget {
  final VoidCallback onSetupFamily;

  const SafetyScreen({super.key, required this.onSetupFamily});

  Future<void> _call1930(BuildContext context) async {
    final uri = Uri.parse('tel:1930');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('copied1930'))),
      );
    }
  }

  Future<void> _openPortal(BuildContext context) async {
    final uri = Uri.parse('https://cybercrime.gov.in');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('portalCopied'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final steps = [
      ('1', context.tr('stepAT'), context.tr('stepAS')),
      ('2', context.tr('stepBT'), context.tr('stepBS')),
      ('3', context.tr('stepCT'), context.tr('stepCS')),
      ('4', context.tr('stepDT'), context.tr('stepDS')),
    ];
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
                Expanded(
                  child: Text(
                    context.tr('safetyTitle'),
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                ),
                const LangButton(),
              ],
            ),
            const SizedBox(height: 8),
            GlassCard(
              borderColor:
                  CyberSafeColors.danger.withValues(alpha: 0.5),
              child: Text(
                context.tr('safetySub'),
                style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    height: 1.5),
              ),
            ),
            const SizedBox(height: 14),
            GlassCard(
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
                            color: CyberSafeColors.washDanger,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(s.$1,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  color: CyberSafeColors.danger)),
                        ),
                        title: Text(s.$2,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15)),
                        subtitle: Text(s.$3,
                            style: const TextStyle(
                                color: CyberSafeColors.sub, fontSize: 13)),
                      ),
                    )
                    .toList(),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _call1930(context),
                    icon: const Icon(Icons.call_rounded),
                    label: Text(context.tr('call1930')),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _openPortal(context),
                    icon: const Icon(Icons.open_in_new_rounded),
                    label: Text(context.tr('cyberPortal')),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            SectionTitle(context.tr('checklist')),
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final k in ['check1', 'check2', 'check3', 'check4'])
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.check_circle_rounded,
                              size: 18, color: CyberSafeColors.safe),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(context.tr(k),
                                style: const TextStyle(
                                    fontSize: 14, height: 1.45)),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            SectionTitle(context.tr('learnTitle')),
            GlassCard(
              child: Text(context.tr('learnBody'),
                  style: const TextStyle(
                      color: CyberSafeColors.sub,
                      fontSize: 13.5,
                      height: 1.55)),
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: onSetupFamily,
              icon: const Icon(Icons.family_restroom_rounded),
              label: Text(context.tr('goFamily')),
            ),
          ],
        ),
      ),
    );
  }
}
