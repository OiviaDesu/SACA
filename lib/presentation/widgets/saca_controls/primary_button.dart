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
    final enabled = onPressed != null;
    final foreground = filled ? SacaTheme.surface : colors.text;

    return CupertinoButton(
      minimumSize: const Size(0, SacaTheme.minTapTarget),
      padding: EdgeInsets.zero,
      pressedOpacity: 1,
      onPressed: onPressed,
      child: _SacaInteractiveSurface(
        surfaceKey: _controlSurfaceKey(key),
        enabled: enabled,
        selected: filled,
        baseGradient: colors.surfaceGradient,
        selectedGradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.accent,
            Color(0xFFE85D75),
          ],
        ),
        baseBorderColor: colors.border,
        selectedBorderColor: colors.accent,
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
