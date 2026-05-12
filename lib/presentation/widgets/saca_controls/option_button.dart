part of '../saca_controls.dart';

class SacaOptionButton extends StatelessWidget {
  const SacaOptionButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.description,
    this.icon,
    this.selected = false,
    this.autofocus = false,
    this.focusNode,
  });

  final String label;
  final VoidCallback? onPressed;
  final String? description;
  final IconData? icon;
  final bool selected;
  final bool autofocus;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    final colors = SacaThemeColors.of(context);
    final theme = SacaThemeContext.of(context);
    final enabled = onPressed != null;
    if (theme.useClassic) {
      final content = SizedBox(
        width: double.infinity,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: SacaTheme.body),
                    if (description != null) ...[
                      const SizedBox(height: 5),
                      Text(
                        description!,
                        style: SacaTheme.small.copyWith(color: colors.mutedText),
                      ),
                    ],
                  ],
                ),
              ),
              if (selected) const Icon(Icons.check_circle, size: 22),
              if (!selected && icon != null) Icon(icon, size: 22),
            ],
          ),
        ),
      );
      final callback = enabled
          ? () {
              unawaited(SacaHaptics.selection());
              onPressed?.call();
            }
          : null;
      return selected
          ? FilledButton(onPressed: callback, child: content)
          : OutlinedButton(onPressed: callback, child: content);
    }
    return CupertinoButton(
      minimumSize: const Size(0, SacaTheme.minTapTarget),
      padding: EdgeInsets.zero,
      pressedOpacity: 1,
      onPressed: enabled
          ? () {
              unawaited(SacaHaptics.selection());
              onPressed?.call();
            }
          : null,
      child: _SacaInteractiveSurface(
        surfaceKey: _controlSurfaceKey(key),
        enabled: enabled,
        selected: selected,
        baseGradient: colors.surfaceGradient,
        selectedGradient: colors.selectedGradient,
        baseBorderColor: colors.border,
        selectedBorderColor: colors.selectedBorder,
        autofocus: autofocus,
        focusNode: focusNode,
        child: SizedBox(
          width: double.infinity,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: SacaTheme.minTapTarget,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: SacaTheme.body.copyWith(color: colors.text),
                          overflow: TextOverflow.visible,
                        ),
                        if (description != null) ...[
                          const SizedBox(height: 5),
                          Text(
                            description!,
                            style: SacaTheme.small
                                .copyWith(color: colors.mutedText),
                            overflow: TextOverflow.visible,
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (icon != null) Icon(icon, size: 24, color: colors.text),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
