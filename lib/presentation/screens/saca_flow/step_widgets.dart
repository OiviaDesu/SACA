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
        const SacaLogoHeader(),
        const _LanguageCarouselText(),
        const SizedBox(height: 20),
        SacaOptionButton(
          label: _localizer.t(SacaLanguage.english, 'languageEnglishLabel'),
          icon: CupertinoIcons.chat_bubble_text,
          selected: state.language == SacaLanguage.english,
          onPressed: () => _controller.selectLanguage(SacaLanguage.english),
        ),
        const SizedBox(height: 12),
        SacaOptionButton(
          label: _localizer.t(SacaLanguage.gurindji, 'languageGurindjiLabel'),
          icon: CupertinoIcons.chat_bubble_text_fill,
          selected: state.language == SacaLanguage.gurindji,
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
        _RecordingButton(
          isRecording: state.isRecording,
          label: state.isRecording
              ? _localizer.t(state.language, 'stopRecording')
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
                        imagePath: 'assets/Images/Cough.png',
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
                    label: _visualStageHasSelection(state, BodyView.front)
                        ? _localizer.t(state.language, 'continue')
                        : _localizer.t(state.language, 'skip'),
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
                    label: _visualStageHasSelection(state, BodyView.back)
                        ? _localizer.t(state.language, 'continue')
                        : _localizer.t(state.language, 'skip'),
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
    final severityDescriptorKey = switch (severity) {
      <= 3 => 'severityDescriptorLow',
      <= 6 => 'severityDescriptorModerate',
      <= 8 => 'severityDescriptorHigh',
      _ => 'severityDescriptorEmergency',
    };

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
          descriptor: _localizer.t(state.language, severityDescriptorKey),
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
    final selectedAnswer = state.questionAnswers['duration'];
    final choices = [
      _choice(state.language, DurationInterpreter.lessThanOneDay, '<1 day'),
      _choice(state.language, DurationInterpreter.oneToThreeDays, '1-3 days'),
      _choice(state.language, DurationInterpreter.fourToSevenDays, '4-7 days'),
      _choice(state.language, DurationInterpreter.moreThanSevenDays, '>7 days'),
    ];
    final answer = selectedAnswer ?? DurationInterpreter.lessThanOneDay;
    return _wrapStep(
      state: state,
      style: style,
      children: [
        _title(
          style,
          _localizer.t(state.language, 'durationTitle'),
          _localizer.t(state.language, 'durationSubtitle'),
        ),
        _voiceQuestionControls(state),
        const SizedBox(height: 18),
        _singleChoiceOptionsGrid(
          state: state,
          style: style,
          questionId: 'duration',
          selected: selectedAnswer,
          choices: choices,
        ),
        const SizedBox(height: 24),
        SacaPrimaryButton(
          label: _localizer.t(state.language, 'continue'),
          icon: CupertinoIcons.arrow_right_circle,
          filled: true,
          onPressed: () {
            _controller.answerQuestion('duration', answer);
            _controller.nextQuestion();
          },
        ),
      ],
    );
  }

  Widget _relatedSymptomsStep(
    BuildContext context,
    SacaFlowState state,
    SacaPlatformStyle style,
  ) {
    final otherText = state.questionAnswers['related_other'] ?? '';
    final showOther = state.questionAnswers.containsKey('related_other');
    final answered =
        (state.questionAnswers['related_symptoms'] ?? '').isNotEmpty ||
            otherText.trim().isNotEmpty;
    final suggestedIds = state.suggestedRelatedSymptomIds.toSet();

    final orderedSymptoms = <Symptom>[
      for (final id in state.suggestedRelatedSymptomIds)
        if (SacaFlowState.relatedSymptoms.any((symptom) => symptom.id == id))
          SacaFlowState.relatedSymptoms
              .firstWhere((symptom) => symptom.id == id),
      for (final symptom in SacaFlowState.relatedSymptoms)
        if (!suggestedIds.contains(symptom.id)) symptom,
    ];
    final compactSymptoms = orderedSymptoms.take(8).toList();

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
          Text(
            _localizer.t(state.language, 'suggestedFromFirstSymptom'),
            style: SacaTheme.small.copyWith(
              color: SacaThemeColors.of(context).mutedText,
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
            for (final symptom in compactSymptoms)
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
            SacaChipButton(
              label: _localizer.t(state.language, 'relatedOtherPlaceholder'),
              selected: showOther || otherText.trim().isNotEmpty,
              onPressed: () => showOther
                  ? _controller.updateQuestionAnswer('related_other', '')
                  : _controller.showQuestionAnswerField('related_other'),
            ),
          ],
        ),
        if (showOther || otherText.trim().isNotEmpty) ...[
          const SizedBox(height: 12),
          _SacaTextField(
            key: const ValueKey('relatedOtherField'),
            value: otherText,
            placeholder:
                _localizer.t(state.language, 'relatedOtherPlaceholder'),
            minLines: 1,
            maxLines: 2,
            onChanged: (value) =>
                _controller.updateQuestionAnswer('related_other', value),
          ),
        ],
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
          state.language,
          'sick contact or travel',
          'Sick contact or travel',
        ),
        _choice(
          state.language,
          'sleep or stress change',
          'Sleep or stress change',
        ),
        _choice(state.language, 'not sure health change', 'Not sure'),
      ],
      nextLabel: _localizer.t(state.language, 'continue'),
      onNext: _controller.nextQuestion,
    );
  }

  Widget _reviewStep(
    BuildContext context,
    SacaFlowState state,
    SacaPlatformStyle style,
  ) {
    final canAddMore = state.addMoreCount < 2;
    return _wrapStep(
      style: style,
      state: state,
      children: [
        _title(
          style,
          _localizer.t(state.language, 'reviewTitle'),
          _localizer.t(state.language, 'reviewSubtitle'),
        ),
        const SizedBox(height: 18),
        _ReviewSummaryCard(
          title: _localizer.t(state.language, 'reviewInput'),
          value: _reviewInputSummary(state),
          actionLabel: _localizer.t(state.language, 'edit'),
          onAction: () => _controller.chooseInputMethod(
            state.inputMethod ?? InputMethod.text,
          ),
        ),
        const SizedBox(height: 12),
        _ReviewSummaryCard(
          title: _localizer.t(state.language, 'reviewQuestions'),
          value: _reviewQuestionSummary(state),
          actionLabel: _localizer.t(state.language, 'edit'),
          onAction: () => _controller.goBack(),
        ),
        const SizedBox(height: 22),
        SacaPrimaryButton(
          key: const ValueKey('reviewAnalyseButton'),
          label: _localizer.t(state.language, 'analyse'),
          icon: CupertinoIcons.waveform_path_ecg,
          filled: true,
          onPressed: _controller.analyse,
        ),
        const SizedBox(height: 10),
        SacaPrimaryButton(
          key: const ValueKey('reviewAddMoreButton'),
          label: canAddMore
              ? _localizer.t(state.language, 'addMoreInfo')
              : _localizer.t(state.language, 'addMoreLimit'),
          icon: CupertinoIcons.plus_circle,
          onPressed: canAddMore ? _controller.addMoreInformation : null,
        ),
      ],
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

  String _symptomImageFor(String symptomId) {
    return switch (symptomId) {
      'headache' => 'assets/Images/Headache.png',
      'fever' => 'assets/Images/Fever.png',
      'stomachache' => 'assets/Images/Stomachache.png',
      'sore_throat' => 'assets/Images/Sore Throat.png',
      'chest_pain' => 'assets/Images/Chest Pain.png',
      'breathing_trouble' => 'assets/Images/Breathing Trouble.png',
      'vomiting' => 'assets/Images/Vomiting.png',
      'bloating' => 'assets/Images/Bloating.png',
      'cough' => 'assets/Images/Cough.png',
      'skin_itch' => 'assets/Images/Skin Itch.png',
      'sneezing' => 'assets/Images/Sneeze.png',
      _ => 'assets/Images/Cough.png',
    };
  }

  bool _visualStageHasSelection(SacaFlowState state, BodyView view) {
    return SacaFlowState.bodyAreas
        .where((area) => area.view == view)
        .any((area) => state.selectedBodyAreaIds.contains(area.id));
  }

  String _reviewInputSummary(SacaFlowState state) {
    final parts = <String>[
      if (state.textInput.trim().isNotEmpty) state.textInput.trim(),
      if (state.transcript.trim().isNotEmpty) state.transcript.trim(),
      ...SacaFlowState.symptoms
          .where((symptom) => state.selectedSymptomIds.contains(symptom.id))
          .map((symptom) =>
              _localizer.compactSymptomLabel(state.language, symptom)),
      ...SacaFlowState.bodyAreas
          .where((area) => state.selectedBodyAreaIds.contains(area.id))
          .map((area) => _localizer.compactBodyAreaLabel(state.language, area)),
    ];
    return parts.isEmpty
        ? _localizer.t(state.language, 'selectedEmpty')
        : parts.join(', ');
  }

  String _reviewQuestionSummary(SacaFlowState state) {
    if (state.questionAnswers.isEmpty) {
      return _localizer.t(state.language, 'notSelected');
    }
    return state.questionAnswers.entries
        .where((entry) => entry.value.trim().isNotEmpty)
        .map((entry) => entry.value
            .split('|')
            .map((value) => _reviewAnswerLabel(state, entry.key, value))
            .join(', '))
        .join(' • ');
  }

  String _reviewAnswerLabel(
    SacaFlowState state,
    String questionId,
    String value,
  ) {
    if (questionId == 'related_symptoms') {
      for (final symptom in SacaFlowState.relatedSymptoms) {
        if (symptom.id == value) {
          return _localizer.compactSymptomLabel(state.language, symptom);
        }
      }
    }
    return _localizer.choiceLabel(state.language, value, value);
  }
}

class _VisualSymptomCard extends StatelessWidget {
  const _VisualSymptomCard({
    required this.label,
    required this.imagePath,
    required this.selected,
    required this.onPressed,
    this.secondaryLabel,
  });

  final String label;
  final String? secondaryLabel;
  final String imagePath;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: secondaryLabel == null ? label : '$label, $secondaryLabel',
      child: SizedBox(
        width: double.infinity,
        child: CupertinoButton(
          padding: EdgeInsets.zero,
          minimumSize: const Size(
            SacaTheme.minTapTarget,
            SacaTheme.minTapTarget,
          ),
          onPressed: onPressed,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOutCubic,
            width: double.infinity,
            height: 210,
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
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
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Center(
                    child: AnimatedScale(
                      duration: const Duration(milliseconds: 160),
                      curve: Curves.easeOutCubic,
                      scale: selected ? 1.04 : 1,
                      child: Image.asset(
                        imagePath,
                        width: 140,
                        height: 140,
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.high,
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(
                            CupertinoIcons.photo,
                            size: 48,
                            color: SacaTheme.text,
                          );
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: SacaTheme.body.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (secondaryLabel != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    secondaryLabel!,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: SacaTheme.small,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
