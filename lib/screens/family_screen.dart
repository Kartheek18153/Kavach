import 'package:flutter/material.dart';

import '../lang.dart';
import '../services/api.dart';
import '../theme.dart';
import '../widgets/cards.dart';

/// Family contact setup: guardian number, Telegram link, safe word.
class FamilyScreen extends StatefulWidget {
  final VoidCallback onSaved;
  const FamilyScreen({super.key, required this.onSaved});

  @override
  State<FamilyScreen> createState() => _FamilyScreenState();
}

class _FamilyScreenState extends State<FamilyScreen> {
  final _name = TextEditingController(text: '');
  final _phone = TextEditingController(text: '');
  final _chatId = TextEditingController(text: '');
  final _safeWord = TextEditingController(text: '');

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _chatId.dispose();
    _safeWord.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 6, 18, 110),
          children: [
            Row(
              children: [
                Text(
                  context.tr('familyTitle'),
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w800),
                ),
                const Spacer(),
                const LangButton(),
              ],
            ),
            const SizedBox(height: 12),
            GlassCard(
            borderColor: KavachColors.teal.withValues(alpha: 0.4),
            child: Row(
              children: [
                const Icon(Icons.family_restroom_rounded,
                    color: KavachColors.teal, size: 30),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    context.tr('familyInfo'),
                    style: const TextStyle(fontSize: 14.5, height: 1.5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SectionTitle(context.tr('trustedContact')),
          GlassCard(
            child: Column(
              children: [
                TextField(
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: context.tr('nameLabel'),
                    prefixIcon:
                        const Icon(Icons.person_outline_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: context.tr('phoneLabel'),
                    prefixIcon: const Icon(Icons.phone_outlined),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SectionTitle(context.tr('telegramTitle')),
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('telegramSteps'),
                  style: const TextStyle(
                      color: KavachColors.sub, fontSize: 13.5, height: 1.7),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _chatId,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: context.tr('chatIdLabel'),
                    prefixIcon: const Icon(Icons.send_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final res = await KavachApi.sendAlert(
                        chatId: _chatId.text.trim(),
                        message:
                            'Kavach test alert: family notifications work. Reply STOP to opt out.',
                      );
                      if (!context.mounted) return;
                      final live = res['sent'] == true &&
                          res['via'] == 'telegram';
                      ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content: Text(context.tr(live
                                  ? 'testSentLive'
                                  : 'testSentDemo'))));
                    },
                    icon: const Icon(Icons.bolt_rounded),
                    label: Text(context.tr('sendTest')),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SectionTitle(context.tr('safeWordTitle')),
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('safeWordInfo'),
                  style: const TextStyle(
                      color: KavachColors.sub, fontSize: 13.5, height: 1.6),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _safeWord,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    labelText: context.tr('safeWordLabel'),
                    prefixIcon: const Icon(Icons.key_rounded),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                widget.onSaved();
                GuardianStore.name = _name.text.trim();
                GuardianStore.phone = _phone.text.trim();
                GuardianStore.chatId = _chatId.text.trim();
                ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(context.tr('contactSaved'))));
              },
              child: Text(context.tr('saveContact')),
            ),
          ),
        ],
      ),
      ),
    );
  }
}
