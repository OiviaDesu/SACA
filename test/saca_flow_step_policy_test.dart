import 'package:flutter_test/flutter_test.dart';
import 'package:saca/domain/models/saca_models.dart';
import 'package:saca/domain/services/saca_flow_step_policy.dart';

void main() {
  group('SacaFlowStepPolicy', () {
    const policy = SacaFlowStepPolicy();

    test('maps input methods to entry steps', () {
      expect(policy.stepForInputMethod(InputMethod.text), SacaStep.textInput);
      expect(policy.stepForInputMethod(InputMethod.voice), SacaStep.voiceInput);
      expect(
          policy.stepForInputMethod(InputMethod.visual), SacaStep.visualInput);
    });

    test('moves through questionnaire without skin details when not needed',
        () {
      const state = SacaFlowState(textInput: 'fever');

      expect(
        policy.nextQuestionStep(SacaStep.questionSeverity, state),
        SacaStep.questionDuration,
      );
      expect(
        policy.nextQuestionStep(SacaStep.questionDuration, state),
        SacaStep.questionRelatedSymptoms,
      );
      expect(
        policy.nextQuestionStep(SacaStep.questionRelatedSymptoms, state),
        SacaStep.questionMedication,
      );
    });

    test('adds skin detail step when skin context exists', () {
      const state = SacaFlowState(textInput: 'itchy rash on skin');

      expect(policy.shouldAskSkinDetails(state), isTrue);
      expect(
        policy.nextQuestionStep(SacaStep.questionRelatedSymptoms, state),
        SacaStep.questionSkinDetails,
      );
      expect(
        policy.previousStep(SacaStep.questionMedication, state),
        SacaStep.questionSkinDetails,
      );
    });

    test('returns to selected input method from first question', () {
      const state = SacaFlowState(inputMethod: InputMethod.visual);

      expect(
        policy.previousStep(SacaStep.questionSeverity, state),
        SacaStep.visualInput,
      );
    });
  });
}
