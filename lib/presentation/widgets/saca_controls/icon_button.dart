part of '../saca_controls.dart';

class SacaIconButton extends StatelessWidget {
  const SacaIconButton({
    super.key,
    required this.semanticLabel,
    required this.icon,
    required this.onPressed,
    this.destructive = false,
    this.selected = false,
    this.minimumSize = const Size.square(44),
  });

  final String semanticLabel;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool destructive;
  final bool selected;
  final Size minimumSize;

  @override
  Widget build(BuildContext context) {
    final colors = SacaThemeColors.of(context);
    final enabled = onPressed != null;
    final color = destructive ? SacaTheme.emergency : colors.text;
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: minimumSize,
      pressedOpacity: 1,
      onPressed: enabled
          ? () {
              unawaited(
                destructive ? SacaHaptics.warning() : SacaHaptics.tap(),
              );
              onPressed?.call();
            }
          : null,
      child: Semantics(
        label: semanticLabel,
        button: true,
        enabled: enabled,
        child: _SacaInteractionMotion(
          enabled: enabled,
          borderRadius: BorderRadius.circular(12),
          hoverColor: destructive
              ? SacaTheme.emergency.withValues(alpha: 0.10)
              : colors.selected.withValues(alpha: selected ? 0.90 : 0.72),
          pressedColor: destructive
              ? SacaTheme.emergency.withValues(alpha: 0.16)
              : colors.selectedBorder.withValues(alpha: 0.14),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              color: selected
                  ? colors.selected.withValues(alpha: 0.78)
                  : CupertinoColors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: selected
                  ? Border.all(
                      color: colors.selectedBorder.withValues(alpha: 0.36),
                    )
                  : null,
            ),
            child: SizedBox.fromSize(
              size: minimumSize,
              child: Icon(
                icon,
                color: enabled ? color : colors.border,
                size: 22,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
