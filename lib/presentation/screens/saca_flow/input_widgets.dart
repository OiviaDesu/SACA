part of '../saca_flow_screen.dart';

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
    final colors = SacaThemeColors.of(context);
    final text = values.isEmpty ? emptyText : values.join(', ');
    return DecoratedBox(
      decoration: _sacaPanelDecoration(context),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: SacaTheme.small.copyWith(color: colors.onSurface),
            ),
            const SizedBox(height: 6),
            Text(text, style: SacaTheme.body.copyWith(color: colors.onSurface)),
          ],
        ),
      ),
    );
  }
}

class _ReviewSummaryCard extends StatelessWidget {
  const _ReviewSummaryCard({
    required this.title,
    required this.value,
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final String value;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final colors = SacaThemeColors.of(context);
    return DecoratedBox(
      decoration: _sacaPanelDecoration(context),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: SacaTheme.body.copyWith(
                      color: colors.onSurface,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                CupertinoButton(
                  minimumSize: Size.zero,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  onPressed: onAction,
                  child: Text(
                    actionLabel,
                    style: SacaTheme.small.copyWith(
                      color: SacaTheme.accent,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(value,
                style: SacaTheme.small.copyWith(color: colors.onSurface)),
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
    final colors = SacaThemeColors.of(context);
    return CupertinoTextField(
      controller: _textController,
      minLines: widget.minLines,
      maxLines: widget.maxLines,
      placeholder: widget.placeholder,
      padding: const EdgeInsets.all(16),
      onChanged: widget.onChanged,
      style: SacaTheme.body.copyWith(color: colors.onFieldSurface),
      placeholderStyle: SacaTheme.body.copyWith(
        color: colors.onFieldSurface.withValues(alpha: 0.72),
      ),
      decoration: _sacaFieldDecoration(context),
    );
  }
}

BoxDecoration _sacaFieldDecoration(BuildContext context) {
  final theme = SacaThemeContext.of(context);
  final colors = theme.colors;
  if (!theme.useGlassStyle) {
    return _sacaPanelDecoration(context);
  }
  final field = theme.glassMaterial(SacaGlassMaterial.field);
  return BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        field.withValues(alpha: theme.glassOpacity(SacaGlassMaterial.field)),
        colors.glassScrim.withValues(alpha: theme.scrimOpacity),
      ],
    ),
    color: field.withValues(alpha: theme.glassOpacity(SacaGlassMaterial.field)),
    borderRadius: BorderRadius.circular(theme.radius(18)),
    border: Border.all(color: colors.glassBorder.withValues(alpha: 0.88)),
    boxShadow: [
      BoxShadow(
        color: colors.glassHighlight.withValues(alpha: theme.glowOpacity),
        blurRadius: 24,
        offset: const Offset(0, 10),
      ),
    ],
  );
}

class _RecordingButton extends StatefulWidget {
  const _RecordingButton({
    required this.label,
    required this.isRecording,
    required this.onPressed,
  });

  final String label;
  final bool isRecording;
  final VoidCallback? onPressed;

  @override
  State<_RecordingButton> createState() => _RecordingButtonState();
}

class _RecordingButtonState extends State<_RecordingButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    if (widget.isRecording) _controller.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant _RecordingButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isRecording && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.isRecording && _controller.isAnimating) {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = SacaThemeColors.of(context);
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        if (!widget.isRecording) {
          return Center(
            child: SacaPrimaryButton(
              label: widget.label,
              icon: CupertinoIcons.mic_fill,
              filled: true,
              onPressed: widget.onPressed,
            ),
          );
        }
        return Semantics(
          label: 'Recording in progress',
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: colors.selectedBorder.withValues(alpha: 0.42),
              ),
              boxShadow: [
                BoxShadow(
                  color: colors.accent.withValues(alpha: 0.12),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  _RecordingDot(progress: _controller.value),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Listening… Speak clearly',
                          style: SacaTheme.body.copyWith(
                            color: colors.onSurface,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        _MiniWaveform(progress: _controller.value),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  SacaPrimaryButton(
                    label: widget.label,
                    icon: CupertinoIcons.stop_fill,
                    filled: false,
                    onPressed: widget.onPressed,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _RecordingDot extends StatelessWidget {
  const _RecordingDot({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final color = SacaThemeColors.of(context).accent;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12 + progress * 0.16),
        shape: BoxShape.circle,
      ),
      child: Padding(
        padding: const EdgeInsets.all(7),
        child: DecoratedBox(
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          child: const SizedBox(width: 10, height: 10),
        ),
      ),
    );
  }
}

class _MiniWaveform extends StatelessWidget {
  const _MiniWaveform({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final colors = SacaThemeColors.of(context);
    final heights = <double>[
      8 + progress * 8,
      16 - progress * 6,
      10 + progress * 10,
      18 - progress * 8,
      9 + progress * 7,
    ];
    return Row(
      children: [
        for (final height in heights) ...[
          DecoratedBox(
            decoration: BoxDecoration(
              color: colors.accent.withValues(alpha: 0.58),
              borderRadius: BorderRadius.circular(99),
            ),
            child: SizedBox(width: 4, height: height),
          ),
          const SizedBox(width: 4),
        ],
      ],
    );
  }
}
