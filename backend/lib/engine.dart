/// Scoring helpers on top of the Tier-1 tactic engine.
/// KEEP IN SYNC with lib/demo/simulator.dart + lib/services/tactic_engine.dart
/// (same lexicon, bands 31/61, diversity rule, safe-word -20).
library;

import 'tactic_engine.dart' as te;

/// Risk band thresholds shared with the app.
String riskLevelFor(int risk) {
  if (risk >= 61) return 'danger';
  if (risk >= 31) return 'caution';
  return 'safe';
}

/// Safe-word discount: trusted family word lowers risk by 20.
int safeWordBonus(String text, String safeWord) {
  final w = safeWord.trim().toLowerCase();
  if (w.isEmpty) return 0;
  return text.toLowerCase().contains(w) ? 20 : 0;
}

/// Scam-type headline from matched tactic families.
String scamTypeFor(Set<String> families, {required bool isScam}) =>
    te.scamTypeForFamilies(families, isScam: isScam);

/// One verdict reason per matched family.
List<String> reasonsFor(Set<String> families) =>
    te.reasonsForFamilies(families);

/// Telugu verdict summary keyed on families.
String reasonsTeluguFor(Set<String> families) =>
    te.reasonsTeluguForFamilies(families);
