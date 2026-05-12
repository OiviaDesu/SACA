import 'dart:async';

import 'package:flutter/cupertino.dart';

import '../../core/errors/app_error.dart';
import '../../domain/models/saca_models.dart';
import '../../domain/services/analysis_service.dart';
import '../../domain/services/speech_input_service.dart';
import '../../domain/services/symptom_suggestion_service.dart';
import '../../domain/services/voice_command_matcher.dart';

class SacaFlowController extends ChangeNotifier {
  SacaFlowController({
    required SpeechInputService speechInput,
    required AnalysisService analysisService,
    SymptomSuggestionService symptomSuggestionService =
        const RuleBasedSymptomSuggestionService(),
    NonSpeechSuggestionService nonSpeechSuggestionService =
        const SafeNonSpeechSuggestionService(),
    VoiceCommandMatcher voiceCommandMatcher = const VoiceCommandMatcher(),
  })  : _speechInput = speechInput,
        _analysisService = analysisService,
        _symptomSuggestionService = symptomSuggestionService,
        _nonSpeechSuggestionService = nonSpeechSuggestionService,
        _voiceCommandMatcher = voiceCommandMatcher;

  final SpeechInputService _speechInput;
  final AnalysisService _analysisService;
  final SymptomSuggestionService _symptomSuggestionService;
  final NonSpeechSuggestionService _nonSpeechSuggestionService;
  final VoiceCommandMatcher _voiceCommandMatcher;
  StreamSubscription<String>? _partialTranscriptSubscription;
  int? _activeRecordingId;
  int _recordingSequence = 0;
  static const String _voiceDraftFallbackNoticeKey = 'voiceDraftFallbackNotice';

  SacaFlowState _state = const SacaFlowState();
  SacaStep? _settingsReturnStep;
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

  void updateLanguage(SacaLanguage language) {
    _setState(
      _state.copyWith(
        language: language,
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
    final mode = _isFollowUpQuestion(_state.step)
        ? SpeechInputMode.command
        : SpeechInputMode.dictation;
    final recordingId = ++_recordingSequence;
    _activeRecordingId = recordingId;
    _setState(
      _state.copyWith(
        isBusy: true,
        voiceBusyPhase: VoiceBusyPhase.none,
        voiceAnswerTranscript: '',
        voiceAnswerMatched: true,
        clearVoiceDraftNotice: true,
        clearError: true,
      ),
    );
    final result = await _speechInput.startRecording(mode: mode);
    if (!result.isSuccess) {
      if (_activeRecordingId == recordingId) {
        _activeRecordingId = null;
      }
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
        clearVoiceDraftNotice: true,
        clearError: true,
      ),
    );
    _listenForPartialTranscript(mode);
    _waitForAutoStop(mode, recordingId);
  }

  void _listenForPartialTranscript(SpeechInputMode mode) {
    _partialTranscriptSubscription?.cancel();
    if (mode != SpeechInputMode.dictation) return;
    _partialTranscriptSubscription =
        _speechInput.partialTranscriptStream.listen((transcript) {
      if (!_state.isRecording || _state.step != SacaStep.voiceInput) return;
      final cleaned = transcript.trim();
      if (cleaned.isEmpty || cleaned == _state.transcript.trim()) return;
      _setState(_state.copyWith(transcript: cleaned, clearError: true));
    });
  }

  void _stopPartialTranscript() {
    _partialTranscriptSubscription?.cancel();
    _partialTranscriptSubscription = null;
  }

  Future<void> _waitForAutoStop(SpeechInputMode mode, int recordingId) async {
    final result = await _speechInput.waitForAutoStopAndTranscribe(mode: mode);
    if (_activeRecordingId != recordingId || !_state.isRecording) return;
    _activeRecordingId = null;
    await _handleTranscriptionResult(result);
  }

  Future<void> stopRecording() async {
    _activeRecordingId = null;
    _setState(
      _state.copyWith(
        isBusy: true,
        isRecording: false,
        voiceBusyPhase: VoiceBusyPhase.transcribing,
      ),
    );
    _stopPartialTranscript();
    final mode = _isFollowUpQuestion(_state.step)
        ? SpeechInputMode.command
        : SpeechInputMode.dictation;
    final result = await _speechInput.stopAndTranscribe(mode: mode);
    await _handleTranscriptionResult(result);
  }

  Future<void> _handleTranscriptionResult(
    AppResult<SpeechInputResult> result,
  ) async {
    if (!result.isSuccess) {
      _stopPartialTranscript();
      final hasUsableDraft = _state.step == SacaStep.voiceInput &&
          _state.transcript.trim().isNotEmpty;
      _setState(
        _state.copyWith(
          isBusy: false,
          isRecording: false,
          voiceBusyPhase: VoiceBusyPhase.none,
          errorMessage: hasUsableDraft ? null : result.failure?.message,
          voiceDraftNotice:
              hasUsableDraft ? _voiceDraftFallbackNoticeKey : null,
          clearError: hasUsableDraft,
          clearVoiceDraftNotice: !hasUsableDraft,
        ),
      );
      return;
    }

    final transcript = result.value?.text ?? '';
    final signalFeatures = result.value?.signalFeatures;
    _stopPartialTranscript();
    if (_isFollowUpQuestion(_state.step)) {
      final stopwatch = Stopwatch()..start();
      final answer = _voiceCommandMatcher.match(_state.step, transcript);
      stopwatch.stop();
      debugPrint(
        '[SACA] Voice command parser match=${answer != null} '
        'latency=${stopwatch.elapsedMilliseconds}ms',
      );
      if (_state.step == SacaStep.questionRelatedSymptoms && answer == null) {
        final mergedCueSuggestions = _mergeVoiceCueRelatedSuggestions(
          signalFeatures,
          transcript,
        );
        if (mergedCueSuggestions) return;
      }
      final nextAnswers = Map<String, String>.from(_state.questionAnswers);
      if (answer != null) {
        nextAnswers[answer.questionId] = answer.value;
      }
      final nextStep =
          answer == null ? _state.step : _nextQuestionStep(_state.step);
      _setState(
        _state.copyWith(
          isBusy: false,
          isRecording: false,
          step: nextStep,
          voiceBusyPhase: VoiceBusyPhase.none,
          questionAnswers: nextAnswers,
          voiceAnswerTranscript: transcript,
          voiceAnswerMatched: answer != null,
          clearError: answer != null,
        ),
      );
      return;
    }

    _setState(
      _state.copyWith(
        isBusy: false,
        isRecording: false,
        voiceBusyPhase: VoiceBusyPhase.none,
        transcript: transcript,
        speechSignalFeatures: signalFeatures,
        voiceAnswerTranscript: '',
        voiceAnswerMatched: true,
        clearVoiceDraftNotice: true,
        clearError: true,
      ),
    );
  }

  void updateTranscript(String value) {
    _setState(_state.copyWith(
      transcript: value,
      clearSpeechSignalFeatures: true,
      clearError: true,
      clearVoiceDraftNotice: true,
    ));
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
    _setState(
      _state.copyWith(
        questionAnswers: next,
        voiceAnswerMatched: true,
        clearError: true,
      ),
    );
  }

  bool answerCurrentQuestionByVoice(String transcript) {
    final answer = _voiceCommandMatcher.match(_state.step, transcript);
    if (answer == null) {
      _setState(
        _state.copyWith(
          voiceAnswerTranscript: transcript,
          voiceAnswerMatched: false,
        ),
      );
      return false;
    }

    final next = Map<String, String>.from(_state.questionAnswers);
    next[answer.questionId] = answer.value;
    _setState(
      _state.copyWith(
        questionAnswers: next,
        voiceAnswerTranscript: transcript,
        voiceAnswerMatched: true,
        clearError: true,
      ),
    );
    return true;
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
            pendingConfirmation: SacaConfirmationType.emptyInput,
            clearError: true,
          ),
        );
        return;
      }

      final suggestions = _symptomSuggestionService.suggestRelatedSymptoms(
        _state.analysisRequest,
      );
      _setState(
        _state.copyWith(
          step: SacaStep.questionSeverity,
          suggestedRelatedSymptomIds: _filterKnownRelatedSymptoms(
            suggestions,
            _state.analysisRequest,
          ),
          voiceAnswerTranscript: '',
          voiceAnswerMatched: true,
          clearError: true,
        ),
      );
    }
  }

  void nextQuestion() {
    final nextStep = switch (_state.step) {
      SacaStep.questionSeverity ||
      SacaStep.questionDuration ||
      SacaStep.questionRelatedSymptoms ||
      SacaStep.questionMedication ||
      SacaStep.questionFood ||
      SacaStep.questionAllergies ||
      SacaStep.questionHealthChanges =>
        _nextQuestionStep(_state.step),
      _ => _state.step,
    };

    _setState(
      _state.copyWith(
        step: nextStep,
        voiceAnswerTranscript: '',
        voiceAnswerMatched: true,
        clearError: true,
      ),
    );
    if (nextStep == SacaStep.questionRelatedSymptoms) {
      _refineRelatedSymptomSuggestions();
    }
  }

  SacaStep _nextQuestionStep(SacaStep step) {
    return switch (step) {
      SacaStep.questionSeverity => SacaStep.questionDuration,
      SacaStep.questionDuration => SacaStep.questionRelatedSymptoms,
      SacaStep.questionRelatedSymptoms => SacaStep.questionMedication,
      SacaStep.questionMedication => SacaStep.questionFood,
      SacaStep.questionFood => SacaStep.questionAllergies,
      SacaStep.questionAllergies => SacaStep.questionHealthChanges,
      SacaStep.questionHealthChanges => SacaStep.reviewInformation,
      _ => step,
    };
  }

  void showReview() {
    _setState(
        _state.copyWith(step: SacaStep.reviewInformation, clearError: true));
  }

  void addMoreInformation() {
    if (_state.addMoreCount >= 2) return;
    _setState(
      _state.copyWith(
        step: SacaStep.inputMethod,
        addMoreCount: _state.addMoreCount + 1,
        clearInputMethod: true,
        clearError: true,
      ),
    );
  }

  void startOverKeepLanguage() {
    final language = _state.language;
    _setState(
      SacaFlowState(
        step: SacaStep.inputMethod,
        language: language,
      ),
    );
  }

  void finish() {
    _setState(const SacaFlowState(step: SacaStep.language));
  }

  Future<void> _refineRelatedSymptomSuggestions() async {
    final request = _state.analysisRequest;
    final suggestions = <String>{
      ...await _symptomSuggestionService.refineRelatedSymptoms(request),
    };
    final voiceCueSuggestions = _filterKnownRelatedSymptoms(
      _nonSpeechSuggestionService.reviewOnlySuggestions(request),
      request,
    );
    suggestions.addAll(voiceCueSuggestions);
    if (_state.step != SacaStep.questionRelatedSymptoms) return;
    _setState(
      _state.copyWith(
        suggestedRelatedSymptomIds: _filterKnownRelatedSymptoms(
          suggestions,
          request,
        ),
        voiceCueSuggestedSymptomIds: voiceCueSuggestions,
      ),
    );
  }

  List<String> _filterKnownRelatedSymptoms(
    Iterable<String> ids,
    AnalysisRequest request,
  ) {
    final known = RuleBasedSymptomSuggestionService.knownSymptomIds(request);
    return RuleBasedSymptomSuggestionService.orderedRelatedSymptoms(
      ids.where((id) => !known.contains(id)),
    );
  }

  bool _mergeVoiceCueRelatedSuggestions(
    SpeechSignalFeatures? signalFeatures,
    String transcript,
  ) {
    if (signalFeatures == null || !signalFeatures.hasUsableSignals) {
      return false;
    }
    final request = _state.analysisRequest.copyWith(
      transcript: transcript.isNotEmpty ? transcript : _state.transcript,
      speechSignalFeatures: signalFeatures,
    );
    final voiceCueSuggestions = _filterKnownRelatedSymptoms(
      _nonSpeechSuggestionService.reviewOnlySuggestions(request),
      request,
    );
    if (voiceCueSuggestions.isEmpty) return false;

    final mergedSuggestions =
        RuleBasedSymptomSuggestionService.orderedRelatedSymptoms(<String>{
      ..._state.suggestedRelatedSymptomIds,
      ...voiceCueSuggestions,
    });
    final mergedVoiceCueSuggestions =
        RuleBasedSymptomSuggestionService.orderedRelatedSymptoms(<String>{
      ..._state.voiceCueSuggestedSymptomIds,
      ...voiceCueSuggestions,
    });
    _setState(
      _state.copyWith(
        isBusy: false,
        isRecording: false,
        voiceBusyPhase: VoiceBusyPhase.none,
        suggestedRelatedSymptomIds: mergedSuggestions,
        voiceCueSuggestedSymptomIds: mergedVoiceCueSuggestions,
        speechSignalFeatures: signalFeatures,
        voiceAnswerTranscript: transcript,
        voiceAnswerMatched: true,
        clearError: true,
      ),
    );
    return true;
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

    final value = result.value;
    if (value != null &&
        !value.isEmergency &&
        value.disease == 'No clear illness detected') {
      _setState(
        _state.copyWith(
          isBusy: false,
          pendingConfirmation: SacaConfirmationType.noClearIllness,
          analysisResult: value,
          clearError: true,
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

  void confirmPendingAction() {
    final pending = _state.pendingConfirmation;
    if (pending == null) return;
    if (pending == SacaConfirmationType.emptyInput) {
      _setState(_state.copyWith(clearPendingConfirmation: true));
      return;
    }
    if (pending == SacaConfirmationType.noClearIllness &&
        _state.analysisResult != null) {
      _setState(
        _state.copyWith(
          step: SacaStep.result,
          clearPendingConfirmation: true,
          clearError: true,
        ),
      );
    }
  }

  void dismissPendingConfirmation() {
    _setState(
      _state.copyWith(
        step: _state.pendingConfirmation == SacaConfirmationType.noClearIllness
            ? SacaStep.questionHealthChanges
            : _state.step,
        isBusy: false,
        clearPendingConfirmation: true,
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
      SacaStep.reviewInformation => SacaStep.questionHealthChanges,
      SacaStep.settings => _settingsReturnStep ?? SacaStep.language,
      SacaStep.analysing => SacaStep.questionHealthChanges,
      SacaStep.result => SacaStep.reviewInformation,
    };

    if (_state.step == SacaStep.settings) {
      _settingsReturnStep = null;
    }

    _setState(_state.copyWith(step: previous, clearError: true));
  }

  void showSettings() {
    if (_state.step == SacaStep.settings) {
      goBack();
      return;
    }
    _settingsReturnStep = _state.step;
    _setState(_state.copyWith(step: SacaStep.settings, clearError: true));
  }

  void reset() {
    finish();
  }

  @override
  void dispose() {
    _stopPartialTranscript();
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

  bool _isFollowUpQuestion(SacaStep step) {
    return switch (step) {
      SacaStep.questionSeverity ||
      SacaStep.questionDuration ||
      SacaStep.questionRelatedSymptoms ||
      SacaStep.questionMedication ||
      SacaStep.questionFood ||
      SacaStep.questionAllergies ||
      SacaStep.questionHealthChanges =>
        true,
      _ => false,
    };
  }

  void updateQuestionAnswer(String questionId, String answer) {
    final next = Map<String, String>.from(_state.questionAnswers);
    if (answer.trim().isEmpty) {
      next.remove(questionId);
    } else {
      next[questionId] = answer;
    }
    _setState(
      _state.copyWith(
        questionAnswers: next,
        voiceAnswerMatched: true,
        clearError: true,
      ),
    );
  }

  void showQuestionAnswerField(String questionId) {
    final next = Map<String, String>.from(_state.questionAnswers);
    next.putIfAbsent(questionId, () => '');
    _setState(
      _state.copyWith(
        questionAnswers: next,
        voiceAnswerMatched: true,
        clearError: true,
      ),
    );
  }
}
