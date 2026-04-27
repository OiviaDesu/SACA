import '../../domain/models/saca_models.dart';
import '../../domain/services/clinical_vocabulary_service.dart';

class SacaLocalizer {
  SacaLocalizer({ClinicalVocabularyService? vocabulary})
      : _vocabulary = vocabulary ?? const ClinicalVocabularyService.empty();

  final ClinicalVocabularyService _vocabulary;

  // Prototype Gurindji UI copy. It must be reviewed by a fluent Gurindji
  // speaker before clinical or community production use.
  static const _english = <String, String>{
    'splashSubtitle': 'Offline triage support',
    'languageTitle': 'Choose your language / Yawu nyawa',
    'languageSubtitle': 'SACA health check',
    'languageGurindjiLabel': 'Gurindji',
    'languageGurindjiDescription': 'Gurindji yawu nyawa.',
    'languageEnglishLabel': 'English',
    'languageEnglishDescription': 'English health check.',
    'languageFootnote': 'Preliminary support only. Not a diagnosis.',
    'inputTitle': 'Choose input',
    'inputSubtitle': '',
    'textInput': 'Text',
    'textInputDescription': '',
    'voiceInput': 'Voice',
    'voiceInputDescription': '',
    'visualSelection': 'Body',
    'visualSelectionDescription': '',
    'voiceTitle': 'Voice',
    'voiceSubtitle': 'Record, then review.',
    'stopRecording': 'Stop recording',
    'record': 'Record',
    'transcriptPlaceholder': 'Transcript',
    'offlineSpeechNotice': 'Offline speech may be wrong. Check it.',
    'voiceAccuracyNotice':
        'Gurindji voice is placeholder. Check text or use Body.',
    'useTranscript': 'Use transcript',
    'textTitle': 'Text',
    'textSubtitle': 'Main symptom',
    'textPlaceholder': 'fever',
    'visualTitle': 'Body',
    'visualSubtitle': 'Tap what fits.',
    'selected': 'Selected',
    'selectedEmpty': 'Nothing selected.',
    'severityTitle': 'Strength',
    'severitySubtitle': '1 to 10',
    'durationTitle': 'Time',
    'durationSubtitle': '',
    'relatedTitle': 'Other symptoms',
    'relatedSubtitle': 'Choose all.',
    'medicationTitle': 'Medicine',
    'medicationSubtitle': '',
    'foodTitle': 'Food',
    'foodSubtitle': '',
    'allergiesTitle': 'Allergy',
    'allergiesSubtitle': '',
    'healthChangesTitle': 'Change',
    'healthChangesSubtitle': '',
    'continue': 'Continue',
    'analyse': 'Analyse',
    'analysingTitle': 'Checking',
    'analysingSubtitle': 'Offline placeholder model',
    'noResultTitle': 'No result',
    'noResultSubtitle': 'Go back and try again.',
    'back': 'Back',
    'resultTitle': 'Result',
    'resultSubtitle': 'Next support step',
    'finish': 'Finish',
    'startAgain': 'Start again',
    'offlineReady': 'Offline',
    'languageStatus': 'Language',
    'notSelected': 'Not selected',
    'assessmentFlow': 'Flow',
    'progressLanguage': 'Language',
    'progressInput': 'Input',
    'progressQuestions': 'Questions',
    'progressAnalysis': 'Analysis',
    'progressResult': 'Result',
    'noPersonalInfo': 'No personal information is stored.',
    'infoTitle': 'SACA prototype',
    'infoContent':
        'SACA is an offline triage support prototype for the Kalkaringi and Daguragu context. It is not a diagnostic tool.',
    'ok': 'OK',
    'call000Now': 'Call 000 now',
    'possiblePattern': 'Possible',
    'severity': 'Level',
    'severityMild': 'Mild',
    'severityModerate': 'Moderate',
    'severitySevere': 'Severe',
    'severityEmergency': 'Emergency',
    'bodyAreaSemantic': 'Body',
    'errorGeneric': 'Try again.',
    'disclaimer': 'Preliminary support only. Not a diagnosis.',
  };

  static const _gurindji = <String, String>{
    'splashSubtitle': 'Jangany nyawa',
    'languageTitle': 'Choose your language / Yawu nyawa',
    'languageSubtitle': 'English nyawa. Gurindji nyawa.',
    'languageGurindjiLabel': 'Gurindji',
    'languageGurindjiDescription': 'Gurindji yawu nyawa.',
    'languageEnglishLabel': 'English',
    'languageEnglishDescription': 'Use English labels and questions.',
    'languageFootnote': 'SACA jangany nyawa. Nyangu-nyangu-wangu.',
    'inputTitle': 'Nyawa',
    'inputSubtitle': '',
    'textInput': 'Yawu',
    'textInputDescription': '',
    'voiceInput': 'Ngayirrp',
    'voiceInputDescription': '',
    'visualSelection': 'Puya',
    'visualSelectionDescription': '',
    'voiceTitle': 'Ngayirrp',
    'voiceSubtitle': 'Ngayirrp. Yawu nyawa.',
    'stopRecording': 'Kurtirni',
    'record': 'Ngayirrp',
    'transcriptPlaceholder': 'Yawu',
    'offlineSpeechNotice': 'Yawu nyawa.',
    'voiceAccuracyNotice': 'Ngayirrp mayi.',
    'useTranscript': 'Yawu',
    'textTitle': 'Yawu',
    'textSubtitle': 'Jangany',
    'textPlaceholder': 'makurrmakurr',
    'visualTitle': 'Puya',
    'visualSubtitle': 'Jangany. Puya.',
    'selected': 'Nyawa',
    'selectedEmpty': 'Karrwarn.',
    'severityTitle': 'Nyatpa?',
    'severitySubtitle': '1-10',
    'durationTitle': 'Tirrip',
    'durationSubtitle': '',
    'relatedTitle': 'Jangany',
    'relatedSubtitle': 'Nyawa.',
    'medicationTitle': 'Mirrijin',
    'medicationSubtitle': '',
    'foodTitle': 'Mangarri',
    'foodSubtitle': '',
    'allergiesTitle': 'Mawuya',
    'allergiesSubtitle': '',
    'healthChangesTitle': 'Puya',
    'healthChangesSubtitle': '',
    'continue': 'Kawayi',
    'analyse': 'Nyawa',
    'analysingTitle': 'Nyawa',
    'analysingSubtitle': 'SACA jangany nyawa.',
    'noResultTitle': 'Nyawa karrwarn',
    'noResultSubtitle': 'Wart nyawa.',
    'back': 'Wart',
    'resultTitle': 'Jangany',
    'resultSubtitle': 'Kawayi.',
    'finish': 'Yuwa',
    'startAgain': 'Jala nyawa',
    'offlineReady': 'Yamak',
    'languageStatus': 'Yawu',
    'notSelected': 'Karrwarn',
    'assessmentFlow': 'Yanku',
    'progressLanguage': 'Yawu',
    'progressInput': 'Nyawa',
    'progressQuestions': 'Nyampa',
    'progressAnalysis': 'Jangany',
    'progressResult': 'Kawayi',
    'noPersonalInfo': 'Yini karrwarn.',
    'infoTitle': 'SACA',
    'infoContent':
        'SACA jangany nyawa Kalkaringi Daguragu. Nyangu-nyangu-wangu.',
    'ok': 'Yuwa',
    'call000Now': '000 kawayi jala',
    'possiblePattern': 'Jangany mayi',
    'severity': 'Jangany',
    'severityMild': 'Yamak',
    'severityModerate': 'Janga',
    'severitySevere': 'Warlarrp',
    'severityEmergency': '000',
    'bodyAreaSemantic': 'Puya',
    'errorGeneric': 'Nyawa karrwarn. Kawayi nyawa.',
    'disclaimer': 'SACA jangany nyawa. Nyangu-nyangu-wangu.',
  };

  static const _englishChoiceLabels = <String, String>{
    'less than one day': '<1 day',
    'one to three days': '1-3 days',
    'four to seven days': '4-7 days',
    'more than seven days': '>7 days',
    'no medication': 'No',
    'taken medication': 'Yes',
    'not sure medication': 'Not sure',
    'no food change': 'No change',
    'unfamiliar food': 'Unfamiliar food',
    'skipped meals': 'Skipped meals',
    'not sure food': 'Not sure',
    'no known allergies': 'No known allergies',
    'possible allergies': 'Yes',
    'not sure allergies': 'Not sure',
    'no recent health change': 'No change',
    'sick contact or travel': 'Sick contact or travel',
    'sleep or stress change': 'Sleep or stress change',
    'not sure health change': 'Not sure',
  };

  static const _gurindjiChoiceLabels = <String, String>{
    'less than one day': '<1 tirrip',
    'one to three days': '1-3 tirrip',
    'four to seven days': '4-7 tirrip',
    'more than seven days': '>7 tirrip',
    'no medication': 'Karrwarn',
    'taken medication': 'Yuwa',
    'not sure medication': 'Mayi',
    'no food change': 'Karrwarn',
    'unfamiliar food': 'Mangarri jalayalang',
    'skipped meals': 'Mangarri karrwarn',
    'not sure food': 'Mayi',
    'no known allergies': 'Karrwarn',
    'possible allergies': 'Mayi',
    'not sure allergies': 'Mayi',
    'no recent health change': 'Karrwarn',
    'sick contact or travel': 'Janga kawayi',
    'sleep or stress change': 'Makin mayi',
    'not sure health change': 'Mayi',
  };

  static const _gurindjiSymptomFallbacks = <String, String>{
    'none': 'Karrwarn',
    'breathing_trouble': 'ngayirrp ma-',
    'bloating': 'majul rumpa',
    'rash': 'warrgarrk marntara',
  };

  static const _gurindjiBodyFallbacks = <String, String>{
    'head': 'ngarlaka',
    'eyes': 'mila',
    'throat': 'ngirlkirri',
    'heart': 'mangarli',
    'chest': 'mangarli',
    'stomach': 'majul',
    'hand': 'marla',
    'leg': 'kurtpu',
    'knees': 'tingarri',
    'toes': 'jamana nantananta',
    'ears': 'langa',
    'neck': 'wirri',
    'shoulder': 'laja',
    'back': 'parntawurru',
    'arm': 'murna',
    'finger': 'wartan nantananta',
    'ankle': 'tari',
    'lower_back': 'parntawurru',
    'lower_leg': 'kurtpu',
  };

  static const _gurindjiDiseaseLabels = <String, String>{
    'Influenza': 'jangany',
    'Stomach upset': 'majul jangany',
    'General symptoms': 'jangany',
    'Urgent symptoms': 'warlarrp',
  };

  static const _gurindjiGuidance = <String, List<String>>{
    'Influenza': [
      'Yawarra.',
      'Mirrijin yamak nyawa.',
      'Nyangu-nyangu kawayi jangany warlarrp.',
      'Ngurra-ngkurra yamak.',
    ],
    'Stomach upset': [
      'Yawarra.',
      'Mangarri yamak.',
      'Nyangu-nyangu kawayi jangany warlarrp.',
    ],
    'General symptoms': [
      'Yawarra.',
      'Jangany nyawa jala.',
      'Nyangu-nyangu kawayi jangany warlarrp.',
    ],
    'Urgent symptoms': [
      '000 kawayi jala.',
      'SACA nyawa-wangu.',
      'Yamak karrinyana.',
    ],
  };

  String t(SacaLanguage? language, String key) {
    final table = _tableFor(language);
    return table[key] ?? _english[key] ?? key;
  }

  String symptomLabel(SacaLanguage? language, Symptom symptom) {
    if (language == SacaLanguage.gurindji) {
      return _vocabulary.symptomTerm(symptom.id)?.gurindjiLabel ??
          _gurindjiSymptomFallbacks[symptom.id] ??
          symptom.id;
    }
    return symptom.label;
  }

  String compactSymptomLabel(SacaLanguage? language, Symptom symptom) {
    return symptomLabel(language, symptom).replaceAll('\n', ' / ');
  }

  String bodyAreaLabel(SacaLanguage? language, BodyArea area) {
    if (language == SacaLanguage.gurindji) {
      return _vocabulary.bodyAreaTerm(area.id)?.gurindjiLabel ??
          _gurindjiBodyFallbacks[area.id] ??
          area.id;
    }
    return area.label;
  }

  String compactBodyAreaLabel(SacaLanguage? language, BodyArea area) {
    return bodyAreaLabel(language, area).replaceAll('\n', ' / ');
  }

  String resultDiseaseLabel(SacaLanguage? language, String disease) {
    if (language == SacaLanguage.gurindji) {
      return _gurindjiDiseaseLabels[disease] ??
          _vocabulary.resultDiseaseLabel(language, disease);
    }
    return disease;
  }

  String choiceLabel(
      SacaLanguage? language, String value, String englishLabel) {
    if (language == SacaLanguage.gurindji) {
      return _gurindjiChoiceLabels[value] ?? englishLabel;
    }
    return _englishChoiceLabels[value] ?? englishLabel;
  }

  String textInputPlaceholder(SacaLanguage? language) {
    return t(language, 'textPlaceholder');
  }

  String? voiceAccuracyNotice(SacaLanguage? language) {
    if (language != SacaLanguage.gurindji) return null;
    return t(language, 'voiceAccuracyNotice');
  }

  String errorMessage(SacaLanguage? language, String message) {
    if (language != SacaLanguage.gurindji) return message;
    return t(language, 'errorGeneric');
  }

  String severityLabel(SacaLanguage? language, SeverityLevel severity) {
    final key = switch (severity) {
      SeverityLevel.mild => 'severityMild',
      SeverityLevel.moderate => 'severityModerate',
      SeverityLevel.severe => 'severitySevere',
      SeverityLevel.emergency => 'severityEmergency',
    };
    return t(language, key);
  }

  List<String> guidance(SacaLanguage? language, AnalysisResult result) {
    if (language != SacaLanguage.gurindji) return result.guidance;
    return _gurindjiGuidance[result.disease] ??
        _gurindjiGuidance['General symptoms']!;
  }

  String disclaimer(SacaLanguage? language, String fallback) {
    if (language == SacaLanguage.gurindji) return t(language, 'disclaimer');
    return t(language, 'disclaimer');
  }

  List<String> progressLabels(SacaLanguage? language) {
    return [
      t(language, 'progressLanguage'),
      t(language, 'progressInput'),
      t(language, 'progressQuestions'),
      t(language, 'progressAnalysis'),
      t(language, 'progressResult'),
    ];
  }

  Map<String, String> _tableFor(SacaLanguage? language) {
    return language == SacaLanguage.gurindji ? _gurindji : _english;
  }
}
