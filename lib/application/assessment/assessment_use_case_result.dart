import '../../domain/models/saca_models.dart';

enum AssessmentEffect {
  none,
  emptyInputConfirmation,
  noClearIllnessConfirmation,
}

class AssessmentUseCaseResult {
  const AssessmentUseCaseResult({
    required this.state,
    this.effect = AssessmentEffect.none,
  });

  final SacaFlowState state;
  final AssessmentEffect effect;
}
