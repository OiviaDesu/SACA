import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:saca_demo/core/errors/app_error.dart';
import 'package:saca_demo/domain/models/saca_models.dart';
import 'package:saca_demo/domain/services/analysis_service.dart';
import 'package:saca_demo/domain/services/speech_input_service.dart';
import 'package:saca_demo/domain/services/symptom_suggestion_service.dart';
import 'package:saca_demo/presentation/controllers/saca_flow_controller.dart';

void main() {
  group('SacaFlowController', () {
    test('language routes directly to input method without gender or start',
        () async {
      final controller = SacaFlowController(
        speechInput: _FakeSpeechInputService(),
        analysisService: _FakeAnalysisService(),
      );
      addTearDown(controller.dispose);

      controller.showLanguage();
      expect(controller.state.step, SacaStep.language);

      controller.selectLanguage(SacaLanguage.english);
      expect(controller.state.step, SacaStep.inputMethod);
      expect(controller.state.language, SacaLanguage.english);
    });

    test('visual input enters shared questionnaire and builds request',
        () async {
      final controller = SacaFlowController(
        speechInput: _FakeSpeechInputService(),
        analysisService: _FakeAnalysisService(),
      );
      addTearDown(controller.dispose);

      controller.showLanguage();
      controller.selectLanguage(SacaLanguage.english);
      await controller.chooseInputMethod(InputMethod.visual);
      controller.toggleSymptom('fever');
      controller.toggleBodyArea('throat');
      controller.continueFromInput();

      expect(controller.state.step, SacaStep.questionSeverity);
      expect(controller.state.analysisRequest.inputMethod, InputMethod.visual);
      expect(controller.state.analysisRequest.selectedSymptomIds,
          contains('fever'));
      expect(controller.state.analysisRequest.selectedBodyAreaIds,
          contains('throat'));
    });

    test('structured answers progress to result', () async {
      final controller = SacaFlowController(
        speechInput: _FakeSpeechInputService(),
        analysisService: _FakeAnalysisService(),
      );
      addTearDown(controller.dispose);

      controller.showLanguage();
      controller.selectLanguage(SacaLanguage.english);
      await controller.chooseInputMethod(InputMethod.text);
      controller.updateTextInput('fever');
      controller.continueFromInput();
      controller.answerQuestion('severity', '5');
      controller.nextQuestion();
      controller.answerQuestion('duration', 'one to three days');
      controller.nextQuestion();
      controller.toggleQuestionOption('related_symptoms', 'sore_throat');
      controller.nextQuestion();
      controller.answerQuestion('medication', 'no medication');
      controller.nextQuestion();
      controller.answerQuestion('food', 'no food change');
      controller.nextQuestion();
      controller.answerQuestion('allergies', 'no known allergies');
      controller.nextQuestion();
      controller.answerQuestion('health_changes', 'no recent health change');
      await controller.analyse();

      expect(controller.state.step, SacaStep.result);
      expect(controller.state.analysisResult?.disease, 'Influenza');
    });

    test('initial input prepares related symptom suggestions', () async {
      final controller = SacaFlowController(
        speechInput: _FakeSpeechInputService(),
        analysisService: _FakeAnalysisService(),
      );
      addTearDown(controller.dispose);

      controller.showLanguage();
      controller.selectLanguage(SacaLanguage.english);
      await controller.chooseInputMethod(InputMethod.text);
      controller.updateTextInput('fever');
      controller.continueFromInput();

      expect(controller.state.suggestedRelatedSymptomIds,
          containsAll(<String>['cough', 'sore_throat', 'headache']));
    });

    test('entering related symptom step refines suggestions', () async {
      final controller = SacaFlowController(
        speechInput: _FakeSpeechInputService(),
        analysisService: _FakeAnalysisService(),
        symptomSuggestionService: _FakeSymptomSuggestionService(),
      );
      addTearDown(controller.dispose);

      controller.showLanguage();
      controller.selectLanguage(SacaLanguage.english);
      await controller.chooseInputMethod(InputMethod.text);
      controller.updateTextInput('fever');
      controller.continueFromInput();
      controller.answerQuestion('severity', '5');
      controller.nextQuestion();
      controller.answerQuestion('duration', 'one to three days');
      controller.nextQuestion();
      await Future<void>.delayed(Duration.zero);

      expect(controller.state.step, SacaStep.questionRelatedSymptoms);
      expect(controller.state.suggestedRelatedSymptomIds, <String>['cough']);
    });

    test('voice prepare failure is exposed as plain recovery text', () async {
      final controller = SacaFlowController(
        speechInput: _FakeSpeechInputService(
          prepareResult: const AppResult.failure(
            AppFailure(
              kind: AppFailureKind.modelMissing,
              message: 'Voice model is not ready. Use text input.',
            ),
          ),
        ),
        analysisService: _FakeAnalysisService(),
      );
      addTearDown(controller.dispose);

      controller.showLanguage();
      controller.selectLanguage(SacaLanguage.english);
      await controller.chooseInputMethod(InputMethod.voice);

      expect(controller.state.step, SacaStep.voiceInput);
      expect(controller.state.isBusy, isFalse);
      expect(
        controller.state.errorMessage,
        'Voice model is not ready. Use text input.',
      );
      expect(controller.state.voiceBusyPhase, VoiceBusyPhase.none);
    });

    test('voice prepare exposes preparing phase until model init completes',
        () async {
      final prepareCompleter = Completer<AppResult<void>>();
      final controller = SacaFlowController(
        speechInput: _FakeSpeechInputService(
          prepareFuture: prepareCompleter.future,
        ),
        analysisService: _FakeAnalysisService(),
      );
      addTearDown(controller.dispose);

      controller.showLanguage();
      controller.selectLanguage(SacaLanguage.english);
      final prepareFuture = controller.chooseInputMethod(InputMethod.voice);

      expect(controller.state.step, SacaStep.voiceInput);
      expect(controller.state.isBusy, isTrue);
      expect(controller.state.voiceBusyPhase, VoiceBusyPhase.preparing);

      prepareCompleter.complete(const AppResult.success(null));
      await prepareFuture;

      expect(controller.state.isBusy, isFalse);
      expect(controller.state.voiceBusyPhase, VoiceBusyPhase.none);
    });

    test('stop recording exposes transcribing phase until transcript returns',
        () async {
      final transcribeCompleter = Completer<AppResult<SpeechInputResult>>();
      final controller = SacaFlowController(
        speechInput: _FakeSpeechInputService(
          transcribeFuture: transcribeCompleter.future,
        ),
        analysisService: _FakeAnalysisService(),
      );
      addTearDown(controller.dispose);

      controller.showLanguage();
      controller.selectLanguage(SacaLanguage.english);
      await controller.chooseInputMethod(InputMethod.voice);
      await controller.startRecording();

      final stopFuture = controller.stopRecording();

      expect(controller.state.isBusy, isTrue);
      expect(controller.state.isRecording, isFalse);
      expect(controller.state.voiceBusyPhase, VoiceBusyPhase.transcribing);

      transcribeCompleter.complete(
        const AppResult.success(
          SpeechInputResult(text: 'headache and sore throat'),
        ),
      );
      await stopFuture;

      expect(controller.state.isBusy, isFalse);
      expect(controller.state.voiceBusyPhase, VoiceBusyPhase.none);
      expect(controller.state.transcript, 'headache and sore throat');
    });

    test('voice maps severity transcripts to structured answer', () async {
      final controller = SacaFlowController(
        speechInput: _FakeSpeechInputService(),
        analysisService: _FakeAnalysisService(),
      );
      addTearDown(controller.dispose);

      controller.showLanguage();
      controller.selectLanguage(SacaLanguage.english);
      await controller.chooseInputMethod(InputMethod.voice);
      controller.updateTranscript('pain');
      controller.continueFromInput();

      expect(controller.answerCurrentQuestionByVoice('nine'), isTrue);
      expect(controller.state.questionAnswers['severity'], '9');
      expect(controller.answerCurrentQuestionByVoice('9'), isTrue);
      expect(controller.state.questionAnswers['severity'], '9');
      expect(controller.answerCurrentQuestionByVoice('severe'), isTrue);
      expect(controller.state.questionAnswers['severity'], '9');
    });

    test('voice maps duration answer and keeps unmatched non-blocking',
        () async {
      final controller = SacaFlowController(
        speechInput: _FakeSpeechInputService(),
        analysisService: _FakeAnalysisService(),
      );
      addTearDown(controller.dispose);

      controller.showLanguage();
      controller.selectLanguage(SacaLanguage.english);
      await controller.chooseInputMethod(InputMethod.voice);
      controller.updateTranscript('pain');
      controller.continueFromInput();
      controller.answerQuestion('severity', '5');
      controller.nextQuestion();

      expect(controller.answerCurrentQuestionByVoice('three days'), isTrue);
      expect(controller.state.questionAnswers['duration'], 'one to three days');
      expect(controller.answerCurrentQuestionByVoice('gibberish'), isFalse);
      expect(controller.state.questionAnswers['duration'], 'one to three days');
      expect(controller.state.voiceAnswerMatched, isFalse);
    });

    test('voice maps more than seven day duration variants', () async {
      final controller = SacaFlowController(
        speechInput: _FakeSpeechInputService(),
        analysisService: _FakeAnalysisService(),
      );
      addTearDown(controller.dispose);

      controller.showLanguage();
      controller.selectLanguage(SacaLanguage.english);
      await controller.chooseInputMethod(InputMethod.voice);
      controller.updateTranscript('pain');
      controller.continueFromInput();
      controller.answerQuestion('severity', '5');
      controller.nextQuestion();

      for (final transcript in <String>[
        'More than 7 days',
        'more than seven days',
        'over 7 days',
        '>7 days',
      ]) {
        expect(controller.answerCurrentQuestionByVoice(transcript), isTrue);
        expect(
          controller.state.questionAnswers['duration'],
          'more than seven days',
        );
        expect(controller.state.voiceAnswerMatched, isTrue);
      }
    });

    test('voice maps allergy choices without generic no stealing not sure',
        () async {
      final controller = SacaFlowController(
        speechInput: _FakeSpeechInputService(),
        analysisService: _FakeAnalysisService(),
      );
      addTearDown(controller.dispose);

      controller.showLanguage();
      controller.selectLanguage(SacaLanguage.english);
      await controller.chooseInputMethod(InputMethod.voice);
      controller.updateTranscript('pain');
      controller.continueFromInput();
      controller.answerQuestion('severity', '5');
      controller.nextQuestion();
      controller.answerQuestion('duration', 'one to three days');
      controller.nextQuestion();
      controller.toggleQuestionOption('related_symptoms', 'headache');
      controller.nextQuestion();
      controller.answerQuestion('medication', 'no medication');
      controller.nextQuestion();
      controller.answerQuestion('food', 'no food change');
      controller.nextQuestion();

      expect(controller.answerCurrentQuestionByVoice('Not sure.'), isTrue);
      expect(
          controller.state.questionAnswers['allergies'], 'not sure allergies');
      expect(controller.answerCurrentQuestionByVoice('No known allergies'),
          isTrue);
      expect(
          controller.state.questionAnswers['allergies'], 'no known allergies');
      expect(controller.answerCurrentQuestionByVoice('banana sky'), isFalse);
      expect(
          controller.state.questionAnswers['allergies'], 'no known allergies');
      expect(controller.state.voiceAnswerMatched, isFalse);
    });
  });
}

class _FakeSpeechInputService implements SpeechInputService {
  _FakeSpeechInputService({
    this.prepareResult = const AppResult<void>.success(null),
    this.prepareFuture,
    this.transcribeFuture,
  });

  final AppResult<void> prepareResult;
  final Future<AppResult<void>>? prepareFuture;
  final Future<AppResult<SpeechInputResult>>? transcribeFuture;

  @override
  bool get supportsOnDeviceStt => true;

  @override
  Future<AppResult<void>> prepare(SacaLanguage language) async {
    if (prepareFuture != null) {
      return await prepareFuture!;
    }
    return prepareResult;
  }

  @override
  Future<AppResult<void>> startRecording() async {
    return const AppResult.success(null);
  }

  @override
  Future<AppResult<SpeechInputResult>> stopAndTranscribe() async {
    if (transcribeFuture != null) {
      return transcribeFuture!;
    }
    return const AppResult.success(
      SpeechInputResult(text: 'headache and sore throat'),
    );
  }

  @override
  Future<void> cancel() async {}

  @override
  void dispose() {}
}

class _FakeAnalysisService implements AnalysisService {
  @override
  Future<AppResult<AnalysisResult>> analyse(AnalysisRequest request) async {
    return const AppResult.success(
      AnalysisResult(
        disease: 'Influenza',
        severity: SeverityLevel.mild,
        guidance: <String>['Rest and drink fluids.'],
        isEmergency: false,
        disclaimer: 'Prototype guidance only.',
      ),
    );
  }
}

class _FakeSymptomSuggestionService implements SymptomSuggestionService {
  @override
  List<String> suggestRelatedSymptoms(AnalysisRequest request) {
    return const <String>['sore_throat'];
  }

  @override
  Future<List<String>> refineRelatedSymptoms(AnalysisRequest request) async {
    return const <String>['cough'];
  }
}
