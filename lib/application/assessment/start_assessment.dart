import '../../domain/models/saca_models.dart';

class StartAssessment {
  const StartAssessment();

  SacaFlowState call({SacaLanguage? keepLanguage}) {
    return SacaFlowState(
      step: keepLanguage == null ? SacaStep.language : SacaStep.inputMethod,
      language: keepLanguage,
    );
  }
}
