part of '../saca_flow_screen.dart';

class _VoiceQuestionControls extends StatelessWidget {
  const _VoiceQuestionControls({
    required this.state,
    required this.localizer,
    required this.onStartRecording,
    required this.onStopRecording,
  });

  final SacaFlowState state;
  final SacaLocalizer localizer;
  final VoidCallback onStartRecording;
  final VoidCallback onStopRecording;

  @override
  Widget build(BuildContext context) {
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
                ? localizer.t(state.language, 'stopVoiceAnswer')
                : localizer.t(state.language, 'answerByVoice'),
            icon: state.isRecording
                ? CupertinoIcons.stop_circle
                : CupertinoIcons.mic,
            onPressed: state.isBusy
                ? null
                : state.isRecording
                    ? onStopRecording
                    : onStartRecording,
          ),
          if (heard.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              '${localizer.t(state.language, 'voiceAnswerHeard')} $heard',
              key: const ValueKey('voiceQuestionHeard'),
              textAlign: TextAlign.center,
              style: SacaTheme.small,
            ),
          ],
          if (!state.voiceAnswerMatched) ...[
            const SizedBox(height: 6),
            Text(
              localizer.t(state.language, 'voiceAnswerNotMatched'),
              key: const ValueKey('voiceQuestionNotMatched'),
              textAlign: TextAlign.center,
              style: SacaTheme.small.copyWith(color: SacaTheme.emergency),
            ),
          ],
        ],
      ),
    );
  }
}

class _VoiceDraftNotice extends StatelessWidget {
  const _VoiceDraftNotice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = SacaThemeColors.of(context);
    return Semantics(
      label: message,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colors.border),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: SacaTheme.small.copyWith(color: colors.onSurfaceMuted),
          ),
        ),
      ),
    );
  }
}
