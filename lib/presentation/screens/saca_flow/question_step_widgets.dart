part of '../saca_flow_screen.dart';

extension _SacaFlowQuestionStepWidgets on _SacaFlowScreenState {
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
    final voiceCueIds = state.voiceCueSuggestedSymptomIds.toSet();
    final relatedById = {
      for (final symptom in SacaFlowState.relatedSymptoms) symptom.id: symptom,
    };

    final orderedSymptoms = <Symptom>[
      if (relatedById['none'] != null) relatedById['none']!,
      for (final id in state.suggestedRelatedSymptomIds)
        if (id != 'none' && relatedById[id] != null) relatedById[id]!,
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
          Text(
            _localizer.t(
              state.language,
              voiceCueIds.isNotEmpty
                  ? 'suggestedFromVoiceCues'
                  : 'suggestedFromFirstSymptom',
            ),
            style: SacaTheme.small.copyWith(
              color: SacaThemeColors.of(context).onSurfaceMuted,
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
                highlighted: voiceCueIds.contains(symptom.id),
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

  Widget _skinDetailsStep(
    BuildContext context,
    SacaFlowState state,
    SacaPlatformStyle style,
  ) {
    return _singleChoiceQuestion(
      state: state,
      style: style,
      title: _localizer.t(state.language, 'skinDetailsTitle'),
      subtitle: _localizer.t(state.language, 'skinDetailsSubtitle'),
      questionId: 'skin_details',
      choices: [
        _choice(state.language, 'itching at night', 'Itching at night'),
        _choice(
          state.language,
          'between fingers or wrists',
          'Between fingers or wrists',
        ),
        _choice(state.language, 'new medicine', 'New medicine'),
        _choice(state.language, 'spreading rash', 'Spreading rash'),
        _choice(state.language, 'none', 'None / not sure'),
      ],
      nextLabel: _localizer.t(state.language, 'continue'),
      onNext: _controller.nextQuestion,
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
}
