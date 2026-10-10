import 'package:flutter/material.dart';

import '../lang.dart';
import '../services/api.dart';
import '../theme.dart';
import '../widgets/cards.dart';

/// Family contact setup: guardian number, safe word.
class FamilyScreen extends StatefulWidget {
  final VoidCallback onSaved;
  const FamilyScreen({super.key, required this.onSaved});

  @override
  State<FamilyScreen> createState() => _FamilyScreenState();
}

class _FamilyScreenState extends State<FamilyScreen> {
  final _name = TextEditingController(text: GuardianStore.name);
  final _phone = TextEditingController(text: GuardianStore.phone);
  final _safeWord = TextEditingController(text: GuardianStore.safeWord);
  String? _nameError;
  String? _phoneError;
  String? _safeWordError;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _safeWord.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final nameOk = GuardianStore.isValidName(_name.text);
    final phoneOk = GuardianStore.isValidPhone(_phone.text);
    final wordRaw = _safeWord.text.trim();
    final wordOk = wordRaw.isEmpty || GuardianStore.isValidSafeWord(wordRaw);
    final nameMsg = nameOk ? null : context.tr('invalidName');
    final phoneMsg = phoneOk ? null : context.tr('invalidPhone');
    final wordMsg = wordOk ? null : context.tr('invalidSafeWord');
    setState(() {
      _nameError = nameMsg;
      _phoneError = phoneMsg;
      _safeWordError = wordMsg;
    });
    if (!nameOk || !phoneOk || !wordOk) return;
    GuardianStore.name = _name.text.trim();
    GuardianStore.phone = _phone.text.trim();
    GuardianStore.safeWord = wordRaw;
    await GuardianStore.save();
    _phone.text = GuardianStore.phone;
    _safeWord.text = GuardianStore.safeWord;
    widget.onSaved();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('contactSaved'))));
  }

  Future<void> _confirmClear() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(context.tr('clearTitle')),
        content: Text(context.tr('clearBody')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(c).pop(false),
            child: Text(context.tr('cancelBtn')),
          ),
          TextButton(
            onPressed: () => Navigator.of(c).pop(true),
            child: Text(context.tr('deleteBtn'),
                style: const TextStyle(color: CyberSafeColors.danger)),
          ),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    await GuardianStore.clear();
    setState(() {
      _name.text = '';
      _phone.text = '';
      _safeWord.text = '';
      _nameError = _phoneError = _safeWordError = null;
    });
    widget.onSaved();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('contactCleared'))));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 6, 18, 24),
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
            borderColor: CyberSafeColors.teal.withValues(alpha: 0.4),
            child: Row(
              children: [
                const Icon(Icons.family_restroom_rounded,
                    color: CyberSafeColors.teal, size: 30),
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
                    errorText: _nameError,
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
                    errorText: _phoneError,
                    prefixIcon: const Icon(Icons.phone_outlined),
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
                      color: CyberSafeColors.sub, fontSize: 13.5, height: 1.6),
                ),
                const SizedBox(height: 12),
                Text(
                  context.tr('safeWordHelp'),
                  style: const TextStyle(
                      color: CyberSafeColors.teal,
                      fontSize: 13,
                      height: 1.6,
                      fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _safeWord,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    labelText: context.tr('safeWordLabel'),
                    errorText: _safeWordError,
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
              onPressed: _save,
              child: Text(context.tr('saveContact')),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              onPressed: _confirmClear,
              icon: const Icon(Icons.delete_outline_rounded),
              label: Text(context.tr('clearContact')),
            ),
          ),
        ],
      ),
      ),
    );
  }
}
