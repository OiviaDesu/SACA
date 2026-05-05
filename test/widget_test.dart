import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saca_demo/core/errors/app_error.dart';
import 'package:saca_demo/core/theme/saca_theme.dart';
import 'package:saca_demo/domain/models/lexicon_entry.dart';
import 'package:saca_demo/domain/models/saca_models.dart';
import 'package:saca_demo/domain/services/analysis_service.dart';
import 'package:saca_demo/domain/services/clinical_vocabulary_service.dart';
import 'package:saca_demo/domain/services/speech_input_service.dart';
import 'package:saca_demo/infrastructure/analysis/mock_analysis_service.dart';
import 'package:saca_demo/presentation/adaptive/saca_platform_style.dart';
import 'package:saca_demo/presentation/controllers/saca_flow_controller.dart';
import 'package:saca_demo/presentation/localization/saca_localizer.dart';
import 'package:saca_demo/presentation/readiness/saca_readiness_controller.dart';
import 'package:saca_demo/presentation/screens/saca_flow_screen.dart';
import 'package:saca_demo/presentation/settings/saca_settings_controller.dart';
import 'package:saca_demo/presentation/widgets/saca_controls.dart';
import 'package:saca_demo/presentation/widgets/saca_logo_header.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ClinicalVocabularyService vocabulary;
  late SacaLocalizer localizer;

  setUpAll(() async {
    final source = await rootBundle.loadString(
      'assets/data/gurindji_lexicon.json',
    );
    vocabulary = ClinicalVocabularyService.fromEntries(
      LexiconEntry.listFromJson(source),
    );
    localizer = SacaLocalizer(vocabulary: vocabulary);
  });

  test('platform style resolves desktop and mobile variants', () {
    expect(
      SacaPlatformStyleResolver.resolve(
        platform: TargetPlatform.windows,
        width: 1000,
      ),
      SacaPlatformStyle.windowsDesktop,
    );
    expect(
      SacaPlatformStyleResolver.resolve(
        platform: TargetPlatform.windows,
        width: 420,
      ),
      SacaPlatformStyle.androidMobile,
    );
    expect(
      SacaPlatformStyleResolver.resolve(
        platform: TargetPlatform.android,
        width: 1000,
      ),
      SacaPlatformStyle.androidMobile,
    );
  });

  testWidgets('windows shell renders centered content without progress rail',
      (tester) async {
    final controller = await _pumpFlow(
      tester,
      style: SacaPlatformStyle.windowsDesktop,
    );

    expect(find.byKey(const ValueKey('windowsFramelessShell')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('windowsRoundedShellClip')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('windowsResizeOverlay')), findsOneWidget);
    expect(find.byKey(const ValueKey('windowsCustomTitleBar')), findsOneWidget);
    expect(find.byKey(const ValueKey('windowsWindowControls')), findsOneWidget);
    expect(find.bySemanticsLabel('Settings'), findsOneWidget);
    expect(find.byKey(const ValueKey('windowsContentColumn')), findsOneWidget);
    expect(find.byKey(const ValueKey('windowsProgressRail')), findsNothing);
    expect(find.text('Ready'), findsOneWidget);

    await tester.tap(find.text('English'));
    await tester.pump();
    expect(controller.state.step, SacaStep.inputMethod);
  });

  testWidgets('android mobile shell renders single-column language flow',
      (tester) async {
    await _pumpFlow(tester, style: SacaPlatformStyle.androidMobile);

    expect(find.byKey(const ValueKey('windowsFramelessShell')), findsNothing);
    expect(find.byKey(const ValueKey('windowsResizeOverlay')), findsNothing);
    expect(find.bySemanticsLabel('Settings'), findsOneWidget);
    expect(find.textContaining('English'), findsWidgets);
    expect(find.byType(SacaLogoHeader), findsWidgets);
  });

  testWidgets('windows narrow preview keeps toolbar and resize overlay',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    await tester.binding.setSurfaceSize(const Size(520, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pumpFlow(tester, style: null);

    expect(find.byKey(const ValueKey('windowsCustomTitleBar')), findsOneWidget);
    expect(find.byKey(const ValueKey('windowsResizeOverlay')), findsOneWidget);
    expect(find.byKey(const ValueKey('windowsWindowControls')), findsOneWidget);
    expect(find.byKey(const ValueKey('windowsContentColumn')), findsOneWidget);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('settings page changes theme and text size', (tester) async {
    final controller = await _pumpFlow(
      tester,
      style: SacaPlatformStyle.androidMobile,
    );

    await tester.ensureVisible(find.bySemanticsLabel('Settings').first);
    await tester.tap(find.bySemanticsLabel('Settings').first,
        warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 300));

    expect(controller.state.step, SacaStep.settings);
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Light'), findsOneWidget);
    expect(find.text('Dark'), findsOneWidget);
    expect(find.text('System'), findsOneWidget);
    expect(
        find.byKey(const ValueKey('settingsTextScaleSlider')), findsOneWidget);
    expect(find.text('115%'), findsOneWidget);

    await tester.tap(find.text('Dark'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.drag(
      find.byKey(const ValueKey('settingsTextScaleSlider')),
      const Offset(200, 0),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('115%'), findsNothing);

    await tester.tap(find.bySemanticsLabel('Back'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(controller.state.step, SacaStep.language);
  });

  testWidgets('settings icon toggles settings page closed on second tap',
      (tester) async {
    final controller = await _pumpFlow(
      tester,
      style: SacaPlatformStyle.windowsDesktop,
    );

    await tester.tap(find.byIcon(CupertinoIcons.gear_alt));
    await tester.pump(const Duration(milliseconds: 300));

    expect(controller.state.step, SacaStep.settings);
    expect(find.text('Settings'), findsOneWidget);

    await tester.tap(find.byIcon(CupertinoIcons.gear_alt));
    await tester.pump(const Duration(milliseconds: 500));

    expect(controller.state.step, SacaStep.language);
    expect(find.text('SACA'), findsWidgets);
  });

  testWidgets('theme colors interpolate during light dark transition',
      (tester) async {
    const light = SacaTheme.lightColors;
    const dark = SacaTheme.darkColors;
    var useDark = false;

    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) {
          return CupertinoApp(
            home: CupertinoButton(
              child: TweenAnimationBuilder<SacaThemeColors>(
                duration: const Duration(milliseconds: 260),
                tween: _TestThemeTween(
                  begin: light,
                  end: useDark ? dark : light,
                ),
                builder: (context, colors, child) {
                  return ColoredBox(
                    key: const ValueKey('animatedThemeProbe'),
                    color: colors.background,
                    child: const SizedBox.square(dimension: 40),
                  );
                },
              ),
              onPressed: () => setState(() => useDark = true),
            ),
          );
        },
      ),
    );

    expect(_probeColor(tester), SacaTheme.background);

    await tester.tap(find.byType(CupertinoButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 130));
    final midColor = _probeColor(tester);

    expect(midColor, isNot(SacaTheme.background));
    expect(midColor, isNot(SacaTheme.darkBackground));

    await tester.pumpAndSettle();

    expect(_probeColor(tester), SacaTheme.darkBackground);
  });

  testWidgets('not ready badge appears when active assets missing',
      (tester) async {
    await _pumpFlow(
      tester,
      style: SacaPlatformStyle.windowsDesktop,
      readiness: const SacaReadinessState(
        isReady: false,
        messages: <String>['Diagnosis model is missing.'],
      ),
    );

    expect(find.text('Not ready'), findsOneWidget);
  });

  testWidgets('language flow reaches input method with exactly three options', (
    tester,
  ) async {
    final controller = await _pumpFlow(tester);

    await _reachInputMethod(tester);

    expect(controller.state.step, SacaStep.inputMethod);
    expect(find.text('How do you want to enter symptoms?'), findsOneWidget);
    expect(find.text('Text input'), findsOneWidget);
    expect(find.text('Voice input'), findsOneWidget);
    expect(find.text('Body map'), findsOneWidget);
    expect(find.text('Symptom select'), findsNothing);
    expect(find.text('Body diagram'), findsNothing);
  });

  testWidgets('text input fever reaches structured questions and result', (
    tester,
  ) async {
    await _pumpFlow(tester);
    await _reachInputMethod(tester);

    await tester.tap(find.text('Text input'));
    await tester.pump();
    await tester.enterText(
      find.byKey(const ValueKey('symptomTextField')),
      'fever',
    );
    await tester.pump();
    await _tapVisible(tester, find.text('Continue'));
    await _answerQuestionnaire(tester);

    expect(find.text('Care guidance'), findsOneWidget);
    expect(find.text('Fever and throat symptoms'), findsOneWidget);
    expect(find.text('Severity: Mild'), findsOneWidget);
    expect(find.textContaining('does not replace a clinician'), findsOneWidget);
  });

  testWidgets('visual body map path supports symptom and body selection', (
    tester,
  ) async {
    final controller = await _pumpFlow(tester);
    await _reachInputMethod(tester);

    await tester.tap(find.text('Body map'));
    await tester.pump();
    await tester.tap(find.text('Fever'));
    await tester.pump();
    await _pressPrimaryButton(
      tester,
      const ValueKey('visualSymptomsContinueButton'),
    );
    expect(find.byKey(const ValueKey('bodyDiagram-front')), findsOneWidget);
    await tester.tap(find.text('Throat').first);
    await tester.pump();
    await _pressPrimaryButton(
      tester,
      const ValueKey('visualFrontContinueButton'),
    );
    expect(find.byKey(const ValueKey('bodyDiagram-back')), findsOneWidget);
    await _pressPrimaryButton(
        tester, const ValueKey('visualBackContinueButton'));

    expect(controller.state.selectedSymptomIds, contains('fever'));
    expect(controller.state.selectedBodyAreaIds, contains('throat'));
    expect(controller.state.step, SacaStep.questionSeverity);
  });

  testWidgets('empty body stage shows Skip', (tester) async {
    await _pumpFlow(tester);
    await _reachInputMethod(tester);

    await tester.tap(find.text('Body map'));
    await tester.pump();
    await tester.tap(find.text('Fever'));
    await tester.pump();
    await _pressPrimaryButton(
      tester,
      const ValueKey('visualSymptomsContinueButton'),
    );

    expect(find.text('Skip'), findsOneWidget);
  });

  testWidgets('review gate supports adding more information', (tester) async {
    final controller = await _pumpFlow(tester);
    await _reachInputMethod(tester);

    await tester.tap(find.text('Text input'));
    await tester.pump();
    await tester.enterText(
      find.byKey(const ValueKey('symptomTextField')),
      'fever',
    );
    await tester.pump();
    await _tapVisible(tester, find.text('Continue'));
    await _answerQuestionnaire(tester, stopAtReview: true);

    expect(controller.state.step, SacaStep.reviewInformation);
    await _tapVisible(tester, find.text('Add more information'));
    expect(controller.state.step, SacaStep.inputMethod);
    expect(controller.state.textInput, 'fever');
  });

  testWidgets('severity question uses a large default slider value', (
    tester,
  ) async {
    await _pumpFlow(tester);
    await _reachInputMethod(tester);

    await tester.tap(find.text('Text input'));
    await tester.pump();
    await tester.enterText(
      find.byKey(const ValueKey('symptomTextField')),
      'fever',
    );
    await tester.pump();
    await _tapVisible(tester, find.text('Continue'));

    expect(find.byKey(const ValueKey('severitySlider')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('severitySliderInlineControl')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('severityValue-5')), findsOneWidget);
  });

  testWidgets('severity slider fits narrow mobile layout', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpFlow(tester, style: SacaPlatformStyle.androidMobile);
    await _reachInputMethod(tester);

    await tester.tap(find.text('Text input'));
    await tester.pump();
    await tester.enterText(
      find.byKey(const ValueKey('symptomTextField')),
      'fever',
    );
    await tester.pump();
    await _tapVisible(tester, find.text('Continue'));

    expect(find.byKey(const ValueKey('severitySlider')), findsOneWidget);
    expect(find.byKey(const ValueKey('severityValue-5')), findsOneWidget);
    await _setSeveritySlider(tester, 9);
    expect(find.byKey(const ValueKey('severityValue-9')), findsOneWidget);
  });

  testWidgets('red flag text shows emergency advice', (tester) async {
    await _pumpFlow(tester);
    await _reachInputMethod(tester);

    await tester.tap(find.text('Text input'));
    await tester.pump();
    await tester.enterText(
      find.byKey(const ValueKey('symptomTextField')),
      'chest pain and cannot breathe',
    );
    await tester.pump();
    await _tapVisible(tester, find.text('Continue'));
    await _answerQuestionnaire(tester, severity: '9', related: 'Chest pain');

    expect(find.text('Call 000 now'), findsOneWidget);
    expect(
      find.text('Urgent chest, breathing, or bleeding signs'),
      findsOneWidget,
    );
    expect(find.text('Severity: Emergency'), findsOneWidget);
  });

  testWidgets('result screen shows ranked top three confidence cards', (
    tester,
  ) async {
    await _pumpFlow(tester, analysisService: const _RankedAnalysisService());
    await _reachInputMethod(tester);

    await tester.tap(find.text('Text input'));
    await tester.pump();
    await tester.enterText(
      find.byKey(const ValueKey('symptomTextField')),
      'fever',
    );
    await tester.pump();
    await _tapVisible(tester, find.text('Continue'));
    await _answerQuestionnaire(tester);

    expect(find.text('Fever and throat symptoms'), findsOneWidget);
    expect(find.text('Common Cold'), findsOneWidget);
    expect(find.text('Migraine'), findsOneWidget);
    expect(find.textContaining('82%'), findsOneWidget);
    expect(find.textContaining('High'), findsOneWidget);
  });

  testWidgets('gurindji visual selection shows Gurindji clinical labels', (
    tester,
  ) async {
    final controller = await _pumpFlow(
      tester,
      vocabulary: vocabulary,
      localizer: localizer,
    );
    await _reachInputMethod(tester, language: 'Gurindji');

    await tester.tap(find.text('Puya nyawa'));
    await tester.pump();

    expect(find.text('makurrmakurr'), findsOneWidget);
    await tester.tap(find.text('makurrmakurr'));
    await tester.pump();
    await _pressPrimaryButton(
      tester,
      const ValueKey('visualSymptomsContinueButton'),
    );
    expect(find.byKey(const ValueKey('bodyDiagram-front')), findsOneWidget);
    expect(find.text('ngirlkirri'), findsOneWidget);
    expect(find.text('Fever'), findsNothing);
    expect(find.text('Throat'), findsNothing);

    await _tapVisible(tester, find.text('ngirlkirri').first);
    await _pressPrimaryButton(
      tester,
      const ValueKey('visualFrontContinueButton'),
    );
    expect(find.byKey(const ValueKey('bodyDiagram-back')), findsOneWidget);
    await _pressPrimaryButton(
        tester, const ValueKey('visualBackContinueButton'));

    expect(controller.state.step, SacaStep.questionSeverity);
    expect(controller.state.selectedSymptomIds, contains('fever'));
    expect(controller.state.selectedBodyAreaIds, contains('throat'));
  });

  testWidgets('gurindji fever text reaches the same mock result', (
    tester,
  ) async {
    await _pumpFlow(tester, vocabulary: vocabulary, localizer: localizer);
    await _reachInputMethod(tester, language: 'Gurindji');

    await tester.tap(find.text('Yawu'));
    await tester.pump();
    await tester.enterText(
      find.byKey(const ValueKey('symptomTextField')),
      'makurrmakurr',
    );
    await tester.pump();
    await _tapVisible(tester, find.text('Kawayi'));
    await _answerQuestionnaire(
      tester,
      gurindji: true,
      related: 'ngirlkirri pung',
    );

    expect(find.text('Jangany nyawa'), findsOneWidget);
    expect(find.text('makurrmakurr / ngirlkirri pung'), findsOneWidget);
    expect(find.text('Jangany: Yamak'), findsOneWidget);
    expect(find.text('Care guidance'), findsNothing);
    expect(find.text('Severity: Mild'), findsNothing);
  });

  testWidgets('gurindji voice input shows Gurindji stt notice', (
    tester,
  ) async {
    await _pumpFlow(tester, vocabulary: vocabulary, localizer: localizer);
    await _reachInputMethod(tester, language: 'Gurindji');

    await tester.tap(find.text('Ngayirrp'));
    await tester.pump();

    expect(
      find.textContaining('Gurindji ngayirrp mayi'),
      findsOneWidget,
    );
    expect(find.text('Voice input'), findsNothing);
  });

  testWidgets('voice input shows centered loading overlay while preparing', (
    tester,
  ) async {
    final prepareCompleter = Completer<AppResult<void>>();
    await _pumpFlow(
      tester,
      speechInput: _ControllableSpeechInputService(
        prepareFuture: prepareCompleter.future,
      ),
    );
    await _reachInputMethod(tester);

    await tester.tap(find.text('Voice input'));
    await tester.pump();

    expect(find.byKey(const ValueKey('voiceLoadingOverlay')), findsOneWidget);
    expect(find.text('Getting voice ready'), findsOneWidget);
    expect(find.text('Listening to your recording'), findsNothing);

    prepareCompleter.complete(const AppResult.success(null));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 220));

    expect(find.byKey(const ValueKey('voiceLoadingOverlay')), findsNothing);
    expect(find.byKey(const ValueKey('voiceTranscriptField')), findsOneWidget);
  });

  testWidgets(
      'voice transcribe shows loading overlay and then fills transcript',
      (tester) async {
    final transcribeCompleter = Completer<AppResult<SpeechInputResult>>();
    final speechInput = _ControllableSpeechInputService(
      transcribeFuture: transcribeCompleter.future,
    );
    await _pumpFlow(tester, speechInput: speechInput);
    await _reachInputMethod(tester);

    await tester.tap(find.text('Voice input'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 220));

    await tester.tap(find.text('Record'));
    await tester.pump();
    await tester.tap(find.text('Stop recording'));
    await tester.pump();

    expect(find.byKey(const ValueKey('voiceLoadingOverlay')), findsOneWidget);
    expect(find.text('Listening to your recording'), findsOneWidget);

    transcribeCompleter.complete(
      const AppResult.success(
          SpeechInputResult(text: 'headache and sore throat')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 220));

    expect(find.byKey(const ValueKey('voiceLoadingOverlay')), findsNothing);
    expect(find.text('headache and sore throat'), findsOneWidget);
  });

  testWidgets('voice input shows mic controls on severity follow-up',
      (tester) async {
    final controller = await _pumpFlow(tester);
    await _reachInputMethod(tester);

    await tester.tap(find.text('Voice input'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 220));
    controller.updateTranscript('headache');
    controller.continueFromInput();
    await tester.pump();

    expect(find.byKey(const ValueKey('voiceQuestionRecordButton')),
        findsOneWidget);
    expect(find.text('Answer by voice'), findsOneWidget);
    expect(find.byKey(const ValueKey('severitySlider')), findsOneWidget);
  });

  testWidgets('voice answer on duration selects matching manual option',
      (tester) async {
    final controller = await _pumpFlow(
      tester,
      speechInput: _ControllableSpeechInputService(
        transcribeFuture: Future.value(
          const AppResult.success(SpeechInputResult(text: 'three days')),
        ),
      ),
    );
    await _reachInputMethod(tester);

    await tester.tap(find.text('Voice input'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 220));
    controller.updateTranscript('headache');
    controller.continueFromInput();
    controller.answerQuestion('severity', '5');
    controller.nextQuestion();
    await tester.pump();

    await tester.tap(find.text('Answer by voice'));
    await tester.pump();
    await tester.tap(find.text('Stop voice answer'));
    await tester.pumpAndSettle();

    expect(controller.state.questionAnswers['duration'], 'one to three days');
    expect(find.byKey(const ValueKey('voiceQuestionHeard')), findsOneWidget);
    expect(find.text('1-3 days'), findsOneWidget);
  });

  testWidgets('voice answer on duration selects more than seven days',
      (tester) async {
    final controller = await _pumpFlow(
      tester,
      speechInput: _ControllableSpeechInputService(
        transcribeFuture: Future.value(
          const AppResult.success(SpeechInputResult(text: 'More than 7 days')),
        ),
      ),
    );
    await _reachInputMethod(tester);

    await tester.tap(find.text('Voice input'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 220));
    controller.updateTranscript('headache');
    controller.continueFromInput();
    controller.answerQuestion('severity', '5');
    controller.nextQuestion();
    await tester.pump();

    await tester.tap(find.text('Answer by voice'));
    await tester.pump();
    await tester.tap(find.text('Stop voice answer'));
    await tester.pumpAndSettle();

    expect(
        controller.state.questionAnswers['duration'], 'more than seven days');
    expect(find.byKey(const ValueKey('voiceQuestionNotMatched')), findsNothing);
    expect(find.text('>7 days'), findsOneWidget);
  });

  testWidgets('voice answer on allergies selects not sure', (tester) async {
    final controller = await _pumpFlow(
      tester,
      speechInput: _ControllableSpeechInputService(
        transcribeFuture: Future.value(
          const AppResult.success(SpeechInputResult(text: 'Not sure.')),
        ),
      ),
    );
    await _reachInputMethod(tester);

    await tester.tap(find.text('Voice input'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 220));
    controller.updateTranscript('headache');
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
    await tester.pump();

    await tester.tap(find.text('Answer by voice'));
    await tester.pump();
    await tester.tap(find.text('Stop voice answer'));
    await tester.pumpAndSettle();

    expect(controller.state.questionAnswers['allergies'], 'not sure allergies');
    expect(find.byKey(const ValueKey('voiceQuestionNotMatched')), findsNothing);
    expect(find.text('Not sure'), findsOneWidget);
  });

  testWidgets('unmatched voice answer shows fallback and keeps controls',
      (tester) async {
    final controller = await _pumpFlow(
      tester,
      speechInput: _ControllableSpeechInputService(
        transcribeFuture: Future.value(
          const AppResult.success(SpeechInputResult(text: 'banana sky')),
        ),
      ),
    );
    await _reachInputMethod(tester);

    await tester.tap(find.text('Voice input'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 220));
    controller.updateTranscript('headache');
    controller.continueFromInput();
    controller.answerQuestion('severity', '5');
    controller.nextQuestion();
    await tester.pump();

    await tester.tap(find.text('Answer by voice'));
    await tester.pump();
    await tester.tap(find.text('Stop voice answer'));
    await tester.pumpAndSettle();

    expect(
        find.byKey(const ValueKey('voiceQuestionNotMatched')), findsOneWidget);
    expect(
      find.text('Could not match answer. Please tap or try again.'),
      findsOneWidget,
    );
    expect(find.text('1-3 days'), findsOneWidget);
    expect(controller.state.questionAnswers['duration'], isNull);
  });

  testWidgets('maximized desktop content expands past old narrow width',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(2048, 1152));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pumpFlow(tester, style: SacaPlatformStyle.windowsDesktop);
    await _reachInputMethod(tester);

    final contentSize = tester.getSize(
      find.byKey(const ValueKey('windowsContentColumn')),
    );
    expect(contentSize.width, greaterThan(1000));

    final optionSize = tester.getSize(find.text('Text input').first);
    expect(optionSize.width, greaterThan(0));
  });

  testWidgets('maximized desktop centers flow content vertically',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(2048, 1152));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pumpFlow(tester, style: SacaPlatformStyle.windowsDesktop);
    await _reachInputMethod(tester);

    final shellTopLeft = tester.getTopLeft(
      find.byKey(const ValueKey('windowsContentColumn')),
    );
    final shellSize = tester.getSize(
      find.byKey(const ValueKey('windowsContentColumn')),
    );
    final contentCenterY = shellTopLeft.dy + shellSize.height / 2;
    final availableCenterY = 64 + (1152 - 64) / 2;

    expect(contentCenterY, closeTo(availableCenterY, 60));
    expect(shellTopLeft.dy, greaterThan(250));
  });

  testWidgets('short desktop window remains scroll-safe', (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 360));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pumpFlow(tester, style: SacaPlatformStyle.windowsDesktop);
    await _reachInputMethod(tester);

    expect(find.byKey(const ValueKey('windowsContentColumn')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('gurindji voice loading overlay stays localized', (tester) async {
    final prepareCompleter = Completer<AppResult<void>>();
    await _pumpFlow(
      tester,
      vocabulary: vocabulary,
      localizer: localizer,
      speechInput: _ControllableSpeechInputService(
        prepareFuture: prepareCompleter.future,
      ),
    );
    await _reachInputMethod(tester, language: 'Gurindji');

    await tester.tap(find.text('Ngayirrp'));
    await tester.pump();

    expect(find.byKey(const ValueKey('voiceLoadingOverlay')), findsOneWidget);
    expect(find.text('Ngayirrp yamak'), findsOneWidget);
    expect(find.text('Getting voice ready'), findsNothing);

    prepareCompleter.complete(const AppResult.success(null));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 220));
  });

  testWidgets('gurindji emergency result uses Gurindji copy and keeps 000', (
    tester,
  ) async {
    await _pumpFlow(tester, vocabulary: vocabulary, localizer: localizer);
    await _reachInputMethod(tester, language: 'Gurindji');

    await tester.tap(find.text('Yawu'));
    await tester.pump();
    await tester.enterText(
      find.byKey(const ValueKey('symptomTextField')),
      'mangarli pung',
    );
    await tester.pump();
    await _tapVisible(tester, find.text('Kawayi'));
    await _answerQuestionnaire(
      tester,
      gurindji: true,
      severity: '9',
      related: 'mangarli pung',
    );

    expect(find.text('000 kawayi jala'), findsOneWidget);
    expect(
      find.text('mangarli pung / ngayirrp ma- / warlarrp'),
      findsOneWidget,
    );
    expect(find.text('Jangany: 000'), findsOneWidget);
    expect(find.text('Call 000 now'), findsNothing);
    expect(
      find.text('Urgent chest, breathing, or bleeding signs'),
      findsNothing,
    );
  });
}

Future<SacaFlowController> _pumpFlow(
  WidgetTester tester, {
  SacaPlatformStyle? style = SacaPlatformStyle.androidMobile,
  ClinicalVocabularyService? vocabulary,
  SacaLocalizer? localizer,
  SpeechInputService? speechInput,
  AnalysisService? analysisService,
  SacaReadinessState readiness = SacaReadinessState.ready,
}) async {
  final activeVocabulary =
      vocabulary ?? const ClinicalVocabularyService.empty();
  final controller = SacaFlowController(
    speechInput: speechInput ?? _NoopSpeechInputService(),
    analysisService:
        analysisService ?? MockAnalysisService(vocabulary: activeVocabulary),
  );

  await tester.pumpWidget(
    CupertinoApp(
      theme: SacaTheme.cupertinoTheme,
      home: SacaFlowScreen(
        controller: controller,
        readiness: readiness,
        settings: SacaSettingsController(store: _WidgetSettingsStore()),
        styleOverride: style,
        localizer: localizer ?? SacaLocalizer(vocabulary: activeVocabulary),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 700));
  return controller;
}

class _WidgetSettingsStore implements SacaSettingsStore {
  final Map<String, Object?> _values = <String, Object?>{};

  @override
  Future<String?> getString(String key) async => _values[key] as String?;

  @override
  Future<double?> getDouble(String key) async => _values[key] as double?;

  @override
  Future<void> setString(String key, String value) async {
    _values[key] = value;
  }

  @override
  Future<void> setDouble(String key, double value) async {
    _values[key] = value;
  }
}

Future<void> _reachInputMethod(
  WidgetTester tester, {
  String language = 'English',
}) async {
  await tester.ensureVisible(find.text(language));
  await tester.tap(find.text(language), warnIfMissed: false);
  await tester.pump();
}

Color _probeColor(WidgetTester tester) {
  final coloredBox = tester.widget<ColoredBox>(
    find.byKey(const ValueKey('animatedThemeProbe')),
  );
  return coloredBox.color;
}

class _TestThemeTween extends Tween<SacaThemeColors> {
  _TestThemeTween({required SacaThemeColors begin, required SacaThemeColors end})
      : super(begin: begin, end: end);

  @override
  SacaThemeColors lerp(double t) {
    return SacaThemeColors.lerp(
      begin ?? SacaTheme.lightColors,
      end ?? SacaTheme.lightColors,
      t,
    );
  }
}

Future<void> _answerQuestionnaire(
  WidgetTester tester, {
  String severity = '4',
  String related = 'Sore throat',
  bool gurindji = false,
  bool stopAtReview = false,
}) async {
  final continueLabel = gurindji ? 'Kawayi' : 'Continue';
  final durationLabel = gurindji ? '1-3 tirrip' : '1-3 days';
  final noLabel = gurindji ? 'Karrwarn' : 'No';
  final noChangeLabel = gurindji ? 'Karrwarn' : 'No change';
  final noAllergyLabel = gurindji ? 'Karrwarn' : 'No known allergies';
  final analyseLabel = gurindji ? 'Nyawa' : 'Analyse';

  await _setSeveritySlider(tester, int.parse(severity));
  await _tapVisible(tester, find.text(continueLabel));
  await _tapVisible(tester, find.text(durationLabel));
  await _tapVisible(tester, find.text(continueLabel));
  await _tapVisible(tester, find.text(related));
  await _tapVisible(tester, find.text(continueLabel));
  await _tapVisible(tester, find.text(noLabel));
  await _tapVisible(tester, find.text(continueLabel));
  await _tapVisible(tester, find.text(noChangeLabel));
  await _tapVisible(tester, find.text(continueLabel));
  await _tapVisible(tester, find.text(noAllergyLabel));
  await _tapVisible(tester, find.text(continueLabel));
  await _tapVisible(tester, find.text(noChangeLabel));
  await _tapVisible(tester, find.text(continueLabel));
  expect(find.text(gurindji ? 'Yawu nyawa' : 'Review your information'),
      findsOneWidget);
  if (stopAtReview) return;
  await _tapVisible(tester, find.text(analyseLabel));
  await tester.pump(const Duration(milliseconds: 500));
}

Future<void> _setSeveritySlider(WidgetTester tester, int severity) async {
  final slider = find.byKey(const ValueKey('severitySlider'));
  await tester.ensureVisible(slider);
  await tester.pump();

  final current = tester.widget<CupertinoSlider>(slider).value;
  final rect = tester.getRect(slider);
  final clampedSeverity = severity.clamp(1, 10);
  final dx = ((clampedSeverity - current) / 9) * (rect.width - 56);

  if (dx.abs() > 0.1) {
    await tester.drag(slider, Offset(dx, 0));
    await tester.pump();
  }
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  final visibleFinder = finder.last;
  final descendantButton = find.descendant(
    of: visibleFinder,
    matching: find.byType(CupertinoButton),
  );
  final ancestorButton = find.ancestor(
    of: visibleFinder,
    matching: find.byType(CupertinoButton),
  );
  final target = descendantButton.evaluate().isNotEmpty
      ? descendantButton.last
      : ancestorButton.evaluate().isNotEmpty
          ? ancestorButton.last
          : visibleFinder;
  await tester.ensureVisible(target);
  await tester.pump();
  await tester.tap(target);
  await tester.pump();
}

Future<void> _pressPrimaryButton(
    WidgetTester tester, ValueKey<String> key) async {
  final button = tester.widget<SacaPrimaryButton>(find.byKey(key));
  button.onPressed?.call();
  await tester.pump();
}

class _NoopSpeechInputService implements SpeechInputService {
  @override
  bool get supportsOnDeviceStt => true;

  @override
  Future<AppResult<void>> prepare(SacaLanguage language) async {
    return const AppResult.success(null);
  }

  @override
  Future<AppResult<void>> startRecording() async {
    return const AppResult.success(null);
  }

  @override
  Future<AppResult<SpeechInputResult>> stopAndTranscribe() async {
    return const AppResult.success(
      SpeechInputResult(text: 'headache and sore throat'),
    );
  }

  @override
  Future<void> cancel() async {}

  @override
  void dispose() {}
}

class _RankedAnalysisService implements AnalysisService {
  const _RankedAnalysisService();

  @override
  Future<AppResult<AnalysisResult>> analyse(AnalysisRequest request) async {
    return const AppResult.success(
      AnalysisResult(
        disease: 'Influenza',
        severity: SeverityLevel.mild,
        guidance: <String>['Rest and monitor symptoms.'],
        isEmergency: false,
        disclaimer: 'Prototype guidance only.',
        predictions: <ConditionPrediction>[
          ConditionPrediction(label: 'Influenza', rank: 1, confidence: 0.82),
          ConditionPrediction(label: 'Common Cold', rank: 2, confidence: 0.54),
          ConditionPrediction(label: 'Migraine', rank: 3, confidence: 0.21),
        ],
      ),
    );
  }
}

class _ControllableSpeechInputService implements SpeechInputService {
  _ControllableSpeechInputService({
    this.prepareFuture,
    this.transcribeFuture,
  });

  final Future<AppResult<void>>? prepareFuture;
  final Future<AppResult<SpeechInputResult>>? transcribeFuture;

  @override
  bool get supportsOnDeviceStt => true;

  @override
  Future<AppResult<void>> prepare(SacaLanguage language) async {
    if (prepareFuture != null) {
      return await prepareFuture!;
    }
    return const AppResult.success(null);
  }

  @override
  Future<AppResult<void>> startRecording() async {
    return const AppResult.success(null);
  }

  @override
  Future<AppResult<SpeechInputResult>> stopAndTranscribe() async {
    if (transcribeFuture != null) {
      return await transcribeFuture!;
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
