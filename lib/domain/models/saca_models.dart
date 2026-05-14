import 'saca_catalogs.dart';

enum SacaLanguage { english, gurindji }

enum InputMethod { text, voice, visual }

enum SeverityLevel { mild, moderate, severe, emergency }

enum ConfidenceLevel { low, medium, high }

enum VoiceBusyPhase { none, preparing, transcribing }

enum SacaConfirmationType { emptyInput, noClearIllness }

enum SacaStep {
  splash,
  language,
  inputMethod,
  voiceInput,
  textInput,
  visualInput,
  questionSeverity,
  questionDuration,
  questionRelatedSymptoms,
  questionSkinDetails,
  questionMedication,
  questionFood,
  questionAllergies,
  questionHealthChanges,
  reviewInformation,
  settings,
  analysing,
  result,
}

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

enum BodyView { front, back }

class Symptom {
  const Symptom({required this.id, required this.label});

  final String id;
  final String label;
}

class BodyArea {
  const BodyArea({required this.id, required this.label, required this.view});

  final String id;
  final String label;
  final BodyView view;
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

class NonSpeechCue {
  const NonSpeechCue({
    required this.kind,
    required this.confidence,
    required this.evidence,
  });

  final String kind;
  final double confidence;
  final String evidence;
}

class SpeechSignalFeatures {
  const SpeechSignalFeatures({
    required this.transcript,
    this.cues = const <NonSpeechCue>[],
    this.confidence,
    this.qualityFlags = const <String>[],
    this.isSupported = true,
  });

  final String transcript;
  final List<NonSpeechCue> cues;
  final double? confidence;
  final List<String> qualityFlags;
  final bool isSupported;

  bool get hasUsableSignals {
    if (!isSupported || qualityFlags.isNotEmpty) return false;
    final value = confidence;
    return value == null || value >= 0.55;
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

class SacaFlowState {
  const SacaFlowState({
    this.step = SacaStep.splash,
    this.language,
    this.inputMethod,
    this.transcript = '',
    this.textInput = '',
    this.selectedSymptomIds = const <String>{},
    this.selectedBodyAreaIds = const <String>{},
    this.suggestedRelatedSymptomIds = const <String>[],
    this.voiceCueSuggestedSymptomIds = const <String>[],
    this.questionAnswers = const <String, String>{},
    this.speechSignalFeatures,
    this.voiceAnswerTranscript = '',
    this.voiceAnswerMatched = true,
    this.voiceDraftNotice,
    this.addMoreCount = 0,
    this.analysisResult,
    this.isRecording = false,
    this.isBusy = false,
    this.voiceBusyPhase = VoiceBusyPhase.none,
    this.pendingConfirmation,
    this.errorMessage,
  });

  final SacaStep step;
  final SacaLanguage? language;
  final InputMethod? inputMethod;
  final String transcript;
  final String textInput;
  final Set<String> selectedSymptomIds;
  final Set<String> selectedBodyAreaIds;
  final List<String> suggestedRelatedSymptomIds;
  final List<String> voiceCueSuggestedSymptomIds;
  final Map<String, String> questionAnswers;
  final SpeechSignalFeatures? speechSignalFeatures;
  final String voiceAnswerTranscript;
  final bool voiceAnswerMatched;
  final String? voiceDraftNotice;
  final int addMoreCount;
  final AnalysisResult? analysisResult;
  final bool isRecording;
  final bool isBusy;
  final VoiceBusyPhase voiceBusyPhase;
  final SacaConfirmationType? pendingConfirmation;
  final String? errorMessage;

  String get combinedInput => analysisRequest.combinedInput;

  AnalysisRequest get analysisRequest {
    return AnalysisRequest(
      language: language ?? SacaLanguage.english,
      inputMethod: inputMethod ?? InputMethod.text,
      transcript: transcript,
      textInput: textInput,
      selectedSymptomIds: selectedSymptomIds,
      selectedBodyAreaIds: selectedBodyAreaIds,
      answers: questionAnswers,
      speechSignalFeatures: speechSignalFeatures,
    );
  }

  SacaFlowState copyWith({
    SacaStep? step,
    SacaLanguage? language,
    bool clearLanguage = false,
    InputMethod? inputMethod,
    bool clearInputMethod = false,
    String? transcript,
    String? textInput,
    Set<String>? selectedSymptomIds,
    Set<String>? selectedBodyAreaIds,
    List<String>? suggestedRelatedSymptomIds,
    List<String>? voiceCueSuggestedSymptomIds,
    Map<String, String>? questionAnswers,
    SpeechSignalFeatures? speechSignalFeatures,
    bool clearSpeechSignalFeatures = false,
    String? voiceAnswerTranscript,
    bool? voiceAnswerMatched,
    String? voiceDraftNotice,
    bool clearVoiceDraftNotice = false,
    int? addMoreCount,
    AnalysisResult? analysisResult,
    bool clearAnalysisResult = false,
    bool? isRecording,
    bool? isBusy,
    VoiceBusyPhase? voiceBusyPhase,
    SacaConfirmationType? pendingConfirmation,
    bool clearPendingConfirmation = false,
    String? errorMessage,
    bool clearError = false,
  }) {
    return SacaFlowState(
      step: step ?? this.step,
      language: clearLanguage ? null : language ?? this.language,
      inputMethod: clearInputMethod ? null : inputMethod ?? this.inputMethod,
      transcript: transcript ?? this.transcript,
      textInput: textInput ?? this.textInput,
      selectedSymptomIds: selectedSymptomIds ?? this.selectedSymptomIds,
      selectedBodyAreaIds: selectedBodyAreaIds ?? this.selectedBodyAreaIds,
      suggestedRelatedSymptomIds:
          suggestedRelatedSymptomIds ?? this.suggestedRelatedSymptomIds,
      voiceCueSuggestedSymptomIds:
          voiceCueSuggestedSymptomIds ?? this.voiceCueSuggestedSymptomIds,
      questionAnswers: questionAnswers ?? this.questionAnswers,
      speechSignalFeatures: clearSpeechSignalFeatures
          ? null
          : speechSignalFeatures ?? this.speechSignalFeatures,
      voiceAnswerTranscript:
          voiceAnswerTranscript ?? this.voiceAnswerTranscript,
      voiceAnswerMatched: voiceAnswerMatched ?? this.voiceAnswerMatched,
      voiceDraftNotice: clearVoiceDraftNotice
          ? null
          : voiceDraftNotice ?? this.voiceDraftNotice,
      addMoreCount: addMoreCount ?? this.addMoreCount,
      analysisResult:
          clearAnalysisResult ? null : analysisResult ?? this.analysisResult,
      isRecording: isRecording ?? this.isRecording,
      isBusy: isBusy ?? this.isBusy,
      voiceBusyPhase: voiceBusyPhase ?? this.voiceBusyPhase,
      pendingConfirmation: clearPendingConfirmation
          ? null
          : pendingConfirmation ?? this.pendingConfirmation,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }

  static List<Symptom> get symptoms => SacaCatalogs.symptoms;
  static List<Symptom> get relatedSymptoms => SacaCatalogs.relatedSymptoms;
  static List<BodyArea> get bodyAreas => SacaCatalogs.bodyAreas;
}
