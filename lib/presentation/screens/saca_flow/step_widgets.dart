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
                          icon: _symptomIconFor(symptom.id),
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
                        icon: CupertinoIcons.ellipsis_circle,
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
                    onPressed: () =>
                        _setVisualStage(_VisualInputStage.symptoms),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SacaPrimaryButton(
                    key: const ValueKey('visualFrontContinueButton'),
                    label: _localizer.t(state.language, 'continue'),
                    icon: CupertinoIcons.arrow_right_circle,
                    filled: true,
                    onPressed: () => _setVisualStage(_VisualInputStage.back),
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
                    onPressed: () => _setVisualStage(_VisualInputStage.front),
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
        _voiceQuestionControls(state),
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
    final suggestedIds = state.suggestedRelatedSymptomIds.toSet();
    final orderedSymptoms = <Symptom>[
      for (final id in state.suggestedRelatedSymptomIds)
        if (SacaFlowState.relatedSymptoms.any((symptom) => symptom.id == id))
          SacaFlowState.relatedSymptoms
              .firstWhere((symptom) => symptom.id == id),
      for (final symptom in SacaFlowState.relatedSymptoms)
        if (!suggestedIds.contains(symptom.id)) symptom,
    ];

    return _wrapStep(
      style: style,
      state: state,
      children: [
        _title(
          style,
          _localizer.t(state.language, 'relatedTitle'),
          _localizer.t(state.language, 'relatedSubtitle'),
        ),
        if (suggestedIds.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            'Suggested from your first symptom',
            style: TextStyle(
              color: SacaTheme.mutedText,
              fontSize: style == SacaPlatformStyle.windowsDesktop ? 15 : 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
        _voiceQuestionControls(state),
        const SizedBox(height: 18),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final symptom in orderedSymptoms)
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
        _voiceQuestionControls(state),
        const SizedBox(height: 18),
        _singleChoiceOptionsGrid(
          state: state,
          style: style,
          questionId: questionId,
          selected: selected,
          choices: choices,
        ),
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

  Widget _singleChoiceOptionsGrid({
    required SacaFlowState state,
    required SacaPlatformStyle style,
    required String questionId,
    required String? selected,
    required List<_Choice> choices,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final useTwoColumns = style == SacaPlatformStyle.windowsDesktop &&
            constraints.maxWidth >= 920 &&
            choices.length > 2;
        final spacing = useTwoColumns ? 12.0 : 10.0;
        final itemWidth = useTwoColumns
            ? (constraints.maxWidth - spacing) / 2
            : constraints.maxWidth;

        return Wrap(
          key: const ValueKey('singleChoiceOptionsGrid'),
          spacing: spacing,
          runSpacing: 10,
          children: [
            for (final choice in choices)
              SizedBox(
                width: itemWidth,
                child: _AnswerButton(
                  label: choice.label,
                  selected: selected == choice.value,
                  onPressed: () => _controller.answerQuestion(
                    questionId,
                    choice.value,
                  ),
                ),
              ),
          ],
        );
      },
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

  Widget _voiceQuestionControls(SacaFlowState state) {
    if (state.inputMethod != InputMethod.voice) {
      return const SizedBox.shrink();
    }

    final heard = state.voiceAnswerTranscript.trim();
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SacaPrimaryButton(
            key: const ValueKey('voiceQuestionRecordButton'),
            label: state.isRecording
                ? _localizer.t(state.language, 'stopVoiceAnswer')
                : _localizer.t(state.language, 'answerByVoice'),
            icon: state.isRecording
                ? CupertinoIcons.stop_circle
                : CupertinoIcons.mic,
            onPressed: state.isBusy
                ? null
                : () {
                    if (state.isRecording) {
                      _controller.stopRecording();
                    } else {
                      _controller.startRecording();
                    }
                  },
          ),
          if (heard.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              '${_localizer.t(state.language, 'voiceAnswerHeard')} $heard',
              key: const ValueKey('voiceQuestionHeard'),
              textAlign: TextAlign.center,
              style: SacaTheme.small,
            ),
          ],
          if (!state.voiceAnswerMatched) ...[
            const SizedBox(height: 6),
            Text(
              _localizer.t(state.language, 'voiceAnswerNotMatched'),
              key: const ValueKey('voiceQuestionNotMatched'),
              textAlign: TextAlign.center,
              style: SacaTheme.small.copyWith(color: SacaTheme.emergency),
            ),
          ],
        ],
      ),
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

  IconData _symptomIconFor(String symptomId) {
    return switch (symptomId) {
      'headache' => CupertinoIcons.bandage,
      'fever' => CupertinoIcons.thermometer,
      'stomachache' => CupertinoIcons.circle_grid_hex,
      'sore_throat' => CupertinoIcons.waveform_path_ecg,
      'chest_pain' => CupertinoIcons.heart,
      'breathing_trouble' => CupertinoIcons.wind,
      'vomiting' => CupertinoIcons.drop,
      'bloating' => CupertinoIcons.circle,
      _ => CupertinoIcons.staroflife,
    };
  }
}

class _VisualSymptomCard extends StatelessWidget {
  const _VisualSymptomCard({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onPressed,
    this.secondaryLabel,
  });

  final String label;
  final String? secondaryLabel;
  final IconData icon;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: secondaryLabel == null ? label : '$label, $secondaryLabel',
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        minimumSize: const Size(
          SacaTheme.minTapTarget,
          SacaTheme.minTapTarget,
        ),
        onPressed: onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          constraints: const BoxConstraints(minHeight: 142),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: selected
                ? SacaTheme.selectedGradient
                : SacaTheme.surfaceGradient,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? SacaTheme.selectedBorder : SacaTheme.border,
              width: selected ? 2 : 1,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x12000000),
                blurRadius: 16,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: selected
                      ? const Color(0x268FC8DE)
                      : const Color(0x14D9D4D1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Icon(icon, size: 28, color: SacaTheme.text),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: SacaTheme.body.copyWith(fontWeight: FontWeight.w800),
              ),
              if (secondaryLabel != null) ...[
                const SizedBox(height: 4),
                Text(
                  secondaryLabel!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: SacaTheme.small,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
