part of '../saca_flow_screen.dart';

extension _SacaFlowStepWidgets on _SacaFlowScreenState {
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
      SacaStep.questionSkinDetails => _skinDetailsStep(context, state, style),
      SacaStep.questionMedication => _medicationStep(context, state, style),
      SacaStep.questionFood => _foodStep(context, state, style),
      SacaStep.questionAllergies => _allergiesStep(context, state, style),
      SacaStep.questionHealthChanges =>
        _healthChangesStep(context, state, style),
      SacaStep.reviewInformation => _reviewStep(context, state, style),
      SacaStep.settings => _settingsStep(context, state, style),
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
        const SacaLogoHeader(lift: 60),
        const _LanguageCarouselText(),
        const SizedBox(height: 20),
        SacaOptionButton(
          label: _localizer.t(SacaLanguage.english, 'languageEnglishLabel'),
          icon: CupertinoIcons.chat_bubble_text,
          selected: state.language == SacaLanguage.english,
          minHeight: 72,
          onPressed: () => _controller.selectLanguage(SacaLanguage.english),
        ),
        const SizedBox(height: 20),
        SacaOptionButton(
          label: _localizer.t(SacaLanguage.gurindji, 'languageGurindjiLabel'),
          icon: CupertinoIcons.chat_bubble_text_fill,
          selected: state.language == SacaLanguage.gurindji,
          minHeight: 72,
          onPressed: () => _controller.selectLanguage(SacaLanguage.gurindji),
        ),
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
            _setVisualStage(_VisualInputStage.symptoms);
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
    final canContinue = !state.isBusy;
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
        _RecordingButton(
          isRecording: state.isRecording,
          label: state.isRecording
              ? _localizer.t(state.language, 'stop')
              : _localizer.t(state.language, 'record'),
          onPressed: state.isBusy
              ? null
              : () {
                  state.isRecording
                      ? _controller.stopRecording()
                      : _controller.startRecording();
                },
        ),
        const SizedBox(height: 18),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            _localizer.t(state.language, 'transcriptPreview'),
            style: SacaTheme.small.copyWith(
              color: SacaThemeColors.of(context).onSurfaceMuted,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(height: 8),
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
        if (state.voiceDraftNotice != null) ...[
          const SizedBox(height: 8),
          _VoiceDraftNotice(
            message: _localizer.t(state.language, state.voiceDraftNotice!),
          ),
        ],
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
    final canContinue = !state.isBusy;

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
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 620 ? 3 : 2;
                final cardWidth =
                    (constraints.maxWidth - (columns - 1) * 12) / columns;

                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final symptom in SacaFlowState.symptoms)
                      SizedBox(
                        width: cardWidth,
                        child: _VisualSymptomCard(
                          label: _localizer.symptomLabel(
                            state.language,
                            symptom,
                          ),
                          secondaryLabel:
                              state.language == SacaLanguage.gurindji
                                  ? symptom.label
                                  : null,
                          imagePath: _symptomImageFor(symptom.id),
                          selected:
                              state.selectedSymptomIds.contains(symptom.id),
                          onPressed: () =>
                              _controller.toggleSymptom(symptom.id),
                        ),
                      ),
                    SizedBox(
                      width: cardWidth,
                      child: _VisualSymptomCard(
                        label: _localizer.t(state.language, 'visualOtherTitle'),
                        secondaryLabel:
                            _localizer.t(state.language, 'visualOtherSubtitle'),
                        imagePath: 'assets/images/other.png',
                        selected: false,
                        onPressed: () =>
                            _controller.chooseInputMethod(InputMethod.text),
                      ),
                    ),
                  ],
                );
              },
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
              onPressed: hasSelection
                  ? () => _setVisualStage(_VisualInputStage.front)
                  : null,
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
            SizedBox(height: _visualBodySpacing(context)),
            _visualBodySelectionLayout(
              state: state,
              view: BodyView.front,
              selectedLabels: selectedLabels,
              backButtonKey: const ValueKey('visualFrontBackButton'),
              continueButtonKey: const ValueKey('visualFrontContinueButton'),
              backLabel: _localizer.t(state.language, 'back'),
              continueLabel: _visualStageHasSelection(state, BodyView.front)
                  ? _localizer.t(state.language, 'continue')
                  : _localizer.t(state.language, 'skip'),
              onBack: () => _setVisualStage(_VisualInputStage.symptoms),
              onContinue: () => _setVisualStage(_VisualInputStage.back),
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
            SizedBox(height: _visualBodySpacing(context)),
            _visualBodySelectionLayout(
              state: state,
              view: BodyView.back,
              selectedLabels: selectedLabels,
              backButtonKey: const ValueKey('visualBackBackButton'),
              continueButtonKey: const ValueKey('visualBackContinueButton'),
              backLabel: _localizer.t(state.language, 'back'),
              continueLabel: _visualStageHasSelection(state, BodyView.back)
                  ? _localizer.t(state.language, 'continue')
                  : _localizer.t(state.language, 'skip'),
              onBack: () => _setVisualStage(_VisualInputStage.front),
              onContinue: hasSelection ? _controller.continueFromInput : null,
            ),
          ],
        ),
    };
  }

  Widget _visualBodySelectionLayout({
    required SacaFlowState state,
    required BodyView view,
    required List<String> selectedLabels,
    required Key backButtonKey,
    required Key continueButtonKey,
    required String backLabel,
    required String continueLabel,
    required VoidCallback onBack,
    required VoidCallback? onContinue,
  }) {
    Widget diagram({required double maxWidth, required double maxHeight}) {
      const diagramAspectRatio = 0.92;
      final fittedWidth =
          maxWidth.clamp(0.0, maxHeight * diagramAspectRatio).toDouble();
      final fittedHeight =
          maxHeight.clamp(0.0, fittedWidth / diagramAspectRatio).toDouble();
      return Center(
        child: SizedBox(
          key: const ValueKey('visualBodyDiagramFrame'),
          width: fittedWidth,
          height: fittedHeight,
          child: BodyDiagram(
            view: view,
            selectedIds: state.selectedBodyAreaIds,
            onToggle: _controller.toggleBodyArea,
            labelForArea: (area) => _localizer.bodyAreaLabel(
              state.language,
              area,
            ),
            semanticsPrefix: _localizer.t(state.language, 'bodyAreaSemantic'),
          ),
        ),
      );
    }

    final sidePanel = _visualBodySidePanel(
      state: state,
      selectedLabels: selectedLabels,
      backButtonKey: backButtonKey,
      continueButtonKey: continueButtonKey,
      backLabel: backLabel,
      continueLabel: continueLabel,
      onBack: onBack,
      onContinue: onContinue,
    );

    return _ResponsiveVisualBodySelectionLayout(
      diagramBuilder: diagram,
      sidePanel: sidePanel,
    );
  }

  double _visualBodySpacing(BuildContext context) {
    return MediaQuery.sizeOf(context).height < 820 ? 8 : 18;
  }

  Widget _visualBodySidePanel({
    required SacaFlowState state,
    required List<String> selectedLabels,
    required Key backButtonKey,
    required Key continueButtonKey,
    required String backLabel,
    required String continueLabel,
    required VoidCallback onBack,
    required VoidCallback? onContinue,
  }) {
    final compact = MediaQuery.sizeOf(context).height < 820;
    return Column(
      key: const ValueKey('visualBodySidePanel'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        compact
            ? _CompactSelectedSummary(
                title: _localizer.t(state.language, 'selected'),
                emptyText: _localizer.t(state.language, 'selectedEmpty'),
                values: selectedLabels,
              )
            : _SelectedSummary(
                title: _localizer.t(state.language, 'selected'),
                emptyText: _localizer.t(state.language, 'selectedEmpty'),
                values: selectedLabels,
              ),
        SizedBox(height: compact ? 6 : 22),
        Row(
          children: [
            Expanded(
              child: SacaPrimaryButton(
                key: backButtonKey,
                label: backLabel,
                icon: CupertinoIcons.arrow_left_circle,
                onPressed: onBack,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SacaPrimaryButton(
                key: continueButtonKey,
                label: continueLabel,
                icon: CupertinoIcons.arrow_right_circle,
                filled: true,
                onPressed: onContinue,
              ),
            ),
          ],
        ),
      ],
    );
  }

  _Choice _choice(SacaLanguage? language, String value, String englishLabel) {
    return _Choice(
      value,
      _localizer.choiceLabel(language, value, englishLabel),
    );
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
          label: _localizer.t(state.language, 'startAgain'),
          icon: CupertinoIcons.refresh,
          filled: true,
          onPressed: _controller.startOverKeepLanguage,
        ),
        const SizedBox(height: 10),
        SacaPrimaryButton(
          label: _localizer.t(state.language, 'finish'),
          icon: CupertinoIcons.check_mark_circled,
          onPressed: _controller.finish,
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
      onBack: state.step == SacaStep.settings
          ? _controller.goBack
          : _canGoBack(state.step)
              ? _controller.goBack
              : null,
      onInfo: () => _showPrototypeInfo(context),
      onSettings: _showSettings,
      localizer: _localizer,
      children: children,
    );
  }

  Widget _voiceQuestionControls(SacaFlowState state) {
    return _VoiceQuestionControls(
      state: state,
      localizer: _localizer,
      onStartRecording: _controller.startRecording,
      onStopRecording: _controller.stopRecording,
    );
  }

  Widget _title(SacaPlatformStyle style, String title, String subtitle) {
    final lift = style == SacaPlatformStyle.windowsDesktop ? 15.0 : 0.0;

    return Transform.translate(
      offset: Offset(0, -lift),
      child: _StepTitle(
        title: title,
        subtitle: subtitle,
        align: TextAlign.center,
      ),
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
                    curve: Curves.easeOutCubic,
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
        step != SacaStep.settings &&
        step != SacaStep.analysing &&
        step != SacaStep.result;
  }

  void _showSettings() {
    _controller.showSettings();
  }

  void _closeSettings() {
    _controller.goBack();
  }

  void _showPrototypeInfo(BuildContext context) {
    final language = _controller.state.language;

    showCupertinoDialog<void>(
      context: context,
      builder: (dialogContext) {
        return _SacaMessageDialog(
          title: _localizer.t(language, 'infoTitle'),
          message: _localizer.t(language, 'infoContent'),
          actionLabel: _localizer.t(language, 'ok'),
          onAction: () => Navigator.of(dialogContext).pop(),
        );
      },
    );
  }

  String _symptomImageFor(String symptomId) {
    return switch (symptomId) {
      'headache' => 'assets/images/headache.png',
      'fever' => 'assets/images/fever.png',
      'stomachache' => 'assets/images/stomachache.png',
      'sore_throat' => 'assets/images/sore_throat.png',
      'chest_pain' => 'assets/images/chest_pain.png',
      'breathing_trouble' => 'assets/images/breathing_trouble.png',
      'vomiting' => 'assets/images/vomiting.png',
      'bloating' => 'assets/images/bloating.png',
      'cough' => 'assets/images/cough.png',
      'skin_itch' => 'assets/images/skin_itch.png',
      'sneezing' => 'assets/images/sneeze.png',
      _ => 'assets/images/cough.png',
    };
  }

  bool _visualStageHasSelection(SacaFlowState state, BodyView view) {
    return SacaFlowState.bodyAreas
        .where((area) => area.view == view)
        .any((area) => state.selectedBodyAreaIds.contains(area.id));
  }
}
