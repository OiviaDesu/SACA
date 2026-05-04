enum SacaLanguage { english, gurindji }

enum InputMethod { text, voice, visual }

enum SeverityLevel { mild, moderate, severe, emergency }

enum VoiceBusyPhase { none, preparing, transcribing }

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
  questionMedication,
  questionFood,
  questionAllergies,
  questionHealthChanges,
  analysing,
  result,
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
  });

  final String disease;
  final SeverityLevel severity;
  final List<String> guidance;
  final bool isEmergency;
  final String disclaimer;

  AnalysisResult copyWith({
    String? disease,
    SeverityLevel? severity,
    List<String>? guidance,
    bool? isEmergency,
    String? disclaimer,
  }) {
    return AnalysisResult(
      disease: disease ?? this.disease,
      severity: severity ?? this.severity,
      guidance: guidance ?? this.guidance,
      isEmergency: isEmergency ?? this.isEmergency,
      disclaimer: disclaimer ?? this.disclaimer,
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
  });

  final SacaLanguage language;
  final InputMethod inputMethod;
  final String transcript;
  final String textInput;
  final Set<String> selectedSymptomIds;
  final Set<String> selectedBodyAreaIds;
  final Map<String, String> answers;

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
  }) {
    return AnalysisRequest(
      language: language ?? this.language,
      inputMethod: inputMethod ?? this.inputMethod,
      transcript: transcript ?? this.transcript,
      textInput: textInput ?? this.textInput,
      selectedSymptomIds: selectedSymptomIds ?? this.selectedSymptomIds,
      selectedBodyAreaIds: selectedBodyAreaIds ?? this.selectedBodyAreaIds,
      answers: answers ?? this.answers,
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
    this.questionAnswers = const <String, String>{},
    this.voiceAnswerTranscript = '',
    this.voiceAnswerMatched = true,
    this.analysisResult,
    this.isRecording = false,
    this.isBusy = false,
    this.voiceBusyPhase = VoiceBusyPhase.none,
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
  final Map<String, String> questionAnswers;
  final String voiceAnswerTranscript;
  final bool voiceAnswerMatched;
  final AnalysisResult? analysisResult;
  final bool isRecording;
  final bool isBusy;
  final VoiceBusyPhase voiceBusyPhase;
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
    Map<String, String>? questionAnswers,
    String? voiceAnswerTranscript,
    bool? voiceAnswerMatched,
    AnalysisResult? analysisResult,
    bool clearAnalysisResult = false,
    bool? isRecording,
    bool? isBusy,
    VoiceBusyPhase? voiceBusyPhase,
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
      questionAnswers: questionAnswers ?? this.questionAnswers,
      voiceAnswerTranscript:
          voiceAnswerTranscript ?? this.voiceAnswerTranscript,
      voiceAnswerMatched: voiceAnswerMatched ?? this.voiceAnswerMatched,
      analysisResult:
          clearAnalysisResult ? null : analysisResult ?? this.analysisResult,
      isRecording: isRecording ?? this.isRecording,
      isBusy: isBusy ?? this.isBusy,
      voiceBusyPhase: voiceBusyPhase ?? this.voiceBusyPhase,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }

  static const symptoms = <Symptom>[
    Symptom(id: 'headache', label: 'Headache'),
    Symptom(id: 'fever', label: 'Fever'),
    Symptom(id: 'stomachache', label: 'Stomachache'),
    Symptom(id: 'sore_throat', label: 'Sore throat'),
    Symptom(id: 'chest_pain', label: 'Chest pain'),
    Symptom(id: 'breathing_trouble', label: 'Breathing trouble'),
    Symptom(id: 'vomiting', label: 'Vomiting'),
    Symptom(id: 'bloating', label: 'Bloating'),
  ];

  static const relatedSymptoms = <Symptom>[
    Symptom(id: 'none', label: 'None'),
    Symptom(id: 'sore_throat', label: 'Sore throat'),
    Symptom(id: 'headache', label: 'Headache'),
    Symptom(id: 'cough', label: 'Cough'),
    Symptom(id: 'nausea_vomiting', label: 'Nausea or vomiting'),
    Symptom(id: 'rash', label: 'Rash'),
    Symptom(id: 'chest_pain', label: 'Chest pain'),
    Symptom(id: 'breathing_trouble', label: 'Breathing trouble'),
  ];

  static const bodyAreas = <BodyArea>[
    BodyArea(id: 'head', label: 'Head', view: BodyView.front),
    BodyArea(id: 'eyes', label: 'Eyes', view: BodyView.front),
    BodyArea(id: 'throat', label: 'Throat', view: BodyView.front),
    BodyArea(id: 'heart', label: 'Heart', view: BodyView.front),
    BodyArea(id: 'chest', label: 'Chest', view: BodyView.front),
    BodyArea(id: 'stomach', label: 'Stomach', view: BodyView.front),
    BodyArea(id: 'hand', label: 'Hand', view: BodyView.front),
    BodyArea(id: 'leg', label: 'Leg', view: BodyView.front),
    BodyArea(id: 'knees', label: 'Knees', view: BodyView.front),
    BodyArea(id: 'toes', label: 'Toes', view: BodyView.front),

    BodyArea(id: 'ears', label: 'Ears', view: BodyView.back),
    BodyArea(id: 'neck', label: 'Neck', view: BodyView.back),
    BodyArea(id: 'shoulder', label: 'Shoulder', view: BodyView.back),
    BodyArea(id: 'back', label: 'Back', view: BodyView.back),
    BodyArea(id: 'arm', label: 'Arm', view: BodyView.back),

    // New back-view body area.
    BodyArea(id: 'elbow', label: 'Elbow', view: BodyView.back),

    BodyArea(id: 'lower_back', label: 'Lower Back', view: BodyView.back),
    BodyArea(id: 'finger', label: 'Finger', view: BodyView.back),
    BodyArea(id: 'lower_leg', label: 'Lower Leg', view: BodyView.back),
    BodyArea(id: 'ankle', label: 'Ankle', view: BodyView.back),
  ];
}
