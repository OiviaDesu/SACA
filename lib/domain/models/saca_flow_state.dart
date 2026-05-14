part of 'saca_models.dart';

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
