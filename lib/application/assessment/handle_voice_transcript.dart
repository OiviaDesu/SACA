import '../../domain/models/saca_models.dart';
import '../../domain/services/related_symptom_policy.dart';
import '../../domain/services/saca_flow_step_policy.dart';
import '../../domain/services/symptom_suggestion_service.dart';
import '../../domain/services/voice_command_matcher.dart';

class HandleVoiceTranscript {
  const HandleVoiceTranscript({
    VoiceCommandMatcher voiceCommandMatcher = const VoiceCommandMatcher(),
    SacaFlowStepPolicy stepPolicy = const SacaFlowStepPolicy(),
    NonSpeechSuggestionService nonSpeechSuggestionService =
        const SafeNonSpeechSuggestionService(),
    RelatedSymptomPolicy relatedSymptomPolicy = const RelatedSymptomPolicy(),
  })  : _voiceCommandMatcher = voiceCommandMatcher,
        _stepPolicy = stepPolicy,
        _nonSpeechSuggestionService = nonSpeechSuggestionService,
        _relatedSymptomPolicy = relatedSymptomPolicy;

  final VoiceCommandMatcher _voiceCommandMatcher;
  final SacaFlowStepPolicy _stepPolicy;
  final NonSpeechSuggestionService _nonSpeechSuggestionService;
  final RelatedSymptomPolicy _relatedSymptomPolicy;

  SacaFlowState call(
    SacaFlowState state,
    String transcript, {
    SpeechSignalFeatures? signalFeatures,
  }) {
    if (_stepPolicy.isFollowUpQuestion(state.step)) {
      final answer = _voiceCommandMatcher.match(state.step, transcript);
      if (state.step == SacaStep.questionRelatedSymptoms && answer == null) {
        final cueState = _mergeVoiceCueRelatedSuggestions(
          state,
          transcript,
          signalFeatures,
        );
        if (cueState != null) return cueState;
      }
      final nextAnswers = Map<String, String>.from(state.questionAnswers);
      if (answer != null) {
        nextAnswers[answer.questionId] = answer.value;
      }
      final nextStep = answer == null
          ? state.step
          : _stepPolicy.nextQuestionStep(state.step, state);
      return state.copyWith(
        isBusy: false,
        isRecording: false,
        step: nextStep,
        voiceBusyPhase: VoiceBusyPhase.none,
        questionAnswers: nextAnswers,
        voiceAnswerTranscript: transcript,
        voiceAnswerMatched: answer != null,
        clearError: answer != null,
      );
    }

    return state.copyWith(
      isBusy: false,
      isRecording: false,
      voiceBusyPhase: VoiceBusyPhase.none,
      transcript: transcript,
      speechSignalFeatures: signalFeatures,
      voiceAnswerTranscript: '',
      voiceAnswerMatched: true,
      clearVoiceDraftNotice: true,
      clearError: true,
    );
  }

  SacaFlowState? _mergeVoiceCueRelatedSuggestions(
    SacaFlowState state,
    String transcript,
    SpeechSignalFeatures? signalFeatures,
  ) {
    if (signalFeatures == null || !signalFeatures.hasUsableSignals) {
      return null;
    }
    final request = state.analysisRequest.copyWith(
      transcript: transcript.isNotEmpty ? transcript : state.transcript,
      speechSignalFeatures: signalFeatures,
    );
    final voiceCueSuggestions = _relatedSymptomPolicy.knownFilteredSuggestions(
      _nonSpeechSuggestionService.reviewOnlySuggestions(request),
      request,
    );
    if (voiceCueSuggestions.isEmpty) return null;

    return state.copyWith(
      isBusy: false,
      isRecording: false,
      voiceBusyPhase: VoiceBusyPhase.none,
      suggestedRelatedSymptomIds: _relatedSymptomPolicy.mergeOrdered(
        state.suggestedRelatedSymptomIds,
        voiceCueSuggestions,
      ),
      voiceCueSuggestedSymptomIds: _relatedSymptomPolicy.mergeOrdered(
        state.voiceCueSuggestedSymptomIds,
        voiceCueSuggestions,
      ),
      speechSignalFeatures: signalFeatures,
      voiceAnswerTranscript: transcript,
      voiceAnswerMatched: true,
      clearError: true,
    );
  }
}
