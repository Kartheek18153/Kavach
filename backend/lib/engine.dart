/// Rule engine ported from the Flutter demo simulator.
/// KEEP IN SYNC with lib/demo/simulator.dart (same groups, points,
/// thresholds 31/61, hard-trigger, safe-word -20).
library;

/// One keyword group: name, danger points, trigger words.
typedef KeywordGroup = (String name, int points, List<String> words);

const List<KeywordGroup> keywordGroups = [
  (
    'authority',
    20,
    ['cbi', 'police', 'customs', 'trai', 'rbi', 'court', 'officer']
  ),
  (
    'threat',
    25,
    ['arrest', 'warrant', 'case', 'jail', 'legal']
  ),
  (
    'secrecy',
    25,
    ['secret', 'cheppakandi', 'cut cheyyakandi', 'disconnect']
  ),
  (
    'urgency',
    10,
    ['immediately', 'ippude', 'one hour', 'tonight', 'ventane']
  ),
  (
    'sensitive',
    35,
    ['otp', 'pin', 'cvv', 'aadhaar', 'aadhar', 'password', 'card']
  ),
  (
    'remote',
    35,
    ['anydesk', 'teamviewer', 'screen share', 'screen']
  ),
  (
    'money',
    30,
    ['safe account', 'transfer', 'refund', 'upi', '₹', 'rs.']
  ),
];

/// Risk band thresholds shared with the app.
String riskLevelFor(int risk) {
  if (risk >= 61) return 'danger';
  if (risk >= 31) return 'caution';
  return 'safe';
}

/// Groups matched by [text] that are not yet in [seen].
List<(String, int)> matchGroups(String text, Set<String> seen) {
  final t = text.toLowerCase();
  final out = <(String, int)>[];
  for (final (name, points, words) in keywordGroups) {
    if (!seen.contains(name) && words.any(t.contains)) {
      out.add((name, points));
    }
  }
  return out;
}

/// Safe-word discount: trusted family word lowers risk by 20.
int safeWordBonus(String text, String safeWord) {
  final w = safeWord.trim().toLowerCase();
  if (w.isEmpty) return 0;
  return text.toLowerCase().contains(w) ? 20 : 0;
}

/// Hard-trigger rule: authority + sensitive/money, or secrecy + money.
bool hardTriggered(Set<String> seen) {
  return (seen.contains('authority') &&
          (seen.contains('sensitive') || seen.contains('money'))) ||
      (seen.contains('secrecy') && seen.contains('money'));
}

String scamTypeFor(Set<String> seen, {required bool isScam}) {
  if (seen.contains('authority')) return 'Fake police / Digital arrest';
  if (seen.contains('remote')) return 'Screen-share fraud';
  if (seen.contains('sensitive') || seen.contains('money')) {
    return isScam ? 'Bank / OTP fraud' : 'Checking...';
  }
  if (seen.isEmpty) return '-';
  return 'Suspicious pattern';
}

String groupReason(String name) {
  switch (name) {
    case 'authority':
      return 'Caller claims to be police / CBI / customs';
    case 'threat':
      return 'Threatens arrest or legal action';
    case 'secrecy':
      return 'Tells you to keep the call secret';
    case 'urgency':
      return 'Creates false urgency ("right now")';
    case 'sensitive':
      return 'Asks for OTP / PIN / Aadhaar';
    case 'remote':
      return 'Asks to install a screen-sharing app';
    case 'money':
      return 'Asks to transfer money / UPI';
    default:
      return name;
  }
}

List<String> reasonsFor(Set<String> seen) =>
    seen.map(groupReason).toList(growable: false);

String reasonsTeluguFor(Set<String> seen) {
  if (seen.isEmpty) return '';
  if (seen.contains('authority') && seen.contains('sensitive')) {
    return 'Ee caller police ani cheppi OTP adugutunnadu. Idi scam - phone cut cheyyandi.';
  }
  if (seen.contains('authority')) {
    return 'Ee caller police / CBI ani cheptunnadu. Nijamaina police phone lo threat cheyyaru.';
  }
  if (seen.contains('sensitive') || seen.contains('money')) {
    return 'OTP / PIN / dabbulu adige call scam ayyundavachu. Evariki cheppakandi ani ante inka danger.';
  }
  if (seen.contains('remote')) {
    return 'Screen share app install cheyamante cheppakandi. Idi scam trick.';
  }
  return 'Konchem anumananga undi - jagratta ga undandi.';
}
