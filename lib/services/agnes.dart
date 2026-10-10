/// Agnes AI second opinion (Agnes 2.5 Flash via the Agnes API hub).
///
/// Role: display-only text for the two human-facing features —
/// "Why am I at risk?" explanations and "What should I do?" advice.
/// The rule engine stays the scorer; AI text never changes the meter.
///
/// Privacy: strictly opt-in (default OFF, see [AgnesConsent]). When on,
/// only detected signals leave the phone (matched phrases, families,
/// risk score) — never the full transcript. Every call fails soft to
/// null so the app keeps working offline with the rule-based cards.
///
/// Config (compile-time, never committed to git):
///   flutter run --dart-define=AGNES_API_KEY=sk-... \
///     --dart-define=KAVACH_API=http://10.0.2.2:8080
/// Optional overrides:
///   --dart-define=AGNES_BASE_URL=https://apihub.agnes-ai.com/v1
///   --dart-define=AGNES_MODEL=agnes-2.5-flash
library;

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Compile-time config for the Agnes API hub.
class AgnesConfig {
  /// Bearer key. Empty when not passed via --dart-define.
  static const apiKey = String.fromEnvironment('AGNES_API_KEY',
      defaultValue: '');

  static const baseUrl = String.fromEnvironment('AGNES_BASE_URL',
      defaultValue: 'https://apihub.agnes-ai.com/v1');

  static const model = String.fromEnvironment('AGNES_MODEL',
      defaultValue: 'agnes-2.5-flash');

  /// True when a key was baked in at build time. The key itself is
  /// never displayed anywhere in the UI.
  static bool get isConfigured => apiKey.isNotEmpty;
}

/// Explicit user opt-in for AI features. Off by default; persisted.
class AgnesConsent {
  static const _key = 'kavach_agnes_optin_v1';
  static bool isOn = false;

  static Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      isOn = prefs.getBool(_key) ?? false;
    } catch (_) {
      isOn = false;
    }
  }

  static Future<void> set(bool v) async {
    isOn = v;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_key, v);
    } catch (_) {}
  }
}

String _langName(String lang) {
  switch (lang) {
    case 'te':
      return 'Telugu';
    case 'hi':
      return 'Hindi';
    default:
      return 'English';
  }
}

/// Grounded "why at risk" prompt: the model must only use the detected
/// signals below and must not invent facts. Pure + unit-testable.
Map<String, String> buildExplainPrompt({
  required Set<String> families,
  required Map<String, List<String>> evidence,
  required int risk,
  required String band,
  required String scamType,
  required String lang,
}) {
  final buf = StringBuffer()
    ..writeln('Detected scam signals (risk $risk/100, $band):');
  final sorted = families.toList()..sort();
  for (final f in sorted) {
    final spans = (evidence[f] ?? const []).take(3).join('; ');
    buf.writeln('- $f${spans.isEmpty ? '' : ': "$spans"'}');
  }
  return {
    'system':
        'You explain phone-scam risk to a user in India in ${_langName(lang)}. '
        'Use ONLY the detected signals given. Do not invent new facts. '
        'The family labels describe the trick — trust them (e.g. CBI is an Indian police agency, never a bank). '
        'Keep it to 3 short sentences, plain words, no jargon.',
    'user':
        'Call classified as "$scamType".\n${buf}Explain why this call looks risky.',
  };
}

/// Grounded "what to do" prompt: short ordered steps, safety-first.
/// Pure + unit-testable.
Map<String, String> buildAdvicePrompt({
  required Set<String> families,
  required int risk,
  required String band,
  required String lang,
}) {
  final sorted = families.toList()..sort();
  return {
    'system':
        'You give phone-scam safety advice in ${_langName(lang)} to a user in India. '
        'Use ONLY the detected signals given. Do not invent new facts. '
        'Reply with at most 4 numbered steps, shortest first (hang up, protect codes, protect money, report). '
        'If money was mentioned, always include calling 1930 — this is INDIA\'s national cyber fraud helpline. '
        'The only complaint portal is https://cybercrime.gov.in. '
        'Never mention any other country\'s helplines, portals, or agencies.',
    'user':
        'Risk $risk/100 ($band). Detected: ${sorted.isEmpty ? 'no strong signals yet' : sorted.join(', ')}. '
        'What should I do right now, in order?',
  };
}

/// Grounded SMS verdict prompt: forces a one-word verdict (FRAUD / SCAM /
/// SAFE) plus a short why, in the user's language. Pure + unit-testable.
Map<String, String> buildSmsPrompt({
  required String message,
  required int risk,
  required String band,
  required List<String> signals,
  required String lang,
}) {
  final text = message.trim().length > 1000
      ? '${message.trim().substring(0, 1000)}…'
      : message.trim();
  final sig = signals.take(4).join('; ');
  return {
    'system':
        'You are an SMS fraud classifier for a user in India. Reply in ${_langName(lang)}. '
        'Use ONLY this message and these detected signals. Do not invent new facts. '
        'First line must be exactly one word: FRAUD, SCAM, or SAFE. '
        'FRAUD means clearly malicious (credential theft, phishing link, money trap). '
        'SCAM means suspicious but not conclusive. '
        'SAFE means no fraud signs. '
        'Then at most 2 short sentences explaining why, in plain words.',
    'user':
        'Rule-engine risk $risk/100 ($band). Signals: ${sig.isEmpty ? 'none' : sig}. '
        'Message:\n"""$text"""\nIs it FRAUD, SCAM, or SAFE?',
  };
}

/// Extracts the assistant text from an OpenAI-compatible chat response.
/// Null-safe: returns null on any unexpected shape.
String? parseChatText(Map<String, dynamic> json) {
  try {
    final choices = json['choices'];
    if (choices is! List || choices.isEmpty) return null;
    final first = choices.first;
    if (first is! Map) return null;
    final msg = first['message'];
    if (msg is! Map) return null;
    final content = msg['content'];
    if (content is! String) return null;
    final t = content.trim();
    return t.isEmpty ? null : t;
  } catch (_) {
    return null;
  }
}

/// Thin client for the Agnes chat API. Never throws — null on any
/// failure (no key, no opt-in, offline, timeout, bad response).
class AgnesClient {
  AgnesClient._();

  static Future<String?> _chat(
    Map<String, String> prompt, {
    http.Client? client,
  }) async {
    if (!AgnesConfig.isConfigured) return null;
    if (!AgnesConsent.isOn) return null;
    final system = prompt['system'] ?? '';
    final user = prompt['user'] ?? '';
    if (system.isEmpty || user.isEmpty) return null;
    final http.Client c = client ?? http.Client();
    final owned = client == null;
    try {
      final res = await c
          .post(
            Uri.parse('${AgnesConfig.baseUrl}/chat/completions'),
            headers: {
              'content-type': 'application/json',
              'authorization': 'Bearer ${AgnesConfig.apiKey}',
            },
            body: jsonEncode({
              // Generous budget: this model spends tokens on hidden
              // reasoning first; a small cap returns empty content.
              'model': AgnesConfig.model,
              'temperature': 0.3,
              'max_tokens': 1000,
              'messages': [
                {'role': 'system', 'content': system},
                {'role': 'user', 'content': user},
              ],
            }),
          )
          .timeout(const Duration(seconds: 30));
      if (res.statusCode != 200) return null;
      final body = jsonDecode(res.body);
      if (body is! Map<String, dynamic>) return null;
      return parseChatText(body);
    } catch (_) {
      return null;
    } finally {
      if (owned) c.close();
    }
  }

  /// AI "Why am I at risk?" paragraph, or null when unavailable.
  static Future<String?> explain({
    required Set<String> families,
    required Map<String, List<String>> evidence,
    required int risk,
    required String band,
    required String scamType,
    required String lang,
    http.Client? client,
  }) =>
      _chat(
        buildExplainPrompt(
          families: families,
          evidence: evidence,
          risk: risk,
          band: band,
          scamType: scamType,
          lang: lang,
        ),
        client: client,
      );

  /// AI SMS verdict (FRAUD / SCAM / SAFE + why), or null when unavailable.
  static Future<String?> analyzeSms({
    required String message,
    required int risk,
    required String band,
    required List<String> signals,
    required String lang,
    http.Client? client,
  }) =>
      _chat(
        buildSmsPrompt(
          message: message,
          risk: risk,
          band: band,
          signals: signals,
          lang: lang,
        ),
        client: client,
      );

  /// AI "What should I do?" steps, or null when unavailable.
  static Future<String?> advise({
    required Set<String> families,
    required int risk,
    required String band,
    required String lang,
    http.Client? client,
  }) =>
      _chat(
        buildAdvicePrompt(
          families: families,
          risk: risk,
          band: band,
          lang: lang,
        ),
        client: client,
      );
}
