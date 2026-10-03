import 'package:flutter/material.dart';

import '../lang.dart';
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
      appBar: AppBar(
        title: Text(context.tr('familyTitle')),
        actions: const [
          LangButton(),
          SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 6, 18, 110),
        children: [
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
                    onPressed: () => ScaffoldMessenger.of(context)
                        .showSnackBar(SnackBar(
                            content: Text(context.tr('testSent')))),
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
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: const LinearGradient(
                  colors: [KavachColors.blue, KavachColors.violet],
                ),
                boxShadow: [
                  BoxShadow(
                    color: KavachColors.violet.withValues(alpha: 0.35),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: () {
                  widget.onSaved();
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text(context.tr('contactSaved'))));
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                ),
                child: Text(context.tr('saveContact')),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
