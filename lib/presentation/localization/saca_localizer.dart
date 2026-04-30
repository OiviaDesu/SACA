import '../../domain/models/saca_models.dart';
import '../../domain/services/clinical_vocabulary_service.dart';

part 'saca_localizer_data.dart';

class SacaLocalizer {
  SacaLocalizer({ClinicalVocabularyService? vocabulary})
      : _vocabulary = vocabulary ?? const ClinicalVocabularyService.empty();

  final ClinicalVocabularyService _vocabulary;

  // Prototype Gurindji UI copy. It must be reviewed by a fluent Gurindji
  // speaker before clinical or community production use.
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
    return _englishDiseaseLabels[disease] ?? disease;
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

  String? voiceBusyTitle(SacaLanguage? language, VoiceBusyPhase phase) {
    return switch (phase) {
      VoiceBusyPhase.none => null,
      VoiceBusyPhase.preparing => t(language, 'voicePreparingTitle'),
      VoiceBusyPhase.transcribing => t(language, 'voiceTranscribingTitle'),
    };
  }

  String? voiceBusySubtitle(SacaLanguage? language, VoiceBusyPhase phase) {
    return switch (phase) {
      VoiceBusyPhase.none => null,
      VoiceBusyPhase.preparing => t(language, 'voicePreparingSubtitle'),
      VoiceBusyPhase.transcribing => t(language, 'voiceTranscribingSubtitle'),
    };
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
    if (language != SacaLanguage.gurindji) {
      return _englishGuidance[result.disease] ?? result.guidance;
    }
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
