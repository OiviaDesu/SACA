part of '../saca_controls.dart';

class SacaChipButton extends StatelessWidget {
  const SacaChipButton({
    super.key,
    required this.label,
    required this.selected,
    required this.onPressed,
    this.autofocus = false,
    this.focusNode,
    this.highlighted = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onPressed;
  final bool autofocus;
  final FocusNode? focusNode;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final colors = SacaThemeColors.of(context);
    final theme = SacaThemeContext.of(context);
    if (theme.useClassic) {
      void callback() {
        unawaited(SacaHaptics.selection());
        onPressed();
      }
      final child = Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(fontWeight: FontWeight.w600),
      );
      return selected
          ? FilledButton(onPressed: callback, child: child)
          : OutlinedButton(onPressed: callback, child: child);
    }
    return CupertinoButton(
      minimumSize: const Size(0, 42),
      padding: EdgeInsets.zero,
      pressedOpacity: 1,
      onPressed: () {
        unawaited(SacaHaptics.selection());
        onPressed();
      },
      child: _SacaInteractiveSurface(
        surfaceKey: _controlSurfaceKey(key),
        enabled: true,
        selected: selected,
        baseGradient: colors.surfaceGradient,
        selectedGradient: colors.selectedGradient,
        baseBorderColor: highlighted
            ? colors.selectedBorder.withValues(alpha: 0.55)
            : colors.border,
        selectedBorderColor: colors.selectedBorder,
        autofocus: autofocus,
        focusNode: focusNode,
        baseShadow: highlighted
            ? SacaThemeContext.of(context).surfaceShadow(highlighted: true)
            : const [],
        hoverShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
        pressedShadow: const [],
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 22),
            child: Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.visible,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                letterSpacing: 0,
                color: colors.text,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
