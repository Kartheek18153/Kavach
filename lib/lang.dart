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
          size: 18, color: KavachColors.teal),
      label: Text(
        scope.lang.buttonLabel,
        style: const TextStyle(
          color: KavachColors.teal,
          fontWeight: FontWeight.w800,
          fontSize: 14,
        ),
      ),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        minimumSize: const Size(0, 36),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: KavachColors.line),
        ),
        backgroundColor: KavachColors.surface,
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
    AppLang.english: 'Kavach | Scam Call Shield',
    AppLang.telugu: 'కవచ్ | స్కామ్ కాల్ షీల్డ్',
    AppLang.hindi: 'कवच | स्कैम कॉल शील्ड',
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
    AppLang.english: 'Kavach listens, you watch the meter',
    AppLang.telugu: 'Kavach vintundi, meter chudandi',
    AppLang.hindi: 'कवच सुनेगा, आप मीटर देखें',
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
        'Kavach never records, saves, or uploads your calls. It listens live on your device only while Protect is on - and forgets everything the moment the call ends.',
    AppLang.telugu:
        'Kavach మీ కాల్స్‌ను రికార్డ్ చేయదు, సేవ్ చేయదు, అప్‌లోడ్ చేయదు. Protect ఆన్‌లో ఉన్నప్పుడు మాత్రమే మీ ఫోన్‌లోనే వింటుంది - కాల్ ముగియగానే అన్నీ మర్చిపోతుంది.',
    AppLang.hindi:
        'कवच आपकी कॉल रिकॉर्ड, सेव या अपलोड नहीं करता। सिर्फ Protect ऑन रहने पर आपके डिवाइस पर लाइव सुनता है - कॉल खत्म होते ही सब भूल जाता है।',
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
  'typedTitle': {
    AppLang.english: 'Typed fallback (if mic fails)',
    AppLang.telugu: 'టైప్ ప్రత్యామ్నాయం (మైక్ పనిచేయకపోతే)',
    AppLang.hindi: 'टाइप बैकअप (माइक न चले तो)',
  },
  'typedHint': {
    AppLang.english: 'Type a line the caller said...',
    AppLang.telugu: 'కాలర్ అన్న మాట టైప్ చేయండి...',
    AppLang.hindi: 'कॉलर ने क्या कहा, लिखें...',
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
  'familySent': {
    AppLang.english: 'Family alert sent  - guardian notified',
    AppLang.telugu: 'కుటుంబ హెచ్చరిక పంపాం  - రక్షకుడికి తెలిసింది',
    AppLang.hindi: 'परिवार अलर्ट भेजा  - अभिभावक को सूचित किया',
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
  'familyAlerted': {
    AppLang.english: 'Family alerted ',
    AppLang.telugu: 'కుటుంబానికి తెలిసింది ',
    AppLang.hindi: 'परिवार सूचित ',
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
  'telegramTitle': {
    AppLang.english: 'Telegram alert (free, instant)',
    AppLang.telugu: 'టెలిగ్రామ్ హెచ్చరిక (ఉచితం, వెంటనే)',
    AppLang.hindi: 'टेलीग्राम अलर्ट (मुफ्त, तुरंत)',
  },
  'telegramSteps': {
    AppLang.english:
        '1. Create a bot with BotFather\n2. Ask the family member to open it and press Start\n3. Paste their chat ID here',
    AppLang.telugu:
        '1. BotFather tho bot create cheyyandi\n2. Family member bot ni open chesi Start nokkandi\n3. Valla chat ID ikkada paste cheyyandi',
    AppLang.hindi:
        '1. BotFather से बॉट बनाएं\n2. परिवार सदस्य से उसे खोलकर Start दबाने को कहें\n3. उनका चैट ID यहां चिपकाएं',
  },
  'chatIdLabel': {
    AppLang.english: 'Telegram chat ID',
    AppLang.telugu: 'టెలిగ్రామ్ చాట్ ID',
    AppLang.hindi: 'टेलीग्राम चैट ID',
  },
  'sendTest': {
    AppLang.english: 'Send test alert',
    AppLang.telugu: 'టెస్ట్ హెచ్చరిక పంపండి',
    AppLang.hindi: 'टेस्ट अलर्ट भेजें',
  },
  'testSent': {
    AppLang.english: 'Demo test alert sent to family ',
    AppLang.telugu: 'కుటుంబానికి టెస్ట్ హెచ్చరిక పంపాం ',
    AppLang.hindi: 'परिवार को डेमो टेस्ट अलर्ट भेजा ',
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
};
