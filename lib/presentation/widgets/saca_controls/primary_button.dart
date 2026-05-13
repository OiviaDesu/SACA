part of '../saca_controls.dart';

class SacaPrimaryButton extends StatelessWidget {
  const SacaPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.filled = false,
    this.autofocus = false,
    this.focusNode,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool filled;
  final bool autofocus;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    final colors = SacaThemeColors.of(context);
    final theme = SacaThemeContext.of(context);
    final enabled = onPressed != null;
    final foreground = !enabled
        ? colors.onDisabledControl
        : filled
            ? colors.onControl
            : colors.onSurface;
    if (theme.useClassic) {
      final content = Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 22, color: foreground),
            const SizedBox(width: 10),
          ],
          Flexible(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: SacaTheme.body.copyWith(color: foreground),
            ),
          ),
        ],
      );
      final callback = enabled
          ? () {
              unawaited(filled ? SacaHaptics.confirm() : SacaHaptics.tap());
              onPressed?.call();
            }
          : null;
      return ConstrainedBox(
        constraints: const BoxConstraints(minHeight: SacaTheme.minTapTarget),
        child: filled
            ? FilledButton(onPressed: callback, child: content)
            : OutlinedButton(onPressed: callback, child: content),
      );
    }

    return CupertinoButton(
      minimumSize: const Size(0, SacaTheme.minTapTarget),
      padding: EdgeInsets.zero,
      pressedOpacity: 1,
      onPressed: enabled
          ? () {
              unawaited(filled ? SacaHaptics.confirm() : SacaHaptics.tap());
              onPressed?.call();
            }
          : null,
      child: _SacaInteractiveSurface(
        surfaceKey: _controlSurfaceKey(key),
        enabled: enabled,
        selected: filled,
        baseGradient: colors.surfaceGradient,
        selectedGradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.control,
            colors.selectedBorder,
          ],
        ),
        baseBorderColor: colors.border,
        selectedBorderColor: enabled ? colors.control : colors.fieldOutline,
        autofocus: autofocus,
        focusNode: focusNode,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: SacaTheme.minTapTarget,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 22, color: foreground),
                  const SizedBox(width: 10),
                ],
                Flexible(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: SacaTheme.body.copyWith(color: foreground),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
