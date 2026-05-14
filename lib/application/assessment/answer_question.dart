import '../../domain/models/saca_models.dart';
import '../../domain/services/saca_flow_step_policy.dart';

class AnswerQuestion {
  const AnswerQuestion({
    SacaFlowStepPolicy stepPolicy = const SacaFlowStepPolicy(),
  }) : _stepPolicy = stepPolicy;

  final SacaFlowStepPolicy _stepPolicy;

  SacaFlowState answer(SacaFlowState state, String questionId, String answer) {
    final next = Map<String, String>.from(state.questionAnswers);
    next[questionId] = answer;
    return state.copyWith(
      questionAnswers: next,
      voiceAnswerMatched: true,
      clearError: true,
    );
  }

  SacaFlowState toggleOption(
    SacaFlowState state,
    String questionId,
    String option,
  ) {
    final current = state.questionAnswers[questionId]
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

    final next = Map<String, String>.from(state.questionAnswers);
    if (current.isEmpty) {
      next.remove(questionId);
    } else {
      next[questionId] = current.join('|');
    }
    if (questionId == 'related_symptoms' && option == 'none') {
      next.remove('related_other');
    }
    return state.copyWith(questionAnswers: next, clearError: true);
  }

  SacaFlowState next(SacaFlowState state) {
    final nextStep = switch (state.step) {
      SacaStep.questionSeverity ||
      SacaStep.questionDuration ||
      SacaStep.questionRelatedSymptoms ||
      SacaStep.questionSkinDetails ||
      SacaStep.questionMedication ||
      SacaStep.questionFood ||
      SacaStep.questionAllergies ||
      SacaStep.questionHealthChanges =>
        _stepPolicy.nextQuestionStep(state.step, state),
      _ => state.step,
    };

    return state.copyWith(
      step: nextStep,
      voiceAnswerTranscript: '',
      voiceAnswerMatched: true,
      clearError: true,
    );
  }
}
