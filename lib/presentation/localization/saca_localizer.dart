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
    'languageSubtitle': 'SACA health check. SACA jangany nyawa.',
    'languageGurindjiLabel': 'Gurindji',
    'languageGurindjiDescription': 'Gurindji yawu nyawa.',
    'languageEnglishLabel': 'English',
    'languageEnglishDescription': 'Use English labels and questions.',
    'languageFootnote':
        'This app gives preliminary guidance only. SACA jangany nyawa. Nyangu-nyangu-wangu.',
    'inputTitle': 'How do you want to enter symptoms?',
    'inputSubtitle':
        'Choose one path. Every path asks the same follow-up questions.',
    'textInput': 'Text input',
    'textInputDescription': 'Type symptoms in simple words, such as fever.',
    'voiceInput': 'Voice input',
    'voiceInputDescription':
        'Record speech offline, then review the transcript.',
    'visualSelection': 'Visual selection',
    'visualSelectionDescription':
        'Tap symptoms and body areas on a simple diagram.',
    'voiceTitle': 'Voice input',
    'voiceSubtitle':
        'Speak clearly. Review and edit the transcript before continuing.',
    'stopRecording': 'Stop recording',
    'record': 'Record',
    'transcriptPlaceholder': 'Transcript will appear here.',
    'offlineSpeechNotice':
        'Offline speech recognition can make mistakes. Please check it.',
    'voiceAccuracyNotice':
        'Gurindji speech recognition is placeholder only. Please review the transcript or use text/visual input.',
    'useTranscript': 'Use transcript',
    'textTitle': 'Text input',
    'textSubtitle':
        'Write the main symptom first. The next screens ask for details.',
    'textPlaceholder': 'Example: fever',
    'visualTitle': 'Visual selection',
    'visualSubtitle':
        'Tap symptoms and any body areas that match what is happening.',
    'selected': 'Selected',
    'selectedEmpty': 'No symptoms or body areas selected yet.',
    'severityTitle': 'How strong is it?',
    'severitySubtitle': 'Choose a number from 1 to 10.',
    'durationTitle': 'How long has it been happening?',
    'durationSubtitle': 'Pick the closest answer.',
    'relatedTitle': 'Any related symptoms?',
    'relatedSubtitle': 'Select all that apply.',
    'medicationTitle': 'Have you taken medicine?',
    'medicationSubtitle': 'This helps avoid unsafe advice.',
    'foodTitle': 'Any recent food changes?',
    'foodSubtitle': 'Think about the last day or two.',
    'allergiesTitle': 'Any possible allergies?',
    'allergiesSubtitle':
        'Food, medicine, insects, or something in the environment.',
    'healthChangesTitle': 'Any recent health or lifestyle changes?',
    'healthChangesSubtitle':
        'This includes sleep, stress, travel, or sick contacts.',
    'continue': 'Continue',
    'analyse': 'Analyse',
    'analysingTitle': 'Analysing',
    'analysingSubtitle':
        'Checking symptoms with the offline placeholder model.',
    'noResultTitle': 'No result available',
    'noResultSubtitle': 'Please go back and run the analysis again.',
    'back': 'Back',
    'resultTitle': 'Triage guidance',
    'resultSubtitle': 'Use this to decide the next support step.',
    'finish': 'Finish',
    'startAgain': 'Start again',
    'offlineReady': 'Offline ready',
    'languageStatus': 'Language',
    'notSelected': 'Not selected',
    'assessmentFlow': 'Assessment flow',
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
    'possiblePattern': 'Possible pattern',
    'severity': 'Severity',
    'severityMild': 'Mild',
    'severityModerate': 'Moderate',
    'severitySevere': 'Severe',
    'severityEmergency': 'Emergency',
    'bodyAreaSemantic': 'Body area',
    'errorGeneric': 'Something went wrong. Please try again.',
    'disclaimer':
        'SACA provides preliminary triage guidance only. It does not replace a clinician.',
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
    'inputTitle': 'Nyatpa jangany nyawa?',
    'inputSubtitle': 'Nyawa yawu. Nyawa puya. Nyawa ngayirrp.',
    'textInput': 'Yawu',
    'textInputDescription': 'Jangany yawu nyawa.',
    'voiceInput': 'Ngayirrp',
    'voiceInputDescription': 'Ngayirrp nyawa. Yawu nyawa.',
    'visualSelection': 'Puya nyawa',
    'visualSelectionDescription': 'Jangany puya nyawa.',
    'voiceTitle': 'Ngayirrp',
    'voiceSubtitle': 'Ngayirrp yamak. Yawu nyawa jala.',
    'stopRecording': 'Kurtirni',
    'record': 'Ngayirrp',
    'transcriptPlaceholder': 'Yawu jala karrinyana.',
    'offlineSpeechNotice': 'Ngayirrp yawu mayi. Yawu nyawa.',
    'voiceAccuracyNotice': 'Gurindji ngayirrp mayi. Yawu nyawa.',
    'useTranscript': 'Yawu nyawa',
    'textTitle': 'Yawu',
    'textSubtitle': 'Jangany yawu nyawa. Ngana yawu nyawa kaput.',
    'textPlaceholder': 'makurrmakurr',
    'visualTitle': 'Puya nyawa',
    'visualSubtitle': 'Jangany nyawa. Puya nyawa.',
    'selected': 'Nyawa',
    'selectedEmpty': 'Jangany puya karrwarn.',
    'severityTitle': 'Nyatpa jangany?',
    'severitySubtitle': '1-10 nyawa.',
    'durationTitle': 'Nyangurla jala?',
    'durationSubtitle': 'Tirrip nyawa.',
    'relatedTitle': 'Jangany kirri?',
    'relatedSubtitle': 'Nyawa.',
    'medicationTitle': 'Mirrijin nyawa?',
    'medicationSubtitle': 'Mirrijin yamak nyawa.',
    'foodTitle': 'Mangarri jala?',
    'foodSubtitle': 'Jala puriny nyawa.',
    'allergiesTitle': 'Mawuya nyawa?',
    'allergiesSubtitle': 'Mangarri, mirrijin, mawuya nyawa.',
    'healthChangesTitle': 'Puya jala?',
    'healthChangesSubtitle': 'Makin, yawarra, kawayi nyawa.',
    'continue': 'Kawayi',
    'analyse': 'Nyawa',
    'analysingTitle': 'Nyawa jala',
    'analysingSubtitle': 'SACA jangany nyawa.',
    'noResultTitle': 'Nyawa karrwarn',
    'noResultSubtitle': 'Wart nyawa.',
    'back': 'Wart',
    'resultTitle': 'Jangany nyawa',
    'resultSubtitle': 'Kawayi nyawa.',
    'finish': 'Yuwa',
    'startAgain': 'Jala nyawa',
    'offlineReady': 'Yamak',
    'languageStatus': 'Yawu',
    'notSelected': 'Karrwarn',
    'assessmentFlow': 'Jangany yanku',
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
    return fallback;
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
