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

    final transcript = result.value?.text ?? '';
    if (_isFollowUpQuestion(_state.step)) {
      final answer = _voiceAnswerForStep(_state.step, transcript);
      final nextAnswers = Map<String, String>.from(_state.questionAnswers);
      if (answer != null) {
        nextAnswers[answer.questionId] = answer.value;
      }
      _setState(
        _state.copyWith(
          isBusy: false,
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
        voiceBusyPhase: VoiceBusyPhase.none,
        transcript: transcript,
        voiceAnswerTranscript: '',
        voiceAnswerMatched: true,
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
    _setState(
      _state.copyWith(
        questionAnswers: next,
        voiceAnswerMatched: true,
        clearError: true,
      ),
    );
  }

  bool answerCurrentQuestionByVoice(String transcript) {
    final answer = _voiceAnswerForStep(_state.step, transcript);
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

    _setState(
      _state.copyWith(
        step: nextStep,
        voiceAnswerTranscript: '',
        voiceAnswerMatched: true,
        clearError: true,
      ),
    );
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

  _VoiceAnswer? _voiceAnswerForStep(SacaStep step, String transcript) {
    final normalized = _normalizeVoiceText(transcript);
    if (normalized.isEmpty) return null;
    return switch (step) {
      SacaStep.questionSeverity => _severityVoiceAnswer(normalized),
      SacaStep.questionDuration => _choiceVoiceAnswer('duration', normalized, {
          'more than seven days': [
            'more than seven days',
            'more than 7 days',
            'more than seven',
            'more than 7',
            'over seven days',
            'over 7 days',
            'over seven',
            'over 7',
            'greater than seven',
            'greater than 7',
            'longer than seven',
            'longer than 7',
            'after seven days',
            'after 7 days',
            'seven plus',
            '7 plus',
            'above seven',
            'above 7',
            'more than week',
          ],
          'four to seven days': [
            'four to seven days',
            '4 to 7 days',
            'four seven days',
            '4 7 days',
            'four to seven',
            '4 to 7',
            'four seven',
            '4 7',
            'one week',
            'a week',
            'week',
          ],
          'one to three days': [
            'one to three days',
            '1 to 3 days',
            'one three days',
            '1 3 days',
            'one to three',
            '1 to 3',
            'one three',
            '1 3',
            'three days',
            '3 days',
          ],
          'less than one day': [
            'less than one day',
            'less than 1 day',
            'under one day',
            'under 1 day',
            'less than day',
            'today',
          ],
        }),
      SacaStep.questionRelatedSymptoms =>
        _relatedSymptomsVoiceAnswer(normalized),
      SacaStep.questionMedication =>
        _choiceVoiceAnswer('medication', normalized, {
          'not sure medication': [
            'not sure medication',
            'not sure',
            'unsure',
            'maybe'
          ],
          'taken medication': [
            'taken medication',
            'yes',
            'medicine',
            'medication'
          ],
          'no medication': ['no medication', 'none medication', 'no', 'none'],
        }),
      SacaStep.questionFood => _choiceVoiceAnswer('food', normalized, {
          'not sure food': ['not sure food', 'not sure', 'unsure', 'maybe'],
          'skipped meals': [
            'skipped meals',
            'skipped',
            'missed meal',
            'not eating'
          ],
          'unfamiliar food': [
            'unfamiliar food',
            'unfamiliar',
            'new food',
            'different food'
          ],
          'no food change': [
            'no food change',
            'no change',
            'same food',
            'normal food',
            'no'
          ],
        }),
      SacaStep.questionAllergies =>
        _choiceVoiceAnswer('allergies', normalized, {
          'not sure allergies': [
            'not sure allergies',
            'not sure allergy',
            'not sure',
            'unsure',
            'maybe'
          ],
          'no known allergies': [
            'no known allergies',
            'no known allergy',
            'no allergies',
            'no allergy',
            'no known',
            'none',
            'no'
          ],
          'possible allergies': ['allergy', 'allergies', 'yes'],
        }),
      SacaStep.questionHealthChanges =>
        _choiceVoiceAnswer('health_changes', normalized, {
          'sick contact or travel': ['sick contact', 'travel', 'someone sick'],
          'sleep or stress change': ['sleep', 'stress', 'tired'],
          'not sure health change': [
            'not sure health',
            'not sure',
            'unsure',
            'maybe'
          ],
          'no recent health change': [
            'no recent health change',
            'no health change',
            'no change',
            'normal',
            'no'
          ],
        }),
      _ => null,
    };
  }

  _VoiceAnswer? _severityVoiceAnswer(String normalized) {
    const words = {
      'one': 1,
      'two': 2,
      'three': 3,
      'four': 4,
      'five': 5,
      'six': 6,
      'seven': 7,
      'eight': 8,
      'nine': 9,
      'ten': 10,
    };
    final numericMatch = RegExp(r'\b(10|[1-9])\b').firstMatch(normalized);
    var value = numericMatch == null ? null : int.parse(numericMatch.group(1)!);
    for (final entry in words.entries) {
      if (value == null && normalized.contains(entry.key)) {
        value = entry.value;
      }
    }
    if (value == null) {
      if (normalized.contains('emergency')) value = 10;
      if (normalized.contains('severe')) value = 9;
      if (normalized.contains('moderate')) value = 5;
      if (normalized.contains('mild')) value = 2;
    }
    return value == null
        ? null
        : _VoiceAnswer('severity', value.clamp(1, 10).toString());
  }

  _VoiceAnswer? _choiceVoiceAnswer(
    String questionId,
    String normalized,
    Map<String, List<String>> keywords,
  ) {
    for (final entry in keywords.entries) {
      if (_matchesAnyVoiceKeyword(normalized, entry.value)) {
        return _VoiceAnswer(questionId, entry.key);
      }
    }
    return null;
  }

  bool _matchesAnyVoiceKeyword(String normalized, List<String> keywords) {
    return keywords.any((keyword) {
      final normalizedKeyword = _normalizeVoiceText(keyword);
      if (normalizedKeyword.isEmpty) return false;
      return ' $normalized '.contains(' $normalizedKeyword ');
    });
  }

  _VoiceAnswer? _relatedSymptomsVoiceAnswer(String normalized) {
    final matches = <String>{};
    for (final symptom in SacaFlowState.relatedSymptoms) {
      final label = _normalizeVoiceText(symptom.label);
      if (normalized.contains(label) ||
          normalized.contains(symptom.id.replaceAll('_', ' '))) {
        matches.add(symptom.id);
      }
    }
    if (matches.isEmpty) return null;
    if (matches.contains('none')) {
      return const _VoiceAnswer('related_symptoms', 'none');
    }
    matches.remove('none');
    return _VoiceAnswer('related_symptoms', matches.join('|'));
  }

  String _normalizeVoiceText(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'>\s*7'), 'more than 7')
        .replaceAll(RegExp(r'>\s*seven'), 'more than seven')
        .replaceAll(RegExp(r'<\s*1'), 'less than 1')
        .replaceAll(RegExp(r'<\s*one'), 'less than one')
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .trim();
  }
}

class _VoiceAnswer {
  const _VoiceAnswer(this.questionId, this.value);

  final String questionId;
  final String value;
}
