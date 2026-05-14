import '../models/saca_models.dart';

class SacaFlowStepPolicy {
  const SacaFlowStepPolicy();

  SacaStep stepForInputMethod(InputMethod method) {
    return switch (method) {
      InputMethod.text => SacaStep.textInput,
      InputMethod.voice => SacaStep.voiceInput,
      InputMethod.visual => SacaStep.visualInput,
    };
  }

  bool isFollowUpQuestion(SacaStep step) {
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

  SacaStep nextQuestionStep(SacaStep step, SacaFlowState state) {
    return switch (step) {
      SacaStep.questionSeverity => SacaStep.questionDuration,
      SacaStep.questionDuration => SacaStep.questionRelatedSymptoms,
      SacaStep.questionRelatedSymptoms => shouldAskSkinDetails(state)
          ? SacaStep.questionSkinDetails
          : SacaStep.questionMedication,
      SacaStep.questionSkinDetails => SacaStep.questionMedication,
      SacaStep.questionMedication => SacaStep.questionFood,
      SacaStep.questionFood => SacaStep.questionAllergies,
      SacaStep.questionAllergies => SacaStep.questionHealthChanges,
      SacaStep.questionHealthChanges => SacaStep.reviewInformation,
      _ => step,
    };
  }

  SacaStep previousStep(
    SacaStep step,
    SacaFlowState state, {
    SacaStep? settingsReturnStep,
  }) {
    return switch (step) {
      SacaStep.splash => SacaStep.splash,
      SacaStep.language => SacaStep.splash,
      SacaStep.inputMethod => SacaStep.language,
      SacaStep.voiceInput => SacaStep.inputMethod,
      SacaStep.textInput => SacaStep.inputMethod,
      SacaStep.visualInput => SacaStep.inputMethod,
      SacaStep.questionSeverity => stepForInputMethod(
          state.inputMethod ?? InputMethod.text,
        ),
      SacaStep.questionDuration => SacaStep.questionSeverity,
      SacaStep.questionRelatedSymptoms => SacaStep.questionDuration,
      SacaStep.questionSkinDetails => SacaStep.questionRelatedSymptoms,
      SacaStep.questionMedication => shouldAskSkinDetails(state)
          ? SacaStep.questionSkinDetails
          : SacaStep.questionRelatedSymptoms,
      SacaStep.questionFood => SacaStep.questionMedication,
      SacaStep.questionAllergies => SacaStep.questionFood,
      SacaStep.questionHealthChanges => SacaStep.questionAllergies,
      SacaStep.reviewInformation => SacaStep.questionHealthChanges,
      SacaStep.settings => settingsReturnStep ?? SacaStep.language,
      SacaStep.analysing => SacaStep.questionHealthChanges,
      SacaStep.result => SacaStep.reviewInformation,
    };
  }

  bool shouldAskSkinDetails(SacaFlowState state) {
    final request = state.analysisRequest;
    final haystack = <String>[
      request.combinedInput,
      ...request.selectedSymptomIds,
      ...request.selectedBodyAreaIds,
      ...request.answers.values,
    ].join(' ').toLowerCase();
    return RegExp(r'\b(rash|itch|itching|skin|scabies|spots?)\b')
        .hasMatch(haystack);
  }
}
