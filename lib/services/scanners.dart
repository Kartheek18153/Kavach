/// Offline rule engines for the Scan tools + shared Tier-1 tactic engine.
///
/// Pure Dart (no Flutter imports) so it stays unit-testable. Call and SMS
/// scoring run the Tier-1 tactic engine (tactic_engine.dart): 5 families,
/// trilingual markers, guards, decay, diversity rule. Same bands everywhere:
/// Safe 0-30 / Caution 31-60 / Danger 61+.
library;

import 'sim_swap_api.dart';
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
  r'(share|send|tell|enter|type|provide|give|forward|verify|batao|bataiye|bhejo|daliye).{0,40}(otp|pin|cvv|password|card number|card no|aadhaar|aadhar|net.?banking|account number|customer.?id|debit card|credit card)|(otp|pin|cvv|password|card number|aadhaar).{0,40}(share|send|tell|enter|verify|batao|bataiye|bhejo)',
  caseSensitive: false,
);

/// Explicit payment instruction ("pay Rs 5000") - same HIGH pairing.
final _paymentPattern = RegExp(
  r'(pay|transfer|send|deposit|processing.?fee|advance|refund|collect).{0,40}(₹|rs\.?|inr|upi|amount|account|fee|charge|deposit|duty|tax|bill)|upi://',
  caseSensitive: false,
);

/// Urgency phrasing the lexicon may not cover word-for-word. Only counted
/// alongside a link (or other signals) — never alone.
final _urgencyPattern = RegExp(
  r'block|suspend|deactivat|expir|urgent|immediately|24 hours|today only|last date|discontinu|disconnect|tonight|midnight|\d+\s*hrs?|final notice|last warning|cut.?off|power.?cut',
  caseSensitive: false,
);

/// Smishing lure families from real-world 2024-26 campaigns (KYC, power,
/// parcel, prize, job, scheme, emergency, APK). Each matched family is one
/// evidence unit, counted only when a link, credential ask, or payment
/// instruction is also present — lures alone never convict.
const _parcelLures = {
  'parcel',
  'courier',
  'delivery',
  'shipment',
  'tracking',
  'customs',
  'duty',
  'redelivery',
  'indiapost',
  'bluedart',
  'fedex',
  'dhl',
  'post',
};

const _prizeLures = {
  'prize',
  'lottery',
  'winner',
  'lucky draw',
  'kbc',
  'jackpot',
  'congratulations',
};

const _jobLures = {
  'part time',
  'part-time',
  'work from home',
  'earn',
  'telegram',
  'prepaid',
  'unlock',
  'per day',
  'daily income',
  'rating',
};

const _utilityLures = {
  'electric',
  'bijli',
  'power',
  'discom',
  'bses',
  'tata power',
  'adani',
  'bescom',
  'tneb',
  'tangedco',
  'msedcl',
  'bill',
};

const _schemeLures = {
  'kyc',
  'pan ',
  'aadhaar',
  'aadhar',
  'income tax',
  'incometax',
  'refund',
  'subsidy',
  'pension',
  'trai',
  'sim card',
  'sim swap',
  'ckyc',
};

const _emergencyLures = {
  'accident',
  'hospital',
  'emergency',
  'stuck',
  'bail',
  'operation',
  'icu',
  'urgent help',
};

const _installLures = {
  '.apk',
  'install',
  'download the app',
  'update the app',
  'apk file',
};

/// Callback-number lure: a dialable number inside a threat/pressure
/// message. Legit helplines lack the threat context, so they stay safe.
final _callbackPattern = RegExp(
  r'(\b\d{10}\b|1[89]00[\s-]?\d+)',
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

  // Message-Guard evidence classification (reference SmsMessageAnalyzer),
  // extended with real-world smishing lure families (KYC, power, parcel,
  // prize, job, scheme, emergency, APK). Lures corroborate — they count
  // only with a link, credential ask, or payment instruction present.
  final suspiciousLink = worstLink >= 50;
  final credential = _credentialPattern.hasMatch(t);
  final payment = _paymentPattern.hasMatch(t);
  final urgency = _urgencyPattern.hasMatch(t);
  final hasLink = links.isNotEmpty;
  final low = t.toLowerCase();
  var evidences = snap.families.length;
  if (suspiciousLink) {
    evidences++;
  } else if (hasLink) {
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
      (suspiciousLink ||
          hasLink ||
          snap.families.isNotEmpty ||
          credential ||
          payment)) {
    reasons.add('False deadline pressure ("blocked / today only").');
    evidences++;
  }
  const lureGroups = {
    'Parcel / courier': _parcelLures,
    'Prize / lottery': _prizeLures,
    'Job / task': _jobLures,
    'Utility bill': _utilityLures,
    'KYC / tax / scheme': _schemeLures,
    'Emergency': _emergencyLures,
    'App install': _installLures,
  };
  var lureCount = 0;
  if (hasLink || credential || payment) {
    for (final entry in lureGroups.entries) {
      final hits =
          entry.value.where((w) => low.contains(w)).toList();
      if (hits.isNotEmpty) {
        lureCount++;
        evidences++;
        reasons.add('${entry.key} lure ("${hits.first}").');
      }
    }
  }
  if ((urgency || credential || payment || snap.families.isNotEmpty) &&
      _callbackPattern.hasMatch(t)) {
    evidences++;
    reasons.add(
        'Includes a callback number — verify it independently, never dial it blindly.');
  }
  final apkLink =
      links.any((l) => l.toLowerCase().contains('.apk'));
  if ((suspiciousLink && (credential || payment)) ||
      snap.families.length >= 3) {
    if (risk < 70) risk = 70;
    reasons.add('Link + instruction combo — classic phishing shape.');
  } else if (suspiciousLink && urgency && lureCount >= 1) {
    if (risk < 70) risk = 70;
    reasons.add('Suspicious link + deadline + lure — classic phishing shape.');
  } else if (apkLink && lureCount >= 1) {
    if (risk < 70) risk = 70;
    reasons.add('App download pushed by a lure message — likely malware.');
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

/// Ported detection layers from the hackathon2026 QR + UPI Scam Detection
/// Engine (rule codes, weights and floors kept; bands stay this app's
/// Safe 0-30 / Caution 31-60 / Danger 61+).
///
/// Layers: known-suspect blocklist (+80), impersonation keywords (30/15),
/// typosquat (+25), random/machine-minted handles (35/20), reverse-collect
/// (+35), mandate hijack (floor 85), tamper guards (duplicate +35,
/// zero-width +30, obfuscation +20, currency +30, high-value P2P +25).

/// Starter threat repository (mock I4C/LEA fixtures from the reference
/// engine). Exact-match, lower-cased. Replace with a live feed when
/// available; unknown IDs are UNVERIFIED, never safe.
const _suspectVpas = {
  'refund-officer@ybl',
  'customs-clearance-fee@upi',
  'kyc-support01@axl',
  'army-canteen-offer@ibl',
  'phonepecashback2024@ybl',
  'rbi-refund-dept@paytm',
};

/// Suspect phones, last-10-digits form.
const _suspectPhones = {
  '9876543210',
  '9123456780',
};

const _suspectHandles = {
  'fake-refund-desk',
};

/// PSP / bank handles seen in legitimate Indian UPI traffic. Anything else
/// is untrusted (small weight, not a block).
const _trustedPspHandles = {
  'okhdfcbank',
  'okicici',
  'oksbi',
  'okaxisbank',
  'okaxis',
  'ybl',
  'ibl',
  'axl',
  'apl',
  'upi',
  'paytm',
  'phonepe',
  'airtel',
  'jio',
  'slice',
  'navi',
  'cred',
  'superyes',
  'yesbank',
  'idfcbank',
  'cmsidfc',
  'indus',
  'hsbc',
  'dbs',
  'freecharge',
  'mobikwik',
  'kotak',
  'rbl',
  'federal',
  'pnb',
  'bob',
  'canara',
  'unionbank',
  'okbizaxis',
  'sbi',
  'hdfc',
  'icici',
};

/// Personal-use handles most abused in impersonation scams.
const _personalPspHandles = {
  'ybl',
  'ibl',
  'axl',
  'apl',
  'upi',
  'paytm',
  'phonepe',
};

/// High-precision refund / authority / KYC scam keywords.
const _impersonationKeywords = {
  'refund',
  'custom',
  'customs',
  'support',
  'kyc',
  'rbi',
  'bank',
  'officer',
  'army',
  'navy',
  'airforce',
  'police',
  'cbi',
  'incometax',
  'income',
  'gst',
  'electricity',
  'loan',
  'prize',
  'lottery',
  'cashback',
  'reward',
  'verif',
  'blocked',
  'suspend',
  'helpline',
  'care',
  'service',
  'claim',
  'bonus',
  'offer',
};

/// Brand tokens for typosquat / lookalike detection.
const _brandTokens = {
  'gpay',
  'googlepay',
  'googlepe',
  'phonepe',
  'phonepay',
  'paytm',
  'paytem',
  'bhim',
  'upi',
  'rbi',
  'sbi',
  'hdfc',
  'icici',
  'axis',
  'amazon',
  'flipkart',
};

/// Urgency / secrecy pressure in transaction notes.
const _pressureKeywords = {
  'urgent',
  'immediately',
  'secret',
  'otp',
  'pin',
  'cvv',
  'expir',
  'last chance',
  'block',
  'suspend',
  'do not tell',
  'dont tell',
  'confidential',
};

/// Merchant-name hints for the P2M-spoof check.
const _merchantNameHints = {
  'ltd',
  'pvt',
  'store',
  'mart',
  'shop',
  'merchant',
  'bazaar',
  'traders',
  'enterprise',
  'electricity',
  'utility',
  'board',
  'department',
  'govt',
  'bill',
};

/// Deceptive "you will receive" phrases inside a debit (tn) note.
const _incomingLureHints = {
  'receive',
  'refund',
  'cashback',
  'prize',
  'reward',
  'collect',
  'incoming',
  'credit',
  'claim',
  'bonus',
  'lottery',
};

/// Consumer P2P handles — large amounts here with no MCC are unverified.
const _nonMerchantHandles = {
  'ybl',
  'ibl',
  'axl',
  'apl',
  'upi',
  'paytm',
  'phonepe',
  'okhdfcbank',
  'okicici',
  'oksbi',
  'okaxis',
  'okaxisbank',
};

const _zeroWidthChars = ['\u200b', '\u200c', '\u200d', '\ufeff'];

/// Critical UPI tags whose duplication signals a parser-differential attack.
const _criticalTags = {
  'pa',
  'pn',
  'mc',
  'am',
  'cu',
  'tn',
  'tr',
  'mode',
  'recurrence',
  'validitystart',
  'validityend',
  'share',
  'sign',
};

String? _hitAny(String haystack, Set<String> needles) {
  final hay = haystack.toLowerCase();
  for (final n in needles) {
    if (hay.contains(n)) return n;
  }
  return null;
}

List<String> _hitsAll(String haystack, Set<String> needles) {
  final hay = haystack.toLowerCase();
  return [for (final n in needles) if (hay.contains(n)) n];
}

/// Bounded Levenshtein distance (early exit above 2) for typosquatting.
int _levenshteinLe2(String a, String b) {
  if (a == b) return 0;
  if ((a.length - b.length).abs() > 2) return 3;
  var prev = List<int>.generate(b.length + 1, (j) => j);
  for (var i = 1; i <= a.length; i++) {
    final cur = <int>[i];
    var rowMin = i;
    for (var j = 1; j <= b.length; j++) {
      final cost = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
      cur.add([prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + cost]
          .reduce((x, y) => x < y ? x : y));
      if (cur[j] < rowMin) rowMin = cur[j];
    }
    if (rowMin > 2) return 3;
    prev = cur;
  }
  return prev[b.length];
}

String _normVpa(String v) => v.trim().toLowerCase();

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
/// [expectsIncoming] arms the reverse-collect rule (user was promised
/// incoming money but faces an outgoing debit).
({ScanFinding finding, String kind}) scoreQrUpi(String raw,
    {bool expectsIncoming = false, String? note}) {
  final kind = detectQrUpiKind(raw);
  if (kind == 'upi' && !raw.trim().toLowerCase().startsWith('upi://')) {
    return (
      finding: scoreUpi(raw,
          expectsIncoming: expectsIncoming, note: note),
      kind: kind
    );
  }
  return (
    finding: scoreQrContent(raw,
        expectsIncoming: expectsIncoming, note: note),
    kind: kind
  );
}

/// Classifies + scores pasted QR content (the decoded text behind a QR).
ScanFinding scoreQrContent(String raw,
    {bool expectsIncoming = false, String? note}) {
  final content = raw.trim();
  if (content.isEmpty) {
    return const ScanFinding(0, ['Paste the QR content to scan it.']);
  }
  final lower = content.toLowerCase();
  if (lower.startsWith('upi://')) {
    final inner = scoreUpi(content,
        expectsIncoming: expectsIncoming, note: note);
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
final _mccRegex = RegExp(r'^\d{4}$');

/// Parses a upi:// intent query into lower-cased keys (first value wins,
/// `+` treated as space like QR payloads carry it).
Map<String, String> _upiQuery(String raw) {
  final out = <String, String>{};
  final q = raw.indexOf('?');
  if (q < 0) return out;
  for (final part in raw.substring(q + 1).split('&')) {
    final eq = part.indexOf('=');
    final k =
        (eq < 0 ? part : part.substring(0, eq)).trim().toLowerCase();
    if (k.isEmpty || out.containsKey(k)) continue;
    var v = eq < 0 ? '' : part.substring(eq + 1);
    try {
      v = Uri.decodeComponent(v.replaceAll('+', ' '));
    } catch (_) {}
    out[k] = v;
  }
  return out;
}

/// Duplicate critical tags (parser-differential attack): tag -> values.
Map<String, List<String>> _duplicateUpiParams(String raw) {
  final out = <String, List<String>>{};
  final m = RegExp(r'^upi:(?://)?[a-z]+\?(.*)$',
          dotAll: true, caseSensitive: false)
      .firstMatch(raw.trim());
  if (m == null) return out;
  for (final part in (m.group(1) ?? '').split('&')) {
    final eq = part.indexOf('=');
    final k =
        (eq < 0 ? part : part.substring(0, eq)).trim().toLowerCase();
    if (!_criticalTags.contains(k)) continue;
    (out[k] ??= []).add(eq < 0 ? '' : part.substring(eq + 1));
  }
  out.removeWhere((_, v) => v.length < 2);
  return out;
}

DateTime? _parseNpciDate(String? value) {
  final text = (value ?? '').trim();
  if (text.isEmpty) return null;
  // NPCI canonical DDMMYYYY first, then common variants. Never throws.
  try {
    if (RegExp(r'^\d{8}$').hasMatch(text)) {
      return DateTime(
        int.parse(text.substring(4, 8)),
        int.parse(text.substring(2, 4)),
        int.parse(text.substring(0, 2)),
      );
    }
    if (RegExp(r'^\d{2}-\d{2}-\d{4}$').hasMatch(text)) {
      final p = text.split('-');
      return DateTime(int.parse(p[2]), int.parse(p[1]), int.parse(p[0]));
    }
    if (RegExp(r'^\d{2}/\d{2}/\d{4}$').hasMatch(text)) {
      final p = text.split('/');
      return DateTime(int.parse(p[2]), int.parse(p[1]), int.parse(p[0]));
    }
    return DateTime.parse(text);
  } catch (_) {
    return null;
  }
}

/// Mandate-hijack evaluation for upi://mandate|autopay payloads.
/// Returns a record of (hijack, weight, reasons); hijack floors risk at 85.
({bool hijack, int weight, List<String> reasons}) _mandateRisk(
    String raw) {
  final m = RegExp(r'^upi:(?://)?([a-z]+)\?(.*)$',
          dotAll: true, caseSensitive: false)
      .firstMatch(raw.trim());
  const none = (hijack: false, weight: 0, reasons: <String>[]);
  if (m == null) return none;
  final action = (m.group(1) ?? '').toLowerCase();
  if (action != 'mandate' && action != 'autopay') return none;
  final q = _upiQuery(raw);
  final recurrence = (q['recurrence'] ?? '').trim();
  final mode = (q['mode'] ?? '').trim().toLowerCase();
  final hasRecurrence = recurrence.isNotEmpty ||
      mode == 'autopay' ||
      mode == 'mandate' ||
      mode == 'recurring';
  int? windowDays;
  final start = _parseNpciDate(q['validitystart']);
  final end = _parseNpciDate(q['validityend']);
  if (start != null && end != null) {
    windowDays = end.difference(start).inDays;
  }
  final recurring = hasRecurrence ||
      (windowDays != null && windowDays > 30);
  if (!recurring) return none;
  final reasons = <String>[
    'This QR creates a *recurring* auto-debit mandate'
        '${recurrence.isNotEmpty ? ' ($recurrence)' : ''}'
        '${windowDays != null ? ' valid for $windowDays days' : ''}'
        ' — it can pull money repeatedly, not once.',
  ];
  final mc = (q['mc'] ?? '').trim();
  if (!_mccRegex.hasMatch(mc)) {
    reasons.add(
        'Recurring auto-debit to a payee with no registered corporate MCC — '
        'genuine AutoPay merchants always carry one. Authorising this hands '
        'the attacker repeat debits.');
    return (hijack: true, weight: 80, reasons: reasons);
  }
  reasons.add(
      'Recurring mandate to MCC $mc — verify the biller in your UPI app\'s '
      'AutoPay section before authorising.');
  return (hijack: false, weight: 20, reasons: reasons);
}

String _inr(double amount) => amount.toStringAsFixed(
    amount.truncateToDouble() == amount ? 0 : 2);

/// Scores a UPI ID or UPI intent string (upi://pay?... / upi://mandate?...).
///
/// [expectsIncoming] arms the reverse-collect rule: the user was promised
/// incoming money but faces an outgoing debit (receiving never needs a PIN).
/// [note] is an optional transaction note for the pressure-language rule.
ScanFinding scoreUpi(String raw,
    {bool expectsIncoming = false, String? note}) {
  final input = raw.trim();
  if (input.isEmpty) {
    return const ScanFinding(0, ['Enter a UPI ID or payment link to check.']);
  }
  var risk = 0;
  final reasons = <String>[];
  void hit(int points, String label) {
    risk += points;
    reasons.add(label);
  }

  final lower = input.toLowerCase();
  final isIntent = lower.startsWith('upi://');
  final action = isIntent
      ? RegExp(r'^upi:(?://)?([a-z]+)', caseSensitive: false)
          .firstMatch(input)
          ?.group(1)
          ?.toLowerCase()
      : null;
  final isMandate = action == 'mandate' || action == 'autopay';
  // Mandate is the only special action; anything else pays out on approve.
  final isPay = !isMandate;

  var q = <String, String>{};
  var mandateHijack = false;
  if (isIntent) {
    // ---- Tamper audit on the raw link ----
    final dupes = _duplicateUpiParams(input);
    if (dupes.isNotEmpty) {
      final tags = dupes.keys.map((t) => "'$t'").join(', ');
      hit(35,
          'QR repeats critical parameter(s) $tags — preview and payment may use different values.');
    }
    q = _upiQuery(input);
    final cu = (q['cu'] ?? '').trim();
    if (cu.isNotEmpty && !RegExp(r'^[A-Za-z]{3}$').hasMatch(cu)) {
      hit(30,
          "Currency tag '$cu' is not a valid ISO code — tampered QR trying to mask the debit currency.");
    }
    // ---- Mandate hijack ----
    final mand = _mandateRisk(input);
    for (final r in mand.reasons) {
      reasons.add(r);
    }
    if (mand.hijack) {
      mandateHijack = true;
      risk += mand.weight;
    } else {
      risk += mand.weight;
    }
    if (lower.contains('bit.ly') || lower.contains('tinyurl')) {
      hit(15, 'Payment link is shortened — destination hidden.');
    }
  }

  // ---- Resolve the VPA under test (pa tag or bare input) ----
  String vpa = '';
  String pn = '';
  String tn = (note ?? '').trim();
  String mc = '';
  double? amount;
  if (isIntent) {
    vpa = (q['pa'] ?? '').trim();
    pn = (q['pn'] ?? '').trim();
    if (tn.isEmpty) tn = (q['tn'] ?? '').trim();
    mc = (q['mc'] ?? '').trim();
    final amRaw = (q['am'] ?? '').trim().replaceAll(',', '');
    if (amRaw.isNotEmpty) amount = double.tryParse(amRaw);
    if (vpa.isEmpty) {
      return const ScanFinding(
          55, ['Payment link has no receiver address — do not pay.']);
    }
  } else if (input.contains('@')) {
    vpa = input;
    if (tn.isEmpty && note != null) tn = note.trim();
  } else {
    return const ScanFinding(
        45, ['Does not look like a UPI ID (name@bank) or payment link.']);
  }

  final v = _normVpa(vpa);
  final at = v.lastIndexOf('@');
  final local = at < 0 ? v : v.substring(0, at);
  final handle = at < 0 ? '' : v.substring(at + 1);
  final mcOk = _mccRegex.hasMatch(mc);

  // ---- Known-suspect repository (+80) ----
  if (_suspectVpas.contains(v)) {
    hit(80,
        'This payee ID is flagged in the cybercrime threat repository. It has been linked to reported fraud.');
    reasons.add(
        'Do NOT pay this ID — report it at cybercrime.gov.in or call 1930.');
  } else if (handle.isNotEmpty && _suspectHandles.contains(handle)) {
    hit(80,
        "Handle '@$handle' is a flagged fraud handle. Do NOT pay — report it at cybercrime.gov.in or call 1930.");
  } else {
    final digits = local.replaceAll(RegExp(r'\D'), '');
    final tail =
        digits.length > 10 ? digits.substring(digits.length - 10) : digits;
    if (digits.length >= 10 && _suspectPhones.contains(tail)) {
      hit(80,
          'This number is flagged in the cybercrime threat repository. Do NOT pay — call 1930.');
    }
  }

  // ---- Syntax ----
  if (!_vpaRegex.hasMatch(vpa.trim())) {
    if (isIntent) {
      hit(40, 'Receiver ID "$vpa" is malformed.');
    } else {
      return const ScanFinding(
          55, ['Not a valid UPI ID — do not send money to it.']);
    }
  }

  // ---- Invisible-character tricks on intent VPAs ----
  if (isIntent) {
    if (_zeroWidthChars.any(vpa.contains)) {
      hit(30,
          'Payee ID contains invisible zero-width characters — a blocklist-evasion trick. Do not pay.');
    } else if (vpa.runes.any((c) => c > 127)) {
      hit(20,
          'Payee ID contains non-ASCII characters — NPCI VPAs are strict ASCII; likely a lookalike spoof.');
    }
  }

  // ---- Handle trust ----
  if (handle.isNotEmpty && !_trustedPspHandles.contains(handle)) {
    hit(15,
        "Handle '@$handle' is not a recognised PSP/bank handle — verify the payee independently.");
  } else if (handle.isNotEmpty) {
    reasons.add('Known PSP handle — still verify the person before tapping Pay.');
  }

  // ---- Impersonation keywords ----
  final keyword =
      _hitAny('$local $pn $tn', _impersonationKeywords);
  if (keyword != null) {
    if (_personalPspHandles.contains(handle)) {
      hit(30,
          "Payee uses authority keyword '$keyword' on personal handle '@$handle' with no merchant credentials. Banks, RBI and customs never collect over personal IDs.");
    } else {
      hit(15,
          "Payee context contains sensitive keyword '$keyword' without merchant verification.");
    }
    final stacked = _hitsAll(local, _impersonationKeywords);
    if (stacked.length >= 2) {
      hit(10,
          'Multiple bait words stacked (${stacked.take(3).join(', ')}) — classic lure shape.');
    }
  }

  // ---- Typosquat: fragment within edit-distance 1-2 of a brand ----
  var typoFound = false;
  for (final token in _brandTokens) {
    if (typoFound) break;
    for (final frag in local.toLowerCase().split(RegExp(r'[^a-z0-9]+'))) {
      if (frag.isEmpty || frag == token || frag.length < 4) continue;
      if (_levenshteinLe2(frag, token) <= 2) {
        hit(25,
            "Payee handle '$frag' closely mimics trusted brand '$token' — a common impersonation trick.");
        typoFound = true;
        break;
      }
    }
  }

  // ---- Random / machine-minted handles (pure-digit locals are normal) ----
  final alphaOnly = local.replaceAll(RegExp(r'[^a-z]'), '');
  final isPureDigits =
      local.isNotEmpty && RegExp(r'^\d+$').hasMatch(local);
  if (!isPureDigits && alphaOnly.length >= 6 &&
      !RegExp(r'[aeiou]').hasMatch(alphaOnly)) {
    hit(35,
        "Payee handle '$local' looks auto-generated (unpronounceable, UNVERIFIED, no reputation) — scammers rotate random IDs so no database has seen them.");
  } else if (!isPureDigits && local.length >= 10) {
    final digits = local.runes
        .where((c) => c >= 48 && c <= 57)
        .length;
    if (digits / local.length >= 0.7) {
      hit(20,
          "Payee handle '$local' is mostly digits — machine-minted shape with no reputation trail.");
    }
  }

  // ---- Reverse-collect: promised credit, actual debit ----
  // Intent-only: a bare VPA is not a debit screen.
  if (expectsIncoming && isIntent && isPay && !isMandate) {
    hit(35,
        'You expected to RECEIVE money, but this screen sends money OUT — entering your UPI PIN will debit you. Decline it.');
  } else if (isIntent && isPay && tn.isNotEmpty) {
    final lure = _hitAny(tn, _incomingLureHints);
    if (lure != null) {
      hit(40,
          "Note promises '$lure' yet this is an outgoing payment — refund/prize wording inside a PAY link.");
    }
  }

  // ---- Pressure language in the note ----
  if (tn.isNotEmpty) {
    final pressured = _hitAny(tn, _pressureKeywords);
    if (pressured != null) {
      hit(10,
          "Note uses pressure language ('$pressured') typical of scams.");
    }
  }

  // ---- Receiver name ----
  if (isIntent) {
    if (pn.isEmpty) {
      hit(10, 'No receiver name shown — verify who gets the money.');
    } else if (pn.trim().length < 2) {
      hit(10,
          'Receiver name is a single letter — verify who gets the money.');
    }
    final corp = _hitAny(pn, _merchantNameHints);
    if (corp != null && !mcOk) {
      hit(35,
          "Payee claims to be '$pn' with no merchant code — genuine billers carry an MCC. Verify before paying.");
    } else if (mcOk) {
      reasons.add(
          'Registered merchant (MCC $mc) — still confirm the amount.');
    } else if (mc.isNotEmpty) {
      hit(20, "Merchant code '$mc' is malformed.");
    }
  }

  // ---- Amount ----
  if (amount != null && amount > 0) {
    if (isPay && !isMandate) {
      hit(15,
          'Asks for ₹${_inr(amount)} — a collect request. Never approve to "receive" money.');
      if (pn.trim().length < 2) {
        hit(15,
            'Collect request to an unnamed receiver — classic scam setup.');
      }
    }
    if (amount >= 50000) {
      hit(10,
          'High-value payment of ₹${_inr(amount)} — errors and fraud are costlier at this size.');
    } else if (amount >= 10000) {
      hit(5, 'Elevated payment of ₹${_inr(amount)} — check the VPA twice.');
    }
    if (amount >= 25000 &&
        !mcOk &&
        _nonMerchantHandles.contains(handle)) {
      hit(25,
          'High-value transfer of ₹${_inr(amount)} to an unverified personal account (@$handle) with no merchant credentials — confirm on a second channel.');
    }
  } else if (isIntent && !isMandate) {
    risk += 5;
    reasons.add('Always confirm the person before tapping Pay.');
  }

  risk = risk.clamp(0, 100);
  if (mandateHijack && risk < 85) risk = 85;
  return ScanFinding(risk, reasons);
}

/// Maps a completed telco verdict to a scored finding.
/// Unknown/unsupported has no gauge mapping on purpose — the screen shows
/// a warning card instead of a green meter for "could not check".
ScanFinding telcoSimSwapFinding(TelcoSimSwapResult r) {
  if (r.riskSignal == 'recent_sim_change') {
    final reasons = <String>[
      if (r.detail.isNotEmpty) r.detail,
      if (r.lastSwapAt != null && r.lastSwapAt!.isNotEmpty)
        'Last change: ${r.lastSwapAt}',
      'A recent change is a strong hijack signal — call your operator now.',
    ];
    return ScanFinding(75, reasons);
  }
  if (r.riskSignal == 'no_recent_change') {
    return ScanFinding(10, [
      if (r.detail.isNotEmpty) r.detail,
    ]);
  }
  return ScanFinding(0, [
    if (r.detail.isNotEmpty) r.detail,
    'Telco check unavailable — use the checklist below.',
  ]);
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
