import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../core/theme/saca_theme.dart';
import '../../domain/models/saca_models.dart';
import '../adaptive/saca_platform_style.dart';
import '../controllers/saca_flow_controller.dart';
import '../localization/saca_localizer.dart';
import '../widgets/body_diagram.dart';
import '../widgets/desktop_window_chrome.dart';
import '../widgets/saca_controls.dart';
import '../widgets/saca_logo_header.dart';

enum _VisualInputStage { symptoms, front, back }

class SacaFlowScreen extends StatefulWidget {
  const SacaFlowScreen({
    super.key,
    required this.controller,
    this.styleOverride,
    this.localizer,
  });

  final SacaFlowController controller;
  final SacaPlatformStyle? styleOverride;
  final SacaLocalizer? localizer;

  @override
  State<SacaFlowScreen> createState() => _SacaFlowScreenState();
}

class _SacaFlowScreenState extends State<SacaFlowScreen> {
  late final SacaFlowController _controller;
  late final SacaLocalizer _localizer;
  _VisualInputStage _visualStage = _VisualInputStage.symptoms;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller;
    _localizer = widget.localizer ?? SacaLocalizer();
    Future<void>.delayed(const Duration(milliseconds: 650), () {
      if (mounted && _controller.state.step == SacaStep.splash) {
        _controller.showLanguage();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: SacaTheme.background,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const _ShellBackdrop(),
          SafeArea(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final state = _controller.state;
                return LayoutBuilder(
                  builder: (context, constraints) {
                    final style = widget.styleOverride ??
                        SacaPlatformStyleResolver.resolve(
                          platform: defaultTargetPlatform,
                          width: constraints.maxWidth,
                        );
                    final content = AnimatedSwitcher(
                      duration: const Duration(milliseconds: 240),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      transitionBuilder: (child, animation) {
                        final slide = Tween<Offset>(
                          begin: const Offset(0, 0.04),
                          end: Offset.zero,
                        ).animate(animation);
                        return FadeTransition(
                          opacity: animation,
                          child: SlideTransition(position: slide, child: child),
                        );
                      },
                      child: KeyedSubtree(
                        key: ValueKey<String>(
                          '${state.step.name}-${_visualStage.name}',
                        ),
                        child: _contentFor(context, state, style),
                      ),
                    );
                    final shellChild = style == SacaPlatformStyle.windowsDesktop
                        ? _DesktopShell(
                            state: state,
                            localizer: _localizer,
                            onBack: _canGoBack(state.step)
                                ? _controller.goBack
                                : null,
                            onInfo: () => _showPrototypeInfo(context),
                            child: content,
                          )
                        : _MobileShell(child: content);

                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        shellChild,
                        _VoiceLoadingOverlay(
                          visible: state.voiceBusyPhase != VoiceBusyPhase.none,
                          title: _localizer.voiceBusyTitle(
                            state.language,
                            state.voiceBusyPhase,
                          ),
                          subtitle: _localizer.voiceBusySubtitle(
                            state.language,
                            state.voiceBusyPhase,
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _contentFor(
    BuildContext context,
    SacaFlowState state,
    SacaPlatformStyle style,
  ) {
    return switch (state.step) {
      SacaStep.splash => _wrapStep(
          style: style,
          state: state,
          showBack: false,
          children: [
            _SplashStep(subtitle: _localizer.t(null, 'splashSubtitle'))
          ],
        ),
      SacaStep.language => _languageStep(context, state, style),
      SacaStep.inputMethod => _inputMethodStep(context, state, style),
      SacaStep.voiceInput => _voiceStep(context, state, style),
      SacaStep.textInput => _textStep(context, state, style),
      SacaStep.visualInput => _visualStep(context, state, style),
      SacaStep.questionSeverity => _severityStep(context, state, style),
      SacaStep.questionDuration => _durationStep(context, state, style),
      SacaStep.questionRelatedSymptoms =>
        _relatedSymptomsStep(context, state, style),
      SacaStep.questionMedication => _medicationStep(context, state, style),
      SacaStep.questionFood => _foodStep(context, state, style),
      SacaStep.questionAllergies => _allergiesStep(context, state, style),
      SacaStep.questionHealthChanges =>
        _healthChangesStep(context, state, style),
      SacaStep.analysing => _analysingStep(context, state, style),
      SacaStep.result => _resultStep(context, state, style),
    };
  }

  Widget _languageStep(
    BuildContext context,
    SacaFlowState state,
    SacaPlatformStyle style,
  ) {
    return _wrapStep(
      style: style,
      state: state,
      showBack: false,
      children: [
        if (style == SacaPlatformStyle.androidMobile)
          const SacaLogoHeader()
        else
          const SizedBox(height: 12),
        _title(
          style,
          _localizer.t(null, 'languageTitle'),
          _localizer.t(null, 'languageSubtitle'),
        ),
        const SizedBox(height: 18),
        SacaOptionButton(
          label: _localizer.t(null, 'languageGurindjiLabel'),
          description: _localizer.t(null, 'languageGurindjiDescription'),
          icon: CupertinoIcons.chat_bubble_text,
          selected: state.language == SacaLanguage.gurindji,
          onPressed: () => _controller.selectLanguage(SacaLanguage.gurindji),
        ),
        const SizedBox(height: 12),
        SacaOptionButton(
          label: _localizer.t(null, 'languageEnglishLabel'),
          description: _localizer.t(null, 'languageEnglishDescription'),
          icon: CupertinoIcons.chat_bubble_text_fill,
          selected: state.language == SacaLanguage.english,
          onPressed: () => _controller.selectLanguage(SacaLanguage.english),
        ),
        const SizedBox(height: 18),
        _Footnote(text: _localizer.t(null, 'languageFootnote')),
      ],
    );
  }

  Widget _inputMethodStep(
    BuildContext context,
    SacaFlowState state,
    SacaPlatformStyle style,
  ) {
    return _wrapStep(
      style: style,
      state: state,
      children: [
        _title(
          style,
          _localizer.t(state.language, 'inputTitle'),
          _localizer.t(state.language, 'inputSubtitle'),
        ),
        const SizedBox(height: 18),
        SacaOptionButton(
          label: _localizer.t(state.language, 'textInput'),
          description: _localizer.t(state.language, 'textInputDescription'),
          icon: CupertinoIcons.keyboard,
          onPressed: () => _controller.chooseInputMethod(InputMethod.text),
        ),
        const SizedBox(height: 12),
        SacaOptionButton(
          label: _localizer.t(state.language, 'voiceInput'),
          description: _localizer.t(state.language, 'voiceInputDescription'),
          icon: CupertinoIcons.mic,
          onPressed: state.isBusy
              ? null
              : () => _controller.chooseInputMethod(InputMethod.voice),
        ),
        const SizedBox(height: 12),
        SacaOptionButton(
          label: _localizer.t(state.language, 'visualSelection'),
          description:
              _localizer.t(state.language, 'visualSelectionDescription'),
          icon: CupertinoIcons.person_crop_circle,
          onPressed: () {
            setState(() {
              _visualStage = _VisualInputStage.symptoms;
            });
            _controller.chooseInputMethod(InputMethod.visual);
          },
        ),
      ],
    );
  }

  Widget _voiceStep(
    BuildContext context,
    SacaFlowState state,
    SacaPlatformStyle style,
  ) {
    final canContinue = state.transcript.trim().isNotEmpty && !state.isBusy;
    final voiceNotice = _localizer.voiceAccuracyNotice(state.language);

    return _wrapStep(
      style: style,
      state: state,
      children: [
        _title(
          style,
          _localizer.t(state.language, 'voiceTitle'),
          _localizer.t(state.language, 'voiceSubtitle'),
        ),
        const SizedBox(height: 14),
        SacaPrimaryButton(
          label: state.isRecording
              ? _localizer.t(state.language, 'stopRecording')
              : _localizer.t(state.language, 'record'),
          icon:
              state.isRecording ? CupertinoIcons.stop_fill : CupertinoIcons.mic,
          filled: state.isRecording,
          onPressed: state.isBusy
              ? null
              : () {
                  state.isRecording
                      ? _controller.stopRecording()
                      : _controller.startRecording();
                },
        ),
        const SizedBox(height: 18),
        _SacaTextField(
          key: const ValueKey('voiceTranscriptField'),
          value: state.transcript,
          placeholder: _localizer.t(state.language, 'transcriptPlaceholder'),
          minLines: 5,
          maxLines: 7,
          onChanged: _controller.updateTranscript,
        ),
        const SizedBox(height: 12),
        _Footnote(text: _localizer.t(state.language, 'offlineSpeechNotice')),
        if (voiceNotice != null) ...[
          const SizedBox(height: 8),
          _Footnote(text: voiceNotice),
        ],
        const SizedBox(height: 24),
        SacaPrimaryButton(
          label: _localizer.t(state.language, 'useTranscript'),
          icon: CupertinoIcons.check_mark_circled,
          filled: true,
          onPressed: canContinue ? _controller.continueFromInput : null,
        ),
      ],
    );
  }

  Widget _textStep(
    BuildContext context,
    SacaFlowState state,
    SacaPlatformStyle style,
  ) {
    final canContinue = state.textInput.trim().isNotEmpty && !state.isBusy;

    return _wrapStep(
      style: style,
      state: state,
      children: [
        _title(
          style,
          _localizer.t(state.language, 'textTitle'),
          _localizer.t(state.language, 'textSubtitle'),
        ),
        const SizedBox(height: 18),
        _SacaTextField(
          key: const ValueKey('symptomTextField'),
          value: state.textInput,
          placeholder: _localizer.textInputPlaceholder(state.language),
          minLines: 6,
          maxLines: 8,
          onChanged: _controller.updateTextInput,
        ),
        const SizedBox(height: 24),
        SacaPrimaryButton(
          label: _localizer.t(state.language, 'continue'),
          icon: CupertinoIcons.arrow_right_circle,
          filled: true,
          onPressed: canContinue ? _controller.continueFromInput : null,
        ),
      ],
    );
  }

  Widget _visualStep(
    BuildContext context,
    SacaFlowState state,
    SacaPlatformStyle style,
  ) {
    final hasSelection = state.selectedSymptomIds.isNotEmpty ||
        state.selectedBodyAreaIds.isNotEmpty;
    final selectedLabels = [
      ...SacaFlowState.symptoms
          .where((item) => state.selectedSymptomIds.contains(item.id))
          .map((item) => _localizer.compactSymptomLabel(
                state.language,
                item,
              )),
      ...SacaFlowState.bodyAreas
          .where((area) => state.selectedBodyAreaIds.contains(area.id))
          .map((area) => _localizer.compactBodyAreaLabel(
                state.language,
                area,
              )),
    ];

    return switch (_visualStage) {
      _VisualInputStage.symptoms => _wrapStep(
          style: style,
          state: state,
          children: [
            _visualStageHeader(
              language: state.language,
              current: _VisualInputStage.symptoms,
            ),
            _title(
              style,
              _localizer.t(state.language, 'visualSymptomsTitle'),
              _localizer.t(state.language, 'visualSymptomsSubtitle'),
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final symptom in SacaFlowState.symptoms)
                  SacaChipButton(
                    label: _localizer.symptomLabel(state.language, symptom),
                    selected: state.selectedSymptomIds.contains(symptom.id),
                    onPressed: () => _controller.toggleSymptom(symptom.id),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            _SelectedSummary(
              title: _localizer.t(state.language, 'selected'),
              emptyText: _localizer.t(state.language, 'selectedEmpty'),
              values: selectedLabels,
            ),
            const SizedBox(height: 22),
            SacaPrimaryButton(
              key: const ValueKey('visualSymptomsContinueButton'),
              label: _localizer.t(state.language, 'continue'),
              icon: CupertinoIcons.arrow_right_circle,
              filled: true,
              onPressed: () {
                setState(() {
                  _visualStage = _VisualInputStage.front;
                });
              },
            ),
          ],
        ),
      _VisualInputStage.front => _wrapStep(
          style: style,
          state: state,
          children: [
            _visualStageHeader(
              language: state.language,
              current: _VisualInputStage.front,
            ),
            _title(
              style,
              _localizer.t(state.language, 'visualFrontTitle'),
              _localizer.t(state.language, 'visualFrontSubtitle'),
            ),
            const SizedBox(height: 18),
            BodyDiagram(
              view: BodyView.front,
              selectedIds: state.selectedBodyAreaIds,
              onToggle: _controller.toggleBodyArea,
              labelForArea: (area) => _localizer.bodyAreaLabel(
                state.language,
                area,
              ),
              semanticsPrefix: _localizer.t(state.language, 'bodyAreaSemantic'),
            ),
            const SizedBox(height: 16),
            _SelectedSummary(
              title: _localizer.t(state.language, 'selected'),
              emptyText: _localizer.t(state.language, 'selectedEmpty'),
              values: selectedLabels,
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: SacaPrimaryButton(
                    key: const ValueKey('visualFrontBackButton'),
                    label: _localizer.t(state.language, 'back'),
                    icon: CupertinoIcons.arrow_left_circle,
                    onPressed: () {
                      setState(() {
                        _visualStage = _VisualInputStage.symptoms;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SacaPrimaryButton(
                    key: const ValueKey('visualFrontContinueButton'),
                    label: _localizer.t(state.language, 'continue'),
                    icon: CupertinoIcons.arrow_right_circle,
                    filled: true,
                    onPressed: () {
                      setState(() {
                        _visualStage = _VisualInputStage.back;
                      });
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      _VisualInputStage.back => _wrapStep(
          style: style,
          state: state,
          children: [
            _visualStageHeader(
              language: state.language,
              current: _VisualInputStage.back,
            ),
            _title(
              style,
              _localizer.t(state.language, 'visualBackTitle'),
              _localizer.t(state.language, 'visualBackSubtitle'),
            ),
            const SizedBox(height: 18),
            BodyDiagram(
              view: BodyView.back,
              selectedIds: state.selectedBodyAreaIds,
              onToggle: _controller.toggleBodyArea,
              labelForArea: (area) => _localizer.bodyAreaLabel(
                state.language,
                area,
              ),
              semanticsPrefix: _localizer.t(state.language, 'bodyAreaSemantic'),
            ),
            const SizedBox(height: 16),
            _SelectedSummary(
              title: _localizer.t(state.language, 'selected'),
              emptyText: _localizer.t(state.language, 'selectedEmpty'),
              values: selectedLabels,
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: SacaPrimaryButton(
                    key: const ValueKey('visualBackBackButton'),
                    label: _localizer.t(state.language, 'back'),
                    icon: CupertinoIcons.arrow_left_circle,
                    onPressed: () {
                      setState(() {
                        _visualStage = _VisualInputStage.front;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SacaPrimaryButton(
                    key: const ValueKey('visualBackContinueButton'),
                    label: _localizer.t(state.language, 'continue'),
                    icon: CupertinoIcons.arrow_right_circle,
                    filled: true,
                    onPressed:
                        hasSelection ? _controller.continueFromInput : null,
                  ),
                ),
              ],
            ),
          ],
        ),
    };
  }

  Widget _severityStep(
    BuildContext context,
    SacaFlowState state,
    SacaPlatformStyle style,
  ) {
    final severity = int.tryParse(state.questionAnswers['severity'] ?? '')
            ?.clamp(1, 10)
            .toInt() ??
        5;

    return _wrapStep(
      state: state,
      style: style,
      children: [
        _title(
          style,
          _localizer.t(state.language, 'severityTitle'),
          _localizer.t(state.language, 'severitySubtitle'),
        ),
        const SizedBox(height: 18),
        SacaSeveritySlider(
          value: severity,
          semanticLabel: _localizer.t(state.language, 'severityTitle'),
          onChanged: (value) =>
              _controller.answerQuestion('severity', value.toString()),
        ),
        const SizedBox(height: 24),
        SacaPrimaryButton(
          label: _localizer.t(state.language, 'continue'),
          icon: CupertinoIcons.arrow_right_circle,
          filled: true,
          onPressed: () {
            _controller.answerQuestion('severity', severity.toString());
            _controller.nextQuestion();
          },
        ),
      ],
    );
  }

  Widget _durationStep(
    BuildContext context,
    SacaFlowState state,
    SacaPlatformStyle style,
  ) {
    return _singleChoiceQuestion(
      state: state,
      style: style,
      title: _localizer.t(state.language, 'durationTitle'),
      subtitle: _localizer.t(state.language, 'durationSubtitle'),
      questionId: 'duration',
      choices: [
        _choice(state.language, 'less than one day', '<1 day'),
        _choice(state.language, 'one to three days', '1-3 days'),
        _choice(state.language, 'four to seven days', '4-7 days'),
        _choice(state.language, 'more than seven days', '>7 days'),
      ],
      nextLabel: _localizer.t(state.language, 'continue'),
      onNext: _controller.nextQuestion,
    );
  }

  Widget _relatedSymptomsStep(
    BuildContext context,
    SacaFlowState state,
    SacaPlatformStyle style,
  ) {
    final answered =
        (state.questionAnswers['related_symptoms'] ?? '').isNotEmpty;

    return _wrapStep(
      style: style,
      state: state,
      children: [
        _title(
          style,
          _localizer.t(state.language, 'relatedTitle'),
          _localizer.t(state.language, 'relatedSubtitle'),
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final symptom in SacaFlowState.relatedSymptoms)
              SacaChipButton(
                label: _localizer.symptomLabel(state.language, symptom),
                selected: _controller.hasQuestionAnswer(
                  'related_symptoms',
                  symptom.id,
                ),
                onPressed: () => _controller.toggleQuestionOption(
                  'related_symptoms',
                  symptom.id,
                ),
              ),
          ],
        ),
        const SizedBox(height: 24),
        SacaPrimaryButton(
          label: _localizer.t(state.language, 'continue'),
          icon: CupertinoIcons.arrow_right_circle,
          filled: true,
          onPressed: answered ? _controller.nextQuestion : null,
        ),
      ],
    );
  }

  Widget _medicationStep(
    BuildContext context,
    SacaFlowState state,
    SacaPlatformStyle style,
  ) {
    return _singleChoiceQuestion(
      state: state,
      style: style,
      title: _localizer.t(state.language, 'medicationTitle'),
      subtitle: _localizer.t(state.language, 'medicationSubtitle'),
      questionId: 'medication',
      choices: [
        _choice(state.language, 'no medication', 'No'),
        _choice(state.language, 'taken medication', 'Yes'),
        _choice(state.language, 'not sure medication', 'Not sure'),
      ],
      nextLabel: _localizer.t(state.language, 'continue'),
      onNext: _controller.nextQuestion,
    );
  }

  Widget _foodStep(
    BuildContext context,
    SacaFlowState state,
    SacaPlatformStyle style,
  ) {
    return _singleChoiceQuestion(
      state: state,
      style: style,
      title: _localizer.t(state.language, 'foodTitle'),
      subtitle: _localizer.t(state.language, 'foodSubtitle'),
      questionId: 'food',
      choices: [
        _choice(state.language, 'no food change', 'No change'),
        _choice(state.language, 'unfamiliar food', 'Unfamiliar food'),
        _choice(state.language, 'skipped meals', 'Skipped meals'),
        _choice(state.language, 'not sure food', 'Not sure'),
      ],
      nextLabel: _localizer.t(state.language, 'continue'),
      onNext: _controller.nextQuestion,
    );
  }

  Widget _allergiesStep(
    BuildContext context,
    SacaFlowState state,
    SacaPlatformStyle style,
  ) {
    return _singleChoiceQuestion(
      state: state,
      style: style,
      title: _localizer.t(state.language, 'allergiesTitle'),
      subtitle: _localizer.t(state.language, 'allergiesSubtitle'),
      questionId: 'allergies',
      choices: [
        _choice(state.language, 'no known allergies', 'No known allergies'),
        _choice(state.language, 'possible allergies', 'Yes'),
        _choice(state.language, 'not sure allergies', 'Not sure'),
      ],
      nextLabel: _localizer.t(state.language, 'continue'),
      onNext: _controller.nextQuestion,
    );
  }

  Widget _healthChangesStep(
    BuildContext context,
    SacaFlowState state,
    SacaPlatformStyle style,
  ) {
    return _singleChoiceQuestion(
      state: state,
      style: style,
      title: _localizer.t(state.language, 'healthChangesTitle'),
      subtitle: _localizer.t(state.language, 'healthChangesSubtitle'),
      questionId: 'health_changes',
      choices: [
        _choice(state.language, 'no recent health change', 'No change'),
        _choice(
            state.language, 'sick contact or travel', 'Sick contact or travel'),
        _choice(
            state.language, 'sleep or stress change', 'Sleep or stress change'),
        _choice(state.language, 'not sure health change', 'Not sure'),
      ],
      nextLabel: _localizer.t(state.language, 'analyse'),
      onNext: _controller.analyse,
    );
  }

  Widget _singleChoiceQuestion({
    required SacaFlowState state,
    required SacaPlatformStyle style,
    required String title,
    required String subtitle,
    required String questionId,
    required List<_Choice> choices,
    required String nextLabel,
    required VoidCallback onNext,
  }) {
    final selected = state.questionAnswers[questionId];

    return _wrapStep(
      style: style,
      state: state,
      children: [
        _title(style, title, subtitle),
        const SizedBox(height: 18),
        for (final choice in choices) ...[
          _AnswerButton(
            label: choice.label,
            selected: selected == choice.value,
            onPressed: () => _controller.answerQuestion(
              questionId,
              choice.value,
            ),
          ),
          const SizedBox(height: 10),
        ],
        const SizedBox(height: 18),
        SacaPrimaryButton(
          label: nextLabel,
          icon: questionId == 'health_changes'
              ? CupertinoIcons.waveform_path_ecg
              : CupertinoIcons.arrow_right_circle,
          filled: true,
          onPressed: selected == null ? null : onNext,
        ),
      ],
    );
  }

  _Choice _choice(SacaLanguage? language, String value, String englishLabel) {
    return _Choice(
        value, _localizer.choiceLabel(language, value, englishLabel));
  }

  Widget _analysingStep(
    BuildContext context,
    SacaFlowState state,
    SacaPlatformStyle style,
  ) {
    return _wrapStep(
      style: style,
      state: state,
      showBack: false,
      children: [
        const SizedBox(height: 40),
        if (style == SacaPlatformStyle.androidMobile)
          const SacaLogoHeader(compact: true),
        const SizedBox(height: 18),
        const CupertinoActivityIndicator(radius: 14),
        const SizedBox(height: 16),
        _title(
          style,
          _localizer.t(state.language, 'analysingTitle'),
          _localizer.t(state.language, 'analysingSubtitle'),
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _resultStep(
    BuildContext context,
    SacaFlowState state,
    SacaPlatformStyle style,
  ) {
    final result = state.analysisResult;
    if (result == null) {
      return _wrapStep(
        style: style,
        state: state,
        children: [
          _title(
            style,
            _localizer.t(state.language, 'noResultTitle'),
            _localizer.t(state.language, 'noResultSubtitle'),
          ),
          const SizedBox(height: 28),
          SacaPrimaryButton(
            label: _localizer.t(state.language, 'back'),
            icon: CupertinoIcons.arrow_left_circle,
            onPressed: _controller.goBack,
          ),
        ],
      );
    }

    return _wrapStep(
      style: style,
      state: state,
      showBack: false,
      children: [
        _title(
          style,
          _localizer.t(state.language, 'resultTitle'),
          _localizer.t(state.language, 'resultSubtitle'),
        ),
        const SizedBox(height: 12),
        _ResultPanel(
          result: result,
          language: state.language,
          localizer: _localizer,
        ),
        const SizedBox(height: 28),
        SacaPrimaryButton(
          label: _localizer.t(state.language, 'finish'),
          icon: CupertinoIcons.check_mark_circled,
          filled: true,
          onPressed: _controller.reset,
        ),
        const SizedBox(height: 10),
        SacaPrimaryButton(
          label: _localizer.t(state.language, 'startAgain'),
          icon: CupertinoIcons.refresh,
          onPressed: _controller.reset,
        ),
      ],
    );
  }

  Widget _wrapStep({
    required SacaPlatformStyle style,
    required SacaFlowState state,
    required List<Widget> children,
    bool showBack = true,
  }) {
    return _StepLayout(
      style: style,
      state: state,
      showBack: showBack,
      onBack: _canGoBack(state.step) ? _controller.goBack : null,
      onInfo: () => _showPrototypeInfo(context),
      localizer: _localizer,
      children: children,
    );
  }

  Widget _title(SacaPlatformStyle _, String title, String subtitle) {
    return _StepTitle(
      title: title,
      subtitle: subtitle,
      align: TextAlign.center,
    );
  }

  Widget _visualStageHeader({
    required SacaLanguage? language,
    required _VisualInputStage current,
  }) {
    final stages = [
      (
        _VisualInputStage.symptoms,
        _localizer.t(language, 'visualStageSymptoms')
      ),
      (_VisualInputStage.front, _localizer.t(language, 'visualStageFront')),
      (_VisualInputStage.back, _localizer.t(language, 'visualStageBack')),
    ];

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        children: [
          Row(
            children: [
              for (var index = 0; index < stages.length; index++) ...[
                Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    height: 6,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(99),
                      gradient: stages[index].$1.index <= current.index
                          ? const LinearGradient(
                              colors: [
                                SacaTheme.accent,
                                SacaTheme.selectedBorder,
                              ],
                            )
                          : const LinearGradient(
                              colors: [
                                Color(0xFFF0E5E2),
                                Color(0xFFE9F0F2),
                              ],
                            ),
                    ),
                  ),
                ),
                if (index != stages.length - 1) const SizedBox(width: 8),
              ],
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              for (var index = 0; index < stages.length; index++) ...[
                Expanded(
                  child: Text(
                    stages[index].$2,
                    textAlign: TextAlign.center,
                    style: SacaTheme.small.copyWith(
                      color: stages[index].$1 == current
                          ? SacaTheme.text
                          : SacaTheme.mutedText,
                    ),
                  ),
                ),
                if (index != stages.length - 1) const SizedBox(width: 8),
              ],
            ],
          ),
        ],
      ),
    );
  }

  bool _canGoBack(SacaStep step) {
    return step != SacaStep.splash &&
        step != SacaStep.language &&
        step != SacaStep.analysing &&
        step != SacaStep.result;
  }

  void _showPrototypeInfo(BuildContext context) {
    final language = _controller.state.language;
    showCupertinoDialog<void>(
      context: context,
      builder: (dialogContext) {
        return CupertinoAlertDialog(
          title: Text(_localizer.t(language, 'infoTitle')),
          content: Text(_localizer.t(language, 'infoContent')),
          actions: [
            CupertinoDialogAction(
              child: Text(_localizer.t(language, 'ok')),
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
          ],
        );
      },
    );
  }
}

class _MobileShell extends StatelessWidget {
  const _MobileShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            child: Center(
              child: ConstrainedBox(
                constraints:
                    const BoxConstraints(maxWidth: SacaTheme.phoneWidth),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DesktopShell extends StatelessWidget {
  const _DesktopShell({
    required this.state,
    required this.localizer,
    required this.child,
    required this.onInfo,
    this.onBack,
  });

  final SacaFlowState state;
  final SacaLocalizer localizer;
  final Widget child;
  final VoidCallback? onBack;
  final VoidCallback onInfo;

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () {
          onBack?.call();
        },
      },
      child: FocusTraversalGroup(
        child: DecoratedBox(
          key: const ValueKey('windowsFramelessShell'),
          decoration: const BoxDecoration(color: SacaTheme.background),
          child: Stack(
            fit: StackFit.expand,
            children: [
              ClipRRect(
                key: const ValueKey('windowsRoundedShellClip'),
                borderRadius: BorderRadius.circular(18),
                child: Column(
                  children: [
                    _DesktopToolbar(
                      state: state,
                      localizer: localizer,
                      onBack: onBack,
                      onInfo: onInfo,
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(36, 30, 36, 40),
                          child: Center(
                            child: ConstrainedBox(
                              key: const ValueKey('windowsContentColumn'),
                              constraints: const BoxConstraints(maxWidth: 760),
                              child: child,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const _DesktopResizeOverlay(),
            ],
          ),
        ),
      ),
    );
  }
}

class _DesktopResizeOverlay extends StatelessWidget {
  const _DesktopResizeOverlay();

  static const double _edge = 8;
  static const double _corner = 18;

  @override
  Widget build(BuildContext context) {
    return const Stack(
      key: ValueKey('windowsResizeOverlay'),
      fit: StackFit.expand,
      children: [
        Positioned(
          top: 0,
          left: _corner,
          right: _corner,
          height: _edge,
          child: _DesktopResizeZone(
            edge: DesktopResizeEdge.top,
            cursor: SystemMouseCursors.resizeUpDown,
          ),
        ),
        Positioned(
          right: 0,
          top: _corner,
          bottom: _corner,
          width: _edge,
          child: _DesktopResizeZone(
            edge: DesktopResizeEdge.right,
            cursor: SystemMouseCursors.resizeLeftRight,
          ),
        ),
        Positioned(
          bottom: 0,
          left: _corner,
          right: _corner,
          height: _edge,
          child: _DesktopResizeZone(
            edge: DesktopResizeEdge.bottom,
            cursor: SystemMouseCursors.resizeUpDown,
          ),
        ),
        Positioned(
          left: 0,
          top: _corner,
          bottom: _corner,
          width: _edge,
          child: _DesktopResizeZone(
            edge: DesktopResizeEdge.left,
            cursor: SystemMouseCursors.resizeLeftRight,
          ),
        ),
        Positioned(
          top: 0,
          left: 0,
          width: _corner,
          height: _corner,
          child: _DesktopResizeZone(
            edge: DesktopResizeEdge.topLeft,
            cursor: SystemMouseCursors.resizeUpLeftDownRight,
          ),
        ),
        Positioned(
          top: 0,
          right: 0,
          width: _corner,
          height: _corner,
          child: _DesktopResizeZone(
            edge: DesktopResizeEdge.topRight,
            cursor: SystemMouseCursors.resizeUpRightDownLeft,
          ),
        ),
        Positioned(
          bottom: 0,
          right: 0,
          width: _corner,
          height: _corner,
          child: _DesktopResizeZone(
            edge: DesktopResizeEdge.bottomRight,
            cursor: SystemMouseCursors.resizeUpLeftDownRight,
          ),
        ),
        Positioned(
          bottom: 0,
          left: 0,
          width: _corner,
          height: _corner,
          child: _DesktopResizeZone(
            edge: DesktopResizeEdge.bottomLeft,
            cursor: SystemMouseCursors.resizeUpRightDownLeft,
          ),
        ),
      ],
    );
  }
}

class _DesktopResizeZone extends StatelessWidget {
  const _DesktopResizeZone({
    required this.edge,
    required this.cursor,
  });

  final DesktopResizeEdge edge;
  final MouseCursor cursor;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: cursor,
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) => resizeDesktopWindow(edge),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _DesktopToolbar extends StatelessWidget {
  const _DesktopToolbar({
    required this.state,
    required this.localizer,
    required this.onInfo,
    this.onBack,
  });

  final SacaFlowState state;
  final SacaLocalizer localizer;
  final VoidCallback? onBack;
  final VoidCallback onInfo;

  @override
  Widget build(BuildContext context) {
    final language = switch (state.language) {
      SacaLanguage.gurindji => 'Gurindji',
      SacaLanguage.english => 'English',
      null => localizer.t(null, 'notSelected'),
    };

    return DecoratedBox(
      key: const ValueKey('windowsCustomTitleBar'),
      decoration: const BoxDecoration(
        color: Color(0xFFFFFAF9),
        border: Border(bottom: BorderSide(color: Color(0xFFE8DEDC))),
      ),
      child: SizedBox(
        height: 64,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Row(
            children: [
              CupertinoButton(
                padding: EdgeInsets.zero,
                minimumSize: const Size.square(44),
                onPressed: onBack,
                child: Icon(
                  CupertinoIcons.chevron_left,
                  color: onBack == null ? SacaTheme.border : SacaTheme.text,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DesktopDragArea(
                  child: SizedBox(
                    key: const ValueKey('windowsDragRegion'),
                    height: double.infinity,
                    child: Row(
                      children: [
                        Text(
                          'SACA',
                          style: SacaTheme.logoText.copyWith(fontSize: 28),
                        ),
                        const SizedBox(width: 14),
                        _StatusPill(
                          label: localizer.t(state.language, 'offlineReady'),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            '${localizer.t(state.language, 'languageStatus')}: '
                            '$language',
                            textAlign: TextAlign.right,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                            style: SacaTheme.small,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              CupertinoButton(
                padding: EdgeInsets.zero,
                minimumSize: const Size.square(44),
                onPressed: onInfo,
                child: const Icon(
                  CupertinoIcons.info,
                  color: SacaTheme.text,
                  size: 22,
                ),
              ),
              const _DesktopWindowControls(),
            ],
          ),
        ),
      ),
    );
  }
}

class _DesktopWindowControls extends StatelessWidget {
  const _DesktopWindowControls();

  @override
  Widget build(BuildContext context) {
    return const Row(
      key: ValueKey('windowsWindowControls'),
      children: [
        _DesktopWindowButton(
          icon: CupertinoIcons.minus,
          semanticLabel: 'Minimize window',
          onPressed: minimizeDesktopWindow,
        ),
        _DesktopWindowButton(
          icon: CupertinoIcons.square_on_square,
          semanticLabel: 'Maximize window',
          onPressed: toggleMaximizeDesktopWindow,
        ),
        _DesktopWindowButton(
          icon: CupertinoIcons.xmark,
          semanticLabel: 'Close window',
          destructive: true,
          onPressed: closeDesktopWindow,
        ),
      ],
    );
  }
}

class _DesktopWindowButton extends StatelessWidget {
  const _DesktopWindowButton({
    required this.icon,
    required this.semanticLabel,
    required this.onPressed,
    this.destructive = false,
  });

  final IconData icon;
  final String semanticLabel;
  final Future<void> Function() onPressed;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: const Size(46, 44),
      onPressed: onPressed,
      child: Semantics(
        label: semanticLabel,
        button: true,
        child: Icon(
          icon,
          color: destructive ? SacaTheme.emergency : SacaTheme.text,
          size: 18,
        ),
      ),
    );
  }
}

class _ShellBackdrop extends StatelessWidget {
  const _ShellBackdrop();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: SacaTheme.shellGradient),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Align(
            alignment: Alignment.topCenter,
            child: Container(
              height: 220,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x26A9D5E7),
                    Color(0x00A9D5E7),
                  ],
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              height: 180,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x00F3D7CF),
                    Color(0x2AF3D7CF),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepLayout extends StatelessWidget {
  const _StepLayout({
    required this.style,
    required this.state,
    required this.localizer,
    required this.children,
    this.onBack,
    this.onInfo,
    this.showBack = true,
  });

  final SacaPlatformStyle style;
  final SacaFlowState state;
  final SacaLocalizer localizer;
  final List<Widget> children;
  final VoidCallback? onBack;
  final VoidCallback? onInfo;
  final bool showBack;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (style == SacaPlatformStyle.androidMobile)
          _MobileTopBar(
            canBack: showBack && onBack != null,
            onBack: onBack,
            onInfo: onInfo,
          ),
        if (state.errorMessage != null) ...[
          const SizedBox(height: 8),
          SacaErrorBanner(
            message:
                localizer.errorMessage(state.language, state.errorMessage!),
          ),
          const SizedBox(height: 12),
        ],
        ...children,
      ],
    );
  }
}

class _MobileTopBar extends StatelessWidget {
  const _MobileTopBar({
    required this.canBack,
    this.onBack,
    this.onInfo,
  });

  final bool canBack;
  final VoidCallback? onBack;
  final VoidCallback? onInfo;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: Row(
        children: [
          SizedBox(
            width: 48,
            child: canBack
                ? CupertinoButton(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size.square(44),
                    onPressed: onBack,
                    child: const Icon(
                      CupertinoIcons.chevron_left,
                      color: SacaTheme.text,
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          const Spacer(),
          CupertinoButton(
            padding: EdgeInsets.zero,
            minimumSize: const Size.square(44),
            onPressed: onInfo,
            child: const Icon(
              CupertinoIcons.info,
              color: SacaTheme.text,
              size: 24,
            ),
          ),
        ],
      ),
    );
  }
}

class _SplashStep extends StatelessWidget {
  const _SplashStep({required this.subtitle});

  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(height: 60),
        const SacaLogoHeader(),
        const SizedBox(height: 12),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: SacaTheme.body,
        ),
        const SizedBox(height: 60),
      ],
    );
  }
}

class _StepTitle extends StatelessWidget {
  const _StepTitle({
    required this.title,
    required this.subtitle,
    required this.align,
  });

  final String title;
  final String subtitle;
  final TextAlign align;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: align == TextAlign.left
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.stretch,
      children: [
        Text(title, textAlign: align, style: SacaTheme.title),
        const SizedBox(height: 8),
        Text(
          subtitle,
          textAlign: align,
          style: SacaTheme.body.copyWith(color: SacaTheme.mutedText),
        ),
      ],
    );
  }
}

class _Footnote extends StatelessWidget {
  const _Footnote({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text, textAlign: TextAlign.center, style: SacaTheme.small);
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: SacaTheme.selected,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: SacaTheme.selectedBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child:
            Text(label, style: SacaTheme.small.copyWith(color: SacaTheme.text)),
      ),
    );
  }
}

class _VoiceLoadingOverlay extends StatelessWidget {
  const _VoiceLoadingOverlay({
    required this.visible,
    required this.title,
    required this.subtitle,
  });

  final bool visible;
  final String? title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );
          final scale = Tween<double>(begin: 0.97, end: 1).animate(curved);
          final slide = Tween<Offset>(
            begin: const Offset(0, 0.02),
            end: Offset.zero,
          ).animate(curved);
          return FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: slide,
              child: ScaleTransition(scale: scale, child: child),
            ),
          );
        },
        child: visible
            ? Stack(
                key: const ValueKey('voiceLoadingOverlay'),
                fit: StackFit.expand,
                children: [
                  const ColoredBox(color: Color(0x22000000)),
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 280),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: SacaTheme.surfaceGradient,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: SacaTheme.selectedBorder),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x18000000),
                              blurRadius: 24,
                              offset: Offset(0, 12),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const CupertinoActivityIndicator(radius: 14),
                              if (title != null) ...[
                                const SizedBox(height: 14),
                                Text(
                                  title!,
                                  key: const ValueKey('voiceLoadingTitle'),
                                  textAlign: TextAlign.center,
                                  style: SacaTheme.body.copyWith(
                                    color: SacaTheme.text,
                                  ),
                                ),
                              ],
                              if (subtitle != null) ...[
                                const SizedBox(height: 6),
                                Text(
                                  subtitle!,
                                  key: const ValueKey('voiceLoadingSubtitle'),
                                  textAlign: TextAlign.center,
                                  style: SacaTheme.small,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              )
            : const SizedBox.shrink(),
      ),
    );
  }
}

class _Choice {
  const _Choice(this.value, this.label);

  final String value;
  final String label;
}

class _AnswerButton extends StatelessWidget {
  const _AnswerButton({
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SacaOptionButton(
      label: label,
      selected: selected,
      icon: selected ? CupertinoIcons.check_mark_circled_solid : null,
      onPressed: onPressed,
    );
  }
}

class _SelectedSummary extends StatelessWidget {
  const _SelectedSummary({
    required this.title,
    required this.emptyText,
    required this.values,
  });

  final String title;
  final String emptyText;
  final List<String> values;

  @override
  Widget build(BuildContext context) {
    final text = values.isEmpty ? emptyText : values.join(', ');
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: SacaTheme.surfaceGradient,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: SacaTheme.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: SacaTheme.small.copyWith(color: SacaTheme.text),
            ),
            const SizedBox(height: 6),
            Text(text, style: SacaTheme.body),
          ],
        ),
      ),
    );
  }
}

class _SacaTextField extends StatefulWidget {
  const _SacaTextField({
    super.key,
    required this.value,
    required this.placeholder,
    required this.onChanged,
    required this.minLines,
    required this.maxLines,
  });

  final String value;
  final String placeholder;
  final ValueChanged<String> onChanged;
  final int minLines;
  final int maxLines;

  @override
  State<_SacaTextField> createState() => _SacaTextFieldState();
}

class _SacaTextFieldState extends State<_SacaTextField> {
  late final TextEditingController _textController;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(covariant _SacaTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != _textController.text) {
      _textController.value = TextEditingValue(
        text: widget.value,
        selection: TextSelection.collapsed(offset: widget.value.length),
      );
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoTextField(
      controller: _textController,
      minLines: widget.minLines,
      maxLines: widget.maxLines,
      placeholder: widget.placeholder,
      padding: const EdgeInsets.all(16),
      onChanged: widget.onChanged,
      style: SacaTheme.body,
      placeholderStyle: SacaTheme.body.copyWith(color: SacaTheme.mutedText),
      decoration: BoxDecoration(
        gradient: SacaTheme.surfaceGradient,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: SacaTheme.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
    );
  }
}

class _ResultPanel extends StatelessWidget {
  const _ResultPanel({
    required this.result,
    required this.language,
    required this.localizer,
  });

  final AnalysisResult result;
  final SacaLanguage? language;
  final SacaLocalizer localizer;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: SacaTheme.surfaceGradient,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: result.isEmergency ? SacaTheme.emergency : SacaTheme.border,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x16000000),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (result.isEmergency) ...[
              DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0x14D92D20),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0x33D92D20)),
                ),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Text(
                    localizer.t(language, 'call000Now'),
                    textAlign: TextAlign.center,
                    style: SacaTheme.title.copyWith(color: SacaTheme.emergency),
                  ),
                ),
              ),
              const SizedBox(height: 14),
            ],
            Text(
              localizer.t(language, 'possiblePattern'),
              textAlign: TextAlign.center,
              style: SacaTheme.small,
            ),
            const SizedBox(height: 4),
            Text(
              localizer.resultDiseaseLabel(language, result.disease),
              textAlign: TextAlign.center,
              style: SacaTheme.title,
            ),
            const SizedBox(height: 18),
            _SeverityMeter(
              severity: result.severity,
              language: language,
              localizer: localizer,
            ),
            const SizedBox(height: 18),
            for (final item in localizer.guidance(language, result))
              _GuidanceLine(text: item),
            const SizedBox(height: 10),
            Text(
              localizer.disclaimer(language, result.disclaimer),
              textAlign: TextAlign.center,
              style: SacaTheme.small,
            ),
          ],
        ),
      ),
    );
  }
}

class _GuidanceLine extends StatelessWidget {
  const _GuidanceLine({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 3),
            child: Icon(
              CupertinoIcons.check_mark_circled,
              size: 18,
              color: SacaTheme.text,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: SacaTheme.body)),
        ],
      ),
    );
  }
}

class _SeverityMeter extends StatelessWidget {
  const _SeverityMeter({
    required this.severity,
    required this.language,
    required this.localizer,
  });

  final SeverityLevel severity;
  final SacaLanguage? language;
  final SacaLocalizer localizer;

  @override
  Widget build(BuildContext context) {
    final label = localizer.severityLabel(language, severity);
    final position = switch (severity) {
      SeverityLevel.mild => 0.18,
      SeverityLevel.moderate => 0.44,
      SeverityLevel.severe => 0.68,
      SeverityLevel.emergency => 0.92,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${localizer.t(language, 'severity')}: $label',
          textAlign: TextAlign.center,
          style: SacaTheme.body,
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 34,
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Stack(
                alignment: Alignment.centerLeft,
                children: [
                  Positioned.fill(
                    top: 12,
                    bottom: 12,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        gradient: const LinearGradient(
                          colors: [
                            SacaTheme.safe,
                            SacaTheme.warning,
                            SacaTheme.emergency,
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: (constraints.maxWidth - 18) * position,
                    child: const DecoratedBox(
                      decoration: BoxDecoration(
                        color: SacaTheme.text,
                        shape: BoxShape.circle,
                      ),
                      child: SizedBox(width: 18, height: 18),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}
