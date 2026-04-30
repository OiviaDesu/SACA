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
    return CupertinoButton(
      minimumSize: const Size(0, SacaTheme.minTapTarget),
      padding: EdgeInsets.zero,
      pressedOpacity: 1,
      onPressed: onPressed,
      child: _SacaInteractiveSurface(
        surfaceKey: _controlSurfaceKey(key),
        enabled: onPressed != null,
        selected: selected,
        baseGradient: SacaTheme.surfaceGradient,
        selectedGradient: SacaTheme.selectedGradient,
        baseBorderColor: SacaTheme.border,
        selectedBorderColor: SacaTheme.selectedBorder,
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
                          style: SacaTheme.body,
                          overflow: TextOverflow.visible,
                        ),
                        if (description != null) ...[
                          const SizedBox(height: 5),
                          Text(
                            description!,
                            style: SacaTheme.small,
                            overflow: TextOverflow.visible,
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (icon != null) Icon(icon, size: 24, color: SacaTheme.text),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
