import 'package:flutter_test/flutter_test.dart';
import 'package:saca/application/assessment/assessment_use_cases.dart';
import 'package:saca/core/errors/app_error.dart';
import 'package:saca/domain/models/saca_models.dart';
import 'package:saca/domain/services/analysis_service.dart';

void main() {
  group('assessment use cases', () {
    test('StartAssessment resets while optionally keeping language', () {
      const useCase = StartAssessment();

      expect(useCase().step, SacaStep.language);
      final kept = useCase(keepLanguage: SacaLanguage.gurindji);
      expect(kept.step, SacaStep.inputMethod);
      expect(kept.language, SacaLanguage.gurindji);
    });

    test('SubmitInput mirrors empty confirmation and suggestion behavior', () {
      const useCase = SubmitInput();
      final empty = useCase(const SacaFlowState(step: SacaStep.textInput));

      expect(empty.effect, AssessmentEffect.emptyInputConfirmation);
      expect(empty.state.pendingConfirmation, SacaConfirmationType.emptyInput);

      final confirmed = useCase(
        const SacaFlowState(step: SacaStep.textInput),
        clearPendingConfirmation: true,
      );
      expect(confirmed.state.step, SacaStep.questionSeverity);

      final submitted = useCase(
        const SacaFlowState(
          step: SacaStep.textInput,
          language: SacaLanguage.english,
          inputMethod: InputMethod.text,
          textInput: 'fever',
        ),
      );

      expect(submitted.effect, AssessmentEffect.none);
      expect(submitted.state.step, SacaStep.questionSeverity);
      expect(submitted.state.suggestedRelatedSymptomIds,
          <String>['sore_throat', 'headache', 'cough']);
    });

    test('AnswerQuestion updates answers, options, and next step', () {
      const useCase = AnswerQuestion();
      var state = const SacaFlowState(step: SacaStep.questionSeverity);

      state = useCase.answer(state, 'severity', '5');
      expect(state.questionAnswers['severity'], '5');
      state = useCase.next(state);
      expect(state.step, SacaStep.questionDuration);

      state = useCase.toggleOption(state, 'related_symptoms', 'cough');
      state = useCase.toggleOption(state, 'related_symptoms', 'headache');
      expect(state.questionAnswers['related_symptoms'], 'cough|headache');
      state = useCase.toggleOption(state, 'related_symptoms', 'none');
      expect(state.questionAnswers['related_symptoms'], 'none');
    });

    test('RunAnalysis mirrors success, failure, and no-clear states', () async {
      final success = RunAnalysis(
        analysisService: _FakeAnalysisService(
          const AnalysisResult(
            disease: 'Influenza',
            severity: SeverityLevel.moderate,
            guidance: <String>['Rest.'],
            isEmergency: false,
            disclaimer: 'Not medical advice.',
          ),
        ),
      );
      final successResult = await success(const SacaFlowState(textInput: 'fever'));
      expect(successResult.state.step, SacaStep.result);
      expect(successResult.state.isBusy, isFalse);
      expect(successResult.state.analysisResult?.disease, 'Influenza');

      final noClear = RunAnalysis(
        analysisService: _FakeAnalysisService(
          const AnalysisResult(
            disease: 'No clear illness detected',
            severity: SeverityLevel.mild,
            guidance: <String>['Monitor symptoms.'],
            isEmergency: false,
            disclaimer: 'Not medical advice.',
          ),
        ),
      );
      final noClearResult = await noClear(const SacaFlowState(textInput: 'well'));
      expect(noClearResult.effect, AssessmentEffect.noClearIllnessConfirmation);
      expect(noClearResult.state.step, SacaStep.analysing);
      expect(noClearResult.state.pendingConfirmation,
          SacaConfirmationType.noClearIllness);

      final failure = RunAnalysis(
        analysisService: const _FailingAnalysisService(),
      );
      final failureResult = await failure(const SacaFlowState(textInput: 'fever'));
      expect(failureResult.state.step, SacaStep.questionHealthChanges);
      expect(failureResult.state.errorMessage, 'Analysis unavailable.');
    });

    test('HandleVoiceTranscript maps follow-up command and dictation paths', () {
      const useCase = HandleVoiceTranscript();
      final followUp = useCase(
        const SacaFlowState(step: SacaStep.questionDuration),
        'more than seven days',
      );
      expect(followUp.step, SacaStep.questionRelatedSymptoms);
      expect(followUp.questionAnswers['duration'], 'more than seven days');
      expect(followUp.voiceAnswerMatched, isTrue);

      final dictation = useCase(
        const SacaFlowState(step: SacaStep.voiceInput),
        'headache and sore throat',
      );
      expect(dictation.transcript, 'headache and sore throat');
      expect(dictation.voiceBusyPhase, VoiceBusyPhase.none);
    });
  });
}

class _FakeAnalysisService implements AnalysisService {
  const _FakeAnalysisService(this.result);

  final AnalysisResult result;

  @override
  Future<AppResult<AnalysisResult>> analyse(AnalysisRequest request) async {
    return AppResult.success(result);
  }
}

class _FailingAnalysisService implements AnalysisService {
  const _FailingAnalysisService();

  @override
  Future<AppResult<AnalysisResult>> analyse(AnalysisRequest request) async {
    return const AppResult.failure(
      AppFailure(
        kind: AppFailureKind.analysisFailed,
        message: 'Analysis unavailable.',
      ),
    );
  }
}
