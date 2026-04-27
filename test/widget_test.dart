import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saca_demo/core/errors/app_error.dart';
import 'package:saca_demo/core/theme/saca_theme.dart';
import 'package:saca_demo/domain/models/lexicon_entry.dart';
import 'package:saca_demo/domain/models/saca_models.dart';
import 'package:saca_demo/domain/services/clinical_vocabulary_service.dart';
import 'package:saca_demo/domain/services/speech_input_service.dart';
import 'package:saca_demo/infrastructure/analysis/mock_analysis_service.dart';
import 'package:saca_demo/presentation/adaptive/saca_platform_style.dart';
import 'package:saca_demo/presentation/controllers/saca_flow_controller.dart';
import 'package:saca_demo/presentation/localization/saca_localizer.dart';
import 'package:saca_demo/presentation/screens/saca_flow_screen.dart';

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

  testWidgets('windows shell renders custom toolbar and progress rail',
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
    expect(find.byKey(const ValueKey('windowsProgressRail')), findsOneWidget);
    expect(find.text('Offline'), findsOneWidget);

    await tester.tap(find.text('English'));
    await tester.pump();
    expect(controller.state.step, SacaStep.inputMethod);
  });

  testWidgets('android mobile shell renders single-column language flow',
      (tester) async {
    await _pumpFlow(tester, style: SacaPlatformStyle.androidMobile);

    expect(find.byKey(const ValueKey('windowsFramelessShell')), findsNothing);
    expect(find.byKey(const ValueKey('windowsResizeOverlay')), findsNothing);
    expect(find.textContaining('Choose your language'), findsOneWidget);
    expect(find.textContaining('Yawu nyawa'), findsWidgets);
    expect(find.textContaining('SACA health check'), findsOneWidget);
  });

  testWidgets('language flow reaches input method with exactly three options', (
    tester,
  ) async {
    final controller = await _pumpFlow(tester);

    await _reachInputMethod(tester);

    expect(controller.state.step, SacaStep.inputMethod);
    expect(find.text('Choose input'), findsOneWidget);
    expect(find.text('Text'), findsOneWidget);
    expect(find.text('Voice'), findsOneWidget);
    expect(find.text('Body'), findsOneWidget);
    expect(find.text('Symptom select'), findsNothing);
    expect(find.text('Body diagram'), findsNothing);
  });

  testWidgets('text input fever reaches structured questions and result', (
    tester,
  ) async {
    await _pumpFlow(tester);
    await _reachInputMethod(tester);

    await tester.tap(find.text('Text'));
    await tester.pump();
    await tester.enterText(
      find.byKey(const ValueKey('symptomTextField')),
      'fever',
    );
    await tester.pump();
    await _tapVisible(tester, find.text('Continue'));
    await _answerQuestionnaire(tester);

    expect(find.text('Result'), findsOneWidget);
    expect(find.text('Influenza'), findsOneWidget);
    expect(find.text('Level: Mild'), findsOneWidget);
    expect(find.textContaining('Not a diagnosis'), findsOneWidget);
  });

  testWidgets('visual selection path supports symptom and body selection', (
    tester,
  ) async {
    final controller = await _pumpFlow(tester);
    await _reachInputMethod(tester);

    await tester.tap(find.text('Body'));
    await tester.pump();
    await tester.tap(find.text('Fever'));
    await tester.pump();
    await tester.tap(find.text('Throat').first);
    await tester.pump();

    expect(controller.state.selectedSymptomIds, contains('fever'));
    expect(controller.state.selectedBodyAreaIds, contains('throat'));
    await _tapVisible(tester, find.text('Continue'));
    expect(controller.state.step, SacaStep.questionSeverity);
  });

  testWidgets('severity question uses a large default slider value', (
    tester,
  ) async {
    await _pumpFlow(tester);
    await _reachInputMethod(tester);

    await tester.tap(find.text('Text'));
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

    await tester.tap(find.text('Text'));
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

    await tester.tap(find.text('Text'));
    await tester.pump();
    await tester.enterText(
      find.byKey(const ValueKey('symptomTextField')),
      'chest pain and cannot breathe',
    );
    await tester.pump();
    await _tapVisible(tester, find.text('Continue'));
    await _answerQuestionnaire(tester, severity: '9', related: 'Chest pain');

    expect(find.text('Call 000 now'), findsOneWidget);
    expect(find.text('Urgent symptoms'), findsOneWidget);
    expect(find.text('Level: Emergency'), findsOneWidget);
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

    await tester.tap(find.text('Puya'));
    await tester.pump();

    expect(find.text('makurrmakurr'), findsOneWidget);
    expect(find.text('ngirlkirri'), findsOneWidget);
    expect(find.text('Fever'), findsNothing);
    expect(find.text('Throat'), findsNothing);

    await tester.tap(find.text('makurrmakurr'));
    await tester.pump();
    await _tapVisible(tester, find.text('ngirlkirri').first);
    await _tapVisible(tester, find.text('Kawayi'));

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

    expect(find.text('Jangany'), findsWidgets);
    expect(find.text('jangany'), findsOneWidget);
    expect(find.text('Jangany: Yamak'), findsOneWidget);
    expect(find.text('Triage guidance'), findsNothing);
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
      find.textContaining('Ngayirrp mayi'),
      findsOneWidget,
    );
    expect(find.text('Voice'), findsNothing);
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
    expect(find.text('warlarrp'), findsOneWidget);
    expect(find.text('Jangany: 000'), findsOneWidget);
    expect(find.text('Call 000 now'), findsNothing);
    expect(find.text('Urgent symptoms'), findsNothing);
  });
}

Future<SacaFlowController> _pumpFlow(
  WidgetTester tester, {
  SacaPlatformStyle style = SacaPlatformStyle.androidMobile,
  ClinicalVocabularyService? vocabulary,
  SacaLocalizer? localizer,
}) async {
  final activeVocabulary =
      vocabulary ?? const ClinicalVocabularyService.empty();
  final controller = SacaFlowController(
    speechInput: _NoopSpeechInputService(),
    analysisService: MockAnalysisService(vocabulary: activeVocabulary),
  );

  await tester.pumpWidget(
    CupertinoApp(
      theme: SacaTheme.cupertinoTheme,
      home: SacaFlowScreen(
        controller: controller,
        styleOverride: style,
        localizer: localizer ?? SacaLocalizer(vocabulary: activeVocabulary),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 700));
  return controller;
}

Future<void> _reachInputMethod(
  WidgetTester tester, {
  String language = 'English',
}) async {
  await tester.tap(find.text(language));
  await tester.pump();
}

Future<void> _answerQuestionnaire(
  WidgetTester tester, {
  String severity = '4',
  String related = 'Sore throat',
  bool gurindji = false,
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
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
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
