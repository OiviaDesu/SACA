import 'package:flutter/cupertino.dart';

import '../../domain/models/saca_models.dart';
import '../../domain/services/analysis_service.dart';
import '../../domain/services/speech_input_service.dart';

class SacaFlowController extends ChangeNotifier {
  SacaFlowController({
    required SpeechInputService speechInput,
    required AnalysisService analysisService,
  })  : _speechInput = speechInput,
        _analysisService = analysisService;

  final SpeechInputService _speechInput;
  final AnalysisService _analysisService;

  SacaFlowState _state = const SacaFlowState();
  SacaFlowState get state => _state;

  bool get supportsVoiceInput => _speechInput.supportsOnDeviceStt;

  void showLanguage() {
    _setState(_state.copyWith(step: SacaStep.language, clearError: true));
  }

  void selectLanguage(SacaLanguage language) {
    _setState(
      _state.copyWith(
        language: language,
        step: SacaStep.inputMethod,
        clearError: true,
      ),
    );
  }

  Future<void> chooseInputMethod(InputMethod method) async {
    if (method == InputMethod.voice) {
      _setState(
        _state.copyWith(
          inputMethod: method,
          step: SacaStep.voiceInput,
          isBusy: true,
          voiceBusyPhase: VoiceBusyPhase.preparing,
          clearError: true,
        ),
      );

      final result = await _speechInput.prepare(
        _state.language ?? SacaLanguage.english,
      );
      if (!result.isSuccess) {
        _setState(
          _state.copyWith(
            isBusy: false,
            voiceBusyPhase: VoiceBusyPhase.none,
            errorMessage: result.failure?.message,
          ),
        );
        return;
      }
      _setState(
        _state.copyWith(
          isBusy: false,
          voiceBusyPhase: VoiceBusyPhase.none,
          clearError: true,
        ),
      );
      return;
    }

    _setState(
      _state.copyWith(
        inputMethod: method,
        step: _stepForMethod(method),
        voiceBusyPhase: VoiceBusyPhase.none,
        clearError: true,
      ),
    );
  }

  Future<void> startRecording() async {
    _setState(
      _state.copyWith(
        isBusy: true,
        voiceBusyPhase: VoiceBusyPhase.none,
        clearError: true,
      ),
    );
    final result = await _speechInput.startRecording();
    if (!result.isSuccess) {
      _setState(
        _state.copyWith(
          isBusy: false,
          isRecording: false,
          voiceBusyPhase: VoiceBusyPhase.none,
          errorMessage: result.failure?.message,
        ),
      );
      return;
    }

    _setState(
      _state.copyWith(
        isBusy: false,
        isRecording: true,
        voiceBusyPhase: VoiceBusyPhase.none,
        clearError: true,
      ),
    );
  }

  Future<void> stopRecording() async {
    _setState(
      _state.copyWith(
        isBusy: true,
        isRecording: false,
        voiceBusyPhase: VoiceBusyPhase.transcribing,
      ),
    );
    final result = await _speechInput.stopAndTranscribe();
    if (!result.isSuccess) {
      _setState(
        _state.copyWith(
          isBusy: false,
          voiceBusyPhase: VoiceBusyPhase.none,
          errorMessage: result.failure?.message,
        ),
      );
      return;
    }

    _setState(
      _state.copyWith(
        isBusy: false,
        voiceBusyPhase: VoiceBusyPhase.none,
        transcript: result.value?.text ?? '',
        clearError: true,
      ),
    );
  }

  void updateTranscript(String value) {
    _setState(_state.copyWith(transcript: value, clearError: true));
  }

  void updateTextInput(String value) {
    _setState(_state.copyWith(textInput: value, clearError: true));
  }

  void toggleSymptom(String id) {
    final next = Set<String>.from(_state.selectedSymptomIds);
    if (!next.add(id)) {
      next.remove(id);
    }
    _setState(_state.copyWith(selectedSymptomIds: next, clearError: true));
  }

  void toggleBodyArea(String id) {
    final next = Set<String>.from(_state.selectedBodyAreaIds);
    if (!next.add(id)) {
      next.remove(id);
    }
    _setState(_state.copyWith(selectedBodyAreaIds: next, clearError: true));
  }

  void answerQuestion(String questionId, String answer) {
    final next = Map<String, String>.from(_state.questionAnswers);
    next[questionId] = answer;
    _setState(_state.copyWith(questionAnswers: next, clearError: true));
  }

  void toggleQuestionOption(String questionId, String option) {
    final current = _state.questionAnswers[questionId]
            ?.split('|')
            .where((item) => item.isNotEmpty)
            .toSet() ??
        <String>{};

    if (option == 'none') {
      current
        ..clear()
        ..add(option);
    } else {
      current.remove('none');
      if (!current.add(option)) {
        current.remove(option);
      }
    }

    final next = Map<String, String>.from(_state.questionAnswers);
    if (current.isEmpty) {
      next.remove(questionId);
    } else {
      next[questionId] = current.join('|');
    }
    _setState(_state.copyWith(questionAnswers: next, clearError: true));
  }

  bool hasQuestionAnswer(String questionId, String option) {
    return _state.questionAnswers[questionId]?.split('|').contains(option) ??
        false;
  }

  void continueFromInput() {
    if (_state.step == SacaStep.voiceInput ||
        _state.step == SacaStep.textInput ||
        _state.step == SacaStep.visualInput) {
      if (_state.combinedInput.trim().isEmpty) {
        _setState(
          _state.copyWith(
            errorMessage: 'Please add a symptom before continuing.',
          ),
        );
        return;
      }

      _setState(
        _state.copyWith(step: SacaStep.questionSeverity, clearError: true),
      );
    }
  }

  void nextQuestion() {
    final nextStep = switch (_state.step) {
      SacaStep.questionSeverity => SacaStep.questionDuration,
      SacaStep.questionDuration => SacaStep.questionRelatedSymptoms,
      SacaStep.questionRelatedSymptoms => SacaStep.questionMedication,
      SacaStep.questionMedication => SacaStep.questionFood,
      SacaStep.questionFood => SacaStep.questionAllergies,
      SacaStep.questionAllergies => SacaStep.questionHealthChanges,
      _ => _state.step,
    };

    _setState(_state.copyWith(step: nextStep, clearError: true));
  }

  Future<void> analyse() async {
    _setState(
      _state.copyWith(
        step: SacaStep.analysing,
        isBusy: true,
        clearAnalysisResult: true,
        clearError: true,
      ),
    );

    final result = await _analysisService.analyse(_state.analysisRequest);
    if (!result.isSuccess) {
      _setState(
        _state.copyWith(
          step: SacaStep.questionHealthChanges,
          isBusy: false,
          errorMessage: result.failure?.message,
        ),
      );
      return;
    }

    _setState(
      _state.copyWith(
        step: SacaStep.result,
        isBusy: false,
        analysisResult: result.value,
        clearError: true,
      ),
    );
  }

  void goBack() {
    final previous = switch (_state.step) {
      SacaStep.splash => SacaStep.splash,
      SacaStep.language => SacaStep.splash,
      SacaStep.inputMethod => SacaStep.language,
      SacaStep.voiceInput => SacaStep.inputMethod,
      SacaStep.textInput => SacaStep.inputMethod,
      SacaStep.visualInput => SacaStep.inputMethod,
      SacaStep.questionSeverity => _stepForMethod(
          _state.inputMethod ?? InputMethod.text,
        ),
      SacaStep.questionDuration => SacaStep.questionSeverity,
      SacaStep.questionRelatedSymptoms => SacaStep.questionDuration,
      SacaStep.questionMedication => SacaStep.questionRelatedSymptoms,
      SacaStep.questionFood => SacaStep.questionMedication,
      SacaStep.questionAllergies => SacaStep.questionFood,
      SacaStep.questionHealthChanges => SacaStep.questionAllergies,
      SacaStep.analysing => SacaStep.questionHealthChanges,
      SacaStep.result => SacaStep.questionHealthChanges,
    };

    _setState(_state.copyWith(step: previous, clearError: true));
  }

  void reset() {
    _setState(
      SacaFlowState(
        step: SacaStep.language,
        language: _state.language,
      ),
    );
  }

  @override
  void dispose() {
    _speechInput.dispose();
    super.dispose();
  }

  SacaStep _stepForMethod(InputMethod method) {
    switch (method) {
      case InputMethod.text:
        return SacaStep.textInput;
      case InputMethod.voice:
        return SacaStep.voiceInput;
      case InputMethod.visual:
        return SacaStep.visualInput;
    }
  }

  void _setState(SacaFlowState value) {
    _state = value;
    notifyListeners();
  }
}
