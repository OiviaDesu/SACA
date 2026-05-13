import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:saca/core/errors/app_error.dart';
import 'package:saca/domain/models/saca_models.dart';
import 'package:saca/domain/services/analysis_service.dart';
import 'package:saca/domain/services/speech_input_service.dart';
import 'package:saca/domain/services/symptom_suggestion_service.dart';
import 'package:saca/presentation/controllers/saca_flow_controller.dart';

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
      controller.nextQuestion();

      expect(controller.state.step, SacaStep.reviewInformation);
      await controller.analyse();

      expect(controller.state.step, SacaStep.result);
      expect(controller.state.analysisResult?.disease, 'Influenza');
    });

    test('add more loops keep data and stop after two rounds', () async {
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
      controller.nextQuestion();

      controller.addMoreInformation();
      expect(controller.state.step, SacaStep.inputMethod);
      expect(controller.state.textInput, 'fever');
      expect(controller.state.addMoreCount, 1);
      controller.showReview();
      controller.addMoreInformation();
      expect(controller.state.addMoreCount, 2);
      controller.showReview();
      controller.addMoreInformation();
      expect(controller.state.step, SacaStep.reviewInformation);
      expect(controller.state.addMoreCount, 2);
    });

    test('finish clears language while start over keeps it', () async {
      final controller = SacaFlowController(
        speechInput: _FakeSpeechInputService(),
        analysisService: _FakeAnalysisService(),
      );
      addTearDown(controller.dispose);

      controller.showLanguage();
      controller.selectLanguage(SacaLanguage.gurindji);
      controller.updateTextInput('fever');
      controller.startOverKeepLanguage();
      expect(controller.state.step, SacaStep.inputMethod);
      expect(controller.state.language, SacaLanguage.gurindji);
      expect(controller.state.textInput, isEmpty);

      controller.finish();
      expect(controller.state.step, SacaStep.language);
      expect(controller.state.language, isNull);
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

    test('initial text symptoms are not suggested again', () async {
      final controller = SacaFlowController(
        speechInput: _FakeSpeechInputService(),
        analysisService: _FakeAnalysisService(),
        symptomSuggestionService: const _FixedSymptomSuggestionService(
          initial: <String>[
            'cough',
            'fever',
            'headache',
            'breathing_trouble',
            'sore_throat',
          ],
        ),
      );
      addTearDown(controller.dispose);

      controller.showLanguage();
      controller.selectLanguage(SacaLanguage.english);
      await controller.chooseInputMethod(InputMethod.text);
      controller.updateTextInput(
          'I have cough, fever, headache and breathing trouble');
      controller.continueFromInput();

      expect(
          controller.state.suggestedRelatedSymptomIds, <String>['sore_throat']);
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

    test('selected and initial symptoms are filtered during related refinement',
        () async {
      final controller = SacaFlowController(
        speechInput: _FakeSpeechInputService(),
        analysisService: _FakeAnalysisService(),
        symptomSuggestionService: const _FixedSymptomSuggestionService(
          initial: <String>['cough'],
          refined: <String>['cough', 'fever', 'headache', 'sore_throat'],
        ),
      );
      addTearDown(controller.dispose);

      controller.showLanguage();
      controller.selectLanguage(SacaLanguage.english);
      await controller.chooseInputMethod(InputMethod.text);
      controller.updateTextInput('fever and headache');
      controller.continueFromInput();
      controller.answerQuestion('severity', '5');
      controller.nextQuestion();
      controller.answerQuestion('duration', 'one to three days');
      controller.nextQuestion();
      await Future<void>.delayed(Duration.zero);

      expect(controller.state.suggestedRelatedSymptomIds,
          <String>['sore_throat', 'cough']);
    });

    test('none clears related symptoms and other text', () async {
      final controller = SacaFlowController(
        speechInput: _FakeSpeechInputService(),
        analysisService: _FakeAnalysisService(),
      );
      addTearDown(controller.dispose);

      controller.toggleQuestionOption('related_symptoms', 'cough');
      controller.toggleQuestionOption('related_symptoms', 'headache');
      controller.updateQuestionAnswer('related_other', 'dizziness');

      controller.toggleQuestionOption('related_symptoms', 'none');

      expect(controller.state.questionAnswers['related_symptoms'], 'none');
      expect(controller.state.questionAnswers.containsKey('related_other'),
          isFalse);
      expect(
          controller.hasQuestionAnswer('related_symptoms', 'cough'), isFalse);

      controller.toggleQuestionOption('related_symptoms', 'sore_throat');

      expect(
          controller.state.questionAnswers['related_symptoms'], 'sore_throat');
      expect(controller.hasQuestionAnswer('related_symptoms', 'none'), isFalse);
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

    test('partial transcript updates while recording and final replaces it',
        () async {
      final partials = StreamController<String>();
      final controller = SacaFlowController(
        speechInput: _FakeSpeechInputService(
          partialTranscriptStream: partials.stream,
        ),
        analysisService: _FakeAnalysisService(),
      );
      addTearDown(() async {
        await partials.close();
        controller.dispose();
      });

      controller.showLanguage();
      controller.selectLanguage(SacaLanguage.english);
      await controller.chooseInputMethod(InputMethod.voice);
      await controller.startRecording();

      partials.add('sore throat draft');
      await Future<void>.delayed(Duration.zero);

      expect(controller.state.transcript, 'sore throat draft');

      await controller.stopRecording();

      expect(controller.state.transcript, 'headache and sore throat');
    });

    test('partial draft hides final transcription failure as soft notice',
        () async {
      final partials = StreamController<String>();
      final controller = SacaFlowController(
        speechInput: _FakeSpeechInputService(
          partialTranscriptStream: partials.stream,
          transcribeFuture: Future.value(
            const AppResult.failure(
              AppFailure(
                kind: AppFailureKind.transcriptionFailed,
                message: 'Could not transcribe the recording. Try text input.',
              ),
            ),
          ),
        ),
        analysisService: _FakeAnalysisService(),
      );
      addTearDown(() async {
        await partials.close();
        controller.dispose();
      });

      controller.showLanguage();
      controller.selectLanguage(SacaLanguage.english);
      await controller.chooseInputMethod(InputMethod.voice);
      await controller.startRecording();

      partials.add('draft chest pain');
      await Future<void>.delayed(Duration.zero);
      await controller.stopRecording();

      expect(controller.state.transcript, 'draft chest pain');
      expect(controller.state.errorMessage, isNull);
      expect(controller.state.voiceDraftNotice, isNotNull);
      expect(controller.state.combinedInput, contains('draft chest pain'));
    });

    test('empty transcript keeps final transcription failure as hard error',
        () async {
      final controller = SacaFlowController(
        speechInput: _FakeSpeechInputService(
          transcribeFuture: Future.value(
            const AppResult.failure(
              AppFailure(
                kind: AppFailureKind.transcriptionFailed,
                message: 'Could not transcribe the recording. Try text input.',
              ),
            ),
          ),
        ),
        analysisService: _FakeAnalysisService(),
      );
      addTearDown(controller.dispose);

      controller.showLanguage();
      controller.selectLanguage(SacaLanguage.english);
      await controller.chooseInputMethod(InputMethod.voice);
      await controller.startRecording();
      await controller.stopRecording();

      expect(controller.state.transcript, isEmpty);
      expect(
        controller.state.errorMessage,
        'Could not transcribe the recording. Try text input.',
      );
      expect(controller.state.voiceDraftNotice, isNull);
    });

    test('editing draft fallback clears soft notice', () async {
      final controller = SacaFlowController(
        speechInput: _FakeSpeechInputService(
          transcribeFuture: Future.value(
            const AppResult.failure(
              AppFailure(
                kind: AppFailureKind.transcriptionFailed,
                message: 'Could not transcribe the recording. Try text input.',
              ),
            ),
          ),
        ),
        analysisService: _FakeAnalysisService(),
      );
      addTearDown(controller.dispose);

      controller.showLanguage();
      controller.selectLanguage(SacaLanguage.english);
      await controller.chooseInputMethod(InputMethod.voice);
      controller.updateTranscript('draft pain');
      await controller.startRecording();
      await controller.stopRecording();

      expect(controller.state.voiceDraftNotice, isNotNull);

      controller.updateTranscript('edited draft pain');

      expect(controller.state.transcript, 'edited draft pain');
      expect(controller.state.voiceDraftNotice, isNull);
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

    test('voice maps Gurindji command words', () async {
      final controller = SacaFlowController(
        speechInput: _FakeSpeechInputService(),
        analysisService: _FakeAnalysisService(),
      );
      addTearDown(controller.dispose);

      controller.showLanguage();
      controller.selectLanguage(SacaLanguage.gurindji);
      await controller.chooseInputMethod(InputMethod.voice);
      controller.updateTranscript('ngurrulyp');
      controller.continueFromInput();

      expect(controller.answerCurrentQuestionByVoice('yamak'), isTrue);
      expect(controller.state.questionAnswers['severity'], '2');
      controller.nextQuestion();
      expect(controller.answerCurrentQuestionByVoice('jala'), isTrue);
      expect(controller.state.questionAnswers['duration'], 'less than one day');
      controller.nextQuestion();
      controller.toggleQuestionOption('related_symptoms', 'none');
      controller.nextQuestion();
      expect(controller.answerCurrentQuestionByVoice('lawara'), isTrue);
      expect(controller.state.questionAnswers['medication'], 'no medication');
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

    test('follow-up voice uses command mode and auto-advances on match',
        () async {
      final speechInput = _FakeSpeechInputService(
        transcribeFuture: Future.value(
          const AppResult.success(SpeechInputResult(text: 'yuwayi')),
        ),
      );
      final controller = SacaFlowController(
        speechInput: speechInput,
        analysisService: _FakeAnalysisService(),
      );
      addTearDown(controller.dispose);

      controller.showLanguage();
      controller.selectLanguage(SacaLanguage.gurindji);
      await controller.chooseInputMethod(InputMethod.voice);
      controller.updateTranscript('ngurrulyp');
      controller.continueFromInput();
      controller.answerQuestion('severity', '5');
      controller.nextQuestion();
      controller.answerQuestion('duration', 'less than one day');
      controller.nextQuestion();
      controller.toggleQuestionOption('related_symptoms', 'none');
      controller.nextQuestion();

      await controller.startRecording();
      await controller.stopRecording();

      expect(speechInput.startedModes, contains(SpeechInputMode.command));
      expect(speechInput.stoppedModes, contains(SpeechInputMode.command));
      expect(
          controller.state.questionAnswers['medication'], 'taken medication');
      expect(controller.state.step, SacaStep.questionFood);
    });

    test('unmatched follow-up voice stays on current step', () async {
      final controller = SacaFlowController(
        speechInput: _FakeSpeechInputService(
          transcribeFuture: Future.value(
            const AppResult.success(SpeechInputResult(text: 'banana sky')),
          ),
        ),
        analysisService: _FakeAnalysisService(),
      );
      addTearDown(controller.dispose);

      controller.showLanguage();
      controller.selectLanguage(SacaLanguage.english);
      await controller.chooseInputMethod(InputMethod.voice);
      controller.updateTranscript('pain');
      controller.continueFromInput();

      await controller.startRecording();
      await controller.stopRecording();

      expect(controller.state.step, SacaStep.questionSeverity);
      expect(controller.state.voiceAnswerMatched, isFalse);
    });

    test('follow-up voice state is scoped to current question', () async {
      final controller = SacaFlowController(
        speechInput: _FakeSpeechInputService(
          transcribeFuture: Future.value(
            const AppResult.success(SpeechInputResult(text: 'I have a fever')),
          ),
        ),
        analysisService: _FakeAnalysisService(),
      );
      addTearDown(controller.dispose);

      controller.showLanguage();
      controller.selectLanguage(SacaLanguage.english);
      await controller.chooseInputMethod(InputMethod.voice);
      controller.updateTranscript('headache');
      controller.continueFromInput();
      await controller.startRecording();
      await controller.stopRecording();

      expect(controller.state.step, SacaStep.questionSeverity);
      expect(controller.state.voiceAnswerTranscript, 'I have a fever');
      expect(controller.state.voiceAnswerMatched, isFalse);

      controller.answerQuestion('severity', '5');
      controller.nextQuestion();

      expect(controller.state.step, SacaStep.questionDuration);
      expect(controller.state.voiceAnswerTranscript, isEmpty);
      expect(controller.state.voiceAnswerMatched, isTrue);
    });

    test('starting follow-up recording clears stale heard text immediately',
        () async {
      final controller = SacaFlowController(
        speechInput: _FakeSpeechInputService(
          transcribeFuture: Future.value(
            const AppResult.success(SpeechInputResult(text: 'I have a fever')),
          ),
        ),
        analysisService: _FakeAnalysisService(),
      );
      addTearDown(controller.dispose);

      controller.showLanguage();
      controller.selectLanguage(SacaLanguage.english);
      await controller.chooseInputMethod(InputMethod.voice);
      controller.updateTranscript('headache');
      controller.continueFromInput();
      await controller.startRecording();
      await controller.stopRecording();

      expect(controller.state.voiceAnswerTranscript, 'I have a fever');
      await controller.startRecording();

      expect(controller.state.voiceAnswerTranscript, isEmpty);
      expect(controller.state.voiceAnswerMatched, isTrue);
    });

    test('auto-stop transcription clears recording state', () async {
      final controller = SacaFlowController(
        speechInput: _FakeSpeechInputService(
          autoStopFuture: Future.value(
            const AppResult.success(SpeechInputResult(text: 'throat pain')),
          ),
        ),
        analysisService: _FakeAnalysisService(),
      );
      addTearDown(controller.dispose);

      controller.showLanguage();
      controller.selectLanguage(SacaLanguage.english);
      await controller.chooseInputMethod(InputMethod.voice);
      await controller.startRecording();

      await Future<void>.delayed(Duration.zero);

      expect(controller.state.isRecording, isFalse);
      expect(controller.state.isBusy, isFalse);
      expect(controller.state.voiceBusyPhase, VoiceBusyPhase.none);
      expect(controller.state.transcript, 'throat pain');
    });

    test('voice cough cue suggests cough without selecting it', () async {
      final controller = SacaFlowController(
        speechInput: _FakeSpeechInputService(
          transcribeFuture: Future.value(
            const AppResult.success(
              SpeechInputResult(
                text: 'throat pain',
                signalFeatures: SpeechSignalFeatures(
                  transcript: 'throat pain',
                  confidence: 0.8,
                  cues: <NonSpeechCue>[
                    NonSpeechCue(
                      kind: 'cough',
                      confidence: 0.8,
                      evidence: 'bracket_token',
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        analysisService: _FakeAnalysisService(),
      );
      addTearDown(controller.dispose);

      controller.showLanguage();
      controller.selectLanguage(SacaLanguage.english);
      await controller.chooseInputMethod(InputMethod.voice);
      await controller.startRecording();
      await controller.stopRecording();
      controller.continueFromInput();
      controller.answerQuestion('severity', '5');
      controller.nextQuestion();
      controller.answerQuestion('duration', 'less than one day');
      controller.nextQuestion();
      await Future<void>.delayed(Duration.zero);

      expect(controller.state.step, SacaStep.questionRelatedSymptoms);
      expect(controller.state.voiceCueSuggestedSymptomIds, contains('cough'));
      expect(
          controller.hasQuestionAnswer('related_symptoms', 'cough'), isFalse);
    });

    test('voice cue does not suggest symptom already in transcript', () async {
      final controller = SacaFlowController(
        speechInput: _FakeSpeechInputService(
          transcribeFuture: Future.value(
            const AppResult.success(
              SpeechInputResult(
                text: 'cough and fever',
                signalFeatures: SpeechSignalFeatures(
                  transcript: 'cough and fever',
                  confidence: 0.8,
                  cues: <NonSpeechCue>[
                    NonSpeechCue(
                      kind: 'cough',
                      confidence: 0.8,
                      evidence: 'bracket_token',
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        analysisService: _FakeAnalysisService(),
      );
      addTearDown(controller.dispose);

      controller.showLanguage();
      controller.selectLanguage(SacaLanguage.english);
      await controller.chooseInputMethod(InputMethod.voice);
      await controller.startRecording();
      await controller.stopRecording();
      controller.continueFromInput();
      controller.answerQuestion('severity', '5');
      controller.nextQuestion();
      controller.answerQuestion('duration', 'less than one day');
      controller.nextQuestion();
      await Future<void>.delayed(Duration.zero);

      expect(controller.state.step, SacaStep.questionRelatedSymptoms);
      expect(controller.state.suggestedRelatedSymptomIds,
          isNot(contains('cough')));
      expect(controller.state.voiceCueSuggestedSymptomIds, isEmpty);
    });

    test('voice cue on related step appends suggestion without selecting it',
        () async {
      final controller = SacaFlowController(
        speechInput: _FakeSpeechInputService(
          transcribeFuture: Future.value(
            const AppResult.success(
              SpeechInputResult(
                text: '',
                signalFeatures: SpeechSignalFeatures(
                  transcript: '',
                  confidence: 0.8,
                  cues: <NonSpeechCue>[
                    NonSpeechCue(
                      kind: 'cough',
                      confidence: 0.8,
                      evidence: 'bracket_token',
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        analysisService: _FakeAnalysisService(),
      );
      addTearDown(controller.dispose);

      controller.showLanguage();
      controller.selectLanguage(SacaLanguage.english);
      await controller.chooseInputMethod(InputMethod.text);
      controller.updateTextInput('headache');
      controller.continueFromInput();
      controller.answerQuestion('severity', '5');
      controller.nextQuestion();
      controller.answerQuestion('duration', 'less than one day');
      controller.nextQuestion();
      await Future<void>.delayed(Duration.zero);

      expect(controller.state.step, SacaStep.questionRelatedSymptoms);
      expect(controller.state.suggestedRelatedSymptomIds,
          contains('nausea_vomiting'));
      expect(controller.state.suggestedRelatedSymptomIds,
          isNot(contains('cough')));

      await controller.startRecording();
      await controller.stopRecording();

      expect(controller.state.step, SacaStep.questionRelatedSymptoms);
      expect(controller.state.suggestedRelatedSymptomIds,
          containsAll(<String>['nausea_vomiting', 'cough']));
      expect(controller.state.voiceCueSuggestedSymptomIds, <String>['cough']);
      expect(
          controller.hasQuestionAnswer('related_symptoms', 'cough'), isFalse);
    });

    test('live voice cue on related step respects known symptom filter',
        () async {
      final controller = SacaFlowController(
        speechInput: _FakeSpeechInputService(
          transcribeFuture: Future.value(
            const AppResult.success(
              SpeechInputResult(
                text: '',
                signalFeatures: SpeechSignalFeatures(
                  transcript: '',
                  confidence: 0.8,
                  cues: <NonSpeechCue>[
                    NonSpeechCue(
                      kind: 'cough',
                      confidence: 0.8,
                      evidence: 'bracket_token',
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        analysisService: _FakeAnalysisService(),
      );
      addTearDown(controller.dispose);

      controller.showLanguage();
      controller.selectLanguage(SacaLanguage.english);
      await controller.chooseInputMethod(InputMethod.text);
      controller.updateTextInput('cough and fever');
      controller.continueFromInput();
      controller.answerQuestion('severity', '5');
      controller.nextQuestion();
      controller.answerQuestion('duration', 'less than one day');
      controller.nextQuestion();
      await Future<void>.delayed(Duration.zero);

      await controller.startRecording();
      await controller.stopRecording();

      expect(controller.state.step, SacaStep.questionRelatedSymptoms);
      expect(controller.state.voiceCueSuggestedSymptomIds, isEmpty);
      expect(controller.state.suggestedRelatedSymptomIds,
          isNot(contains('cough')));
    });

    test('voice breathing cue needs airway context before suggestion',
        () async {
      final features = const SpeechSignalFeatures(
        transcript: 'chest pain',
        confidence: 0.8,
        cues: <NonSpeechCue>[
          NonSpeechCue(
            kind: 'choke',
            confidence: 0.8,
            evidence: 'bracket_token',
          ),
        ],
      );
      final service = const SafeNonSpeechSuggestionService();

      expect(
        service.reviewOnlySuggestions(
          AnalysisRequest(
            language: SacaLanguage.english,
            inputMethod: InputMethod.voice,
            transcript: 'leg pain',
            textInput: '',
            selectedSymptomIds: const <String>{},
            selectedBodyAreaIds: const <String>{},
            answers: const <String, String>{},
            speechSignalFeatures: features,
          ),
        ),
        isEmpty,
      );
      expect(
        service.reviewOnlySuggestions(
          AnalysisRequest(
            language: SacaLanguage.english,
            inputMethod: InputMethod.voice,
            transcript: 'chest pain',
            textInput: '',
            selectedSymptomIds: const <String>{},
            selectedBodyAreaIds: const <String>{'chest'},
            answers: const <String, String>{},
            speechSignalFeatures: features,
          ),
        ),
        contains('breathing_trouble'),
      );
    });

    test('unknown or low confidence cues do not create suggestions', () {
      const service = SafeNonSpeechSuggestionService();
      const request = AnalysisRequest(
        language: SacaLanguage.english,
        inputMethod: InputMethod.voice,
        transcript: 'chest pain',
        textInput: '',
        selectedSymptomIds: <String>{},
        selectedBodyAreaIds: <String>{'chest'},
        answers: <String, String>{},
        speechSignalFeatures: SpeechSignalFeatures(
          transcript: 'chest pain',
          confidence: 0.8,
          cues: <NonSpeechCue>[
            NonSpeechCue(
              kind: 'possible_fever',
              confidence: 0.9,
              evidence: 'bracket_token',
            ),
            NonSpeechCue(
              kind: 'gasp',
              confidence: 0.4,
              evidence: 'bracket_token',
            ),
          ],
        ),
      );

      expect(service.reviewOnlySuggestions(request), isEmpty);
    });

    test('manual transcript edit clears stale voice cue features', () async {
      final controller = SacaFlowController(
        speechInput: _FakeSpeechInputService(
          transcribeFuture: Future.value(
            const AppResult.success(
              SpeechInputResult(
                text: 'throat pain',
                signalFeatures: SpeechSignalFeatures(
                  transcript: 'throat pain',
                  cues: <NonSpeechCue>[
                    NonSpeechCue(
                      kind: 'cough',
                      confidence: 0.8,
                      evidence: 'bracket_token',
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        analysisService: _FakeAnalysisService(),
      );
      addTearDown(controller.dispose);

      controller.showLanguage();
      controller.selectLanguage(SacaLanguage.english);
      await controller.chooseInputMethod(InputMethod.voice);
      await controller.startRecording();
      await controller.stopRecording();
      expect(controller.state.speechSignalFeatures, isNotNull);

      controller.updateTranscript('headache');

      expect(controller.state.speechSignalFeatures, isNull);
    });

    test('empty input creates confirmation instead of red error', () async {
      final controller = SacaFlowController(
        speechInput: _FakeSpeechInputService(),
        analysisService: _FakeAnalysisService(),
      );
      addTearDown(controller.dispose);

      controller.showLanguage();
      controller.selectLanguage(SacaLanguage.english);
      await controller.chooseInputMethod(InputMethod.text);
      controller.continueFromInput();

      expect(controller.state.pendingConfirmation,
          SacaConfirmationType.emptyInput);
      expect(controller.state.errorMessage, isNull);

      controller.confirmPendingAction();

      expect(controller.state.pendingConfirmation, isNull);
      expect(controller.state.step, SacaStep.questionSeverity);
    });

    test('empty input review stays on input step', () async {
      final controller = SacaFlowController(
        speechInput: _FakeSpeechInputService(),
        analysisService: _FakeAnalysisService(),
      );
      addTearDown(controller.dispose);

      controller.showLanguage();
      controller.selectLanguage(SacaLanguage.english);
      await controller.chooseInputMethod(InputMethod.text);
      controller.continueFromInput();
      controller.dismissPendingConfirmation();

      expect(controller.state.pendingConfirmation, isNull);
      expect(controller.state.step, SacaStep.textInput);
    });

    test('no clear illness waits for confirmation before result', () async {
      final controller = SacaFlowController(
        speechInput: _FakeSpeechInputService(),
        analysisService: _FakeAnalysisService(
          result: const AnalysisResult(
            disease: 'No clear illness detected',
            severity: SeverityLevel.mild,
            guidance: <String>['Review symptoms.'],
            isEmergency: false,
            disclaimer: 'Prototype guidance only.',
          ),
        ),
      );
      addTearDown(controller.dispose);

      controller.showLanguage();
      controller.selectLanguage(SacaLanguage.english);
      await controller.chooseInputMethod(InputMethod.text);
      controller.updateTextInput('nothing clear');
      controller.continueFromInput();
      controller.answerQuestion('severity', '5');
      controller.nextQuestion();
      controller.answerQuestion('duration', 'less than one day');
      controller.nextQuestion();
      controller.nextQuestion();
      controller.nextQuestion();
      controller.nextQuestion();
      controller.nextQuestion();
      controller.nextQuestion();
      await controller.analyse();

      expect(controller.state.pendingConfirmation,
          SacaConfirmationType.noClearIllness);
      expect(controller.state.step, SacaStep.analysing);

      controller.confirmPendingAction();

      expect(controller.state.step, SacaStep.result);
    });
  });
}

class _FakeSpeechInputService implements SpeechInputService {
  _FakeSpeechInputService({
    this.prepareResult = const AppResult<void>.success(null),
    this.prepareFuture,
    this.transcribeFuture,
    this.autoStopFuture,
    Stream<String>? partialTranscriptStream,
  }) : partialTranscriptStream =
            partialTranscriptStream ?? const Stream<String>.empty();

  final AppResult<void> prepareResult;
  final Future<AppResult<void>>? prepareFuture;
  final Future<AppResult<SpeechInputResult>>? transcribeFuture;
  final Future<AppResult<SpeechInputResult>>? autoStopFuture;
  @override
  final Stream<String> partialTranscriptStream;
  final List<SpeechInputMode> startedModes = <SpeechInputMode>[];
  final List<SpeechInputMode> stoppedModes = <SpeechInputMode>[];

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
  Future<AppResult<void>> startRecording({
    SpeechInputMode mode = SpeechInputMode.dictation,
  }) async {
    startedModes.add(mode);
    return const AppResult.success(null);
  }

  @override
  Future<AppResult<SpeechInputResult>> waitForAutoStopAndTranscribe({
    SpeechInputMode mode = SpeechInputMode.dictation,
  }) async {
    if (autoStopFuture != null) {
      return autoStopFuture!;
    }
    return Completer<AppResult<SpeechInputResult>>().future;
  }

  @override
  Future<AppResult<SpeechInputResult>> stopAndTranscribe({
    SpeechInputMode mode = SpeechInputMode.dictation,
  }) async {
    stoppedModes.add(mode);
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
  _FakeAnalysisService({this.result});

  final AnalysisResult? result;

  @override
  Future<AppResult<AnalysisResult>> analyse(AnalysisRequest request) async {
    return AppResult.success(
      result ??
          const AnalysisResult(
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

class _FixedSymptomSuggestionService implements SymptomSuggestionService {
  const _FixedSymptomSuggestionService({
    this.initial = const <String>[],
    this.refined = const <String>[],
  });

  final List<String> initial;
  final List<String> refined;

  @override
  List<String> suggestRelatedSymptoms(AnalysisRequest request) => initial;

  @override
  Future<List<String>> refineRelatedSymptoms(AnalysisRequest request) async =>
      refined;
}
