part of 'saca_models.dart';

class ConditionPrediction {
  const ConditionPrediction({
    required this.label,
    required this.rank,
    this.confidence,
  });

  final String label;
  final int rank;
  final double? confidence;

  ConfidenceLevel get confidenceLevel {
    final value = confidence;
    if (value == null) return ConfidenceLevel.low;
    if (value >= 0.70) return ConfidenceLevel.high;
    if (value >= 0.40) return ConfidenceLevel.medium;
    return ConfidenceLevel.low;
  }

  int? get confidencePercent {
    final value = confidence;
    if (value == null) return null;
    return (value * 100).round().clamp(0, 100);
  }
}

class AnalysisResult {
  const AnalysisResult({
    required this.disease,
    required this.severity,
    required this.guidance,
    required this.isEmergency,
    required this.disclaimer,
    this.predictions = const <ConditionPrediction>[],
  });

  final String disease;
  final SeverityLevel severity;
  final List<String> guidance;
  final bool isEmergency;
  final String disclaimer;
  final List<ConditionPrediction> predictions;

  AnalysisResult copyWith({
    String? disease,
    SeverityLevel? severity,
    List<String>? guidance,
    bool? isEmergency,
    String? disclaimer,
    List<ConditionPrediction>? predictions,
  }) {
    return AnalysisResult(
      disease: disease ?? this.disease,
      severity: severity ?? this.severity,
      guidance: guidance ?? this.guidance,
      isEmergency: isEmergency ?? this.isEmergency,
      disclaimer: disclaimer ?? this.disclaimer,
      predictions: predictions ?? this.predictions,
    );
  }
}

class AnalysisRequest {
  const AnalysisRequest({
    required this.language,
    required this.inputMethod,
    required this.transcript,
    required this.textInput,
    required this.selectedSymptomIds,
    required this.selectedBodyAreaIds,
    required this.answers,
    this.speechSignalFeatures,
  });

  final SacaLanguage language;
  final InputMethod inputMethod;
  final String transcript;
  final String textInput;
  final Set<String> selectedSymptomIds;
  final Set<String> selectedBodyAreaIds;
  final Map<String, String> answers;
  final SpeechSignalFeatures? speechSignalFeatures;

  String get combinedInput {
    return [
      transcript,
      textInput,
      selectedSymptomIds.join(' '),
      selectedBodyAreaIds.join(' '),
      answers.values.join(' '),
    ].where((item) => item.trim().isNotEmpty).join(' ');
  }

  AnalysisRequest copyWith({
    SacaLanguage? language,
    InputMethod? inputMethod,
    String? transcript,
    String? textInput,
    Set<String>? selectedSymptomIds,
    Set<String>? selectedBodyAreaIds,
    Map<String, String>? answers,
    SpeechSignalFeatures? speechSignalFeatures,
    bool clearSpeechSignalFeatures = false,
  }) {
    return AnalysisRequest(
      language: language ?? this.language,
      inputMethod: inputMethod ?? this.inputMethod,
      transcript: transcript ?? this.transcript,
      textInput: textInput ?? this.textInput,
      selectedSymptomIds: selectedSymptomIds ?? this.selectedSymptomIds,
      selectedBodyAreaIds: selectedBodyAreaIds ?? this.selectedBodyAreaIds,
      answers: answers ?? this.answers,
      speechSignalFeatures: clearSpeechSignalFeatures
          ? null
          : speechSignalFeatures ?? this.speechSignalFeatures,
    );
  }
}
