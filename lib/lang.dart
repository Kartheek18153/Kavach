import 'package:flutter/material.dart';

import 'theme.dart';

/// App-wide language: English, Telugu, Hindi.
enum AppLang { english, telugu, hindi }

extension AppLangX on AppLang {
  /// Short label shown on the toggle button.
  String get buttonLabel {
    switch (this) {
      case AppLang.english:
        return 'EN';
      case AppLang.telugu:
        return 'తె';
      case AppLang.hindi:
        return 'हिं';
    }
  }

  /// Full name shown in the home language picker.
  String get nativeName {
    switch (this) {
      case AppLang.english:
        return 'English';
      case AppLang.telugu:
        return 'తెలుగు';
      case AppLang.hindi:
        return 'हिन्दी';
    }
  }

  AppLang get next {
    switch (this) {
      case AppLang.english:
        return AppLang.telugu;
      case AppLang.telugu:
        return AppLang.hindi;
      case AppLang.hindi:
        return AppLang.english;
    }
  }
}

/// Inherited language state + lookup.
class LangScope extends InheritedWidget {
  const LangScope({
    super.key,
    required this.lang,
    required this.onLang,
    required super.child,
  });

  final AppLang lang;
  final ValueChanged<AppLang> onLang;

  static LangScope of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<LangScope>()!;

  @override
  bool updateShouldNotify(LangScope old) => lang != old.lang;
}

extension TrX on BuildContext {
  AppLang get appLang => LangScope.of(this).lang;

  /// Localized string for [key]; falls back to English, then the key.
  String tr(String key) {
    final m = _strings[key];
    if (m == null) return key;
    return m[appLang] ?? m[AppLang.english] ?? key;
  }

  /// Localized string with `{name}` placeholders replaced from [params].
  String trP(String key, Map<String, String> params) {
    var s = tr(key);
    params.forEach((k, v) => s = s.replaceAll('{$k}', v));
    return s;
  }
}

/// Localized risk-band label (single language, unlike the bilingual pair).
String riskLabel(RiskLevel level, AppLang lang) {
  switch (lang) {
    case AppLang.telugu:
      return level.telugu;
    case AppLang.hindi:
      switch (level) {
        case RiskLevel.safe:
          return 'सुरक्षित';
        case RiskLevel.caution:
          return 'सावधान';
        case RiskLevel.danger:
          return 'खतरा';
      }
    case AppLang.english:
      return level.label;
  }
}

/// Toggle button: shows current language, taps cycle EN → తె → हिं.
class LangButton extends StatelessWidget {
  const LangButton({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = LangScope.of(context);
    return TextButton.icon(
      onPressed: () => scope.onLang(scope.lang.next),
      icon: const Icon(Icons.translate_rounded,
          size: 18, color: CyberSafeColors.teal),
      label: Text(
        scope.lang.buttonLabel,
        style: const TextStyle(
          color: CyberSafeColors.teal,
          fontWeight: FontWeight.w800,
          fontSize: 14,
        ),
      ),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        minimumSize: const Size(0, 36),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: CyberSafeColors.line),
        ),
        backgroundColor: CyberSafeColors.surface,
      ),
    );
  }
}

const Map<String, Map<AppLang, String>> _strings = {
  // Bottom tabs
  'tabHome': {
    AppLang.english: 'Home',
    AppLang.telugu: 'హోమ్',
    AppLang.hindi: 'होम',
  },
  'tabLive': {
    AppLang.english: 'Live',
    AppLang.telugu: 'లైవ్',
    AppLang.hindi: 'लाइव',
  },
  'tabFamily': {
    AppLang.english: 'Family',
    AppLang.telugu: 'కుటుంబం',
    AppLang.hindi: 'परिवार',
  },
  'tabReport': {
    AppLang.english: 'Report',
    AppLang.telugu: 'రిపోర్ట్',
    AppLang.hindi: 'रिपोर्ट',
  },
  // Home
  'brandSub': {
    AppLang.english: 'CyberSafe | Scam Call Shield',
    AppLang.telugu: 'సైబర్‌సేఫ్ | స్కామ్ కాల్ షీల్డ్',
    AppLang.hindi: 'साइबरसेफ | स्कैम कॉल शील्ड',
  },
  'ready': {
    AppLang.english: 'READY',
    AppLang.telugu: 'సిద్ధం',
    AppLang.hindi: 'तैयार',
  },
  'heroTitle': {
    AppLang.english: 'Call on speaker? We are listening with you.',
    AppLang.telugu: 'స్పీకర్‌పై కాల్? మేము మీతో పాటు వింటున్నాం.',
    AppLang.hindi: 'स्पीकर पर कॉल है? हम आपके साथ सुन रहे हैं।',
  },
  'heroSub': {
    AppLang.english:
        'Tap Protect with speaker on - we warn you the moment it smells like fraud.',
    AppLang.telugu:
        'స్పీకర్ ఆన్ చేసి Protect నొక్కండి - మోసం అనిపిస్తే వెంటనే హెచ్చరిస్తాం.',
    AppLang.hindi:
        'स्पीकर ऑन करके Protect दबाएं - धोखा लगे तो तुरंत चेताएंगे।',
  },
  'protectBtn': {
    AppLang.english: 'Protect this call',
    AppLang.telugu: 'ఈ కాల్‌ను రక్షించండి',
    AppLang.hindi: 'इस कॉल को सुरक्षित करें',
  },
  'langTitle': {
    AppLang.english: 'Listening language',
    AppLang.telugu: 'వినే భాష',
    AppLang.hindi: 'सुनने की भाषा',
  },
  'familyAlert': {
    AppLang.english: 'Family alert',
    AppLang.telugu: 'కుటుంబ హెచ్చరిక',
    AppLang.hindi: 'परिवार अलर्ट',
  },
  'notSet': {
    AppLang.english: 'Not set yet',
    AppLang.telugu: 'ఇంకా సెట్ చేయలేదు',
    AppLang.hindi: 'अभी सेट नहीं',
  },
  'connected': {
    AppLang.english: 'Connected ',
    AppLang.telugu: 'కనెక్ట్ అయింది ',
    AppLang.hindi: 'जुड़ गया ',
  },
  'lastScan': {
    AppLang.english: 'Last scan',
    AppLang.telugu: 'గత స్కాన్',
    AppLang.hindi: 'पिछला स्कैन',
  },
  'noCalls': {
    AppLang.english: 'No calls yet',
    AppLang.telugu: 'ఇంకా కాల్స్ లేవు',
    AppLang.hindi: 'अभी कोई कॉल नहीं',
  },
  'howItWorks': {
    AppLang.english: 'How it works',
    AppLang.telugu: 'ఎలా పనిచేస్తుంది',
    AppLang.hindi: 'यह कैसे काम करता है',
  },
  'step1t': {
    AppLang.english: 'Answer + speaker',
    AppLang.telugu: 'ఆన్సర్ + స్పీకర్',
    AppLang.hindi: 'उठाएं + स्पीकर',
  },
  'step1s': {
    AppLang.english: 'Pick up and put the call on speaker',
    AppLang.telugu: 'Call lift chesi speaker on cheyyandi',
    AppLang.hindi: 'कॉल उठाकर स्पीकर ऑन करें',
  },
  'step2t': {
    AppLang.english: 'Tap Protect',
    AppLang.telugu: 'Protect నొక్కండి',
    AppLang.hindi: 'Protect दबाएं',
  },
  'step2s': {
    AppLang.english: 'CyberSafe listens, you watch the meter',
    AppLang.telugu: 'CyberSafe vintundi, meter chudandi',
    AppLang.hindi: 'साइबरसेफ सुनेगा, आप मीटर देखें',
  },
  'step3t': {
    AppLang.english: 'We warn + alert family',
    AppLang.telugu: 'మేము హెచ్చరిస్తాం + కుటుంబానికి చెప్తాం',
    AppLang.hindi: 'हम चेताएंगे + परिवार को बताएंगे',
  },
  'step3s': {
    AppLang.english: 'If it turns red, cut the call',
    AppLang.telugu: 'Red vasthe cut cheyyandi',
    AppLang.hindi: 'लाल दिखे तो काट दें',
  },
  'emergency': {
    AppLang.english: 'Already lost money? Call 1930 now, then your bank.',
    AppLang.telugu: 'డబ్బు పోయిందా? వెంటనే 1930కి కాల్ చేయండి, తర్వాత బ్యాంకుకు.',
    AppLang.hindi: 'पैसे गंवा दिए? अभी 1930 पर कॉल करें, फिर बैंक को।',
  },
  'privacyNote': {
    AppLang.english: 'No recording - listens live on your phone only',
    AppLang.telugu: 'రికార్డింగ్ ఉండదు - మీ ఫోన్‌లోనే ప్రత్యక్షంగా వింటుంది',
    AppLang.hindi: 'रिकॉर्डिंग नहीं - सिर्फ आपके फोन पर लाइव सुनता है',
  },
  'privacyTitle': {
    AppLang.english: 'Private by design',
    AppLang.telugu: 'గోప్యతే మా డిజైన్',
    AppLang.hindi: 'प्राइवेसी हमारी डिज़ाइन',
  },
  'privacyBody': {
    AppLang.english:
        'CyberSafe never records, saves, or uploads your calls. It listens live on your device only while Protect is on - and forgets everything the moment the call ends.',
    AppLang.telugu:
        'CyberSafe మీ కాల్స్‌ను రికార్డ్ చేయదు, సేవ్ చేయదు, అప్‌లోడ్ చేయదు. Protect ఆన్‌లో ఉన్నప్పుడు మాత్రమే మీ ఫోన్‌లోనే వింటుంది - కాల్ ముగియగానే అన్నీ మర్చిపోతుంది.',
    AppLang.hindi:
        'साइबरसेफ आपकी कॉल रिकॉर्ड, सेव या अपलोड नहीं करता। सिर्फ Protect ऑन रहने पर आपके डिवाइस पर लाइव सुनता है - कॉल खत्म होते ही सब भूल जाता है।',
  },
  'privacyReport': {
    AppLang.english: 'Call audio was never recorded or saved.',
    AppLang.telugu: 'కాల్ ఆడియో రికార్డ్ చేయలేదు, సేవ్ చేయలేదు.',
    AppLang.hindi: 'कॉल ऑडियो रिकॉर्ड या सेव नहीं किया गया।',
  },
  // Live
  'liveTitle': {
    AppLang.english: 'Live protection',
    AppLang.telugu: 'ప్రత్యక్ష రక్షణ',
    AppLang.hindi: 'लाइव सुरक्षा',
  },
  'detected': {
    AppLang.english: 'Detected pattern',
    AppLang.telugu: 'గుర్తించిన తీరు',
    AppLang.hindi: 'पहचाना गया पैटर्न',
  },
  'listening': {
    AppLang.english: 'Listening... keep it on speaker',
    AppLang.telugu: 'వింటున్నాం... స్పీకర్ దగ్గర పెట్టండి',
    AppLang.hindi: 'सुन रहे हैं... स्पीकर पास रखें',
  },
  'callComplete': {
    AppLang.english: 'Call analysis complete',
    AppLang.telugu: 'కాల్ విశ్లేషణ పూర్తయింది',
    AppLang.hindi: 'कॉल विश्लेषण पूरा',
  },
  'pressDemo': {
    AppLang.english: 'Press a demo below to begin',
    AppLang.telugu: 'మొదలు పెట్టడానికి కింద డెమో నొక్కండి',
    AppLang.hindi: 'शुरू करने के लिए नीचे डेमो दबाएं',
  },
  'liveTranscript': {
    AppLang.english: 'Live transcript',
    AppLang.telugu: 'ప్రత్యక్ష మాటలు',
    AppLang.hindi: 'लाइव बातचीत',
  },
  'demoControls': {
    AppLang.english: 'Demo controls',
    AppLang.telugu: 'డెమో నియంత్రణలు',
    AppLang.hindi: 'डेमो नियंत्रण',
  },
  'playScam': {
    AppLang.english: 'Play scam call',
    AppLang.telugu: 'స్కామ్ కాల్ వేయండి',
    AppLang.hindi: 'स्कैम कॉल चलाएं',
  },
  'playNormal': {
    AppLang.english: 'Play normal call',
    AppLang.telugu: 'సాధారణ కాల్ వేయండి',
    AppLang.hindi: 'सामान्य कॉल चलाएं',
  },
  'endReport': {
    AppLang.english: 'End & report',
    AppLang.telugu: 'ముగించి రిపోర్ట్',
    AppLang.hindi: 'समाप्त + रिपोर्ट',
  },
  'reset': {
    AppLang.english: 'Reset',
    AppLang.telugu: 'రీసెట్',
    AppLang.hindi: 'रीसेट',
  },
  'transcriptEmpty': {
    AppLang.english: 'Transcript will appear here...',
    AppLang.telugu: 'మాటలు ఇక్కడ కనిపిస్తాయి...',
    AppLang.hindi: 'बातचीत यहां दिखेगी...',
  },
  'verdictTitle': {
    AppLang.english: 'Why this is flagged',
    AppLang.telugu: 'ఎందుకు గుర్తించాం',
    AppLang.hindi: 'इसे क्यों चिह्नित किया',
  },
  'dangerNow': {
    AppLang.english: 'Danger — warn your family right now',
    AppLang.telugu: 'ప్రమాదం — వెంటనే కుటుంబాన్ని హెచ్చరించండి',
    AppLang.hindi: 'खतरा — अभी परिवार को सचेत करें',
  },
  'hangup': {
    AppLang.english: 'HANG UP NOW',
    AppLang.telugu: 'ఇప్పుడే కట్ చేయండి',
    AppLang.hindi: 'अभी कॉल काटें!',
  },
  'hangupSub': {
    AppLang.english: 'Cut the call right now',
    AppLang.telugu: 'ఇప్పుడే ఫోన్ కట్ చేయండి',
    AppLang.hindi: 'अभी फोन काट दें',
  },
  'hungUp': {
    AppLang.english: 'I hung up - show report',
    AppLang.telugu: 'కట్ చేశాను - రిపోర్ట్ చూపించు',
    AppLang.hindi: 'मैंने काट दिया - रिपोर्ट दिखाएं',
  },
  'keepListening': {
    AppLang.english: 'Keep listening',
    AppLang.telugu: 'వింటూ ఉండు',
    AppLang.hindi: 'सुनते रहें',
  },
  'cutFirst': {
    AppLang.english: '1. Cut the real phone call now  2. Then tap below',
    AppLang.telugu: '1. ముందు నిజమైన కాల్ కట్ చేయండి  2. తర్వాత కింద నొక్కండి',
    AppLang.hindi: '1. पहले असली कॉल काटें  2. फिर नीचे दबाएं',
  },
  'smsDangerBody': {
    AppLang.english:
        'CyberSafe DANGER: {type} risk {risk}/100. Cut the call now. Dial 1930 if money was shared.',
    AppLang.telugu:
        'CyberSafe ప్రమాదం: {type} రిస్క్ {risk}/100. వెంటనే కాల్ కట్ చేయండి. డబ్బు విషయం ఉంటే 1930కి కాల్ చేయండి.',
    AppLang.hindi:
        'CyberSafe खतरा: {type} जोखिम {risk}/100। अभी कॉल काटें। पैसे की बात हो तो 1930 पर कॉल करें।',
  },
  'smsAlert': {
    AppLang.english: 'Alert family via SMS',
    AppLang.telugu: 'కుటుంబానికి SMS చేయండి',
    AppLang.hindi: 'परिवार को SMS करें',
  },
  'smsNoContact': {
    AppLang.english: 'Set family contact first',
    AppLang.telugu: 'ముందు కుటుంబ సంప్రదింపు సెట్ చేయండి',
    AppLang.hindi: 'पहले परिवार संपर्क सेट करें',
  },
  'typeWhatYouHear': {
    AppLang.english: 'Type what you hear...',
    AppLang.telugu: 'మీరు విన్నది టైప్ చేయండి...',
    AppLang.hindi: 'जो सुन रहे हैं लिखें...',
  },
  // Family
  'familyTitle': {
    AppLang.english: 'Family alert',
    AppLang.telugu: 'కుటుంబ హెచ్చరిక',
    AppLang.hindi: 'परिवार अलर्ट',
  },
  'familyInfo': {
    AppLang.english:
        'On danger, your family gets an instant message with the scam type.',
    AppLang.telugu:
        'Danger vasthe mee family ki ventane message velutundi - scam type tho saha.',
    AppLang.hindi: 'खतरा हुआ तो परिवार को स्कैम प्रकार सहित तुरंत संदेश जाएगा।',
  },
  'trustedContact': {
    AppLang.english: 'Trusted contact',
    AppLang.telugu: 'నమ్మకమైన వ్యక్తి',
    AppLang.hindi: 'विश्वसनीय संपर्क',
  },
  'nameLabel': {
    AppLang.english: 'Name (e.g. Amma / Daughter)',
    AppLang.telugu: 'పేరు (ఉదా. అమ్మ / కూతురు)',
    AppLang.hindi: 'नाम (जैसे अम्मा / बेटी)',
  },
  'phoneLabel': {
    AppLang.english: 'Phone number',
    AppLang.telugu: 'ఫోన్ నంబర్',
    AppLang.hindi: 'फोन नंबर',
  },
  'safeWordTitle': {
    AppLang.english: 'Family safe word (stretch)',
    AppLang.telugu: 'కుటుంబ సేఫ్ పదం',
    AppLang.hindi: 'परिवार सेफ शब्द',
  },
  'safeWordInfo': {
    AppLang.english:
        'If an emergency caller cannot say your safe word, treat it as higher risk.',
    AppLang.telugu:
        'Emergency caller mee safe word cheppalekapothe risk perugutundi.',
    AppLang.hindi: 'आपातकालीन कॉलर सेफ शब्द न बताए तो खतरा ज़्यादा समझें।',
  },
  'safeWordLabel': {
    AppLang.english: 'Safe word (e.g. KAVACHAM)',
    AppLang.telugu: 'సేఫ్ పదం (ఉదా. KAVACHAM)',
    AppLang.hindi: 'सेफ शब्द (जैसे KAVACHAM)',
  },
  'saveContact': {
    AppLang.english: 'Save family contact',
    AppLang.telugu: 'కుటుంబ సంప్రదింపు సేవ్ చేయండి',
    AppLang.hindi: 'परिवार संपर्क सहेजें',
  },
  'contactSaved': {
    AppLang.english: 'Family contact saved ',
    AppLang.telugu: 'కుటుంబ సంప్రదింపు సేవ్ అయింది ',
    AppLang.hindi: 'परिवार संपर्क सहेजा ',
  },
  'invalidName': {
    AppLang.english: 'Enter a name (2+ letters)',
    AppLang.telugu: 'పేరు రాయండి (2+ అక్షరాలు)',
    AppLang.hindi: 'नाम लिखें (2+ अक्षर)',
  },
  'invalidPhone': {
    AppLang.english: 'Enter a valid 10-digit mobile number',
    AppLang.telugu: 'సరైన 10-అంకెల మొబైల్ నంబర్ రాయండి',
    AppLang.hindi: 'सही 10 अंकों का मोबाइल नंबर लिखें',
  },
  'invalidSafeWord': {
    AppLang.english: 'Use one word, 4+ letters, no spaces',
    AppLang.telugu: 'ఒకే పదం, 4+ అక్షరాలు, ఖాళీలు వద్దు',
    AppLang.hindi: 'एक शब्द, 4+ अक्षर, बिना स्पेस',
  },
  'safeWordHelp': {
    AppLang.english: 'Pick a word only family knows, e.g. KAVACHAM. Say it on a doubt call — if they can’t say it, hang up.',
    AppLang.telugu: 'కుటుంబానికి మాత్రమే తెలిసిన పదం ఎంచుకోండి, ఉదా. KAVACHAM. అనుమానం వస్తే అడగండి — చెప్పలేకపోతే కట్ చేయండి.',
    AppLang.hindi: 'सिर्फ परिवार को पता शब्द चुनें, जैसे KAVACHAM। शक हो तो पूछें — न बता पाए तो काट दें।',
  },
  'clearContact': {
    AppLang.english: 'Remove contact',
    AppLang.telugu: 'సంప్రదింపు తొలగించండి',
    AppLang.hindi: 'संपर्क हटाएं',
  },
  'contactCleared': {
    AppLang.english: 'Family contact removed',
    AppLang.telugu: 'కుటుంబ సంప్రదింపు తొలగింది',
    AppLang.hindi: 'परिवार संपर्क हटाया',
  },
  'clearTitle': {
    AppLang.english: 'Remove family contact?',
    AppLang.telugu: 'కుటుంబ సంప్రదింపు తొలగించాలా?',
    AppLang.hindi: 'परिवार संपर्क हटाएं?',
  },
  'clearBody': {
    AppLang.english: 'Alerts and safe-word checks stop working until you save again.',
    AppLang.telugu: 'మళ్లీ సేవ్ చేసేవరకు హెచ్చరికలు, సేఫ్ పదం పనిచేయవు.',
    AppLang.hindi: 'दोबारा सेव करने तक अलर्ट और सेफ शब्द काम नहीं करेंगे।',
  },
  'cancelBtn': {
    AppLang.english: 'Cancel',
    AppLang.telugu: 'రద్దు',
    AppLang.hindi: 'रद्द करें',
  },
  'deleteBtn': {
    AppLang.english: 'Remove',
    AppLang.telugu: 'తొలగించు',
    AppLang.hindi: 'हटाएं',
  },
  // Report
  'reportTitle': {
    AppLang.english: 'After-call report',
    AppLang.telugu: 'కాల్ తర్వాత రిపోర్ట్',
    AppLang.hindi: 'कॉल के बाद रिपोर्ट',
  },
  'reportEmpty': {
    AppLang.english:
        'No call analysed yet.\nProtect a call from the Live tab,\nthen the report appears here.',
    AppLang.telugu:
        'ఇంకా ఏ కాల్ విశ్లేషించలేదు.\nLive ట్యాబ్ నుండి కాల్‌ను రక్షించండి,\nఅప్పుడు రిపోర్ట్ ఇక్కడ కనిపిస్తుంది.',
    AppLang.hindi:
        'अभी कोई कॉल विश्लेषित नहीं।\nलाइव टैब से कॉल सुरक्षित करें,\nफिर रिपोर्ट यहां दिखेगी।',
  },
  'riskWord': {
    AppLang.english: 'Risk',
    AppLang.telugu: 'రిస్క్',
    AppLang.hindi: 'जोखिम',
  },
  'durationWord': {
    AppLang.english: 'Duration',
    AppLang.telugu: 'నిడివి',
    AppLang.hindi: 'अवधि',
  },
  'linesWord': {
    AppLang.english: 'lines',
    AppLang.telugu: 'లైన్లు',
    AppLang.hindi: 'पंक्तियां',
  },
  'familyWord': {
    AppLang.english: 'Family',
    AppLang.telugu: 'కుటుంబం',
    AppLang.hindi: 'परिवार',
  },
  'alertedYes': {
    AppLang.english: 'alerted ',
    AppLang.telugu: 'తెలిసింది ',
    AppLang.hindi: 'सूचित ',
  },
  'alertedNo': {
    AppLang.english: 'not alerted',
    AppLang.telugu: 'తెలియలేదు',
    AppLang.hindi: 'सूचित नहीं',
  },
  'reportHelp': {
    AppLang.english: 'Report & get help',
    AppLang.telugu: 'రిపోర్ట్ & సహాయం',
    AppLang.hindi: 'रिपोर्ट + मदद',
  },
  'call1930': {
    AppLang.english: 'Call 1930',
    AppLang.telugu: '1930కి కాల్',
    AppLang.hindi: '1930 पर कॉल करें',
  },
  'copied1930': {
    AppLang.english: '1930 copied - dial it now',
    AppLang.telugu: '1930 కాపీ అయింది - ఇప్పుడే డయల్ చేయండి',
    AppLang.hindi: '1930 कॉपी - अभी डायल करें',
  },
  'cyberPortal': {
    AppLang.english: 'Cyber portal',
    AppLang.telugu: 'సైబర్ పోర్టల్',
    AppLang.hindi: 'साइबर पोर्टल',
  },
  'portalCopied': {
    AppLang.english: 'cybercrime.gov.in link copied',
    AppLang.telugu: 'cybercrime.gov.in లింక్ కాపీ అయింది',
    AppLang.hindi: 'cybercrime.gov.in लिंक कॉपी',
  },
  'copySummary': {
    AppLang.english: 'Copy summary',
    AppLang.telugu: 'సారాంశం కాపీ',
    AppLang.hindi: 'सारांश कॉपी करें',
  },
  'summaryCopied': {
    AppLang.english: 'Summary copied ',
    AppLang.telugu: 'సారాంశం కాపీ అయింది ',
    AppLang.hindi: 'सारांश कॉपी ',
  },
  'shareReport': {
    AppLang.english: 'Share',
    AppLang.telugu: 'షేర్',
    AppLang.hindi: 'शेयर करें',
  },
  'pastScans': {
    AppLang.english: 'Past scans',
    AppLang.telugu: 'గత స్కాన్లు',
    AppLang.hindi: 'पिछले स्कैन',
  },
  'viewLatest': {
    AppLang.english: 'Latest',
    AppLang.telugu: 'తాజాది',
    AppLang.hindi: 'ताज़ा',
  },
  'memoryTitle': {
    AppLang.english: 'Your protection',
    AppLang.telugu: 'మీ రక్షణ',
    AppLang.hindi: 'आपकी सुरक्षा',
  },
  'caughtMonth': {
    AppLang.english: 'Scams caught this month',
    AppLang.telugu: 'ఈ నెలలో పట్టిన స్కామ్‌లు',
    AppLang.hindi: 'इस महीने पकड़े स्कैम',
  },
  'worstMonth': {
    AppLang.english: 'Worst risk',
    AppLang.telugu: 'అత్యధిక రిస్క్',
    AppLang.hindi: 'सबसे बड़ा जोखिम',
  },
  'noneYet': {
    AppLang.english: 'None yet',
    AppLang.telugu: 'ఇంకా లేవు',
    AppLang.hindi: 'अभी कोई नहीं',
  },
  'firstTitle': {
    AppLang.english: 'Start in 2 minutes',
    AppLang.telugu: '2 నిమిషాల్లో మొదలు',
    AppLang.hindi: '2 मिनट में शुरू करें',
  },
  'firstBody': {
    AppLang.english: 'Save your family contact, then practice with a demo scam call.',
    AppLang.telugu: 'ముందు కుటుంబ సంప్రదింపు సేవ్ చేయండి, తర్వాత డెమో స్కామ్ కాల్‌తో ప్రాక్టీస్ చేయండి.',
    AppLang.hindi: 'पहले परिवार संपर्क सहेजें, फिर डेमो स्कैम कॉल से अभ्यास करें।',
  },
  'goFamily': {
    AppLang.english: 'Set up family',
    AppLang.telugu: 'కుటుంబం సెట్ చేయండి',
    AppLang.hindi: 'परिवार सेट करें',
  },
  'tryDemo': {
    AppLang.english: 'Practice demo',
    AppLang.telugu: 'ప్రాక్టీస్ డెమో',
    AppLang.hindi: 'अभ्यास डेमो',
  },
  'clearHistory': {
    AppLang.english: 'Clear history',
    AppLang.telugu: 'చరిత్ర తొలగించండి',
    AppLang.hindi: 'इतिहास साफ़ करें',
  },
  'clearHistTitle': {
    AppLang.english: 'Clear past scans?',
    AppLang.telugu: 'గత స్కాన్లు తొలగించాలా?',
    AppLang.hindi: 'पिछले स्कैन साफ़ करें?',
  },
  'clearHistBody': {
    AppLang.english: 'Your saved reports will be deleted from this phone.',
    AppLang.telugu: 'మీ సేవ్ చేసిన రిపోర్టులు ఈ ఫోన్ నుండి తొలగుతాయి.',
    AppLang.hindi: 'आपकी सहेजी रिपोर्ट इस फोन से हट जाएंगी।',
  },
  'historyCleared': {
    AppLang.english: 'History cleared',
    AppLang.telugu: 'చరిత్ర తొలగింది',
    AppLang.hindi: 'इतिहास साफ़ हुआ',
  },
  'originDemo': {
    AppLang.english: 'Practice demo',
    AppLang.telugu: 'ప్రాక్టీస్ డెమో',
    AppLang.hindi: 'अभ्यास डेमो',
  },
  'originLive': {
    AppLang.english: 'Live call',
    AppLang.telugu: 'ప్రత్యక్ష కాల్',
    AppLang.hindi: 'लाइव कॉल',
  },
  'smsYes': {
    AppLang.english: 'SMS sent',
    AppLang.telugu: 'SMS పంపాం',
    AppLang.hindi: 'SMS भेजा',
  },
  'smsNo': {
    AppLang.english: 'no SMS',
    AppLang.telugu: 'SMS లేదు',
    AppLang.hindi: 'SMS नहीं',
  },
  'checklist': {
    AppLang.english: 'Safety checklist',
    AppLang.telugu: 'భద్రతా జాబితా',
    AppLang.hindi: 'सुरक्षा सूची',
  },
  'check1': {
    AppLang.english: 'Never tell OTP / PIN to anyone',
    AppLang.telugu: 'OTP / PIN evariki cheppakandi',
    AppLang.hindi: 'OTP / PIN किसी को न बताएं',
  },
  'check2': {
    AppLang.english: 'Never install apps like AnyDesk',
    AppLang.telugu: 'AnyDesk lanti apps install cheyyakandi',
    AppLang.hindi: 'AnyDesk जैसे ऐप इंस्टॉल न करें',
  },
  'check3': {
    AppLang.english: 'Never transfer money on a call',
    AppLang.telugu: 'Dabbulu transfer cheyyakandi',
    AppLang.hindi: 'कॉल पर पैसे ट्रांसफर न करें',
  },
  'check4': {
    AppLang.english: 'Tell family, then call your bank',
    AppLang.telugu: 'Family ki cheppi, bank ki call cheyyandi',
    AppLang.hindi: 'परिवार को बताएं, फिर बैंक को कॉल करें',
  },
  'learnTitle': {
    AppLang.english: 'How does this scam work?',
    AppLang.telugu: 'ఈ స్కామ్ ఎలా పనిచేస్తుంది?',
    AppLang.hindi: 'यह स्कैम कैसे काम करता है?',
  },
  'learnBody': {
    AppLang.english:
        'The scammer scares you posing as police/CBI, tells you to keep it secret, then asks for OTP/money. Real police never threaten arrest on a call, and never ask for OTP.',
    AppLang.telugu:
        'Scammer police/CBI ani cheppi bayapettistadu, secret ga unchamani cheptadu, tarvata OTP/money adugutadu. Nijamaina police phone lo arrest threat ivvaru, OTP adagaru.',
    AppLang.hindi:
        'स्कैमर पुलिस/CBI बनकर डराता है, गुप्त रखने को कहता है, फिर OTP/पैसे मांगता है। असली पुलिस फोन पर गिरफ्तारी की धमकी नहीं देती, OTP नहीं मांगती।',
  },
  'learnScreen': {
    AppLang.english:
        'The scammer asks you to install apps like AnyDesk and share your screen, then watches you type OTPs and passwords. No real bank or officer ever needs your screen.',
    AppLang.telugu:
        'Scammer AnyDesk lanti app install chesi screen share adugutadu, tarvata OTP/password chustadu. Nijamaina bank/officer screen adagaru.',
    AppLang.hindi:
        'स्कैमर AnyDesk जैसा ऐप इंस्टॉल कराकर स्क्रीन शेयर मांगता है, फिर OTP/पासवर्ड देखता है। असली बैंक/अधिकारी स्क्रीन नहीं मांगते।',
  },
  'learnOtp': {
    AppLang.english:
        'The scammer poses as your bank, says your account is blocked, and asks for the OTP or PIN that just arrived. Banks never ask for OTP on a call.',
    AppLang.telugu:
        'Scammer bank ani cheppi account block ani bayapettistadu, vachina OTP/PIN adugutadu. Bank eppudu phone lo OTP adagadu.',
    AppLang.hindi:
        'स्कैमर बैंक बनकर खाता ब्लॉक होने का डर दिखाता है और आया OTP/PIN मांगता है। बैंक फोन पर OTP कभी नहीं मांगता।',
  },
  'learnGeneric': {
    AppLang.english:
        'Scammers rush you, scare you, and ask for codes or money. Slow down, hang up, and call back on an official number.',
    AppLang.telugu:
        'Scammerlu bayapetti, tondarapetti, OTP/dabbulu adugutaru. Haste padakandi, cut chesi official number ki call cheyyandi.',
    AppLang.hindi:
        'स्कैमर डराते हैं, जल्दी मचाते हैं, OTP/पैसे मांगते हैं। रुकें, काटें, आधिकारिक नंबर पर वापस कॉल करें।',
  },
  'learnNote': {
    AppLang.english: 'Remember: "{r}".',
    AppLang.telugu: 'గుర్తు పెట్టుకోండి: "{r}".',
    AppLang.hindi: 'याद रखें: "{r}".',
  },
  'startScan': {
    AppLang.english: 'Start new scan',
    AppLang.telugu: 'కొత్త స్కాన్ మొదలు',
    AppLang.hindi: 'नया स्कैन शुरू करें',
  },
  'liveListening': {
    AppLang.english: 'Listening live — keep the call on speaker',
    AppLang.telugu: 'ప్రత్యక్షంగా వింటున్నాం — కాల్ స్పీకర్‌పైనే ఉంచండి',
    AppLang.hindi: 'लाइव सुन रहे हैं — कॉल स्पीकर पर रखें',
  },
  'liveHeard': {
    AppLang.english: 'Heard',
    AppLang.telugu: 'విన్నది',
    AppLang.hindi: 'सुना',
  },
  'liveNoStt': {
    AppLang.english: 'Voice typing unavailable — type what you hear below.',
    AppLang.telugu: 'వాయిస్ టైపింగ్ లేదు — కింద విన్నది టైప్ చేయండి.',
    AppLang.hindi: 'वॉइस टाइपिंग नहीं है — नीचे जो सुनें लिखें।',
  },
  'liveMicDenied': {
    AppLang.english: 'Mic off — type what you hear below.',
    AppLang.telugu: 'మైక్ ఆఫ్ — కింద విన్నది టైప్ చేయండి.',
    AppLang.hindi: 'माइक बंद — नीचे जो सुनें लिखें।',
  },
  // Dashboard
  // Dashboard
  'shieldTitle': {
    AppLang.english: 'Security shield',
    AppLang.telugu: 'భద్రతా కవచం',
    AppLang.hindi: 'सुरक्षा कवच',
  },
  'shieldSub': {
    AppLang.english: 'Calls, links, QR, UPI, SMS — one shield for all fraud.',
    AppLang.telugu: 'కాల్స్, లింకులు, QR, UPI, SMS — అన్ని మోసాలకు ఒకే కవచం.',
    AppLang.hindi: 'कॉल, लिंक, QR, UPI, SMS — हर धोखे के लिए एक कवच।',
  },
  'toolsTitle': {
    AppLang.english: 'Safety tools',
    AppLang.telugu: 'భద్రతా పరికరాలు',
    AppLang.hindi: 'सुरक्षा उपकरण',
  },
  'recentTitle': {
    AppLang.english: 'Recent activity',
    AppLang.telugu: 'ఇటీవలి కార్యకలాపం',
    AppLang.hindi: 'हाल की गतिविधि',
  },
  'viewAll': {
    AppLang.english: 'View all',
    AppLang.telugu: 'అన్నీ చూడండి',
    AppLang.hindi: 'सभी देखें',
  },
  'noActivity': {
    AppLang.english: 'Nothing scanned yet — run your first check.',
    AppLang.telugu: 'ఇంకా ఏమీ స్కాన్ చేయలేదు — మొదటి తనిఖీ చేయండి.',
    AppLang.hindi: 'अभी कुछ स्कैन नहीं — पहली जांच करें।',
  },
  'scansMonth': {
    AppLang.english: 'Checks this month',
    AppLang.telugu: 'ఈ నెల తనిఖీలు',
    AppLang.hindi: 'इस महीने जांचें',
  },
  // Scan hub + tools
  'scanSub': {
    AppLang.english: 'Paste a link, QR text, UPI ID or message — CyberSafe scores the danger offline.',
    AppLang.telugu: 'లింక్, QR టెక్స్ట్, UPI ID లేదా మెసేజ్ ఇవ్వండి — CyberSafe ఆఫ్‌లైన్‌లో రిస్క్ చెప్తుంది.',
    AppLang.hindi: 'लिंक, QR टेक्स्ट, UPI ID या संदेश दें — साइबरसेफ ऑफलाइन जोखिम बताएगा।',
  },
  'toolUrl': {
    AppLang.english: 'Link scanner',
    AppLang.telugu: 'లింక్ స్కానర్',
    AppLang.hindi: 'लिंक स्कैनर',
  },
  'toolUrlSub': {
    AppLang.english: 'Phishing & fake sites',
    AppLang.telugu: 'నకిలీ సైట్లు',
    AppLang.hindi: 'नकली साइटें',
  },
  'toolQrUpi': {
    AppLang.english: 'QR & UPI check',
    AppLang.telugu: 'QR & UPI తనిఖీ',
    AppLang.hindi: 'QR और UPI जांच',
  },
  'toolQrUpiSub': {
    AppLang.english: 'Codes, IDs & payment links',
    AppLang.telugu: 'కోడ్‌లు, IDలు & పేమెంట్ లింకులు',
    AppLang.hindi: 'कोड, ID और पेमेंट लिंक',
  },
  'qrUpiHint': {
    AppLang.english: 'Paste QR text, UPI ID (name@bank) or payment link...',
    AppLang.telugu: 'QR టెక్స్ట్, UPI ID (name@bank) లేదా పేమెంట్ లింక్ ఇవ్వండి...',
    AppLang.hindi: 'QR टेक्स्ट, UPI ID (name@bank) या पेमेंट लिंक डालें...',
  },
  'autoKind': {
    AppLang.english: 'Detected: {kind}',
    AppLang.telugu: 'గుర్తించింది: {kind}',
    AppLang.hindi: 'पहचाना: {kind}',
  },
  'toolSim': {
    AppLang.english: 'SIM-swap check',
    AppLang.telugu: 'SIM మార్పు తనిఖీ',
    AppLang.hindi: 'SIM-बदलाव जांच',
  },
  'toolSimSub': {
    AppLang.english: 'Is your number safe?',
    AppLang.telugu: 'మీ నంబర్ సురక్షితమేనా?',
    AppLang.hindi: 'क्या आपका नंबर सुरक्षित है?',
  },
  'toolSms': {
    AppLang.english: 'SMS analyzer',
    AppLang.telugu: 'SMS విశ్లేషణ',
    AppLang.hindi: 'SMS विश्लेषण',
  },
  'toolSmsSub': {
    AppLang.english: 'Fake bank & prize texts',
    AppLang.telugu: 'నకిలీ బ్యాంక్ మెసేజ్‌లు',
    AppLang.hindi: 'नकली बैंक संदेश',
  },
  'analyzeBtn': {
    AppLang.english: 'Check now',
    AppLang.telugu: 'ఇప్పుడే తనిఖీ',
    AppLang.hindi: 'अभी जांचें',
  },
  'savedNote': {
    AppLang.english: 'Saved to History automatically.',
    AppLang.telugu: 'చరిత్రలో ఆటోమేటిక్‌గా సేవ్ అయింది.',
    AppLang.hindi: 'इतिहास में अपने आप सहेजा गया।',
  },
  'urlHint': {
    AppLang.english: 'Paste the link here...',
    AppLang.telugu: 'లింక్ ఇక్కడ ఇవ్వండి...',
    AppLang.hindi: 'लिंक यहां डालें...',
  },
  'smsHint': {
    AppLang.english: 'Paste the full message here...',
    AppLang.telugu: 'పూర్తి మెసేజ్ ఇక్కడ ఇవ్వండి...',
    AppLang.hindi: 'पूरा संदेश यहां डालें...',
  },
  'repChecking': {
    AppLang.english: 'Checking domain reputation…',
    AppLang.telugu: 'డొమైన్ ఖ్యాతి చూస్తున్నాం…',
    AppLang.hindi: 'डोमेन प्रतिष्ठा जांच रहे हैं…',
  },
  'repOffline': {
    AppLang.english: 'Offline — link checks only.',
    AppLang.telugu: 'ఆఫ్‌లైన్ — లింక్ తనిఖీ మాత్రమే.',
    AppLang.hindi: 'ऑफलाइन — सिर्फ लिंक जांच।',
  },
  'repAge': {
    AppLang.english: 'Domain age',
    AppLang.telugu: 'డొమైన్ వయసు',
    AppLang.hindi: 'डोमेन आयु',
  },
  'repRegistrar': {
    AppLang.english: 'Registrar',
    AppLang.telugu: 'రిజిస్ట్రార్',
    AppLang.hindi: 'रजिस्ट्रार',
  },
  'repGrade': {
    AppLang.english: 'Health grade',
    AppLang.telugu: 'హెల్త్ గ్రేడ్',
    AppLang.hindi: 'हेल्थ ग्रेड',
  },
  'repBlacklist': {
    AppLang.english: 'Blacklists',
    AppLang.telugu: 'బ్లాక్‌లిస్టులు',
    AppLang.hindi: 'ब्लैकलिस्ट',
  },
  'repExpiry': {
    AppLang.english: 'Expires',
    AppLang.telugu: 'గడువు',
    AppLang.hindi: 'समाप्ति',
  },
  'repNameservers': {
    AppLang.english: 'Name servers',
    AppLang.telugu: 'నేమ్ సర్వర్లు',
    AppLang.hindi: 'नेम सर्वर',
  },
  'repDnssec': {
    AppLang.english: 'DNSSEC',
    AppLang.telugu: 'DNSSEC',
    AppLang.hindi: 'DNSSEC',
  },
  'repChecks': {
    AppLang.english: 'Domain checks',
    AppLang.telugu: 'డొమైన్ తనిఖీలు',
    AppLang.hindi: 'डोमेन जांचें',
  },
  'repClean': {
    AppLang.english: 'clean',
    AppLang.telugu: 'క్లీన్',
    AppLang.hindi: 'साफ',
  },
  'repProgress': {
    AppLang.english: '{d}/{t} checks…',
    AppLang.telugu: '{d}/{t} తనిఖీలు…',
    AppLang.hindi: '{d}/{t} जांचें…',
  },
  'repRetry': {
    AppLang.english: 'Retry',
    AppLang.telugu: 'మళ్లీ ప్రయత్నించండి',
    AppLang.hindi: 'पुनः प्रयास करें',
  },
  'repPartial': {
    AppLang.english: '{n} checks timed out.',
    AppLang.telugu: '{n} తనిఖీలు టైమ్ అయ్యాయి.',
    AppLang.hindi: '{n} जांचें समय पर नहीं हुईं।',
  },
  'repPrivacy': {
    AppLang.english: 'Online check sends only the domain name, never the full link.',
    AppLang.telugu: 'ఆన్‌లైన్ తనిఖీ డొమైన్ పేరు మాత్రమే పంపుతుంది, పూర్తి లింక్ కాదు.',
    AppLang.hindi: 'ऑनलाइन जांच सिर्फ डोमेन नाम भेजती है, पूरा लिंक नहीं।',
  },
  'tipUrl': {
    AppLang.english: 'Real banks never send login links by SMS. When in doubt, open the app yourself — never tap the link.',
    AppLang.telugu: 'నిజమైన బ్యాంకులు SMSలో లాగిన్ లింకులు పంపవు. అనుమానం ఉంటే యాప్ మీరే తెరవండి — లింక్ నొక్కకండి.',
    AppLang.hindi: 'असली बैंक SMS में लॉगिन लिंक नहीं भेजते। शक हो तो ऐप खुद खोलें — लिंक न दबाएं।',
  },
  'tipQr': {
    AppLang.english: 'Scan QR codes only at trusted shops. A QR can open a payment or download — always preview first.',
    AppLang.telugu: 'నమ్మకమైన షాపుల్లో మాత్రమే QR స్కాన్ చేయండి. QR పేమెంట్ తెరవచ్చు — ముందు చూడండి.',
    AppLang.hindi: 'भरोसेमंद दुकानों पर ही QR स्कैन करें। QR पेमेंट खोल सकता है — पहले जांचें।',
  },
  'tipUpi': {
    AppLang.english: 'You never enter a PIN to RECEIVE money. Any "approve to receive" request is fraud — decline it.',
    AppLang.telugu: 'డబ్బు తీసుకోవడానికి PIN అవసరం లేదు. "రిసీవ్ చేయడానికి అప్రూవ్" అంటే మోసం — తిరస్కరించండి.',
    AppLang.hindi: 'पैसे पाने के लिए PIN नहीं चाहिए। "पाने के लिए अप्रूव करें" मतलब धोखा — मना करें।',
  },
  'tipSms': {
    AppLang.english: 'Banks never ask for OTP on call or SMS. Forward fraud texts to 1930 with the sender number.',
    AppLang.telugu: 'బ్యాంకులు ఫోన్/SMSలో OTP అడగవు. మోసం మెసేజ్‌లను 1930కి పంపండి.',
    AppLang.hindi: 'बैंक फोन/SMS पर OTP नहीं मांगते। धोखे वाले संदेश 1930 पर भेजें।',
  },
  'simTitle': {
    AppLang.english: 'SIM-swap security check',
    AppLang.telugu: 'SIM మార్పు భద్రతా తనిఖీ',
    AppLang.hindi: 'SIM-बदलाव सुरक्षा जांच',
  },
  'simSub': {
    AppLang.english: 'Answer honestly — CyberSafe scores whether someone may have taken over your number.',
    AppLang.telugu: 'నిజాయితీగా జవాబు ఇవ్వండి — మీ నంబర్ ఎవరైనా లాక్కున్నారా అని చెప్తుంది.',
    AppLang.hindi: 'सच जवाब दें — साइबरसेफ बताएगा कि आपका नंबर खतरे में है या नहीं।',
  },
  'simQ1': {
    AppLang.english: 'Signal lost suddenly for no reason?',
    AppLang.telugu: 'కారణం లేకుండా సిగ్నల్ పోయిందా?',
    AppLang.hindi: 'बिना वजह सिग्नल गायब हुआ?',
  },
  'simQ2': {
    AppLang.english: 'Cannot call or send SMS anymore?',
    AppLang.telugu: 'కాల్/SMS చేయలేకపోతున్నారా?',
    AppLang.hindi: 'कॉल/SMS नहीं हो रहा?',
  },
  'simQ3': {
    AppLang.english: 'Others say your number is switched off?',
    AppLang.telugu: 'మీ నంబర్ స్విచ్ ఆఫ్ అని ఇతరులు అంటున్నారా?',
    AppLang.hindi: 'लोग कह रहे हैं आपका नंबर बंद है?',
  },
  'simQ4': {
    AppLang.english: 'Getting OTPs you never asked for?',
    AppLang.telugu: 'మీరు అడగని OTPలు వస్తున్నాయా?',
    AppLang.hindi: 'बिना मांगे OTP आ रहे हैं?',
  },
  'simQ5': {
    AppLang.english: 'Bank/operator message about a new SIM or eSIM?',
    AppLang.telugu: 'కొత్త SIM/eSIM గురించి బ్యాంక్ మెసేజ్ వచ్చిందా?',
    AppLang.hindi: 'नए SIM/eSIM के बारे में बैंक का संदेश आया?',
  },
  'tipSim': {
    AppLang.english: 'If danger: call your mobile operator immediately, then your bank to freeze UPI and net-banking.',
    AppLang.telugu: 'ప్రమాదం అయితే: వెంటనే మీ ఆపరేటర్‌కు కాల్ చేసి, తర్వాత బ్యాంకుకు చెప్పి UPI ఆపండి.',
    AppLang.hindi: 'खतरा हो तो: तुरंत ऑपरेटर को कॉल करें, फिर बैंक से UPI बंद कराएं।',
  },
  // Threats
  'threatsTitle': {
    AppLang.english: 'Threats',
    AppLang.telugu: 'ముప్పులు',
    AppLang.hindi: 'खतरे',
  },
  'unifiedTitle': {
    AppLang.english: 'Your threat report',
    AppLang.telugu: 'మీ ముప్పు రిపోర్ట్',
    AppLang.hindi: 'आपकी खतरा रिपोर्ट',
  },
  'totalScansM': {
    AppLang.english: 'Total checks',
    AppLang.telugu: 'మొత్తం తనిఖీలు',
    AppLang.hindi: 'कुल जांचें',
  },
  'dangersCaught': {
    AppLang.english: 'Dangers caught',
    AppLang.telugu: 'పట్టిన ప్రమాదాలు',
    AppLang.hindi: 'पकड़े खतरे',
  },
  'intelTitle': {
    AppLang.english: 'Threat alerts near you',
    AppLang.telugu: 'మీ చుట్టూ ముప్పు హెచ్చరికలు',
    AppLang.hindi: 'आपके आसपास खतरे की चेतावनी',
  },
  'topThreat': {
    AppLang.english: 'Top threat',
    AppLang.telugu: 'అతిపెద్ద ముప్పు',
    AppLang.hindi: 'सबसे बड़ा खतरा',
  },
  'adv1t': {
    AppLang.english: 'Digital-arrest calls rising',
    AppLang.telugu: 'డిజిటల్-అరెస్ట్ కాల్స్ పెరుగుతున్నాయి',
    AppLang.hindi: 'डिजिटल-अरेस्ट कॉल बढ़ रहे हैं',
  },
  'adv1b': {
    AppLang.english: 'Fake CBI/police video calls scare victims into paying "fines". Real officers never demand money on a call.',
    AppLang.telugu: 'నకిలీ CBI/పోలీస్ వీడియో కాల్స్‌తో "జరిమానా" కట్టిస్తున్నారు. నిజమైన అధికారులు ఫోన్‌లో డబ్బు అడగరు.',
    AppLang.hindi: 'नकली CBI/पुलिस वीडियो कॉल से "जुर्माना" वसूला जा रहा है। असली अधिकारी फोन पर पैसे नहीं मांगते।',
  },
  'adv2t': {
    AppLang.english: 'KYC-suspension SMS wave',
    AppLang.telugu: 'KYC ఆగిపోతుందని SMS మోసాలు',
    AppLang.hindi: 'KYC-बंदी वाले SMS धोखे',
  },
  'adv2b': {
    AppLang.english: '"Your bank KYC is blocked" texts carry phishing links. Delete them; update KYC only at the branch or official app.',
    AppLang.telugu: '"మీ KYC బ్లాక్" మెసేజ్‌లలో నకిలీ లింకులు ఉంటాయి. తొలగించండి; KYC బ్రాంచ్/అధికారిక యాప్‌లోనే చేయండి.',
    AppLang.hindi: '"KYC ब्लॉक" संदेशों में नकली लिंक होते हैं। हटाएं; KYC ब्रांच/आधिकारिक ऐप में ही कराएं।',
  },
  'adv3t': {
    AppLang.english: 'QR-code payment traps',
    AppLang.telugu: 'QR పేమెంట్ ఉచ్చులు',
    AppLang.hindi: 'QR पेमेंट जाल',
  },
  'adv3b': {
    AppLang.english: 'QR stickers at shops replaced with scammer codes. Check the receiver name on screen before paying.',
    AppLang.telugu: 'షాపుల్లో QR స్టిక్కర్లు మార్చి మోసం చేస్తున్నారు. పే చేసేముందు పేరు చూడండి.',
    AppLang.hindi: 'दुकानों पर QR स्टिकर बदलकर ठगी हो रही है। भुगतान से पहले स्क्रीन पर नाम जांचें।',
  },
  'adv4t': {
    AppLang.english: 'Part-time job frauds',
    AppLang.telugu: 'పార్ట్-టైమ్ ఉద్యోగ మోసాలు',
    AppLang.hindi: 'पार्ट-टाइम नौकरी ठगी',
  },
  'adv4b': {
    AppLang.english: 'Telegram/WhatsApp "like & earn" tasks end in big "deposit" demands. No real job asks you to pay first.',
    AppLang.telugu: '"లైక్ చేసి సంపాదించండి" టాస్క్‌లు చివరికి "డిపాజిట్" అడుగుతాయి. నిజమైన ఉద్యోగం డబ్బు అడగదు.',
    AppLang.hindi: '"लाइक करके कमाएं" टास्क अंत में "जमा" मांगते हैं। असली नौकरी पहले पैसे नहीं मांगती।',
  },
  'adv5t': {
    AppLang.english: 'SIM-swap + OTP theft',
    AppLang.telugu: 'SIM మార్పు + OTP దొంగతనం',
    AppLang.hindi: 'SIM-बदलाव + OTP चोरी',
  },
  'adv5b': {
    AppLang.english: 'Sudden signal loss can mean your number moved to a scammer SIM. Call your operator at once.',
    AppLang.telugu: 'అకస్మాత్తుగా సిగ్నల్ పోవడం అంటే మీ నంబర్ మోసగాడి SIMకి మారి ఉండవచ్చు. వెంటనే ఆపరేటర్‌కు కాల్ చేయండి.',
    AppLang.hindi: 'अचानक सिग्नल जाना मतलब नंबर ठग के SIM पर जा सकता है। तुरंत ऑपरेटर को कॉल करें।',
  },
  // History
  'historyTitle': {
    AppLang.english: 'History',
    AppLang.telugu: 'చరిత్ర',
    AppLang.hindi: 'इतिहास',
  },
  'filterAll': {
    AppLang.english: 'All',
    AppLang.telugu: 'అన్నీ',
    AppLang.hindi: 'सभी',
  },
  'filterCalls': {
    AppLang.english: 'Calls',
    AppLang.telugu: 'కాల్స్',
    AppLang.hindi: 'कॉल',
  },
  'filterScans': {
    AppLang.english: 'Scans',
    AppLang.telugu: 'స్కాన్లు',
    AppLang.hindi: 'स्कैन',
  },
  'emptyHistory': {
    AppLang.english: 'No history yet. Protect a call or run a scan.',
    AppLang.telugu: 'ఇంకా చరిత్ర లేదు. కాల్ రక్షించండి లేదా స్కాన్ చేయండి.',
    AppLang.hindi: 'अभी इतिहास नहीं। कॉल सुरक्षित करें या स्कैन करें।',
  },
  'clearScansBtn': {
    AppLang.english: 'Clear scan history',
    AppLang.telugu: 'స్కాన్ చరిత్ర తొలగించండి',
    AppLang.hindi: 'स्कैन इतिहास साफ़ करें',
  },
  // Safety
  'safetyTitle': {
    AppLang.english: 'Safety guide',
    AppLang.telugu: 'భద్రతా మార్గదర్శి',
    AppLang.hindi: 'सुरक्षा मार्गदर्शिका',
  },
  'safetySub': {
    AppLang.english: 'Lost money or sense danger? Do this now, in order.',
    AppLang.telugu: 'డబ్బు పోయిందా లేదా ప్రమాదం అనిపిస్తోందా? వెంటనే ఇలా చేయండి.',
    AppLang.hindi: 'पैसे गए या खतरा लगा? अभी यही करें, इसी क्रम में।',
  },
  'stepAT': {
    AppLang.english: 'Stop all payments',
    AppLang.telugu: 'అన్ని చెల్లింపులు ఆపండి',
    AppLang.hindi: 'सभी भुगतान रोकें',
  },
  'stepAS': {
    AppLang.english: 'Decline pending UPI requests. Switch on airplane mode if they control your screen.',
    AppLang.telugu: 'పెండింగ్ UPI అభ్యర్థనలు తిరస్కరించండి. స్క్రీన్ వాళ్ల చేతిలో ఉంటే ఫ్లైట్ మోడ్ వేయండి.',
    AppLang.hindi: 'लंबित UPI अनुरोध ठुकराएं। स्क्रीन उनके हाथ में हो तो फ्लाइट मोड लगाएं।',
  },
  'stepBT': {
    AppLang.english: 'Call 1930 immediately',
    AppLang.telugu: 'వెంటనే 1930కి కాల్ చేయండి',
    AppLang.hindi: 'तुरंत 1930 पर कॉल करें',
  },
  'stepBS': {
    AppLang.english: 'National cyber helpline — the faster you call, the better the chance to freeze the money.',
    AppLang.telugu: 'జాతీయ సైబర్ హెల్ప్‌లైన్ — ఎంత త్వరగా కాల్ చేస్తే డబ్బు ఆగే అవకాశం అంత ఎక్కువ.',
    AppLang.hindi: 'राष्ट्रीय साइबर हेल्पलाइन — जितनी जल्दी कॉल, पैसे रुकने की उतनी संभावना।',
  },
  'stepCT': {
    AppLang.english: 'Tell your bank',
    AppLang.telugu: 'మీ బ్యాంకుకు చెప్పండి',
    AppLang.hindi: 'अपने बैंक को बताएं',
  },
  'stepCS': {
    AppLang.english: 'Ask them to block UPI, cards and net-banking linked to the number.',
    AppLang.telugu: 'నంబర్‌కు లింక్ అయిన UPI, కార్డులు, నెట్-బ్యాంకింగ్ బ్లాక్ చేయమని అడగండి.',
    AppLang.hindi: 'नंबर से जुड़े UPI, कार्ड और नेट-बैंकिंग ब्लॉक कराने को कहें।',
  },
  'stepDT': {
    AppLang.english: 'File a complaint',
    AppLang.telugu: 'ఫిర్యాదు చేయండి',
    AppLang.hindi: 'शिकायत दर्ज करें',
  },
  'stepDS': {
    AppLang.english: 'Report at cybercrime.gov.in with screenshots, numbers and transaction IDs.',
    AppLang.telugu: 'స్క్రీన్‌షాట్లు, నంబర్లు, లావాదేవీ IDలతో cybercrime.gov.inలో ఫిర్యాదు చేయండి.',
    AppLang.hindi: 'स्क्रीनशॉट, नंबर और ट्रांजैक्शन ID के साथ cybercrime.gov.in पर शिकायत करें।',
  },
  // Settings
  'settingsTitle': {
    AppLang.english: 'Settings & privacy',
    AppLang.telugu: 'సెట్టింగులు & గోప్యత',
    AppLang.hindi: 'सेटिंग और प्राइवेसी',
  },
  'langSection': {
    AppLang.english: 'Language',
    AppLang.telugu: 'భాష',
    AppLang.hindi: 'भाषा',
  },
  'privacySection': {
    AppLang.english: 'Your privacy',
    AppLang.telugu: 'మీ గోప్యత',
    AppLang.hindi: 'आपकी प्राइवेसी',
  },
  'dataSection': {
    AppLang.english: 'Your data',
    AppLang.telugu: 'మీ డేటా',
    AppLang.hindi: 'आपका डेटा',
  },
  'clearScanData': {
    AppLang.english: 'Clear scan history',
    AppLang.telugu: 'స్కాన్ చరిత్ర తొలగించండి',
    AppLang.hindi: 'स्कैन इतिहास साफ़ करें',
  },
  'scansCleared': {
    AppLang.english: 'Scan history cleared',
    AppLang.telugu: 'స్కాన్ చరిత్ర తొలగింది',
    AppLang.hindi: 'स्कैन इतिहास साफ़ हुआ',
  },
  'voiceSection': {
    AppLang.english: 'Voice check',
    AppLang.telugu: 'వాయిస్ తనిఖీ',
    AppLang.hindi: 'वॉइस जांच',
  },
  'voiceBody': {
    AppLang.english:
        'Tests your microphone and speech recognition before a real call. Speak for a few seconds after tapping.',
    AppLang.telugu:
        'నిజమైన కాల్‌కు ముందు మైక్, వాయిస్ గుర్తింపు పనిచేస్తున్నాయో చూడండి. నొక్కి కొన్ని సెకన్లు మాట్లాడండి.',
    AppLang.hindi:
        'असली कॉल से पहले माइक और वॉइस पहचान जांचें। दबाकर कुछ सेकंड बोलें।',
  },
  'voiceTestBtn': {
    AppLang.english: 'Test voice typing',
    AppLang.telugu: 'వాయిస్ పరీక్షించండి',
    AppLang.hindi: 'वॉइस जांचें',
  },
  'voiceStopBtn': {
    AppLang.english: 'Stop',
    AppLang.telugu: 'ఆపండి',
    AppLang.hindi: 'रोकें',
  },
  'voiceNothing': {
    AppLang.english: 'Heard nothing — speak louder, closer, or check network.',
    AppLang.telugu: 'ఏమీ వినబడలేదు — గట్టిగా, దగ్గరగా మాట్లాడండి లేదా నెట్‌వర్క్ చూడండి.',
    AppLang.hindi: 'कुछ सुनाई नहीं दिया — ज़ोर से, पास से बोलें या नेटवर्क देखें।',
  },
  'aboutSection': {
    AppLang.english: 'About CyberSafe',
    AppLang.telugu: 'CyberSafe గురించి',
    AppLang.hindi: 'साइबरसेफ के बारे में',
  },
  'aboutBody': {
    AppLang.english: 'CyberSafe v1.0.0 — scam-call shield plus link, QR, UPI, SIM and SMS checks. All checks run offline on your phone; nothing is uploaded.',
    AppLang.telugu: 'CyberSafe v1.0.0 — స్కామ్-కాల్ షీల్డ్ + లింక్, QR, UPI, SIM, SMS తనిఖీలు. అన్నీ మీ ఫోన్‌లోనే ఆఫ్‌లైన్‌లో జరుగుతాయి; ఏదీ అప్‌లోడ్ కాదు.',
    AppLang.hindi: 'साइबरसेफ v1.0.0 — स्कैम-कॉल शील्ड + लिंक, QR, UPI, SIM, SMS जांच। सभी जांच आपके फोन पर ऑफलाइन; कुछ अपलोड नहीं होता।',
  },
  // Explainability + decision support
  'whyTitle': {
    AppLang.english: 'Why am I at risk?',
    AppLang.telugu: 'నాకు రిస్క్ ఎందుకు ఉంది?',
    AppLang.hindi: 'मुझे जोखिम क्यों है?',
  },
  'whyEmpty': {
    AppLang.english: 'No scam signals yet — keep listening. The moment a trick appears, it will show up here with proof.',
    AppLang.telugu: 'ఇంకా మోస సంకేతాలు లేవు — వింటూ ఉండండి. ఎత్తుగడ కనిపించగానే రుజువుతో ఇక్కడ చూపిస్తాం.',
    AppLang.hindi: 'अभी कोई ठगी संकेत नहीं — सुनते रहें। चाल दिखते ही सबूत के साथ यहां दिखेगा।',
  },
  'whatTitle': {
    AppLang.english: 'What should I do?',
    AppLang.telugu: 'నేనేం చేయాలి?',
    AppLang.hindi: 'मुझे क्या करना चाहिए?',
  },
  'whatSub': {
    AppLang.english: 'Do them in order — NOW first, then NEXT.',
    AppLang.telugu: 'వరుసగా చేయండి — ముందు ఇప్పుడేవి, తర్వాత తర్వాతివి.',
    AppLang.hindi: 'इसी क्रम में करें — पहले अभी वाले, फिर आगे वाले।',
  },
  // Agnes AI second opinion (opt-in)
  'aiSection': {
    AppLang.english: 'AI second opinion',
    AppLang.telugu: 'AI రెండో అభిప్రాయం',
    AppLang.hindi: 'AI दूसरी राय',
  },
  'aiBody': {
    AppLang.english:
        'Optional and off by default. When on, CyberSafe sends only the detected scam signals (matched phrases, risk score) to an AI service for a plain-language note. Full call words never leave your phone; scoring stays offline.',
    AppLang.telugu:
        'ఐచ్ఛికం, డిఫాల్ట్‌గా ఆఫ్. ఆన్ చేస్తే గుర్తించిన సంకేతాలు (మాటలు, రిస్క్ స్కోర్) మాత్రమే AI సేవకు వెళ్తాయి. పూర్తి కాల్ మాటలు ఫోన్ దాటవు; స్కోరింగ్ ఆఫ్‌లైన్‌లోనే.',
    AppLang.hindi:
        'वैकल्पिक, डिफ़ॉल्ट रूप से बंद। चालू हो तो सिर्फ पहचाने संकेत (वाक्य, जोखिम स्कोर) AI सेवा को जाते हैं। पूरी कॉल बातें फोन से बाहर नहीं जातीं; स्कोरिंग ऑफलाइन रहती है।',
  },
  'aiOptIn': {
    AppLang.english: 'AI explanations',
    AppLang.telugu: 'AI వివరణలు',
    AppLang.hindi: 'AI व्याख्या',
  },
  'aiAsk': {
    AppLang.english: 'Explain with AI',
    AppLang.telugu: 'AIతో వివరించు',
    AppLang.hindi: 'AI से समझें',
  },
  'aiAskAdvice': {
    AppLang.english: 'Get AI advice',
    AppLang.telugu: 'AI సలహా తీసుకోండి',
    AppLang.hindi: 'AI सलाह लें',
  },
  'aiRetry': {
    AppLang.english: 'Retry',
    AppLang.telugu: 'మళ్లీ',
    AppLang.hindi: 'पुनः प्रयास',
  },
  'aiLoading': {
    AppLang.english: 'Asking AI…',
    AppLang.telugu: 'AIని అడుగుతున్నాం…',
    AppLang.hindi: 'AI से पूछ रहे हैं…',
  },
  'aiFailed': {
    AppLang.english: 'AI unavailable — the rule-based result above still stands.',
    AppLang.telugu: 'AI అందుబాటులో లేదు — పైన రూల్-ఆధారిత ఫలితమే వర్తిస్తుంది.',
    AppLang.hindi: 'AI उपलब्ध नहीं — ऊपर वाला नियम-आधारित परिणाम ही मान्य है।',
  },
  'aiBadge': {
    AppLang.english: 'AI',
    AppLang.telugu: 'AI',
    AppLang.hindi: 'AI',
  },
  'aiNote': {
    AppLang.english: 'AI can be wrong — the meter is always the boss.',
    AppLang.telugu: 'AI తప్పు చెప్పవచ్చు — మీటరే ఎప్పుడూ నిర్ణయం.',
    AppLang.hindi: 'AI गलत हो सकता है — मीटर ही अंतिम है।',
  },
  // Telco SIM-swap network check
  'telcoTitle': {
    AppLang.english: 'Network check (telco)',
    AppLang.telugu: 'నెట్‌వర్క్ తనిఖీ',
    AppLang.hindi: 'नेटवर्क जांच',
  },
  'telcoSub': {
    AppLang.english:
        'Ask your mobile network if this SIM changed recently — the strongest SIM-swap signal.',
    AppLang.telugu:
        'ఈ SIM ఇటీవల మారిందేమో మీ మొబైల్ నెట్‌వర్క్‌ను అడగండి — ఇదే బలమైన SIM-మార్పు సంకేతం.',
    AppLang.hindi:
        'यह SIM हाल में बदला है या नहीं, अपने मोबाइल नेटवर्क से पूछें — यही सबसे पक्का SIM-बदलाव संकेत है।',
  },
  'telcoPhoneHint': {
    AppLang.english: 'Phone in +91… format',
    AppLang.telugu: '+91… ఆకృతిలో ఫోన్ నంబర్',
    AppLang.hindi: '+91… प्रारूप में फोन नंबर',
  },
  'telcoCheck': {
    AppLang.english: 'Check network',
    AppLang.telugu: 'నెట్‌వర్క్ తనిఖీ',
    AppLang.hindi: 'नेटवर्क जांचें',
  },
  'telcoLastChange': {
    AppLang.english: 'Last change?',
    AppLang.telugu: 'చివరి మార్పు?',
    AppLang.hindi: 'आखिरी बदलाव?',
  },
  'telcoInvalid': {
    AppLang.english: 'Enter a valid number like +919876543210',
    AppLang.telugu: '+919876543210 లాంటి సరైన నంబర్ ఇవ్వండి',
    AppLang.hindi: '+919876543210 जैसा सही नंबर डालें',
  },
  'telcoUnavailable': {
    AppLang.english: 'Network check unavailable — use the checklist below.',
    AppLang.telugu: 'నెట్‌వర్క్ తనిఖీ అందుబాటులో లేదు — కింది జాబితా వాడండి.',
    AppLang.hindi: 'नेटवर्क जांच उपलब्ध नहीं — नीचे वाली सूची इस्तेमाल करें।',
  },
  // QR scanning
  'scanQr': {
    AppLang.english: 'Scan QR',
    AppLang.telugu: 'QR స్కాన్ చేయండి',
    AppLang.hindi: 'QR स्कैन करें',
  },
  'scanHint': {
    AppLang.english: 'Point the camera at the QR code',
    AppLang.telugu: 'కెమెరాను QR కోడ్ వైపు చూపండి',
    AppLang.hindi: 'कैमरे को QR कोड की ओर रखें',
  },
  'scanGallery': {
    AppLang.english: 'Gallery',
    AppLang.telugu: 'గ్యాలరీ',
    AppLang.hindi: 'गैलरी',
  },
  'scanDenied': {
    AppLang.english: 'Camera blocked — allow it in Settings to scan.',
    AppLang.telugu: 'కెమెరా బ్లాక్ అయింది — స్కాన్ చేయడానికి సెట్టింగ్స్‌లో అనుమతించండి.',
    AppLang.hindi: 'कैमरा ब्लॉक है — स्कैन के लिए सेटिंग्स में अनुमति दें।',
  },
  'scanEmpty': {
    AppLang.english: 'No QR found in that image.',
    AppLang.telugu: 'ఆ చిత్రంలో QR కనబడలేదు.',
    AppLang.hindi: 'उस तस्वीर में QR नहीं मिला।',
  },
  'aiAskSms': {
    AppLang.english: 'AI verdict',
    AppLang.telugu: 'AI తీర్పు',
    AppLang.hindi: 'AI फैसला',
  },
  // QR & UPI direction (reverse-collect context)
  'expectPay': {
    AppLang.english: 'I’m paying',
    AppLang.telugu: 'నేను చెల్లిస్తున్నాను',
    AppLang.hindi: 'मैं भुगतान कर रहा हूं',
  },
  'expectReceive': {
    AppLang.english: 'I’m receiving',
    AppLang.telugu: 'నేను తీసుకుంటున్నాను',
    AppLang.hindi: 'मैं प्राप्त कर रहा हूं',
  },
};
