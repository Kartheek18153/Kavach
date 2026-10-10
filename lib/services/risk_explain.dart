/// Explainable risk + prioritized human decision support for CyberSafe.
///
/// Pure Dart (no Flutter imports) so it stays unit-testable.
/// The Tier-1 tactic engine gives the *score*; this file answers:
///   "Why am I at risk?"  -> per-family contributions + matched signals +
///                            suspicious behaviour in EN/TE/HI.
///   "What should I do?"   -> prioritized, conditional safety actions.
///
/// Language codes: 'en' | 'te' | 'hi'.
library;

import 'tactic_engine.dart';

/// Per-family human explanation (trilingual).
class FamilyExplain {
  final String id;
  final Map<String, String> title;
  final Map<String, String> behaviour;
  final Map<String, String> whyRisky;

  const FamilyExplain({
    required this.id,
    required this.title,
    required this.behaviour,
    required this.whyRisky,
  });

  String inLang(Map<String, String> m, String lang) =>
      m[lang] ?? m['en'] ?? '';
}

const List<FamilyExplain> familyExplains = [
  FamilyExplain(
    id: 'AUTHORITY_IMPERSONATION',
    title: {
      'en': 'Fake authority',
      'te': 'నకిలీ అధికారి',
      'hi': 'नकली अधिकारी',
    },
    behaviour: {
      'en': 'Caller claims to be CBI, police, customs, TRAI or your bank\'s fraud team.',
      'te': 'కాలర్ CBI, పోలీస్, కస్టమ్స్, TRAI లేదా బ్యాంక్ ఫ్రాడ్ టీమ్ అని చెప్తున్నాడు.',
      'hi': 'कॉलर CBI, पुलिस, कस्टम, TRAI या बैंक की फ्रॉड टीम होने का दावा कर रहा है।',
    },
    whyRisky: {
      'en': 'Real officers never threaten arrest on a call or demand money/OTP. Fear + uniform = pressure tactic.',
      'te': 'నిజమైన అధికారులు ఫోన్‌లో అరెస్ట్ బెదిరించరు, డబ్బు/OTP అడగరు. భయం + యూనిఫాం = ఒత్తిడి ఎత్తుగడ.',
      'hi': 'असली अधिकारी फोन पर गिरफ्तारी की धमकी नहीं देते, पैसे/OTP नहीं मांगते। डर + वर्दी = दबाव की चाल।',
    },
  ),
  FamilyExplain(
    id: 'ISOLATION_AND_SECRECY',
    title: {
      'en': 'Secrecy pressure',
      'te': 'రహస్య ఒత్తిడి',
      'hi': 'गोपनीयता का दबाव',
    },
    behaviour: {
      'en': 'You are told to stay on the call, keep the camera on, and tell nobody — not even family.',
      'te': 'కాల్‌లోనే ఉండమని, కెమెరా ఆన్ ఉంచమని, కుటుంబానికి కూడా చెప్పవద్దని అంటున్నారు.',
      'hi': 'कॉल पर बने रहने, कैमरा ऑन रखने और परिवार तक को न बताने को कहा जा रहा है।',
    },
    whyRisky: {
      'en': 'Isolation blocks your best defence — a second opinion. Scammers insist on secrecy; real officials do not.',
      'te': 'ఒంటరితనం మీ ఉత్తమ రక్షణను అడ్డుకుంటుంది — రెండో అభిప్రాయం. మోసగాళ్లే రహస్యం కోరుతారు; నిజ అధికారులు కాదు.',
      'hi': 'अकेलापन आपकी सबसे बड़ी सुरक्षा रोकता है — दूसरी राय। ठग ही गोपनीयता मांगते हैं; असली अधिकारी नहीं।',
    },
  ),
  FamilyExplain(
    id: 'URGENCY_AND_THREAT',
    title: {
      'en': 'Threats & deadlines',
      'te': 'బెదిరింపులు & గడువులు',
      'hi': 'धमकी और समय-सीमा',
    },
    behaviour: {
      'en': 'Account freeze, SIM block, arrest or KYC expiry within hours — act NOW or else.',
      'te': 'గంటల్లో ఖాతా ఫ్రీజ్, SIM బ్లాక్, అరెస్ట్ లేదా KYC గడువు — వెంటనే చేయండి లేదంటే అంటున్నారు.',
      'hi': 'घंटों में खाता फ्रीज, SIM ब्लॉक, गिरफ्तारी या KYC समाप्ति — अभी करो वरना कहा जा रहा है।',
    },
    whyRisky: {
      'en': 'Fake urgency stops you thinking. Real deadlines come in writing, never as a shouted phone threat.',
      'te': 'నకిలీ తొందర మిమ్మల్ని ఆలోచించనివ్వదు. నిజ గడువులు రాతపూర్వకంగా వస్తాయి, ఫోన్ బెదిరింపులుగా కాదు.',
      'hi': 'नकली जल्दबाजी सोचने नहीं देती। असली समय-सीमा लिखित में आती है, फोन की धमकी में नहीं।',
    },
  ),
  FamilyExplain(
    id: 'CREDENTIAL_EXTRACTION',
    title: {
      'en': 'OTP / PIN ask',
      'te': 'OTP / PIN అడుగుతున్నారు',
      'hi': 'OTP / PIN मांग',
    },
    behaviour: {
      'en': 'Caller asks for the OTP, PIN, CVV or password that just arrived on your phone.',
      'te': 'మీ ఫోన్‌కు ఇప్పుడే వచ్చిన OTP, PIN, CVV లేదా పాస్‌వర్డ్ అడుగుతున్నారు.',
      'hi': 'आपके फोन पर अभी आया OTP, PIN, CVV या पासवर्ड मांगा जा रहा है।',
    },
    whyRisky: {
      'en': 'OTP = your signature. Whoever reads it owns the transaction. Banks never ask for it on a call.',
      'te': 'OTP = మీ సంతకం. దాన్ని చదివినవాడే లావాదేవీకి యజమాని. బ్యాంకులు ఫోన్‌లో దాన్ని ఎప్పుడూ అడగవు.',
      'hi': 'OTP = आपके हस्ताक्षर। जो इसे पढ़ ले वही लेन-देन का मालिक। बैंक फोन पर इसे कभी नहीं मांगते।',
    },
  ),
  FamilyExplain(
    id: 'REMOTE_ACCESS_AND_TRANSFER',
    title: {
      'en': 'Screen share / money move',
      'te': 'స్క్రీన్ షేర్ / డబ్బు బదిలీ',
      'hi': 'स्क्रीन शेयर / पैसे का लेन-देन',
    },
    behaviour: {
      'en': 'Caller pushes an app install (AnyDesk/TeamViewer), screen share, QR scan or a "safe account" transfer.',
      'te': 'కాలర్ యాప్ ఇన్‌స్టాల్ (AnyDesk/TeamViewer), స్క్రీన్ షేర్, QR స్కాన్ లేదా "సేఫ్ ఖాతా" బదిలీ కోరుతున్నాడు.',
      'hi': 'कॉलर ऐप इंस्टॉल (AnyDesk/TeamViewer), स्क्रीन शेयर, QR स्कैन या "सेफ खाते" में ट्रांसफर चाह रहा है।',
    },
    whyRisky: {
      'en': 'Screen access lets them watch passwords; "safe accounts" are theirs. No officer needs your screen or money.',
      'te': 'స్క్రీన్ యాక్సెస్‌తో పాస్‌వర్డ్‌లు చూస్తారు; "సేఫ్ ఖాతాలు" వాళ్లవే. ఏ అధికారికి మీ స్క్రీన్, డబ్బు అవసరం లేదు.',
      'hi': 'स्क्रीन मिलने से पासवर्ड दिखते हैं; "सेफ खाते" उन्हीं के हैं। किसी अधिकारी को आपकी स्क्रीन या पैसे नहीं चाहिए।',
    },
  ),
];

FamilyExplain? explainFor(String id) {
  for (final e in familyExplains) {
    if (e.id == id) return e;
  }
  return null;
}

/// One family's share of the current risk score.
class FamilyContribution {
  final String familyId;
  final double raw;
  final double capped;
  final double sharePct; // 0-100 of total positive signal
  final List<String> spans; // matched phrases (evidence)

  const FamilyContribution({
    required this.familyId,
    required this.raw,
    required this.capped,
    required this.sharePct,
    required this.spans,
  });
}

/// Sorted (largest first) per-family contributions for [score].
List<FamilyContribution> breakdownFor(TacticScore score) {
  var denom = 0.0;
  for (final v in score.cappedByFamily.values) {
    denom += v;
  }
  if (score.diversityBonus > 0) denom += score.diversityBonus.toDouble();
  final out = <FamilyContribution>[];
  for (final e in score.cappedByFamily.entries) {
    if (e.value <= 0) continue;
    out.add(FamilyContribution(
      familyId: e.key,
      raw: score.rawByFamily[e.key] ?? 0,
      capped: e.value,
      sharePct: denom > 0 ? (e.value / denom * 100) : 0,
      spans: List.of(score.evidence[e.key] ?? const []),
    ));
  }
  out.sort((a, b) => b.capped.compareTo(a.capped));
  return out;
}

/// Priority: 0 = do NOW, 1 = do NEXT, 2 = follow-up.
class SafetyAction {
  final String id;
  final int priority;
  final Map<String, String> title;
  final Map<String, String> detail;

  const SafetyAction({
    required this.id,
    required this.priority,
    required this.title,
    required this.detail,
  });

  String t(String lang) => title[lang] ?? title['en'] ?? id;
  String d(String lang) => detail[lang] ?? detail['en'] ?? '';
}

const _order = [
  'end_call',
  'no_otp',
  'no_apk',
  'disable_access',
  'no_money',
  'secure_accounts',
  'report_incident',
];

SafetyAction _a(
  String id,
  int p,
  Map<String, String> t,
  Map<String, String> d,
) =>
    SafetyAction(id: id, priority: p, title: t, detail: d);

/// Prioritized, conditional action plan for the current call state.
///
/// Covers every requested action:
/// end the call · don't share OTP/PIN · don't install the APK ·
/// disable suspicious accessibility · don't transfer money ·
/// secure affected accounts/SIM · report the incident.
List<SafetyAction> actionsFor({
  required Set<String> families,
  required int risk,
  required String band, // 'safe' | 'caution' | 'danger'
}) {
  final danger = band == 'danger';
  final caution = band == 'caution';
  final elevated = danger || caution || risk >= 31;
  final has = families.contains;
  final cred = has('CREDENTIAL_EXTRACTION');
  final remote = has('REMOTE_ACCESS_AND_TRANSFER');
  final secrecy = has('ISOLATION_AND_SECRECY');
  final authority = has('AUTHORITY_IMPERSONATION');
  final urgency = has('URGENCY_AND_THREAT');

  int p0(bool cond) => cond ? 0 : 1;

  final list = <SafetyAction>[
    _a(
      'end_call',
      elevated ? 0 : 2,
      {
        'en': 'End the call',
        'te': 'కాల్ కట్ చేయండి',
        'hi': 'कॉल काटें',
      },
      {
        'en': danger
            ? 'Danger score — cut the real phone call FIRST, then come back here.'
            : 'Hang up, then verify on an official number. Do not call back the same number.',
        'te': danger
            ? 'ప్రమాద స్కోర్ — ముందు నిజమైన కాల్ కట్ చేయండి, తర్వాత ఇక్కడికి రండి.'
            : 'కట్ చేసి అధికారిక నంబర్‌లో ధృవీకరించండి. అదే నంబర్‌కు తిరిగి కాల్ చేయకండి.',
        'hi': danger
            ? 'खतरे का स्कोर — पहले असली कॉल काटें, फिर यहां वापस आएं।'
            : 'काटकर आधिकारिक नंबर पर सत्यापित करें। उसी नंबर पर वापस कॉल न करें।',
      },
    ),
    _a(
      'no_otp',
      cred ? 0 : (elevated ? 1 : 2),
      {
        'en': "Don't share OTP / PIN",
        'te': 'OTP / PIN చెప్పకండి',
        'hi': 'OTP / PIN न बताएं',
      },
      {
        'en': cred
            ? 'They already asked for your code — never read it out. The SMS is for YOU only.'
            : 'No bank or officer ever needs your OTP. If asked, that alone proves fraud.',
        'te': cred
            ? 'వాళ్లు మీ కోడ్ అడిగారు — ఎప్పుడూ చదవకండి. ఆ SMS మీకోసమే.'
            : 'ఏ బ్యాంకు/అధికారికి మీ OTP అవసరం లేదు. అడిగితే అదే మోసానికి నిదర్శనం.',
        'hi': cred
            ? 'उन्होंने कोड मांगा है — कभी न पढ़ें। वह SMS सिर्फ आपके लिए है।'
            : 'किसी बैंक/अधिकारी को OTP नहीं चाहिए। मांगे तो वही धोखे का सबूत है।',
      },
    ),
    _a(
      'no_apk',
      p0(remote || (danger && (authority || urgency))),
      {
        'en': "Don't install the APK / app",
        'te': 'APK / యాప్ ఇన్‌స్టాల్ చేయకండి',
        'hi': 'APK / ऐप इंस्टॉल न करें',
      },
      {
        'en': remote
            ? 'AnyDesk / TeamViewer / APK links give them your screen. Stop any install now.'
            : 'Never install apps on a caller\'s word — only from the Play Store, by yourself.',
        'te': remote
            ? 'AnyDesk / TeamViewer / APK లింకులు మీ స్క్రీన్‌ను వాళ్లకిస్తాయి. ఇన్‌స్టాల్ ఆపండి.'
            : 'కాలర్ మాటతో యాప్‌లు ఇన్‌స్టాల్ చేయకండి — Play Store నుండే, మీరే.',
        'hi': remote
            ? 'AnyDesk / TeamViewer / APK लिंक से स्क्रीन उन तक पहुंचती है। इंस्टॉल अभी रोकें।'
            : 'कॉलर के कहने पर ऐप न डालें — सिर्फ Play Store से, खुद।',
      },
    ),
    _a(
      'disable_access',
      p0(remote),
      {
        'en': 'Disable suspicious access',
        'te': 'అనుమానాస్పద యాక్సెస్ ఆపండి',
        'hi': 'संदिग्ध एक्सेस बंद करें',
      },
      {
        'en': remote
            ? 'Stop screen share, uninstall the app, turn OFF its Accessibility permission in Settings.'
            : 'Check Settings → Accessibility: remove any app you do not recognise.',
        'te': remote
            ? 'స్క్రీన్ షేర్ ఆపండి, యాప్ తొలగించండి, Settingsలో దాని Accessibility అనుమతి OFF చేయండి.'
            : 'Settings → Accessibility చూడండి: తెలియని యాప్ ఉంటే తొలగించండి.',
        'hi': remote
            ? 'स्क्रीन शेयर रोकें, ऐप हटाएं, Settings में उसकी Accessibility अनुमति OFF करें।'
            : 'Settings → Accessibility देखें: अनजान ऐप हो तो हटाएं।',
      },
    ),
    _a(
      'no_money',
      p0(remote || cred || danger),
      {
        'en': "Don't transfer money",
        'te': 'డబ్బు పంపకండి',
        'hi': 'पैसे ट्रांसफर न करें',
      },
      {
        'en': remote || cred
            ? '"Safe / verification account" is the scammer\'s. Decline every pending UPI request.'
            : 'No fine, fee or verification is ever paid mid-call. Hang up before paying anything.',
        'te': remote || cred
            ? '"సేఫ్ / వెరిఫికేషన్ ఖాతా" మోసగాడిదే. పెండింగ్ UPI అభ్యర్థనలన్నీ తిరస్కరించండి.'
            : 'కాల్‌లో ఉండి ఎలాంటి జరిమానా/ఫీజు కట్టకండి. చెల్లించేముందు కట్ చేయండి.',
        'hi': remote || cred
            ? '"सेफ / वेरिफिकेशन खाता" ठग का है। हर लंबित UPI अनुरोध ठुकराएं।'
            : 'कॉल के बीच कोई जुर्माना/फीस नहीं दी जाती। भुगतान से पहले काटें।',
      },
    ),
    _a(
      'secure_accounts',
      secrecy || cred || remote ? 1 : (elevated ? 1 : 2),
      {
        'en': 'Secure accounts / SIM',
        'te': 'ఖాతాలు / SIM భద్రపరచండి',
        'hi': 'खाते / SIM सुरक्षित करें',
      },
      {
        'en': secrecy
            ? 'They wanted secrecy — break it: tell family now, then call your bank to freeze UPI/cards.'
            : 'Call your bank to block UPI/cards; if signal was lost, call your operator for SIM-swap.',
        'te': secrecy
            ? 'వాళ్లు రహస్యం కోరారు — బద్దలు కొట్టండి: కుటుంబానికి చెప్పి, బ్యాంకుకు కాల్ చేసి UPI/కార్డులు ఆపండి.'
            : 'బ్యాంకుకు కాల్ చేసి UPI/కార్డులు బ్లాక్ చేయండి; సిగ్నల్ పోతే ఆపరేటర్‌కు SIM-మార్పు చెప్పండి.',
        'hi': secrecy
            ? 'उन्होंने गोपनीयता चाही — तोड़ें: परिवार को बताएं, फिर बैंक से UPI/कार्ड रुकवाएं।'
            : 'बैंक से UPI/कार्ड ब्लॉक कराएं; सिग्नल गया हो तो ऑपरेटर से SIM-बदलाव जांचें।',
      },
    ),
    _a(
      'report_incident',
      danger ? 1 : (elevated ? 1 : 2),
      {
        'en': 'Report the incident',
        'te': 'ఘటనను రిపోర్ట్ చేయండి',
        'hi': 'घटना की रिपोर्ट करें',
      },
      {
        'en': 'Lost money? Call 1930 NOW, then file at cybercrime.gov.in with screenshots + number.',
        'te': 'డబ్బు పోయిందా? వెంటనే 1930కి కాల్ చేసి, స్క్రీన్‌షాట్లు + నంబర్‌తో cybercrime.gov.inలో ఫిర్యాదు చేయండి.',
        'hi': 'पैसे गए? अभी 1930 पर कॉल करें, फिर स्क्रीनशॉट + नंबर के साथ cybercrime.gov.in पर शिकायत करें।',
      },
    ),
  ];

  list.sort((a, b) {
    if (a.priority != b.priority) return a.priority.compareTo(b.priority);
    return _order.indexOf(a.id).compareTo(_order.indexOf(b.id));
  });
  // Safe + silent: keep only calm follow-ups so we never cry wolf.
  if (!elevated && families.isEmpty) {
    return list.where((e) => e.priority == 2).toList();
  }
  return list;
}
