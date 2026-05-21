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
    this.subdued = false,
    this.minHeight,
  });

  final String label;
  final VoidCallback? onPressed;
  final String? description;
  final IconData? icon;
  final bool selected;
  final bool autofocus;
  final FocusNode? focusNode;
  final bool subdued;
  final double? minHeight;

  @override
  Widget build(BuildContext context) {
    final colors = SacaThemeColors.of(context);
    final theme = SacaThemeContext.of(context);
    final enabled = onPressed != null;
    final effectiveMinHeight = minHeight ?? SacaTheme.minTapTarget;
    final selectedForeground =
        theme.useGlassStyle ? colors.onControl : colors.onSelected;
    if (theme.useClassic) {
      final classicForeground = subdued
          ? colors.onSurfaceMuted
          : selected
              ? colors.onControl
              : colors.onSurface;
      final classicMuted =
          selected && !subdued ? colors.onControl : colors.onSurfaceMuted;
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
                    Text(
                      label,
                      style: SacaTheme.body.copyWith(color: classicForeground),
                    ),
                    if (description != null) ...[
                      const SizedBox(height: 5),
                      Text(
                        description!,
                        style: SacaTheme.small.copyWith(color: classicMuted),
                      ),
                    ],
                  ],
                ),
              ),
              if (selected)
                Icon(Icons.check_circle, size: 22, color: classicForeground),
              if (!selected && icon != null)
                Icon(icon, size: 22, color: classicForeground),
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
      minimumSize: Size(0, effectiveMinHeight),
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
        selected: selected && !subdued,
        baseGradient: colors.surfaceGradient,
        selectedGradient: colors.selectedGradient,
        baseBorderColor: colors.border,
        selectedBorderColor: colors.selectedBorder,
        autofocus: autofocus,
        focusNode: focusNode,
        child: SizedBox(
          width: double.infinity,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: effectiveMinHeight,
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
                          style: SacaTheme.body.copyWith(
                            color: subdued
                                ? colors.onSurfaceMuted
                                : selected
                                    ? selectedForeground
                                    : colors.onSurface,
                          ),
                          overflow: TextOverflow.visible,
                        ),
                        if (description != null) ...[
                          const SizedBox(height: 5),
                          Text(
                            description!,
                            style: SacaTheme.small
                                .copyWith(color: colors.onSurfaceMuted),
                            overflow: TextOverflow.visible,
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (icon != null)
                    Icon(
                      icon,
                      size: 24,
                      color: subdued
                          ? colors.onSurfaceMuted
                          : selected
                              ? selectedForeground
                              : colors.onSurface,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
