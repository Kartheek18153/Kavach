/// Offline rule engines for the Scan tools + shared Tier-1 tactic engine.
///
/// Pure Dart (no Flutter imports) so it stays unit-testable. Call and SMS
/// scoring run the Tier-1 tactic engine (tactic_engine.dart): 5 families,
/// trilingual markers, guards, decay, diversity rule. Same bands everywhere:
/// Safe 0-30 / Caution 31-60 / Danger 61+.
library;

import 'tactic_engine.dart';

/// A scored finding from any scanner.
class ScanFinding {
  final int risk;
  final List<String> reasons;

  const ScanFinding(this.risk, [this.reasons = const []]);
}

/// Band name for a risk score (matches `riskLevelFor` in theme.dart).
String levelNameFor(int risk) {
  if (risk >= 61) return 'danger';
  if (risk >= 31) return 'caution';
  return 'safe';
}

const _shorteners = {
  'bit.ly',
  'tinyurl.com',
  't.co',
  'goo.gl',
  'ow.ly',
  'cutt.ly',
  'rebrand.ly',
  'shorturl.at',
  'is.gd',
  'buff.ly',
  'tiny.cc',
};

const _riskyTlds = {
  'tk',
  'ml',
  'ga',
  'cf',
  'gq',
  'top',
  'xyz',
  'buzz',
  'click',
  'loan',
  'win',
  'link',
  'quest',
  'sbs',
  'zip',
  'mov',
  'icu',
  'rest',
  'work',
};

/// Substring hits inside the registrable domain (their keyword-stuffing set).
const _suspiciousRegistrableWords = {
  'login',
  'signin',
  'verify',
  'account',
  'update',
  'secure',
  'banking',
  'confirm',
  'password',
  'wallet',
  'otp',
  'suspend',
  'unlock',
  'paypal',
  'kyc',
  'refund',
  'invoice',
  'gift',
  'claim',
};

/// Brands commonly spoofed in a subdomain (theirs + Indian banks/UPI).
const _spoofBrands = {
  'google',
  'paypal',
  'apple',
  'microsoft',
  'amazon',
  'facebook',
  'instagram',
  'whatsapp',
  'sbi',
  'hdfc',
  'icici',
  'paytm',
  'phonepe',
  'rbi',
};

const _lureWords = [
  'login',
  'verify',
  'verification',
  'kyc',
  'account',
  'update',
  'suspended',
  'blocked',
  'prize',
  'lottery',
  'gift',
  'reward',
  'free',
  'cashback',
  'offer',
  'refund',
  'customs',
  'police',
  'cbi',
  'income-tax',
  'incometax',
  'upi',
  'otp',
];

bool _containsWord(String haystack, String word) {
  final pattern =
      '(?:^|[^A-Za-z])${RegExp.escape(word)}(?:[^A-Za-z]|\$)';
  return RegExp(pattern, caseSensitive: false).hasMatch(haystack);
}

/// One weighted phishing indicator. Indicator set merges the offline
/// heuristics of student-arch/hackthon (phishing_check.py) with
/// India-specific extras (.apk downloads, UPI lures, query secrets).
class UrlFinding {
  final int points;
  final String label;
  const UrlFinding(this.points, this.label);
}

/// Offline URL heuristics → weighted findings (capped sum = risk).
/// Pure + deterministic: safe to unit-test and to run with no network.
List<UrlFinding> urlFindings(String raw) {
  final input = raw.trim();
  if (input.isEmpty) return const [];

  var text = input;
  final hasScheme = RegExp(r'^[a-zA-Z][a-zA-Z0-9+.-]*://').hasMatch(text);
  if (!hasScheme) text = 'https://$text';
  Uri? uri;
  try {
    uri = Uri.parse(text);
  } catch (_) {
    uri = null;
  }
  final host = (uri?.host ?? '').toLowerCase();
  if (uri == null || host.isEmpty || !host.contains('.')) {
    return const [
      UrlFinding(55,
          'Not a valid link — scammers hide the real address this way.')
    ];
  }
  final out = <UrlFinding>[];
  void hit(int points, String label) => out.add(UrlFinding(points, label));

  if (RegExp(r'^\d{1,3}(\.\d{1,3}){3}$').hasMatch(host)) {
    hit(30, 'Raw IP host ($host) — no real website name.');
  }
  if (uri.userInfo.isNotEmpty || uri.host.contains('@')) {
    hit(25, "'@' in the link — the real destination may be hidden.");
  }
  if (host.contains('xn--')) {
    hit(25, 'Punycode look-alike letters (fake brand spelling).');
  }
  if (uri.scheme == 'http') {
    hit(15, 'Plain http, no TLS — login pages must use https.');
  }
  final labels = host.split('.');
  if (labels.length > 4) {
    hit(15, 'Excessive subdomains (${labels.length - 2} levels).');
  } else if (labels.length > 3) {
    hit(8, 'Extra subdomain level — brand name may be faked inside.');
  }
  final sld = labels.length >= 2 ? labels[labels.length - 2] : host;
  if (sld.contains('-')) hit(8, 'Hyphen in the domain name.');
  if (RegExp(r'\d{3,}').hasMatch(sld)) {
    hit(8, 'Long digit run inside the domain.');
  }
  final registrable =
      labels.length >= 2 ? labels.sublist(labels.length - 2).join('.') : host;
  if (registrable.length > 25) {
    hit(10, 'Very long domain (${registrable.length} chars).');
  }
  final tld = labels.last;
  if (_riskyTlds.contains(tld)) {
    hit(12, 'Risky ending (.$tld) favoured by fake sites.');
  }
  final stuffing = _suspiciousRegistrableWords
      .where((w) => registrable.contains(w))
      .toList();
  if (stuffing.isNotEmpty) {
    stuffing.sort();
    hit(10, 'Bait words in the domain: ${stuffing.take(5).join(', ')}.');
  }
  final subLabels = labels.length > 2 ? labels.sublist(0, labels.length - 2) : const <String>[];
  final spoof = _spoofBrands.where(
      (b) => subLabels.contains(b) && !sld.contains(b));
  if (spoof.isNotEmpty) {
    hit(15, "Real brand '${spoof.first}' buried in a fake subdomain.");
  }
  if (_shorteners.contains(host) ||
      _shorteners.any((s) => host.endsWith('.$s'))) {
    hit(15, 'Shortened link hides the real destination.');
  }
  if (uri.path.split('/').length - 1 >= 4) {
    hit(5, 'Deeply nested path.');
  }
  if (RegExp(r'(base64|decode|payload|%2f)', caseSensitive: false)
      .hasMatch(text)) {
    hit(10, 'Encoded/obfuscated path segments.');
  }
  final lures = _lureWords.where((w) => _containsWord(text, w)).toList();
  if (lures.length == 1) {
    hit(15, 'Pressure word found: "${lures.first}".');
  } else if (lures.length > 1) {
    hit(25, 'Pressure words found: ${lures.take(3).join(', ')}.');
  }
  if (text.length > 75) {
    hit(10, 'Unusually long link hides where it really goes.');
  }
  final lower = text.toLowerCase();
  if (lower.endsWith('.apk') ||
      lower.contains('.apk?') ||
      lower.contains('.apk&')) {
    hit(35, 'Downloads an app (.apk) — never install from a link.');
  }
  if (RegExp(r'[?&](password|otp|pin|cvv|token)=', caseSensitive: false)
      .hasMatch(text)) {
    hit(10, 'Link itself carries a secret (password/OTP).');
  }
  return out;
}

/// Scores a link / URL for phishing signs (offline heuristics only).
ScanFinding scoreUrl(String raw) {
  if (raw.trim().isEmpty) {
    return const ScanFinding(0, ['Paste a link to scan it.']);
  }
  final findings = urlFindings(raw);
  final risk = findings.fold<int>(0, (a, f) => a + f.points).clamp(0, 100);
  final reasons = findings.map((f) => f.label).toList();
  if (risk == 0) {
    reasons.add('No phishing signs found — still verify the sender.');
  }
  return ScanFinding(risk, reasons);
}

final _urlRegex =
    RegExp(r'(https?://[^\s]+|www\.[^\s]+)', caseSensitive: false);

/// Explicit credential instruction ("share your OTP") - signals a HIGH
/// finding together with a suspicious link, like the reference Message Guard.
final _credentialPattern = RegExp(
  r'(share|send|tell|enter|type|provide|give|forward|batao|bataiye|bhejo|daliye).{0,40}(otp|pin|cvv|password)|(otp|pin|cvv|password).{0,40}(share|send|tell|enter|batao|bataiye|bhejo)',
  caseSensitive: false,
);

/// Explicit payment instruction ("pay Rs 5000") - same HIGH pairing.
final _paymentPattern = RegExp(
  r'(pay|transfer|send|deposit|processing.?fee|advance|refund|collect).{0,40}(₹|rs\.?|inr|upi|amount|account)|upi://',
  caseSensitive: false,
);

/// Urgency phrasing the lexicon may not cover word-for-word.
final _urgencyPattern = RegExp(
  r'block|suspend|deactivat|expir|urgent|immediately|24 hours|today only|last date|discontinu',
  caseSensitive: false,
);

/// Scores an SMS / message with the Tier-1 tactic engine (same lexicon as
/// calls), plus the Message-Guard evidence rules: a suspicious link paired
/// with a credential/payment instruction is HIGH; any two independent
/// evidences is CAUTION.
ScanFinding scoreSms(String text) {
  final t = text.trim();
  if (t.isEmpty) return const ScanFinding(0, ['Paste the message to scan it.']);
  final snap = TacticSession.scoreTextOnce(t);
  var risk = snap.score;
  final reasons = <String>[
    ...snap.families.map(familyDisplayEn),
  ];

  final links = _urlRegex.allMatches(t).map((m) => m.group(0)!).toList();
  var worstLink = 0;
  for (final link in links) {
    final f = scoreUrl(link);
    if (f.risk > worstLink) worstLink = f.risk;
  }
  if (links.isNotEmpty) {
    risk += (worstLink ~/ 2).clamp(0, 45);
    if (worstLink >= 31) {
      reasons.add('Embedded link looks ${worstLink >= 61 ? 'dangerous' : 'suspicious'}.');
    } else {
      reasons.add('Has a link — open only if you trust the sender.');
    }
  }

  // Message-Guard evidence classification (reference SmsMessageAnalyzer).
  final suspiciousLink = worstLink >= 50;
  final credential = _credentialPattern.hasMatch(t);
  final payment = _paymentPattern.hasMatch(t);
  final urgency = _urgencyPattern.hasMatch(t);
  var evidences = snap.families.length;
  if (suspiciousLink) {
    evidences++;
  } else if (links.isNotEmpty) {
    // A plain link still counts as half-evidence alongside tactic hits.
    if (snap.families.isNotEmpty) evidences++;
  }
  if (credential && !snap.families.contains('CREDENTIAL_EXTRACTION')) {
    reasons.add('Asks for an OTP / PIN outright.');
    evidences++;
  }
  if (payment && !snap.families.contains('REMOTE_ACCESS_AND_TRANSFER')) {
    reasons.add('Pushes a payment inside a message.');
    evidences++;
  }
  if (urgency &&
      !snap.families.contains('URGENCY_AND_THREAT') &&
      (suspiciousLink || snap.families.isNotEmpty)) {
    reasons.add('False deadline pressure ("blocked / today only").');
    evidences++;
  }
  if ((suspiciousLink && (credential || payment)) ||
      snap.families.length >= 3) {
    if (risk < 70) risk = 70;
    reasons.add('Link + instruction combo — classic phishing shape.');
  } else if (evidences >= 2 && risk < 40) {
    risk = 40;
  }

  risk = risk.clamp(0, 100);
  if (risk == 0) reasons.add('No scam signs found in this message.');
  return ScanFinding(risk, reasons);
}

bool _looksLikeUrl(String s) {
  final t = s.trim().toLowerCase();
  return t.startsWith('http://') ||
      t.startsWith('https://') ||
      t.startsWith('www.') ||
      RegExp(r'^[a-z0-9-]+(\.[a-z0-9-]+)+\b').hasMatch(t);
}

/// Detects whether pasted QR/UPI text is a payment ([upi]) or other
/// QR content ([qr]). UPI intents, bare VPAs (name@bank) and collect
/// requests count as payments; links, Wi-Fi shares and plain text as QR.
String detectQrUpiKind(String raw) {
  final content = raw.trim();
  final lower = content.toLowerCase();
  if (lower.startsWith('upi://')) return 'upi';
  if (!content.contains(RegExp(r'\s|://')) && content.contains('@')) {
    return 'upi';
  }
  if (RegExp(r'collect request|approve.*receive|receive.*approve',
          caseSensitive: false)
      .hasMatch(content)) {
    return 'upi';
  }
  return 'qr';
}

/// Unified QR + UPI check: auto-detects the content kind, runs the right
/// engine, and reports which kind was checked alongside the verdict.
({ScanFinding finding, String kind}) scoreQrUpi(String raw) {
  final kind = detectQrUpiKind(raw);
  if (kind == 'upi' && !raw.trim().toLowerCase().startsWith('upi://')) {
    return (finding: scoreUpi(raw), kind: kind);
  }
  return (finding: scoreQrContent(raw), kind: kind);
}

/// Classifies + scores pasted QR content (the decoded text behind a QR).
ScanFinding scoreQrContent(String raw) {
  final content = raw.trim();
  if (content.isEmpty) {
    return const ScanFinding(0, ['Paste the QR content to scan it.']);
  }
  final lower = content.toLowerCase();
  if (lower.startsWith('upi://')) {
    final inner = scoreUpi(content);
    return ScanFinding(
      inner.risk,
      ['QR opens a UPI payment.', ...inner.reasons],
    );
  }
  if (lower.startsWith('wifi:')) {
    return const ScanFinding(
        10, ['QR shares a Wi-Fi login — join only networks you trust.']);
  }
  if (lower.endsWith('.apk') || lower.contains('.apk')) {
    return const ScanFinding(90, [
      'QR downloads an app (.apk) — never install from a QR code.',
      'Delete it and download apps only from the Play Store.',
    ]);
  }
  if (_looksLikeUrl(content)) {
    final inner = scoreUrl(content);
    return ScanFinding(
      inner.risk,
      ['QR opens a link.', ...inner.reasons],
    );
  }
  var risk = 5;
  final reasons = <String>['QR holds plain text — safe to read.'];
  if (['otp', 'pin', 'password', 'upi', 'account'].any((w) => _containsWord(content, w))) {
    risk = 35;
    reasons.add('Text mentions secrets — do not forward or act on it.');
  }
  return ScanFinding(risk, reasons);
}

final _vpaRegex = RegExp(r'^[\w.\-]{2,256}@[a-zA-Z]{2,64}$');

/// Scores a UPI ID or UPI intent string (upi://pay?...).
ScanFinding scoreUpi(String raw) {
  final input = raw.trim();
  if (input.isEmpty) {
    return const ScanFinding(0, ['Enter a UPI ID or payment link to check.']);
  }
  var risk = 0;
  final reasons = <String>[];
  final lower = input.toLowerCase();

  if (lower.startsWith('upi://')) {
    Uri? uri;
    try {
      uri = Uri.parse(input);
    } catch (_) {
      uri = null;
    }
    final q = uri?.queryParameters ?? {};
    final pa = (q['pa'] ?? '').trim();
    final pn = (q['pn'] ?? '').trim();
    final am = (q['am'] ?? '').trim();
    if (pa.isEmpty) {
      return const ScanFinding(
          55, ['Payment link has no receiver address — do not pay.']);
    }
    if (!_vpaRegex.hasMatch(pa)) {
      risk += 40;
      reasons.add('Receiver ID "$pa" is malformed.');
    }
    if (pn.isEmpty) {
      risk += 10;
      reasons.add('No receiver name shown — verify who gets the money.');
    }
    if (pn.isNotEmpty && pn.trim().length < 2) {
      risk += 10;
      reasons.add('Receiver name is a single letter — verify who gets the money.');
    }
    final handle = pa.split('@').first.toLowerCase();
    if (RegExp(r'offer|prize|cashback|lotto|reward|rbi|police|cbi|bank-official')
        .hasMatch(handle)) {
      risk += 25;
      reasons.add('Receiver name looks like bait ("$handle").');
    }
    if (RegExp(r'^\d{8,}$').hasMatch(handle)) {
      risk += 15;
      reasons.add('Receiver is a bare number, not a named account.');
    }
    final amount = double.tryParse(am);
    if (amount != null && amount > 0) {
      risk += 15;
      reasons.add('Asks for ₹${amount.toStringAsFixed(amount.truncateToDouble() == amount ? 0 : 2)} — a collect request. Never approve to "receive" money.');
      if (pn.trim().length < 2) {
        risk += 15;
        reasons.add('Collect request to an unnamed receiver — classic scam setup.');
      }
    } else {
      risk += 5;
      reasons.add('Always confirm the person before tapping Pay.');
    }
    if (lower.contains('bit.ly') || lower.contains('tinyurl')) {
      risk += 15;
      reasons.add('Payment link is shortened — destination hidden.');
    }
  } else if (input.contains('@')) {
    if (_vpaRegex.hasMatch(input)) {
      risk = 5;
      reasons.add('Valid UPI ID format — still verify the person first.');
      final handle = input.split('@').first.toLowerCase();
      if (RegExp(r'offer|prize|cashback|lotto').hasMatch(handle)) {
        risk = 40;
        reasons.add('Handle looks like bait ("$handle").');
      }
    } else {
      risk = 55;
      reasons.add('Not a valid UPI ID — do not send money to it.');
    }
  } else {
    return const ScanFinding(
        45, ['Does not look like a UPI ID (name@bank) or payment link.']);
  }

  risk = risk.clamp(0, 100);
  return ScanFinding(risk, reasons);
}

/// SIM-swap risk checklist: each `true` answer adds 20 points.
ScanFinding scoreSimSwap(List<bool> answers) {
  const labels = [
    'Signal lost suddenly without reason.',
    'Cannot call or send SMS anymore.',
    'Others say your number is switched off.',
    'Getting OTPs you never asked for.',
    'Bank/SIM messages about a new SIM or eSIM.',
  ];
  var risk = 0;
  final reasons = <String>[];
  var count = 0;
  for (var i = 0; i < answers.length && i < labels.length; i++) {
    if (answers[i]) {
      risk += 20;
      count++;
      reasons.add(labels[i]);
    }
  }
  if (count >= 3) {
    risk += 5;
    reasons.add('Multiple signs together — much stronger signal.');
  }
  risk = risk.clamp(0, 100);
  if (risk == 0) {
    reasons.add('No SIM-swap signs — your number looks in your control.');
  } else if (risk >= 61) {
    reasons.add('Treat as SIM-swap until proven otherwise — call your operator now.');
  }
  return ScanFinding(risk, reasons);
}
