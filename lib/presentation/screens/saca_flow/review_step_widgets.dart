part of '../saca_flow_screen.dart';

extension _SacaFlowReviewStepWidgets on _SacaFlowScreenState {
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
