import '../../domain/models/saca_models.dart';
import '../../domain/services/related_symptom_policy.dart';
import '../../domain/services/symptom_suggestion_service.dart';
import 'assessment_use_case_result.dart';

class SubmitInput {
  const SubmitInput({
    SymptomSuggestionService symptomSuggestionService =
        const RuleBasedSymptomSuggestionService(),
    RelatedSymptomPolicy relatedSymptomPolicy = const RelatedSymptomPolicy(),
  })  : _symptomSuggestionService = symptomSuggestionService,
        _relatedSymptomPolicy = relatedSymptomPolicy;

  final SymptomSuggestionService _symptomSuggestionService;
  final RelatedSymptomPolicy _relatedSymptomPolicy;

  AssessmentUseCaseResult call(
    SacaFlowState state, {
    bool clearPendingConfirmation = false,
  }) {
    if (state.combinedInput.trim().isEmpty && !clearPendingConfirmation) {
      final next = state.copyWith(
        pendingConfirmation: SacaConfirmationType.emptyInput,
        clearError: true,
      );
      return AssessmentUseCaseResult(
        state: next,
        effect: AssessmentEffect.emptyInputConfirmation,
      );
    }

    final request = state.analysisRequest;
    final suggestions = _relatedSymptomPolicy.knownFilteredSuggestions(
      _symptomSuggestionService.suggestRelatedSymptoms(request),
      request,
    );
    return AssessmentUseCaseResult(
      state: state.copyWith(
        step: SacaStep.questionSeverity,
        suggestedRelatedSymptomIds: suggestions,
        voiceAnswerTranscript: '',
        voiceAnswerMatched: true,
        clearError: true,
        clearPendingConfirmation: clearPendingConfirmation,
      ),
    );
  }
}
