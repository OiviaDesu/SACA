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
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: SacaTheme.body.copyWith(
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
            Text(value, style: SacaTheme.small.copyWith(color: SacaTheme.text)),
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
