import '../../domain/models/saca_models.dart';
import '../../domain/services/analysis_service.dart';
import 'assessment_use_case_result.dart';

class RunAnalysis {
  const RunAnalysis({required AnalysisService analysisService})
      : _analysisService = analysisService;

  final AnalysisService _analysisService;

  SacaFlowState start(SacaFlowState state) {
    return state.copyWith(
      step: SacaStep.analysing,
      isBusy: true,
      clearAnalysisResult: true,
      clearError: true,
    );
  }

  Future<AssessmentUseCaseResult> call(SacaFlowState state) async {
    final analysing = start(state);
    final result = await _analysisService.analyse(analysing.analysisRequest);
    if (!result.isSuccess) {
      return AssessmentUseCaseResult(
        state: analysing.copyWith(
          step: SacaStep.questionHealthChanges,
          isBusy: false,
          errorMessage: result.failure?.message,
        ),
      );
    }

    final value = result.value;
    if (value != null &&
        !value.isEmergency &&
        value.disease == 'No clear illness detected') {
      return AssessmentUseCaseResult(
        state: analysing.copyWith(
          isBusy: false,
          pendingConfirmation: SacaConfirmationType.noClearIllness,
          analysisResult: value,
          clearError: true,
        ),
        effect: AssessmentEffect.noClearIllnessConfirmation,
      );
    }

    return AssessmentUseCaseResult(
      state: analysing.copyWith(
        step: SacaStep.result,
        isBusy: false,
        analysisResult: result.value,
        clearError: true,
      ),
    );
  }
}
